# shellcheck shell=bash
# Step: cleanup
#
# One step of a run. Registered in ALL_STEPS (globals.sh) and in resolve_steps (plan.sh).
# This file is sourced by lib/odoo-mirror.sh: it only defines functions and constants.

step_cleanup() {
    step_begin cleanup "Clean up intermediate files"
    if (( KEEP_BUILD )); then
        log_info "kept (--keep-build): $WORK_DIR"
    else
        rm -rf "${WORK_DIR:?}/build"
        [[ -f "$WORK_DIR/${REMOTE_DB:-x}.sql.gz" && -n "$ZIP_OUT" && -f "$ZIP_OUT" ]] && rm -f "$WORK_DIR/${REMOTE_DB}.sql.gz"
        log_ok "removed build files (the zip and the log are kept)"
    fi
    step_end
}
