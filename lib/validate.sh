# shellcheck shell=bash
# Validation and preflight
#
# Every value that reaches a shell, a path or a SQL statement is checked here first.
# This file is sourced by lib/odoo-mirror.sh: it only defines functions and constants.

valid_name() { [[ "$1" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]*$ ]]; }
valid_path() { [[ "$1" =~ ^/[A-Za-z0-9_./-]+$ ]]; }

version_ge() { # have want  (dotted)
    [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" == "$2" ]]
}

expand_paths() {
    local v
    for v in OUT_DIR ODOO_BIN ODOO_PYTHON ODOO_CONF ZIP_IN WORK_DIR SSH_KEY SANITIZE_SQL_FILE; do
        if [[ "${!v}" == "~"* ]]; then printf -v "$v" '%s' "${!v/#\~/$HOME}"; fi
    done
}

validate_config() {
    expand_paths
    if needs_remote; then
        [[ -n "$REMOTE_HOST" ]] || die "No SSH host given"
        if [[ "$COMMAND" != discover ]] && (( ! REMOTE_DB_PICK )) && { step_active inspect || step_active dump || step_active filestore; }; then
            valid_name "$REMOTE_DB" || die "Invalid remote database name: '${REMOTE_DB}'"
        fi
        [[ -z "$REMOTE_FS_ROOT" ]] || valid_path "$REMOTE_FS_ROOT" || die "Invalid --remote-fs-root: '$REMOTE_FS_ROOT'"
        [[ -z "$SSH_PORT" || "$SSH_PORT" =~ ^[0-9]+$ ]] || die "Invalid SSH port: $SSH_PORT"
    fi
    if needs_local_restore; then
        valid_name "$LOCAL_DB" || die "Invalid local database name: '${LOCAL_DB}'"
        [[ -f "$ODOO_BIN"  ]] || die "odoo-bin not found: '$ODOO_BIN'"
        [[ -x "$ODOO_PYTHON" ]] || die "Python not executable: '$ODOO_PYTHON'"
        [[ -f "$ODOO_CONF" ]] || die "odoo.conf not found: '$ODOO_CONF'"
        local active; active=$(conf_get db_name)
        [[ "$LOCAL_DB" != "$active" ]] || die "'$LOCAL_DB' is the database your Odoo uses (db_name in odoo.conf). Pick another name."
        if (( ! NEUTRALIZE )) && (( ! I_UNDERSTAND_LIVE_EMAILS )); then
            die "Refusing to restore without neutralizing: the copy would keep real SMTP credentials and crons. Add --i-understand-emails-will-be-live if you really mean it."
        fi
    fi
    [[ -z "$SANITIZE_SQL_FILE" || -f "$SANITIZE_SQL_FILE" ]] || die "--sanitize-sql file not found"
    return 0
}

preflight_tools() {
    local missing=() t
    for t in awk gzip gunzip tar python3 df sort; do command -v "$t" >/dev/null 2>&1 || missing+=("$t"); done
    if needs_remote; then command -v "$SSH_BIN" >/dev/null 2>&1 || missing+=("ssh"); fi
    if needs_local_restore; then command -v psql >/dev/null 2>&1 || missing+=("psql"); fi
    (( ${#missing[@]} == 0 )) || die "Missing tools: ${missing[*]}"
    command -v pv >/dev/null 2>&1 || log_info "Tip: install 'pv' for a nicer progress bar (a built-in one is used otherwise)."
}

# The user left the database name empty: connect (read only), list the databases and let them pick one.
resolve_remote_db() {
    (( REMOTE_DB_PICK )) || return 0
    printf '\n%sDatabases on %s%s  %s(read only: one SELECT on pg_database)%s\n' "$C_BLD" "$REMOTE_HOST" "$C_OFF" "$C_DIM" "$C_OFF" >&2
    connect_remote
    local -a names=() sizes=()
    local name size
    while IFS=$'\t' read -r name size; do
        valid_name "$name" || continue
        names+=("$name"); sizes+=("$size")
    done < <(list_remote_databases)
    (( ${#names[@]} )) || die "No database found on the server (is the os user '$REMOTE_PG_OSUSER' right?)"
    local i
    for i in "${!names[@]}"; do printf '  %2d) %-40s %s\n' $((i + 1)) "${names[i]}" "${sizes[i]}" >&2; done
    local answer=""
    read -r -p "  Number or name of the database to copy: " answer </dev/tty || true
    if [[ "$answer" =~ ^[0-9]+$ ]] && (( answer >= 1 && answer <= ${#names[@]} )); then
        REMOTE_DB=${names[answer - 1]}
    else
        for name in "${names[@]}"; do [[ "$name" == "$answer" ]] && REMOTE_DB=$name; done
    fi
    [[ -n "$REMOTE_DB" ]] || die "'$answer' is not in the list"
    REMOTE_DB_PICK=0
    log_ok "database: $REMOTE_DB"
}
