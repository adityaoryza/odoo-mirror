#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2016  # the tests set globals read by the sourced modules; $ in single quotes is intended
# shellcheck source=../lib/bootstrap.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/bootstrap.sh"

touch "$TMP/odoo-bin"
printf '[options]\ndb_name = active_db\n' > "$TMP/odoo.conf"

# Runs validate_config in a subshell with a restore setup, returns its status.
check() { # extra assignments...
    (
        COMMAND=restore STEPS_ARG="" SKIP_ARG=""; resolve_steps
        LOCAL_DB=copy ODOO_BIN="$TMP/odoo-bin" ODOO_PYTHON=/bin/sh ODOO_CONF="$TMP/odoo.conf" NEUTRALIZE=1
        I_UNDERSTAND_LIVE_EMAILS=0 SANITIZE_SQL_FILE="" REMOTE_DB="" REMOTE_HOST=""
        eval "$*"
        validate_config
    ) >/dev/null 2>&1
}

assert_ok "a normal restore configuration is accepted" check ":"
assert_fails "the database Odoo is configured with is refused" check "LOCAL_DB=active_db"
assert_fails "an invalid database name is refused" check "LOCAL_DB='a;b'"
assert_fails "a missing odoo-bin is refused" check "ODOO_BIN=$TMP/none"
assert_fails "restoring without neutralize is refused" check "NEUTRALIZE=0"
assert_ok "restoring without neutralize needs the explicit acknowledgement" check "NEUTRALIZE=0 I_UNDERSTAND_LIVE_EMAILS=1"
assert_fails "a missing custom SQL file is refused" check "SANITIZE_SQL_FILE=$TMP/none.sql"

finish
