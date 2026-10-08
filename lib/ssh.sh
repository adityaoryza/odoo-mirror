# shellcheck shell=bash
# SSH and remote commands
#
# One multiplexed connection. The sudo password only ever travels through stdin (rsudo).
# This file is sourced by lib/odoo-mirror.sh: it only defines functions and constants.

declare -a SSH_OPTS=()

build_ssh_opts() {
    CTL_PATH="${XDG_RUNTIME_DIR:-/tmp}/odoo-mirror-$$-%C"
    SSH_OPTS=(-o ControlMaster=auto -o "ControlPath=$CTL_PATH" -o ControlPersist=20m
              -o ServerAliveInterval=30 -o ServerAliveCountMax=6)
    [[ -n "$SSH_PORT" ]] && SSH_OPTS+=(-p "$SSH_PORT")
    [[ -n "$SSH_USER" ]] && SSH_OPTS+=(-l "$SSH_USER")
    [[ -n "$SSH_KEY"  ]] && SSH_OPTS+=(-i "$SSH_KEY")
    return 0
}

ssh_run() { "$SSH_BIN" "${SSH_OPTS[@]}" "$REMOTE_HOST" "$@"; }

ssh_close() {
    (( SSH_CONNECTED )) || return 0
    "$SSH_BIN" "${SSH_OPTS[@]}" -O exit "$REMOTE_HOST" >/dev/null 2>&1 || true
    SSH_CONNECTED=0
}

# Run a remote command, as root when sudo is enabled. The sudo password goes
# through stdin only (never through the argument list).
rsudo() {
    if (( USE_SUDO )); then
        printf '%s\n' "$SUDO_PW" | ssh_run "sudo -S -p '' $*"
    else
        ssh_run "$*"
    fi
}

# Same, but for the PostgreSQL operating-system user.
rpg() {
    if (( USE_SUDO )); then
        rsudo "-u $(printf '%q' "$REMOTE_PG_OSUSER") $*"
    else
        ssh_run "$*"
    fi
}

q() { printf '%q' "$1"; }

# Odoo keeps its data under a few usual places; walking the whole disk is the fallback.
readonly FS_SEARCH_ROOTS="/opt /var/lib /srv /home /root /data /mnt"

remote_find_filestores() { # find expression, e.g. -path '*/filestore/db'
    local expr=$1 out
    out=$(rsudo "sh -c $(q "find $FS_SEARCH_ROOTS -xdev -maxdepth 8 -type d $expr 2>/dev/null")" || true)
    if [[ -z "${out//[[:space:]]/}" ]]; then
        log_info "not found in the usual places, searching the whole disk (can take a while)…"
        out=$(rsudo "sh -c $(q "find / -xdev -maxdepth 8 -type d $expr 2>/dev/null")" || true)
    fi
    printf '%s\n' "$out"
}

discover_filestore() {
    local found
    found=$(remote_find_filestores "-path '*/filestore/$(q "$REMOTE_DB")'")
    found=$(printf '%s\n' "$found" | sed '/^$/d')
    local n; n=$(printf '%s\n' "$found" | sed '/^$/d' | wc -l)
    (( n >= 1 )) && [[ -n "$found" ]] || die "No filestore folder named '$REMOTE_DB' found on the server. Use --remote-fs-root."
    if (( n > 1 )); then
        log_warn "Several candidates found:"
        printf '%s\n' "$found" | sed 's/^/        /' >&2
        is_interactive || die "Ambiguous filestore; pass --remote-fs-root."
        local pick=""; ask pick "Directory to use (parent of the DB folder)" ""
        REMOTE_FS_ROOT=$pick
    else
        REMOTE_FS_ROOT=$(dirname "$found")
    fi
    valid_path "$REMOTE_FS_ROOT" || die "Invalid filestore root detected: $REMOTE_FS_ROOT"
    log_ok "filestore root: $REMOTE_FS_ROOT"
}

# Names of the databases on the server, one per line: "name<TAB>size". Read only: one SELECT on pg_database.
list_remote_databases() {
    local sql="select datname||E'\\t'||pg_size_pretty(pg_database_size(datname)) from pg_database where not datistemplate and datname <> 'postgres' and datallowconn order by datname"
    rpg "psql -X -At -c $(q "$sql") postgres" 2>/dev/null
}
