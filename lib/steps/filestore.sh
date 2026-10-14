# shellcheck shell=bash
# Step: filestore
#
# One step of a run. Registered in ALL_STEPS (globals.sh) and in resolve_steps (plan.sh).
# This file is sourced by lib/odoo-mirror.sh: it only defines functions and constants.

step_filestore() {
    step_begin filestore "Download the filestore (streamed, no file on the server)"
    BUILD_DIR="$WORK_DIR/build"; mkdir -p "$BUILD_DIR"
    [[ -n "$REMOTE_FS_ROOT" ]] || discover_filestore
    rm -rf "${BUILD_DIR:?}/filestore" "${BUILD_DIR:?}/${REMOTE_DB:?}"
    PARTIAL_FILES+=("$BUILD_DIR/$REMOTE_DB")
    local -a status
    if rsudo "tar cf - -C $(q "$REMOTE_FS_ROOT") $(q "$REMOTE_DB")" 2>>"$LOG_FILE" \
        | progress_pipe "filestore" "${REMOTE_FS_BYTES:-0}" \
        | tar xf - -C "$BUILD_DIR"; then
        :
    else
        status=("${PIPESTATUS[@]}")
        # A server in use writes files while they are read: GNU tar then finishes the archive and exits with 1
        # ("file changed as we read it"). That is a warning, not a failure: 2 and above are, and so is a failure
        # of the local side of the pipe.
        if (( ${status[0]:-2} == 1 && ${status[1]:-1} == 0 && ${status[2]:-1} == 0 )); then
            log_warn "tar reported files that changed while they were read (the server is in use); the copy is kept"
        else
            die "The filestore copy failed (server tar: ${status[0]:-?}, progress: ${status[1]:-?}, local tar: ${status[2]:-?})"
        fi
    fi
    [[ -d "$BUILD_DIR/$REMOTE_DB" ]] || die "The filestore archive was empty"
    mv "$BUILD_DIR/$REMOTE_DB" "$BUILD_DIR/filestore"
    local got; got=$(find "$BUILD_DIR/filestore" -type f | wc -l)
    if [[ -n "${REMOTE_FS_FILES:-}" && "$got" != "$REMOTE_FS_FILES" ]]; then
        log_warn "File count differs: server $REMOTE_FS_FILES, local $got (files may have changed during the copy)"
    else
        log_ok "$got files received (matches the server)"
    fi
    step_end
}
