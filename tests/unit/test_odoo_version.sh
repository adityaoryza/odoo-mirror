#!/usr/bin/env bash
# shellcheck disable=SC2034  # the tests set globals read by the sourced modules
# shellcheck source=../lib/bootstrap.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/bootstrap.sh"

assert_eq "17.0" "$(parse_odoo_version 17.0.1.3)" "17.0.1.3 -> 17.0"
assert_eq "19.0" "$(parse_odoo_version 19.0)" "19.0 stays"
assert_eq "19.0" "$(parse_odoo_version '19.0+e')" "enterprise tag -> 19.0"
assert_eq "" "$(parse_odoo_version '')" "empty is skipped"
assert_eq "" "$(parse_odoo_version 'garbage')" "garbage is skipped"
assert_eq "" "$(parse_odoo_version 'saas~17.2')" "odd value is skipped"

LOG_FILE="$TMP/log"; : >"$LOG_FILE"
ODOO_BIN="/x/odoo-bin"; ALLOW_VERSION_MISMATCH=0
assert_ok "equal versions pass" check_odoo_version 17.0 17.0
assert_ok "an unknown database version skips the check" check_odoo_version "" 19.0
assert_ok "an unknown local version skips the check" check_odoo_version 17.0 ""
assert_fails "different majors stop the run" bash -c "source '$TESTS_DIR/lib/bootstrap.sh'; LOG_FILE=/dev/null; ALLOW_VERSION_MISMATCH=0; check_odoo_version 17.0 19.0"
out=$(bash -c "source '$TESTS_DIR/lib/bootstrap.sh'; LOG_FILE=/dev/null; check_odoo_version 17.0 19.0" 2>&1 || true)
assert_contains "$out" "The database on the server is Odoo 17.0 but the local Odoo" "the message names both versions"
out=$(bash -c "source '$TESTS_DIR/lib/bootstrap.sh'; LOG_FILE=/dev/null; ALLOW_VERSION_MISMATCH=1; check_odoo_version 17.0 19.0; echo continued" 2>&1)
assert_contains "$out" "--allow-version-mismatch" "the escape hatch warns"
assert_contains "$out" "continued" "the escape hatch continues"

mkdir -p "$TMP/o/odoo"
printf "version_info = (17, 0, 0, FINAL, 0, '')\n" >"$TMP/o/odoo/release.py"
ODOO_BIN="$TMP/o/odoo-bin"
assert_eq "17.0" "$(local_odoo_version)" "local version read from release.py"
ODOO_BIN="$TMP/none/odoo-bin"
assert_eq "" "$(local_odoo_version)" "unknown local version"

if command -v zip >/dev/null 2>&1; then
    printf '{"odoo_dump":"1","version":"17.0","major_version":"17.0"}\n' >"$TMP/manifest.json"
    (cd "$TMP" && zip -q z.zip manifest.json)
    assert_eq "17.0" "$(zip_odoo_version "$TMP/z.zip")" "version read from the zip manifest"
fi
assert_eq "" "$(zip_odoo_version "$TMP/missing.zip")" "no zip, no version"

ALLOW_VERSION_MISMATCH=0; parse_args restore --allow-version-mismatch
assert_eq "1" "$ALLOW_VERSION_MISMATCH" "--allow-version-mismatch"
assert_contains "$(usage)" "--allow-version-mismatch" "usage documents the flag"

finish
