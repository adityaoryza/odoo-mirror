#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2016  # the tests set globals read by the sourced modules; $ in single quotes is intended
# shellcheck source=../lib/bootstrap.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/bootstrap.sh"

# Database names reach a shell, a path and SQL: anything unusual must be refused.
for ok in a my_db my-db.1 my-company_staging_260707 MyServer 0db; do
    assert_ok "valid_name accepts '$ok'" valid_name "$ok"
done
for ko in "" "a;b" "a b" '$(id)' '`id`' "-rf" ".hidden" "a/b" "a'b" 'a"b' "a|b" "é"; do
    assert_fails "valid_name refuses '$ko'" valid_name "$ko"
done

assert_ok "valid_path accepts an absolute path" valid_path "/opt/odoo/.local/share/Odoo/filestore"
for ko in "" "relative/path" "/with space" "/semi;colon" '/dollar$x' "/back\`tick"; do
    assert_fails "valid_path refuses '$ko'" valid_path "$ko"
done

assert_ok "version_ge: equal" version_ge 14.19 14.19
assert_ok "version_ge: greater" version_ge 14.24 14.19
assert_ok "version_ge: numeric, not alphabetic" version_ge 14.100 14.19
assert_fails "version_ge: lower" version_ge 14.18 14.19

assert_eq "19" "$(psql_min_for_restrict 14)" "psql_min_for_restrict: 14"
assert_eq "6" "$(psql_min_for_restrict 17)" "psql_min_for_restrict: 17"
assert_eq "0" "$(psql_min_for_restrict 18)" "psql_min_for_restrict: newer majors need nothing"

finish
