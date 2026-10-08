# shellcheck shell=bash
# Logger and step banners
#
# Every message goes to the terminal (stderr) and to the run log file (no colors, no secrets).
# This file is sourced by lib/odoo-mirror.sh: it only defines functions and constants.

if [[ -t 2 && -z "${NO_COLOR:-}" ]]; then
    C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'; C_BLU=$'\033[34m'
    C_DIM=$'\033[2m'; C_BLD=$'\033[1m'; C_OFF=$'\033[0m'
else
    C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_DIM=""; C_BLD=""; C_OFF=""
fi

_stamp() { date '+%Y-%m-%d %H:%M:%S'; }

_emit() { # level color message
    local level=$1 color=$2; shift 2
    local msg="$*"
    if [[ -n "$LOG_FILE" ]]; then
        printf '%s [%-5s] %s\n' "$(_stamp)" "$level" "$msg" >>"$LOG_FILE"
    fi
    printf '%s%s%s %s\n' "$color" "$(printf '%-5s' "$level")" "$C_OFF" "$msg" >&2
}

log_info()  { _emit INFO  "$C_BLU" "$*"; }
log_ok()    { _emit OK    "$C_GRN" "$*"; }
log_warn()  { _emit WARN  "$C_YEL" "$*"; }
log_error() { _emit ERROR "$C_RED" "$*"; }
log_file_only() {
    [[ -n "$LOG_FILE" ]] && printf '%s [DEBUG] %s\n' "$(_stamp)" "$*" >>"$LOG_FILE"
    return 0
}

fmt_dur() { # seconds -> mm:ss / h:mm:ss
    local s=$1
    if (( s >= 3600 )); then printf '%d:%02d:%02d' $((s/3600)) $((s%3600/60)) $((s%60))
    else printf '%02d:%02d' $((s/60)) $((s%60)); fi
}

fmt_bytes() {
    awk -v b="$1" 'BEGIN{
        split("B KB MB GB TB", u, " "); i=1;
        while (b >= 1024 && i < 5) { b /= 1024; i++ }
        f = (i == 1) ? "%d %s" : "%.1f %s"
        printf f, b, u[i] }'
}

step_begin() { # step-name title
    CURRENT_STEP=$1
    STEP_INDEX=$((STEP_INDEX + 1))
    STEP_START=$SECONDS
    local line="[${STEP_INDEX}/${STEP_TOTAL}] $2"
    printf '\n%s%s%s\n' "$C_BLD" "$line" "$C_OFF" >&2
    [[ -n "$LOG_FILE" ]] && printf '%s [STEP ] %s\n' "$(_stamp)" "$line" >>"$LOG_FILE"
    return 0
}

step_end() {
    log_ok "done in $(fmt_dur $((SECONDS - STEP_START)))"
}

die() {
    log_error "$*"
    exit 1
}
