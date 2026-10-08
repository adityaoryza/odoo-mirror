#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2016  # the tests set globals read by the sourced modules; $ in single quotes is intended
# shellcheck source=../lib/bootstrap.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/bootstrap.sh"

parse_args backup --host srv --port 2222 --user adm --remote-db mydb --local-db copy --no-sudo --anonymize --keep-build -y
assert_eq "backup" "$COMMAND" "the command is read"
assert_eq "srv" "$REMOTE_HOST" "--host"
assert_eq "2222" "$SSH_PORT" "--port"
assert_eq "adm" "$SSH_USER" "--user"
assert_eq "mydb" "$REMOTE_DB" "--remote-db"
assert_eq "copy" "$LOCAL_DB" "--local-db"
assert_eq "0" "$USE_SUDO" "--no-sudo"
assert_eq "1" "$ANONYMIZE" "--anonymize"
assert_eq "1" "$KEEP_BUILD" "--keep-build"
assert_eq "1" "$ASSUME_YES" "-y"
assert_eq "1" "$NEUTRALIZE" "neutralize stays on unless asked"

assert_fails "an unknown option is refused" bash -c "source '$TESTS_DIR/lib/bootstrap.sh'; parse_args --nope"
assert_fails "an option without a value is refused" bash -c "source '$TESTS_DIR/lib/bootstrap.sh'; parse_args --host"
assert_fails "an empty value is refused" bash -c "source '$TESTS_DIR/lib/bootstrap.sh'; parse_args --host ''"

# the wizard must never offer to switch neutralize off
assert_eq "0" "$(grep -c -i 'Neutralize the restored copy' "$LIB_DIR/config.sh" "$LIB_DIR/input.sh" | awk -F: '{s+=$2} END {print s}')" "no question about neutralize in the wizard"

NEUTRALIZE=1; parse_args --no-neutralize
assert_eq "0" "$NEUTRALIZE" "--no-neutralize"

out=$(usage)
assert_contains "$out" "--anonymize" "usage documents --anonymize"
assert_contains "$out" "SECRETS" "usage explains how secrets are handled"

finish
