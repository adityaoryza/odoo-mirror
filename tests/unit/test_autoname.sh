#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2016,SC2329
# shellcheck source=../lib/bootstrap.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/bootstrap.sh"

mkdir -p "$TMP/data/filestore"
printf '[options]\ndata_dir = %s\ndb_name = active_db\n' "$TMP/data" > "$TMP/odoo.conf"
ODOO_CONF="$TMP/odoo.conf"; ODOO_BIN="$TMP/odoo-bin"; touch "$ODOO_BIN"
STAMP=$(date +%y%m%d)

# No PostgreSQL here: the databases that "exist" are listed in TAKEN.
TAKEN=""
local_db_exists() { [[ " $TAKEN " == *" $1 "* ]]; }
load_local_pg() { :; }
COMMAND=restore STEPS_ARG="" SKIP_ARG=""; resolve_steps

# --- the name: <server database>_<YYMMDD> ----------------------------------------------------------
REMOTE_DB=preaucess-master
assert_eq "preaucess_master_$STAMP" "$(auto_local_db_name)" "server database + date, characters PostgreSQL dislikes replaced"

REMOTE_DB=""; ZIP_IN="/x/y/preaucess-master_2026-10-14.zip"
assert_eq "preaucess_master_$STAMP" "$(auto_local_db_name)" "from a zip: the date odoo-mirror puts in its name is not doubled"

REMOTE_DB=$(printf 'a%.0s' {1..70}); ZIP_IN=""
name=$(auto_local_db_name)
assert_eq "1" "$(( ${#name} <= 63 ))" "a very long server name stays within the 63 characters of PostgreSQL"

# --- when the name is taken: _2, _3... ----------------------------------------------------------------
REMOTE_DB=mydb
TAKEN="mydb_$STAMP"
assert_eq "mydb_${STAMP}_2" "$(auto_local_db_name)" "a database with that name exists: _2"
TAKEN="mydb_$STAMP mydb_${STAMP}_2"
assert_eq "mydb_${STAMP}_3" "$(auto_local_db_name)" "...and _3 when _2 exists too"
TAKEN=""
mkdir -p "$TMP/data/filestore/mydb_$STAMP"
assert_eq "mydb_${STAMP}_2" "$(auto_local_db_name)" "a leftover filestore folder counts as taken (it would be reused)"
rmdir "$TMP/data/filestore/mydb_$STAMP"
REMOTE_DB="active"; sed -i "s/^db_name = .*/db_name = active_${STAMP}/" "$TMP/odoo.conf"
assert_eq "active_${STAMP}_2" "$(auto_local_db_name)" "the db_name of odoo.conf is never chosen"
sed -i "s/^db_name = .*/db_name = active_db/" "$TMP/odoo.conf"

# --- --local-db: explicit, auto, empty ---------------------------------------------------------------
REMOTE_DB=mydb TAKEN=""
LOCAL_DB=my_copy;  resolve_local_db >/dev/null 2>&1; assert_eq "my_copy" "$LOCAL_DB" "an explicit name is kept as typed"
LOCAL_DB=auto;     resolve_local_db >/dev/null 2>&1; assert_eq "mydb_$STAMP" "$LOCAL_DB" "--local-db auto is resolved"
LOCAL_DB="";       resolve_local_db >/dev/null 2>&1; assert_eq "mydb_$STAMP" "$LOCAL_DB" "an empty name is resolved the same way"
COMMAND=backup STEPS_ARG="" SKIP_ARG=""; resolve_steps
LOCAL_DB=auto;     resolve_local_db >/dev/null 2>&1; assert_eq "auto" "$LOCAL_DB" "a backup restores nothing: no database name is invented"
COMMAND=restore STEPS_ARG="" SKIP_ARG=""; resolve_steps

# --- the same option twice in odoo.conf (the 17 minutes lost on 2026-10-14) ----------------------------
printf '[options]\ndb_host = localhost\ndb_name = one\ndb_name = two\n# db_name = three\n; db_host = other\n' > "$TMP/dup.conf"
ODOO_CONF="$TMP/dup.conf"
assert_eq "db_name (lines 3, 4)" "$(conf_duplicate_options)" "an option written twice is found, with its lines"
printf '[options]\ndb_name = one\n# db_name = two\nx = 1\n' > "$TMP/ok.conf"
ODOO_CONF="$TMP/ok.conf"
assert_eq "" "$(conf_duplicate_options)" "a commented line is not a duplicate"

check() { ( LOCAL_DB=copy ODOO_PYTHON=/bin/sh NEUTRALIZE=1 I_UNDERSTAND_LIVE_EMAILS=0 SANITIZE_SQL_FILE="" REMOTE_DB="" REMOTE_HOST=""
            eval "$*"; validate_config ) >/dev/null 2>&1; }
assert_ok "a clean odoo.conf is accepted" check "ODOO_CONF=$TMP/ok.conf"
assert_fails "an odoo.conf with a duplicated option is refused before anything is downloaded" check "ODOO_CONF=$TMP/dup.conf"
assert_ok "--local-db auto is accepted" check "ODOO_CONF=$TMP/ok.conf LOCAL_DB=auto"
assert_fails "an explicit name equal to db_name is still refused" check "ODOO_CONF=$TMP/ok.conf LOCAL_DB=one"

# --- saved profiles: the automatic name stays automatic -----------------------------------------------
CONFIG_HOME="$TMP/cfg"; ODOO_CONF="$TMP/odoo.conf"
profile_value() { sed -n 's/^LOCAL_DB="\(.*\)"$/\1/p' "$CONFIG_HOME/profiles/$1.conf"; }

REMOTE_DB=mydb TAKEN="" LOCAL_DB=auto LOCAL_DB_AUTO=0
resolve_local_db >/dev/null 2>&1
assert_eq "mydb_$STAMP" "$LOCAL_DB" "(before saving) the automatic name is resolved"
save_profile autoprof >/dev/null 2>&1
assert_eq "auto" "$(profile_value autoprof)" "a profile saved after an automatic name keeps 'auto', not today's name"

LOCAL_DB=my_copy LOCAL_DB_AUTO=0
save_profile fixedprof >/dev/null 2>&1
assert_eq "my_copy" "$(profile_value fixedprof)" "a name typed by hand is saved as typed"

# the next run: a profile with 'auto' gets a new name when the first one exists
LOCAL_DB="" LOCAL_DB_AUTO=0; REMOTE_DB=""
load_profile autoprof >/dev/null 2>&1
assert_eq "auto" "$LOCAL_DB" "loading the profile brings 'auto'"
REMOTE_DB=mydb TAKEN="mydb_$STAMP"
resolve_local_db >/dev/null 2>&1
assert_eq "mydb_${STAMP}_2" "$LOCAL_DB" "...and the second run gets _2 instead of failing on the first name"

# an explicit flag wins over the profile, like every other option
LOCAL_DB="from_flag" LOCAL_DB_AUTO=0
load_profile autoprof >/dev/null 2>&1
assert_eq "from_flag" "$LOCAL_DB" "--local-db on the command line wins over the profile"

finish
