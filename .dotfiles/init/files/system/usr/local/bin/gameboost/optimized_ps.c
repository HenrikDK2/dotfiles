#define _GNU_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <linux/types.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/syscall.h>
#include <unistd.h>

#define MAX_WORKERS 8
#define GETDENTS_BUF_SIZE (256 * 1024)
#define CMD_BUF_SIZE 4096
#define OUT_BUF_SIZE (1024 * 1024)
#define MAX_PIDS 131072

struct linux_dirent64 {
  uint64_t ino;
  int64_t off;
  unsigned short reclen;
  unsigned char type;
  char name[];
};

struct process {
  char pid[16];
  uint8_t len;
};

struct worker {
  int procfd;
  const struct process *items;
  size_t count;
  _Atomic size_t *next;
  size_t chunk;
  char *out;
  size_t outpos;
};

static inline void flush(struct worker *w) {
  size_t n = 0;

  while (n < w->outpos) {
    ssize_t r = write(1, w->out + n, w->outpos - n);

    if (r > 0)
      n += (size_t)r;
    else if (r < 0 && errno == EINTR)
      continue;
    else
      break;
  }

  w->outpos = 0;
}

static inline int is_pid(const char *s) {
  unsigned char c = (unsigned char)*s;

  if (c < '0' || c > '9')
    return 0;

  while ((c = (unsigned char)*++s) >= '0' && c <= '9')
    ;

  return c == '\0';
}

/*
 * Reads /proc/<pid>/cmdline directly into the output buffer and does the
 * NUL -> space translation in place, instead of reading into a stack
 * buffer and then copying segment-by-segment into the output buffer.
 * This halves the number of passes over the cmdline bytes.
 */
static inline void process_one(struct worker *w, const struct process *p) {
  char path[24];

  memcpy(path, p->pid, p->len);
  memcpy(path + p->len, "/cmdline", 9);

  int fd = openat(w->procfd, path, O_RDONLY);

  if (fd < 0)
    return;

  /* worst case this entry can add: pid + ' ' + CMD_BUF_SIZE + '\n' */
  size_t need = (size_t)p->len + 1 + CMD_BUF_SIZE + 1;

  if (need > OUT_BUF_SIZE - w->outpos)
    flush(w);

  if (need > OUT_BUF_SIZE) {
    /* Shouldn't happen given the constants above, but stay safe. */
    close(fd);
    return;
  }

  size_t start = w->outpos;

  memcpy(w->out + w->outpos, p->pid, p->len);
  w->outpos += p->len;
  w->out[w->outpos++] = ' ';

  char *dst = w->out + w->outpos;
  ssize_t n;

  do {
    n = read(fd, dst, CMD_BUF_SIZE);
  } while (n < 0 && errno == EINTR);

  close(fd);

  if (n < 0) {
    /* Roll back the pid/space we already wrote for this entry. */
    w->outpos = start;
    return;
  }

  if (n > 0) {
    for (ssize_t i = 0; i < n; ++i)
      if (dst[i] == '\0')
        dst[i] = ' ';

    w->outpos += (size_t)n;

    /* cmdline is NUL-terminated, which we just turned into a trailing
     * space; drop it so output matches the original "join with single
     * spaces, no trailing space" behavior. */
    if (w->out[w->outpos - 1] == ' ')
      w->outpos--;
  }

  w->out[w->outpos++] = '\n';
}

static void *worker_main(void *arg) {
  struct worker *w = arg;

  for (;;) {
    /* Claim work in chunks instead of one PID at a time to cut atomic
     * RMW/cache-line-bounce traffic. Chunk size is sized per-run (see
     * main) so this only kicks in once there's actually enough work to
     * spread across threads several times over; for small process
     * counts it degrades to chunk=1, i.e. the original fine-grained
     * behavior, so small runs don't lose parallelism. */
    size_t base =
        atomic_fetch_add_explicit(w->next, w->chunk, memory_order_relaxed);

    if (base >= w->count)
      break;

    size_t end = base + w->chunk;

    if (end > w->count)
      end = w->count;

    for (size_t i = base; i < end; ++i)
      process_one(w, &w->items[i]);
  }

  flush(w);
  return NULL;
}

int main(void) {
  int procfd = open("/proc", O_RDONLY | O_DIRECTORY | O_CLOEXEC);

  if (procfd < 0)
    return 1;

  struct process *items = malloc(sizeof(*items) * MAX_PIDS);

  char *dirbuf = malloc(GETDENTS_BUF_SIZE);

  if (!items || !dirbuf) {
    free(items);
    free(dirbuf);
    close(procfd);
    return 1;
  }

  size_t count = 0;

  for (;;) {
    long n = syscall(SYS_getdents64, procfd, dirbuf, GETDENTS_BUF_SIZE);

    if (n == 0)
      break;

    if (n < 0) {
      if (errno == EINTR)
        continue;

      free(items);
      free(dirbuf);
      close(procfd);
      return 1;
    }

    for (size_t pos = 0; pos < (size_t)n;) {
      struct linux_dirent64 *e = (void *)(dirbuf + pos);

      if (!e->reclen)
        break;

      if (count < MAX_PIDS && is_pid(e->name)) {

        size_t len = strlen(e->name);

        memcpy(items[count].pid, e->name, len + 1);

        items[count].len = (uint8_t)len;

        ++count;
      }

      pos += e->reclen;
    }

    if (count == MAX_PIDS)
      break;
  }

  free(dirbuf);

  long cpus = sysconf(_SC_NPROCESSORS_ONLN);

  if (cpus < 1)
    cpus = 1;

  size_t worker_count = (size_t)cpus;

  if (worker_count > MAX_WORKERS)
    worker_count = MAX_WORKERS;

  if (worker_count > count)
    worker_count = count;

  if (!worker_count)
    worker_count = 1;

  pthread_t threads[MAX_WORKERS];
  struct worker workers[MAX_WORKERS];

  _Atomic size_t next = 0;
  size_t created = 0;

  /* Aim for ~8 chunks per worker so load balances even if some PIDs are
   * much more expensive than others (e.g. huge cmdlines), while cutting
   * atomic traffic roughly (count / (worker_count * 8))-fold on large
   * runs. Clamped to >= 1 so small process counts (fewer than
   * worker_count * 8) fall back to one-PID-at-a-time claims, i.e. the
   * original's full parallelism, instead of serializing onto one thread. */
  size_t chunk = count / (worker_count * 8);

  if (chunk < 1)
    chunk = 1;

  for (; created < worker_count; ++created) {
    workers[created].procfd = procfd;
    workers[created].items = items;
    workers[created].count = count;
    workers[created].next = &next;
    workers[created].chunk = chunk;
    workers[created].outpos = 0;
    workers[created].out = malloc(OUT_BUF_SIZE);

    if (!workers[created].out)
      break;

    if (pthread_create(&threads[created], NULL, worker_main,
                       &workers[created])) {
      free(workers[created].out);
      workers[created].out = NULL;
      break;
    }
  }

  for (size_t i = 0; i < created; ++i)
    pthread_join(threads[i], NULL);

  for (size_t i = 0; i < created; ++i)
    free(workers[i].out);

  free(items);
  close(procfd);

  return 0;
}
