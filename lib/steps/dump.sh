# shellcheck shell=bash
# Step: dump
#
# One step of a run. Registered in ALL_STEPS (globals.sh) and in resolve_steps (plan.sh).
# This file is sourced by lib/odoo-mirror.sh: it only defines functions and constants.

step_dump() {
    step_begin dump "Dump the database as plain SQL (streamed, gzip)"
    BUILD_DIR="$WORK_DIR/build"; mkdir -p "$BUILD_DIR"
    SQL_GZ="$WORK_DIR/${REMOTE_DB}.sql.gz"
    local part="$SQL_GZ.part"
    PARTIAL_FILES+=("$part")
    # Plain SQL is read by any psql, whatever its version, unlike the custom format.
    rpg "pg_dump --no-owner $(q "$REMOTE_DB") | gzip -c" 2>>"$LOG_FILE" \
        | progress_pipe "sql.gz" "$(( REMOTE_DB_BYTES / 8 ))" >"$part"
    gzip -t "$part" || die "The downloaded SQL archive is corrupt"
    (( $(stat -c %s "$part") > 1024 )) || die "The SQL dump is empty: pg_dump did not run (wrong sudo password, or '$REMOTE_PG_OSUSER' cannot read '$REMOTE_DB')"
    mv "$part" "$SQL_GZ"
    log_ok "$(fmt_bytes "$(stat -c %s "$SQL_GZ")") saved → $SQL_GZ"
    log_info "(the percentage is an estimate: the compressed size is not known in advance)"
    step_end
}
