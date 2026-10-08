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

finish
