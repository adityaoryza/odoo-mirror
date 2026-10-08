#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2016  # the tests set globals read by the sourced modules; $ in single quotes is intended
# shellcheck source=../lib/bootstrap.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/bootstrap.sh"

CONFIG_HOME="$TMP/cfg"
mkdir -p "$CONFIG_HOME/profiles"
cat > "$CONFIG_HOME/profiles/p1.conf" <<'CONF'
# comment
REMOTE_HOST="alpha"
SSH_PORT="2222"
REMOTE_DB='dbname'
NOT_ALLOWED="x"
EVIL="$(touch /tmp/odoo-mirror-pwned)"
REMOTE_FS_ROOT="/opt/fs"
CONF

REMOTE_HOST="" SSH_PORT="" REMOTE_DB="" REMOTE_FS_ROOT=""
load_profile p1 2>/dev/null
assert_eq "alpha" "$REMOTE_HOST" "a profile value is loaded"
assert_eq "2222" "$SSH_PORT" "quotes are removed"
assert_eq "dbname" "$REMOTE_DB" "single quotes are removed"
assert_eq "/opt/fs" "$REMOTE_FS_ROOT" "a later line is still read"
assert_eq "no" "$([[ -e /tmp/odoo-mirror-pwned ]] && echo yes || echo no)" "a profile is never executed"
assert_eq "unset" "${NOT_ALLOWED-unset}" "an unknown key is ignored"

REMOTE_HOST="from-flag"
load_profile p1 2>/dev/null
assert_eq "from-flag" "$REMOTE_HOST" "a flag wins over the profile"

assert_fails "a missing profile is refused" bash -c "source '$TESTS_DIR/lib/bootstrap.sh'; CONFIG_HOME='$TMP/cfg'; load_profile nope"

REMOTE_HOST="beta" REMOTE_DB="db2" LOCAL_DB="copy2"
save_profile saved 2>/dev/null
assert_eq "600" "$(stat -c %a "$CONFIG_HOME/profiles/saved.conf")" "a saved profile is private (600)"
assert_contains "$(cat "$CONFIG_HOME/profiles/saved.conf")" 'REMOTE_HOST="beta"' "a saved profile holds the settings"
assert_eq "0" "$(grep -ci 'pass' "$CONFIG_HOME/profiles/saved.conf")" "a saved profile holds no secret"

REMOTE_HOST='bad"value'
assert_fails "a value with a quote is not saved" bash -c "
    source '$TESTS_DIR/lib/bootstrap.sh'; CONFIG_HOME='$TMP/cfg'; REMOTE_HOST='bad\"value'; save_profile q"
assert_fails "an invalid profile name is refused" bash -c "source '$TESTS_DIR/lib/bootstrap.sh'; CONFIG_HOME='$TMP/cfg'; save_profile '../x'"

# --- the whole round trip through the real entry point (no server: --dry-run) ------------------
export ODOO_MIRROR_HOME="$TMP/home"
bin="$ROOT_DIR/bin/odoo-mirror"
"$bin" backup --non-interactive --dry-run --host h1 --port 2222 --user u1 --remote-db db1 \
    --out-dir "$TMP/out" --save-profile ci >/dev/null 2>&1
assert_ok "--save-profile writes the profile" test -f "$TMP/home/profiles/ci.conf"
assert_contains "$(cat "$TMP/home/profiles/ci.conf")" 'SSH_PORT="2222"' "the saved profile keeps the port"
plan=$("$bin" backup --non-interactive --dry-run --profile ci --out-dir "$TMP/out" 2>&1)
assert_contains "$plan" "h1 :2222 user=u1" "--profile ci brings back the server settings"
assert_contains "$plan" "db1" "--profile ci brings back the database"

# --- "odoo-mirror <profile>" is the same as --profile, and the profile remembers its command ----
assert_contains "$(cat "$TMP/home/profiles/ci.conf")" 'COMMAND="backup"' "a saved profile remembers its command"
shortcut=$("$bin" ci --non-interactive --dry-run --out-dir "$TMP/out" 2>&1)
assert_contains "$shortcut" "command        backup" "a bare profile name runs the saved command"
assert_contains "$shortcut" "h1 :2222 user=u1" "a bare profile name brings back the server"
override=$("$bin" discover ci --non-interactive --dry-run --out-dir "$TMP/out" 2>&1)
assert_contains "$override" "command        discover" "an explicit command wins over the saved one"
unknown=$("$bin" nothere --non-interactive --dry-run --out-dir "$TMP/out" 2>&1 || true)
assert_contains "$unknown" "Unknown command or profile: nothere" "an unknown word is refused"
assert_contains "$unknown" "saved profiles: ci" "...and the saved profiles are listed"
listing=$("$bin" profiles 2>&1)
assert_contains "$listing" "ci" "profiles lists the saved profile"
assert_contains "$listing" "h1 / db1" "profiles shows its server and database"

# a profile cannot take the name of a command: it would never be reachable
for word in all backup restore discover check profiles help; do
    assert_fails "the profile name '$word' is refused" bash -c "
        source '$TESTS_DIR/lib/bootstrap.sh'; CONFIG_HOME='$TMP/cfg'; save_profile '$word'"
done
assert_fails "a profile name cannot start with a dash" bash -c "source '$TESTS_DIR/lib/bootstrap.sh'; CONFIG_HOME='$TMP/cfg'; save_profile -x"

finish
