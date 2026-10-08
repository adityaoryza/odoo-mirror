# shellcheck shell=bash
# Progress bar and heartbeat
#
# progress_pipe is `pv` when installed, else lib/py/progress.py. spin_run is for commands without a byte count.
# This file is sourced by lib/odoo-mirror.sh: it only defines functions and constants.

progress_pipe() { # label total_bytes(0 = unknown)  — stdin -> stdout
    local label=$1 total=${2:-0}
    if command -v pv >/dev/null 2>&1; then
        local args=(-pterb -N "$label")
        (( total > 0 )) && args+=(-s "$total")
        pv "${args[@]}"
    else
        python3 "$LIB_DIR/py/progress.py" "$label" "$total"
    fi
}

spin_run() { # label logfile cmd...  — heartbeat for commands without a byte count
    local label=$1 logf=$2; shift 2
    local start=$SECONDS rc=0 i=0 pid last_tick=-1 now_s
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    [[ -t 2 ]] || frames=('-' "\\" '|' '/')
    "$@" >>"$logf" 2>&1 &
    pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        if [[ -t 2 ]]; then
            printf '\r\033[K  %s %s  %s' "${frames[i % ${#frames[@]}]}" "$label" "$(fmt_dur $((SECONDS - start)))" >&2
        else
            now_s=$(( (SECONDS - start) / 30 ))
            if (( now_s != last_tick )); then
                last_tick=$now_s
                printf '  %s … %s\n' "$label" "$(fmt_dur $((SECONDS - start)))" >&2
            fi
        fi
        i=$((i + 1))
        sleep 0.25
    done
    wait "$pid" || rc=$?
    [[ -t 2 ]] && printf '\r\033[K' >&2
    return "$rc"
}
