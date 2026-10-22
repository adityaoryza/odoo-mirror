#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2016  # the tests set globals read by the sourced modules; $ in single quotes is intended
# shellcheck source=../lib/bootstrap.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/bootstrap.sh"

cat > "$TMP/odoo.conf" <<'CONF'
[options]
db_name = active_db
db_host = dbhost
db_user = odoo
db_password = s3cret
list_db = False
data_dir = /srv/odoo-data
CONF
ODOO_CONF="$TMP/odoo.conf"

assert_eq "active_db" "$(conf_get db_name)" "conf_get reads a value"
assert_eq "dbhost" "$(conf_get db_host)" "conf_get reads another value"
assert_eq "" "$(conf_get list_db)" "conf_get turns False into empty"
assert_eq "" "$(conf_get missing_key)" "conf_get returns empty for an absent key"
assert_eq "/srv/odoo-data/filestore" "$(filestore_root_local)" "the local filestore follows data_dir"

load_local_pg
assert_eq "dbhost" "$LOCAL_PG_HOST" "load_local_pg: host"
assert_eq "5432" "$LOCAL_PG_PORT" "load_local_pg: default port"
assert_eq "odoo" "$LOCAL_PG_USER" "load_local_pg: user"

ODOO_CONF="$TMP/absent.conf"
assert_eq "" "$(conf_get db_name)" "conf_get: no configuration file"

# --- which python runs Odoo: one that can import psycopg2; never the system python3 by default ----------------------------------
root="$TMP/odoo-tree"; mkdir -p "$root/odoo" "$root/venv-bare/bin" "$root/venv-x/bin" "$TMP/home"
touch "$root/odoo/odoo-bin"
printf '#!/bin/sh\nexit 0\n' > "$root/venv-x/bin/python3"; printf '#!/bin/sh\nexit 1\n' > "$root/venv-bare/bin/python3"
chmod +x "$root/venv-x/bin/python3" "$root/venv-bare/bin/python3"
detect() { ( HOME="$TMP/home"; unset VIRTUAL_ENV; ODOO_BIN="$root/odoo/odoo-bin"; ODOO_PYTHON=""; ODOO_CONF="$TMP/odoo.conf"; eval "$*"; detect_local_defaults; printf '%s' "$ODOO_PYTHON" ); }
assert_eq "$root/venv-x/bin/python3" "$(detect ':')" "detection skips a virtualenv without psycopg2 and takes the one that has it"
mv "$root/venv-x" "$root/moved-away"
assert_eq "" "$(detect ':')" "with no python that has psycopg2, nothing is chosen (the wizard asks) instead of the system python3"
mv "$root/moved-away" "$root/venv-x"
mkdir -p "$TMP/active/bin"; printf '#!/bin/sh\nexit 0\n' > "$TMP/active/bin/python3"; chmod +x "$TMP/active/bin/python3"
assert_eq "$TMP/active/bin/python3" "$(detect "VIRTUAL_ENV=$TMP/active")" "the virtualenv that is active comes first"
mkdir -p "$TMP/active-bare/bin"; printf '#!/bin/sh\nexit 1\n' > "$TMP/active-bare/bin/python3"; chmod +x "$TMP/active-bare/bin/python3"
assert_eq "$root/venv-x/bin/python3" "$(detect "VIRTUAL_ENV=$TMP/active-bare")" "an active virtualenv without psycopg2 is not taken"
assert_eq "yes" "$(python_runs_odoo "$root/venv-x/bin/python3" && echo yes || echo no)" "python_runs_odoo: true for one that imports psycopg2"
assert_eq "no" "$(python_runs_odoo "$root/venv-bare/bin/python3" && echo yes || echo no)" "...false for one that does not"
assert_eq "no" "$(python_runs_odoo "$TMP/none" && echo yes || echo no)" "...and for one that does not exist"

finish
