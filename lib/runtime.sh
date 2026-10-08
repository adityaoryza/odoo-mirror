# shellcheck shell=bash
# Error handling and clean exit
#
# on_error reports the failing step; on_exit removes partial files, closes SSH and forgets the sudo password.
# This file is sourced by lib/odoo-mirror.sh: it only defines functions and constants.

on_error() {
    local rc=$? line=$1
    trap - ERR
    # Ctrl+C kills the commands of a pipeline (ssh exits with 255, for instance) and bash sees the failure
    # before it runs the INT trap. Wait a moment: a pending interrupt is handled here, as the user stopping
    # the run (exit 130), not as the failure of a step.
    sleep 0.2
    log_error "step '${CURRENT_STEP}' failed (line ${line}, exit ${rc})"
    [[ -n "$LOG_FILE" ]] && log_error "details: $LOG_FILE"
    exit "$rc"
}

on_exit() {
    local rc=$?
    local f
    for f in "${PARTIAL_FILES[@]:-}"; do
        [[ -n "$f" && ( -e "$f" ) && $rc -ne 0 ]] && rm -rf "$f"
    done
    ssh_close
    SUDO_PW=""
    if [[ -n "$LOG_FILE" && $rc -eq 0 ]]; then
        printf '\n%s%s finished in %s%s   log: %s\n' "$C_GRN" "$PROG" "$(fmt_dur $((SECONDS - RUN_START)))" "$C_OFF" "$LOG_FILE" >&2
    fi
}

# Installed once, by the entry point (not at load time, so tests can source the modules).
install_traps() {
    trap 'on_error $LINENO' ERR
    trap on_exit EXIT
    trap 'echo >&2; log_warn "interrupted"; exit 130' INT TERM
}
