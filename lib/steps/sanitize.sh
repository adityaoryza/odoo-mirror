# shellcheck shell=bash
# Step: sanitize
#
# One step of a run. Registered in ALL_STEPS (globals.sh) and in resolve_steps (plan.sh).
# This file is sourced by lib/odoo-mirror.sh: it only defines functions and constants.

step_sanitize() {
    step_begin sanitize "Remove leftovers that point to production services"
    if (( SANITIZE )); then
        psql_local "$LOCAL_DB" -v ON_ERROR_STOP=1 -f "$SQL_DIR/sanitize.sql" >>"$LOG_FILE" 2>&1 || die "sanitize SQL failed (see $LOG_FILE)"
        log_ok "S3 keys removed, remote backup configurations disabled"
    else
        log_warn "S3 keys and remote backup targets kept (--no-sanitize)"
    fi
    if (( ANONYMIZE )); then
        local anon="$SQL_DIR/anonymize-persons.sql"
        [[ -f "$anon" ]] || die "Anonymization script not found: $anon"
        psql_local "$LOCAL_DB" -v ON_ERROR_STOP=1 -f "$anon" >>"$LOG_FILE" 2>&1 \
            || die "anonymization failed (see $LOG_FILE)"
        log_ok "personal data of private individuals anonymized"
    fi
    if [[ -n "$SANITIZE_SQL_FILE" ]]; then
        psql_local "$LOCAL_DB" -v ON_ERROR_STOP=1 -f "$SANITIZE_SQL_FILE" >>"$LOG_FILE" 2>&1 \
            || die "custom sanitize SQL failed (see $LOG_FILE)"
        log_ok "custom SQL applied: $SANITIZE_SQL_FILE"
    fi
    step_end
}
