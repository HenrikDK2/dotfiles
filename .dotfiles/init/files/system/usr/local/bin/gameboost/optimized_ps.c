#define _GNU_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <linux/types.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/syscall.h>
#include <unistd.h>

#define WORKERS            4
#define GETDENTS_BUF_SIZE  (256 * 1024)
#define CMD_BUF_SIZE       65536
#define OUT_BUF_SIZE       (1024 * 1024)
#define MAX_PIDS           131072

struct linux_dirent64 {
    uint64_t       d_ino;
    int64_t        d_off;
    unsigned short d_reclen;
    unsigned char  d_type;
    char           d_name[];
};

struct process {
    char pid[16];
};

struct worker {
    int procfd;
    struct process *items;
    size_t count;
};

static char outbuf[OUT_BUF_SIZE];
static size_t outpos;
static pthread_mutex_t out_lock = PTHREAD_MUTEX_INITIALIZER;

/* --------------------------------------------------------- */

static inline void flush_output_locked(void)
{
    size_t off = 0;

    while (off < outpos) {
        ssize_t n = write(
            STDOUT_FILENO,
            outbuf + off,
            outpos - off
        );

        if (n > 0) {
            off += (size_t)n;
            continue;
        }

        if (n < 0 && errno == EINTR)
            continue;

        break;
    }

    outpos = 0;
}

/* --------------------------------------------------------- */

static inline void output_bytes(
    const char *buf,
    size_t len
)
{
    while (len) {
        size_t space = OUT_BUF_SIZE - outpos;

        if (space == 0) {
            flush_output_locked();
            space = OUT_BUF_SIZE;
        }

        size_t n = len < space ? len : space;

        memcpy(outbuf + outpos, buf, n);
        outpos += n;

        buf += n;
        len -= n;
    }
}

/* --------------------------------------------------------- */

static inline void write_process(
    const char *pid,
    size_t pidlen,
    const char *cmdline,
    ssize_t len
)
{
    pthread_mutex_lock(&out_lock);

    /*
     * ps ax -o pid=,command=
     *
     * ps separates PID and command with whitespace.
     */
    output_bytes(pid, pidlen);
    output_bytes(" ", 1);

    if (len > 0) {
        /*
         * /proc/<pid>/cmdline contains argv[] separated by NULs.
         * ps command= displays those arguments separated by spaces.
         */
        size_t start = 0;

        for (size_t i = 0; i < (size_t)len; ++i) {
            if (cmdline[i] == '\0') {
                if (i > start)
                    output_bytes(cmdline + start, i - start);

                if (i + 1 < (size_t)len)
                    output_bytes(" ", 1);

                start = i + 1;
            }
        }

        if (start < (size_t)len)
            output_bytes(cmdline + start, (size_t)len - start);
    }

    output_bytes("\n", 1);

    pthread_mutex_unlock(&out_lock);
}

/* --------------------------------------------------------- */

static inline int is_pid(const char *s)
{
    unsigned char c = (unsigned char)*s;

    if (c < '0' || c > '9')
        return 0;

    do {
        c = (unsigned char)*++s;
    } while (c >= '0' && c <= '9');

    return c == '\0';
}

/* --------------------------------------------------------- */

static void *worker_main(void *arg)
{
    struct worker *w = arg;

    char path[32];
    char cmdline[CMD_BUF_SIZE];

    for (size_t i = 0; i < w->count; ++i) {
        const char *pid = w->items[i].pid;

        int pathlen = snprintf(
            path,
            sizeof(path),
            "%s/cmdline",
            pid
        );

        if (pathlen < 0 ||
            (size_t)pathlen >= sizeof(path))
            continue;

        int fd = openat(
            w->procfd,
            path,
            O_RDONLY | O_CLOEXEC
        );

        if (fd < 0)
            continue;

        ssize_t len = read(
            fd,
            cmdline,
            sizeof(cmdline)
        );

        close(fd);

        if (len < 0)
            continue;

        write_process(
            pid,
            strlen(pid),
            cmdline,
            len
        );
    }

    return NULL;
}

/* --------------------------------------------------------- */

int main(void)
{
    int procfd = open(
        "/proc",
        O_RDONLY | O_DIRECTORY | O_CLOEXEC
    );

    if (procfd < 0)
        return 1;

    struct process *items =
        malloc(sizeof(*items) * MAX_PIDS);

    if (!items) {
        close(procfd);
        return 1;
    }

    char dirbuf[GETDENTS_BUF_SIZE];
    size_t count = 0;

    for (;;) {
        long nread = syscall(
            SYS_getdents64,
            procfd,
            dirbuf,
            sizeof(dirbuf)
        );

        if (nread == 0)
            break;

        if (nread < 0) {
            if (errno == EINTR)
                continue;

            free(items);
            close(procfd);
            return 1;
        }

        size_t pos = 0;

        while (pos < (size_t)nread) {
            struct linux_dirent64 *e =
                (struct linux_dirent64 *)(dirbuf + pos);

            if (e->d_reclen == 0)
                break;

            if (is_pid(e->d_name) &&
                count < MAX_PIDS) {

                strcpy(items[count].pid, e->d_name);
                ++count;
            }

            pos += e->d_reclen;
        }
    }

    /*
     * Partition PIDs across workers.
     */
    pthread_t threads[WORKERS];
    struct worker workers[WORKERS];

    size_t base = count / WORKERS;
    size_t rem  = count % WORKERS;
    size_t off  = 0;

    for (int i = 0; i < WORKERS; ++i) {
        size_t n = base + ((size_t)i < rem);

        workers[i].procfd = procfd;
        workers[i].items = items + off;
        workers[i].count = n;

        pthread_create(
            &threads[i],
            NULL,
            worker_main,
            &workers[i]
        );

        off += n;
    }

    for (int i = 0; i < WORKERS; ++i)
        pthread_join(threads[i], NULL);

    pthread_mutex_lock(&out_lock);
    flush_output_locked();
    pthread_mutex_unlock(&out_lock);

    free(items);
    close(procfd);

    return 0;
}
