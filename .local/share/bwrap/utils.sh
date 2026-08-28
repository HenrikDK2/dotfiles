#!/bin/bash

trap utils::cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

TRACE_FILE="/tmp/trace.log"
PROXY_SOCKET="$XDG_RUNTIME_DIR/bus-proxy-$$_$RANDOM.sock"
DEBUG=0
EXIT_CODE=0
PROXY_PID=

utils::log() {
	local level=$1 message=$2 color timestamp padding=

	case $level in
		INFO)  color=$'\e[32m' ;;
		WARN)  color=$'\e[33m' ;;
		ERROR) color=$'\e[31m' ;;
		*)     color=$'\e[0m' ;;
	esac

	printf -v timestamp '%(%Y-%m-%d %H:%M:%S)T' -1
	(( LOG_INDENT > 0 )) && printf -v padding '%*s' "$LOG_INDENT" ''
	printf '%s[%s] [%s-%s] [%s] %s%s\e[0m\n' "$color" "$timestamp" "${EXECUTABLE##*/}" "$$" "$level" "$padding" "$message"
}

utils::dbus() {
	(( ${#DBUS_PORTALS[@]} )) || return 0

	utils::log INFO "Starting DBus proxy..."

	local log=
	(( DEBUG )) && log=--log

	xdg-dbus-proxy "$DBUS_SESSION_BUS_ADDRESS" "$PROXY_SOCKET" \
		"${DBUS_PORTALS[@]}" $log --filter &
	PROXY_PID=$!

	utils::log INFO "Waiting for proxy socket..."
	while [[ ! -S $PROXY_SOCKET ]]; do
		if ! kill -0 "$PROXY_PID" 2>/dev/null; then
			utils::log ERROR "DBus proxy exited before creating its socket"
			wait "$PROXY_PID" 2>/dev/null || :
			return 1
		fi
		read -rt 0.01 </dev/null
	done
	utils::log INFO "Proxy ready"

	BWRAP_ARGS+=(
		--dev-bind-try "$PROXY_SOCKET" "$PROXY_SOCKET"
		--dev-bind-try "$XDG_RUNTIME_DIR/bus" "$XDG_RUNTIME_DIR/bus"
		--setenv DBUS_SESSION_BUS_ADDRESS "unix:path=$PROXY_SOCKET"
		--setenv XDG_RUNTIME_DIR "$XDG_RUNTIME_DIR"
		--setenv XDG_SESSION_TYPE "$XDG_SESSION_TYPE"
		--setenv XDG_CURRENT_DESKTOP "$XDG_CURRENT_DESKTOP"
		--setenv XDG_BACKEND "$XDG_BACKEND"
	)
}

utils::kill_existing_process() {
	local pid executable_name=${EXECUTABLE##*/}

	while read -r pid; do
		[[ $pid == $$ ]] && continue

		utils::log WARN "Stopping existing $executable_name process (PID $pid)..."

		if ! kill "$pid" 2>/dev/null; then
			utils::log WARN "Failed to send SIGTERM to PID $pid"
			continue
		fi

		utils::log INFO "Waiting for process $pid to exit..."
		while kill -0 "$pid" 2>/dev/null; do
			read -rt 0.01 </dev/null
		done

		utils::log INFO "Process $pid exited"
	done < <(pgrep -x "$executable_name" || :)
}

utils::cleanup() {
	local cleanup_status=$?

	if [[ -n $PROXY_PID ]]; then
		utils::log INFO "Removing DBus proxy (PID $PROXY_PID)..."
		kill -KILL "$PROXY_PID" 2>/dev/null || :
		rm -f -- "$PROXY_SOCKET"
	fi

	utils::log INFO "Cleanup complete"
	return "$cleanup_status"
}

utils::run() {
	if [[ ${1:-} == --debug ]]; then
		DEBUG=1
		shift
	fi

	utils::dbus || return 1
	utils::log INFO "Launching $EXECUTABLE..."

	if (( ! DEBUG )); then
		bwrap "${BWRAP_ARGS[@]}" "$EXECUTABLE" "$@"
		EXIT_CODE=$?
		exit "$EXIT_CODE"
	fi

	command -v strace >/dev/null 2>&1 || {
		utils::log ERROR "strace is required for --debug but is not installed."
		return 1
	}

	utils::kill_existing_process

	strace -f -tt -s 128 -e trace=all -o "$TRACE_FILE" \
		bwrap "${BWRAP_ARGS[@]}" "$EXECUTABLE" "$@"

	EXIT_CODE=$?
	utils::debug
	exit "$EXIT_CODE"
}

utils::debug() {
	utils::log INFO "Starting debugging..."

	local debug_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/debug" && pwd)"
	source "$debug_dir/lib/normalize_path.sh"
	source "$debug_dir/lib/print_output.sh"

	run_pipeline() {
		local -a items=()
		local -a stages=()
		local stage name before start duration

		mapfile -t stages < <(
			find "$debug_dir/pipeline" \
				-maxdepth 1 \
				-type f \
				-name '*.sh' \
				-print |
				sort -V
		)

		for stage in "${stages[@]}"; do
			name=${stage##*/}
			before=${#items[@]}
			start=$EPOCHREALTIME

			mapfile -t items < <(
				printf '%s\n' "${items[@]}" |
					source "$stage"
			)

			duration=$(
				awk -v start="$start" -v end="$EPOCHREALTIME" \
					'BEGIN { printf "%.6f", (end-start)*1000 }'
			)

			printf \
				'[pipeline] stage: %s\n  - time: %sms\n  - items: %d → %d\n' \
				"${name%.sh}" \
				"$duration" \
				"$before" \
				"${#items[@]}" >&2
		done

		printf '[pipeline] finished stages: %d\n' \
			"${#stages[@]}" >&2

		printf '%s\n' "${items[@]}"
	}

	local -a items=()
	mapfile -t items < <(run_pipeline)

	if [[ ${#items[@]} -eq 0 ]]; then
		utils::log INFO \
			"debug_build_json_suggestions: no recommendations found"
		return
	fi

	utils::log WARN"This dataset comes from strace output, so it includes a lot of paths that the program probably doesn’t actually need."
	utils::log INFO "Profile recommendation:"
	print_output "${items[@]}" 2>/dev/null | tee >(copy_to_clipboard) "/tmp/bwrap-profile.txt"
	utils::log INFO "*Copied to clipboard* - also saved in /tmp/bwrap-profile.txt"
}
