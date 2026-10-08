#!/usr/bin/env bash
# shellcheck disable=SC2034
# shellcheck source=../lib/bootstrap.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/bootstrap.sh"

# connect_remote runs before the log file exists (the database picker connects first):
# it must work with an empty LOG_FILE, with sudo, and be safe to call twice.
FAKE="$ROOT_DIR/tests/integration/fake-remote"
SSH_BIN="$FAKE/ssh"
PATH="$FAKE:$PATH"
REMOTE_HOST=fake; USE_SUDO=1; LOG_FILE=""; SSH_CONNECTED=0
export ODOO_MIRROR_SUDO_PASSWORD=secret

out=$(connect_remote 2>&1); rc=$?
assert_eq "0" "$rc" "connect with sudo works before the log file exists"
assert_contains "$out" "ssh + sudo OK" "...and checks sudo"

connect_remote >/dev/null 2>&1
SSH_CONNECTED=1
assert_contains "$(connect_remote 2>&1)" "already connected" "a second call reuses the connection"

finish
