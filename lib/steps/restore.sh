# shellcheck shell=bash
# Step: restore
#
# One step of a run. Registered in ALL_STEPS (globals.sh) and in resolve_steps (plan.sh).
# This file is sourced by lib/odoo-mirror.sh: it only defines functions and constants.

step_restore() {
    step_begin restore "Restore into the local database '${LOCAL_DB}'"
    local zip=${ZIP_IN:-$ZIP_OUT}
    [[ -n "$zip" && -f "$zip" ]] || die "No zip to restore (use --zip FILE, or run the assemble step)"
    unzip -tq "$zip" >/dev/null 2>&1 || python3 -c 'import sys,zipfile; sys.exit(0 if zipfile.ZipFile(sys.argv[1]).testzip() is None else 1)' "$zip" \
        || die "The zip failed its integrity test: $zip"

    # dumps from recent PostgreSQL releases contain \restrict lines
    local pv_full pmajor pminor need_minor head_sql
    head_sql=$(unzip -p "$zip" dump.sql 2>/dev/null | head -c 4000 || true)
    if [[ "$head_sql" == *'\restrict'* ]]; then
        pv_full=$(psql --version | awk '{print $3}'); pmajor=${pv_full%%.*}; pminor=${pv_full#*.}; pminor=${pminor%%.*}
        need_minor=$(psql_min_for_restrict "$pmajor")
        if (( pminor < need_minor )); then
            die "Your psql $pv_full is too old to read this dump (needs $pmajor.$need_minor+). Update the PostgreSQL client tools."
        fi
    fi

    if local_db_exists "$LOCAL_DB"; then
        (( FORCE )) || die "Local database '$LOCAL_DB' already exists. Use --force to replace it, or pick another name."
        if ! (( ASSUME_YES )); then
            local typed=""
            is_interactive || die "--force needs --yes in non-interactive mode"
            read -r -p "  Type the database name '$LOCAL_DB' to DELETE and replace it: " typed </dev/tty || true
            [[ "$typed" == "$LOCAL_DB" ]] || die "Confirmation did not match; nothing was deleted."
        fi
        log_warn "Replacing existing database $LOCAL_DB"
        drop_local_db "$LOCAL_DB"
    fi

    local args=(db -c "$ODOO_CONF" load)
    (( NEUTRALIZE )) && args+=(-n)
    args+=("$LOCAL_DB" "$zip")
    local olog="$WORK_DIR/odoo-load.log"
    log_info "Odoo prints a lot of warnings while loading; they are kept in $olog"
    if ! spin_run "restoring (psql + filestore + registry)" "$olog" "$ODOO_PYTHON" "$ODOO_BIN" "${args[@]}"; then
        log_error "Odoo failed to load the dump. Last lines:"
        grep -v -E 'WARNING|UserWarning|DeprecationWarning|^[[:space:]]+File |^[[:space:]]+(return|result|response|self|dependencies|val|warnings|raise|fields)|^Stack|^ *$' "$olog" | tail -15 | sed 's/^/        /' >&2 || true
        die "restore failed (full output: $olog)"
    fi
    grep -q "RESTORE DB: ${LOCAL_DB}" "$olog" || die "Odoo did not confirm the restore (see $olog)"
    log_ok "database '$LOCAL_DB' restored"
    step_end
}
