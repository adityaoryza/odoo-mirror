# shellcheck shell=bash
# Step: inspect
#
# One step of a run. Registered in ALL_STEPS (globals.sh) and in resolve_steps (plan.sh).
# This file is sourced by lib/odoo-mirror.sh: it only defines functions and constants.

step_inspect() {
    step_begin inspect "Inspect the remote database and filestore"
    REMOTE_DB_BYTES=$(rpg "psql -Atc $(q "select pg_database_size('${REMOTE_DB}')") postgres" 2>>"$LOG_FILE" | tr -dc '0-9') || true
    [[ -n "$REMOTE_DB_BYTES" ]] || die "Cannot read the size of '$REMOTE_DB' (does it exist? is the os user '$REMOTE_PG_OSUSER' right?)"
    REMOTE_PG_VERSION=$(rpg "psql -Atc 'show server_version' postgres" 2>>"$LOG_FILE" | head -1 | awk '{print $1}')
    log_info "database    : $(fmt_bytes "$REMOTE_DB_BYTES")   PostgreSQL ${REMOTE_PG_VERSION:-?}"

    if step_active filestore || step_active assemble; then
        [[ -n "$REMOTE_FS_ROOT" ]] || discover_filestore
        local dir="$REMOTE_FS_ROOT/$REMOTE_DB"
        rsudo "test -d $(q "$dir")" >/dev/null 2>&1 || die "Filestore folder not found on the server: $dir"
        REMOTE_FS_BYTES=$(rsudo "du -sb $(q "$dir")" 2>>"$LOG_FILE" | awk '{print $1}')
        REMOTE_FS_FILES=$(rsudo "find $(q "$dir") -type f | wc -l" 2>>"$LOG_FILE" | tr -dc '0-9')
        log_info "filestore   : $(fmt_bytes "${REMOTE_FS_BYTES:-0}") in ${REMOTE_FS_FILES:-?} files   ($dir)"
    fi

    local need=$(( ${REMOTE_FS_BYTES:-0} * 22 / 10 + REMOTE_DB_BYTES * 3 ))
    local free; free=$(df --output=avail -B1 "$OUT_DIR" | tail -1 | tr -dc '0-9')
    log_info "local space : need about $(fmt_bytes "$need"), free $(fmt_bytes "${free:-0}")"
    if (( ${free:-0} < need )); then
        if (( FORCE )); then
            log_warn "Not enough free space, continuing because of --force."
        else
            die "Not enough free disk space in $OUT_DIR"
        fi
    fi
    step_end
}
