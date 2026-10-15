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

# Icons and the line eraser are for a terminal only: a log, a pipe or a test keeps the plain words.
UI_TTY=0; UI_UTF=0
[[ -t 2 ]] && UI_TTY=1
[[ "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" == *[Uu][Tt][Ff]* ]] && UI_UTF=1
if (( UI_TTY && UI_UTF )); then
    I_INFO="ℹ"; I_OK="✔"; I_WARN="⚠"; I_ERROR="✘"; I_STEP="▶"
else
    I_INFO="INFO "; I_OK="OK   "; I_WARN="WARN "; I_ERROR="ERROR"; I_STEP=""
fi
# Clears what a progress bar left on the current line (only on a terminal).
_eol() { (( UI_TTY )) && printf '\r\033[K' >&2; return 0; }

_stamp() { date '+%Y-%m-%d %H:%M:%S'; }

_emit() { # level color message
    local level=$1 color=$2; shift 2
    local msg="$*" icon
    if [[ -n "$LOG_FILE" ]]; then
        printf '%s [%-5s] %s\n' "$(_stamp)" "$level" "$msg" >>"$LOG_FILE"
    fi
    case "$level" in
        INFO)  icon=$I_INFO ;;
        OK)    icon=$I_OK ;;
        WARN)  icon=$I_WARN ;;
        ERROR) icon=$I_ERROR ;;
        *)     icon=$(printf '%-5s' "$level") ;;
    esac
    _eol
    printf '%s%s%s %s\n' "$color" "$icon" "$C_OFF" "$msg" >&2
    # A warning raised during a step is kept for the summary.
    [[ "$level" == WARN && -n "${CURRENT_STEP:-}" ]] && STEP_NOTES+=("${CURRENT_STEP}|${msg}")
    return 0
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
    _eol
    printf '\n%s%s%s%s\n' "$C_BLD" "${I_STEP:+$I_STEP }" "$line" "$C_OFF" >&2
    [[ -n "$LOG_FILE" ]] && printf '%s [STEP ] %s\n' "$(_stamp)" "$line" >>"$LOG_FILE"
    return 0
}

# Records the step for the summary. A step that took under 2 seconds says nothing: "done in 00:00" is noise.
step_end() {
    local secs=$((SECONDS - STEP_START))
    STEP_LOG+=("${CURRENT_STEP}|${secs}")
    if (( secs >= 2 )); then
        log_ok "done in $(fmt_dur "$secs")"
    elif [[ -n "$LOG_FILE" ]]; then
        printf '%s [OK   ] done in %s\n' "$(_stamp)" "$(fmt_dur "$secs")" >>"$LOG_FILE"
    fi
    return 0
}

die() {
    log_error "$*"
    exit 1
}
