#!/bin/bash

trap utils::cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

PROXY_SOCKET="${XDG_RUNTIME_DIR}/bus-proxy-$(uuidgen).sock"
DEBUG=0
EXIT_CODE=0

LOG_RESET=$'\e[0m'
LOG_INFO=$'\e[32m'
LOG_WARN=$'\e[33m'
LOG_ERROR=$'\e[31m'

utils::log() {
	local level=$1 message=$2
	local color

	case $level in
		INFO)  color=$'\e[32m' ;;
		WARN)  color=$'\e[33m' ;;
		ERROR) color=$'\e[31m' ;;
		*)     color=$'\e[0m' ;;
	esac

	local timestamp
	printf -v timestamp '%(%Y-%m-%d %H:%M:%S)T' -1

	local padding=
	if (( LOG_INDENT > 0 )); then
		printf -v padding '%*s' "$LOG_INDENT" ''
	fi

	printf '%s[%s] [%s-%s] [%s] %s%s%s\n' \
		"$color" "$timestamp" "${EXECUTABLE##*/}" "$$" \
		"$level" "$padding" "$message" "$LOG_RESET"
}

utils::dbus() {
	if [[ ${#DBUS_PORTALS[@]} -eq 0 ]]; then
		utils::log INFO "DBUS_PORTALS is empty, skipping DBus proxy"
		return 0
	fi

	utils::log INFO "Starting DBus proxy..."

	LOG=
	[[ ${DEBUG:-0} == 1 ]] && LOG=--log

	xdg-dbus-proxy "$DBUS_SESSION_BUS_ADDRESS" "$PROXY_SOCKET" \
		"${DBUS_PORTALS[@]}" $LOG --filter &

	PROXY_PID=$!

	utils::log INFO "Waiting for proxy socket..."

	while [[ ! -S "$PROXY_SOCKET" ]]; do
		read -rt 0.01 </dev/null
	done

	utils::log INFO "Proxy ready"

	# Required for dbus proxy
	BWRAP_ARGS+=(
		"--dev-bind-try" "$PROXY_SOCKET" "$PROXY_SOCKET"
		"--dev-bind-try" "$XDG_RUNTIME_DIR/bus" "$XDG_RUNTIME_DIR/bus"

		"--setenv" "DBUS_SESSION_BUS_ADDRESS" "unix:path=$PROXY_SOCKET"
		"--setenv" "XDG_RUNTIME_DIR" "$XDG_RUNTIME_DIR"
		"--setenv" "XDG_SESSION_TYPE" "$XDG_SESSION_TYPE"
		"--setenv" "XDG_CURRENT_DESKTOP" "$XDG_CURRENT_DESKTOP"
		"--setenv" "XDG_BACKEND" "$XDG_BACKEND"
	)
}

utils::run() {
	if [[ "${1:-}" == "--debug" ]]; then
		DEBUG=1
		shift
	fi

	utils::dbus
	utils::log INFO "Launching $EXECUTABLE..."

	# Filter out unwanted bwrap flag
	CLEAN_BWRAP_ARGS=()
	for arg in "${BWRAP_ARGS[@]}"; do
		# For some reason causes issues with Firefox
		# Not a problem since the cleanup function takes care of it
		if [[ "$arg" != "--die-with-parent" ]]; then
			CLEAN_BWRAP_ARGS+=("$arg")
		fi
	done

	if [[ "$DEBUG" -eq 1 ]]; then
		if ! command -v strace >/dev/null 2>&1; then
			utils::log ERROR "strace is required for --debug but is not installed."
			return 1
		fi

		strace -f -tt -s 128 -e trace=all -o "$TRACE_FILE" \
			bwrap "${CLEAN_BWRAP_ARGS[@]}" "$EXECUTABLE" "$@"

		EXIT_CODE=$?

		utils::debug

		exit "$EXIT_CODE"
	else
		exec bwrap "${CLEAN_BWRAP_ARGS[@]}" "$EXECUTABLE" "$@"
	fi
}

utils::cleanup() {
	utils::log INFO "Cleaning up..."

	if [[ -n "${PROXY_PID:-}" ]] && kill -0 "$PROXY_PID" 2>/dev/null; then
		kill "$PROXY_PID" 2>/dev/null || true
	fi

	rm -f "$PROXY_SOCKET"
}

utils::debug() {
	utils::log INFO "Starting debugging..."

	local debug_dir
	local debug_pipeline_dir
	local debug_lib_dir

	debug_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/debug" && pwd)"
	debug_pipeline_dir="$debug_dir/pipeline"
	debug_lib_dir="$debug_dir/lib"

	source "$debug_lib_dir/normalize_path.sh"
	source "$debug_lib_dir/print_output.sh"

	run_pipeline() {
		local -n _input=$1
		local -a data=("${_input[@]}")
		local -a pipeline_scripts=()
		local -a stage_output=()
		local stage name before start duration

		mapfile -t pipeline_scripts < <(
			find "$debug_pipeline_dir" \
				-maxdepth 1 \
				-type f \
				-name '*.sh' \
				-print |
				sort -V
		)

		for stage in "${pipeline_scripts[@]}"; do
			name="${stage##*/}"
			before=${#data[@]}
			start=$EPOCHREALTIME

			mapfile -t stage_output < <(
				printf '%s\n' "${data[@]}" |
					source "$stage"
			)

			data=("${stage_output[@]}")

			duration=$(
				awk -v s="$start" -v e="$EPOCHREALTIME" \
					'BEGIN { printf "%.6f", (e-s)*1000 }'
			)

			printf '[pipeline] stage: %s\n  - time: %sms\n  - items: %d → %d\n' \
				"${name%.sh}" \
				"$duration" \
				"$before" \
				"${#data[@]}" \
				>&2
		done

		echo "[pipeline] finished stages: ${#pipeline_scripts[@]}" >&2
		printf '%s\n' "${data[@]}"
	}

	# PIPELINE EXECUTION
	local -a items=()
	mapfile -t items < <(
		run_pipeline items
	)

	# OUTPUT
	if [[ "${#items[@]}" -eq 0 ]]; then
		utils::log INFO "debug_build_json_suggestions: no recommendations found"
		return 0
	fi

	echo ""

	utils::log WARN "This dataset comes from strace output, so it includes a lot of paths that the program probably doesn’t actually need."
	utils::log WARN "Expect noise from runtime stuff, debug leftovers, and indirect access patterns."
	utils::log WARN "You should heavily filter out anything sensitive or internal (like /proc, /sys, /dev, /run, sockets, caches, credentials)."
	utils::log WARN "Also keep in mind it can miss important things the program actually needs to run, like binaries or shared libs (e.g. /usr/bin)."
	utils::log WARN "Just because a path shows up doesn’t mean it’s required—and just because it doesn’t show up doesn’t mean it isn’t required."
	utils::log INFO "Profile recommendation:"

	print_output "${items[@]}" 2>/dev/null | tee >(copy_to_clipboard) "$HOME/bwrap-profile.txt"

	echo
	utils::log INFO "*Copied to clipboard* - also saved in $HOME/bwrap-profile.txt"
}
