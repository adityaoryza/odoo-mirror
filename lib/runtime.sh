# shellcheck shell=bash
# Error handling and clean exit
#
# on_error reports the failing step; on_exit removes partial files, closes SSH and forgets the sudo password.
# This file is sourced by lib/odoo-mirror.sh: it only defines functions and constants.

on_error() {
    local rc=$? line=$1
    trap - ERR
    # A pipeline or a subshell runs its own copy of this trap: only the main shell reports, once.
    [[ "$BASHPID" == "$MAIN_PID" ]] || exit "$rc"
    # Ctrl+C kills the commands of a pipeline (ssh exits with 255, for instance) and bash sees the failure
    # before it runs the INT trap. Wait a moment: a pending interrupt is handled here, as the user stopping
    # the run (exit 130), not as the failure of a step.
    sleep 0.2
    print_failure "$rc" "$line"
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
    if [[ -n "$LOG_FILE" && "$BASHPID" == "$MAIN_PID" ]]; then
        if (( rc == 0 )); then
            print_summary || true
        elif (( rc != 130 && rc != 143 && ! FAILURE_REPORTED )); then
            # a step stopped the run with die(): no ERR trap fired, so the failure box was not printed yet
            print_failure "$rc" "" || true
        fi
    fi
}

# Installed once, by the entry point (not at load time, so tests can source the modules).
install_traps() {
    trap 'on_error $LINENO' ERR
    trap on_exit EXIT
    trap 'echo >&2; log_warn "interrupted"; exit 130' INT TERM
}
