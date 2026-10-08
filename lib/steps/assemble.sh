# shellcheck shell=bash
# Step: assemble
#
# One step of a run. Registered in ALL_STEPS (globals.sh) and in resolve_steps (plan.sh).
# This file is sourced by lib/odoo-mirror.sh: it only defines functions and constants.

step_assemble() {
    step_begin assemble "Build the Odoo-format zip (dump.sql + manifest.json + filestore)"
    BUILD_DIR="$WORK_DIR/build"; mkdir -p "$BUILD_DIR"
    SQL_GZ="${SQL_GZ:-$WORK_DIR/${REMOTE_DB}.sql.gz}"
    [[ -f "$SQL_GZ" ]] || die "SQL archive missing: $SQL_GZ (run the dump step first)"
    local usize; usize=$(gzip -l "$SQL_GZ" | awk 'NR==2{print $2}')
    gunzip -c "$SQL_GZ" | progress_pipe "dump.sql" "${usize:-0}" >"$BUILD_DIR/dump.sql"
    tail -n 5 "$BUILD_DIR/dump.sql" | grep -q -E 'PostgreSQL database dump complete|\\unrestrict' \
        || die "dump.sql looks truncated (no end marker)"
    printf '{"odoo_dump":"1","db_name":"%s","version":"%s","major_version":"%s","pg_version":"%s","modules":{}}\n' \
        "$REMOTE_DB" "$ODOO_VERSION_TAG" "${ODOO_VERSION_TAG%%+*}" "${REMOTE_PG_VERSION:-unknown}" >"$BUILD_DIR/manifest.json"
    [[ -d "$BUILD_DIR/filestore" ]] || log_warn "No filestore in the build: the zip will contain the database only."
    ZIP_OUT="$WORK_DIR/${REMOTE_DB}_$(date +%F).zip"
    PARTIAL_FILES+=("$ZIP_OUT.part")
    python3 "$LIB_DIR/py/build_zip.py" "$ZIP_OUT.part" "$BUILD_DIR"
    if command -v unzip >/dev/null 2>&1; then
        unzip -tq "$ZIP_OUT.part" >/dev/null || die "The zip failed its integrity test"
    else
        python3 -c 'import sys,zipfile; sys.exit(0 if zipfile.ZipFile(sys.argv[1]).testzip() is None else 1)' "$ZIP_OUT.part" \
            || die "The zip failed its integrity test"
    fi
    mv "$ZIP_OUT.part" "$ZIP_OUT"
    log_ok "$(fmt_bytes "$(stat -c %s "$ZIP_OUT")") → $ZIP_OUT"
    step_end
}
