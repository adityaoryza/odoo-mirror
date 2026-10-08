# shellcheck shell=bash
# Local Odoo and PostgreSQL
#
# Reads odoo.conf, talks to the local PostgreSQL, drops a local database.
# This file is sourced by lib/odoo-mirror.sh: it only defines functions and constants.

conf_get() { # key  -> value from ODOO_CONF ('' when missing or False)
    [[ -f "$ODOO_CONF" ]] || return 0
    local v
    v=$(awk -F'[[:space:]]*=[[:space:]]*' -v k="$1" '$1 == k {print $2; exit}' "$ODOO_CONF" | tr -d '\r')
    [[ "$v" == "False" || "$v" == "false" ]] && v=""
    printf '%s' "$v"
}

detect_local_defaults() {
    local root
    for root in "$PWD" "$HOME/project-19" "$HOME/odoo"; do
        [[ -z "$ODOO_BIN" && -f "$root/odoo/odoo-bin" ]] && ODOO_BIN="$root/odoo/odoo-bin"
        [[ -z "$ODOO_BIN" && -f "$root/odoo-bin" ]] && ODOO_BIN="$root/odoo-bin"
        [[ -z "$ODOO_CONF" && -f "$root/odoo.conf" ]] && ODOO_CONF="$root/odoo.conf"
    done
    if [[ -z "$ODOO_PYTHON" ]]; then
        # Pick the virtualenv of the same Odoo major version as odoo-bin.
        local major="" rel cand
        rel="$(dirname "${ODOO_BIN:-/nonexistent}")/odoo/release.py"
        [[ -f "$rel" ]] && major=$(sed -n 's/^version_info = (\([0-9]*\),.*/\1/p' "$rel" | head -1)
        for cand in ${major:+"$HOME/venv-odoo-${major}.0/bin/python3"} ${major:+"$HOME"/venv-odoo-"${major}"*/bin/python3} \
                    "$(dirname "${ODOO_BIN:-/x}")/../venv/bin/python3" "$HOME/venv/bin/python3" "$(command -v python3 || true)"; do
            [[ -x "$cand" ]] && { ODOO_PYTHON=$cand; break; }
        done
    fi
}

load_local_pg() {
    LOCAL_PG_HOST=$(conf_get db_host); LOCAL_PG_HOST=${LOCAL_PG_HOST:-localhost}
    LOCAL_PG_PORT=$(conf_get db_port); LOCAL_PG_PORT=${LOCAL_PG_PORT:-5432}
    LOCAL_PG_USER=$(conf_get db_user); LOCAL_PG_USER=${LOCAL_PG_USER:-${USER:-postgres}}
    LOCAL_PG_PASSWORD=$(conf_get db_password)
}

psql_local() { # database psql-args...
    local db=$1; shift
    PGPASSWORD="$LOCAL_PG_PASSWORD" psql -X -q -h "$LOCAL_PG_HOST" -p "$LOCAL_PG_PORT" \
        -U "$LOCAL_PG_USER" -d "$db" "$@"
}

local_db_exists() {
    [[ "$(psql_local postgres -Atc "select 1 from pg_database where datname='${1//\'/}'")" == 1 ]]
}

drop_local_db() { # name — psql based, also removes its filestore
    local db=$1
    valid_name "$db" || die "Invalid database name: $db"
    psql_local postgres -Atc "select pg_terminate_backend(pid) from pg_stat_activity where datname='${db}'" >/dev/null
    psql_local postgres -c "DROP DATABASE IF EXISTS \"${db}\"" >>"$LOG_FILE" 2>&1 || die "Could not drop database $db"
    rm -rf "$(filestore_root_local)/${db:?}"
}

filestore_root_local() {
    local d; d=$(conf_get data_dir); d=${d:-$HOME/.local/share/Odoo}
    printf '%s/filestore' "$d"
}

psql_min_for_restrict() { # psql major -> minimum minor that understands \restrict
    case "$1" in 13) echo 22;; 14) echo 19;; 15) echo 14;; 16) echo 10;; 17) echo 6;; *) echo 0;; esac
}
