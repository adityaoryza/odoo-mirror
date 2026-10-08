# shellcheck shell=bash
# Configuration and workspace
#
# Fills the missing values (asking when a terminal is available) and prepares the output directory and the log.
# This file is sourced by lib/odoo-mirror.sh: it only defines functions and constants.

collect_config() {
    detect_local_defaults

    if needs_remote; then
        ask REMOTE_HOST "SSH host or alias" "" || die "--host is required"
        ask SSH_PORT    "SSH port (empty = from ssh config)" "" || true
        ask SSH_USER    "SSH user (empty = from ssh config)" "" || true
        ask SSH_KEY     "SSH key file (empty = default / password)" "" || true
        if [[ "$COMMAND" != discover ]]; then
            if ! ask REMOTE_DB "Remote database name (empty = list the databases on the server)" ""; then
                is_interactive || die "--remote-db is required"
                REMOTE_DB_PICK=1
            fi
        fi
        if is_interactive && [[ -z "$PROFILE" && "$USE_SUDO" == 1 ]] && ! ask_yn "Does the server need sudo for pg_dump / reading the filestore?" y; then
            USE_SUDO=0
        fi
        [[ "$COMMAND" == discover ]] || ask REMOTE_FS_ROOT "Directory containing the filestore (empty = auto-detect)" "" || true
    fi

    if [[ "$COMMAND" != discover && "$COMMAND" != check ]]; then
        local base=${REMOTE_DB:-}
        if [[ -z "$base" && -n "$ZIP_IN" ]]; then base=$(basename "$ZIP_IN" .zip); fi
        local suggestion=""
        # No database name yet when the user will pick it from the server list: no suggestion then.
        [[ -z "$base" ]] || suggestion="${base//[^A-Za-z0-9_]/_}_local"
        if needs_local_restore; then
            ask LOCAL_DB "Local database to create" "$suggestion" || die "--local-db is required"
            ask ODOO_BIN    "Path to odoo-bin" "" || die "--odoo-bin is required"
            ask ODOO_PYTHON "Python interpreter for Odoo" "" || die "--odoo-python is required"
            ask ODOO_CONF   "Path to odoo.conf" "" || die "--odoo-conf is required"
        fi
        ask OUT_DIR "Output directory" "$OUT_DIR" || true
        if needs_local_restore && (( ! ANONYMIZE )) && (( ! ASSUME_YES )) && [[ -z "$PROFILE" ]] && is_interactive \
            && ask_yn "Anonymize the personal data of private individuals? (no = keep the real customer data)" n; then
            ANONYMIZE=1
        fi
        # Neutralize is never a question: a copy that can send e-mails to real customers is too risky.
        # The only way out is the explicit, long flag pair handled in validate_config.
    fi

    [[ -z "$ODOO_CONF" && -n "${ODOO_BIN:-}" ]] && detect_local_defaults
    return 0
}

make_workspace() {
    local stamp; stamp=$(date +%Y%m%d-%H%M%S)
    local dbname=${REMOTE_DB:-${LOCAL_DB:-misc}}
    if [[ -z "$WORK_DIR" ]]; then WORK_DIR="$OUT_DIR/$dbname/$stamp"; fi
    mkdir -p "$WORK_DIR" "$OUT_DIR/logs"
    LOG_FILE="${ODOO_MIRROR_LOG_FILE:-$OUT_DIR/logs/odoo-mirror_${dbname}_${stamp}.log}"
    : >"$LOG_FILE"; chmod 600 "$LOG_FILE"
}
