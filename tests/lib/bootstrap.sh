# shellcheck shell=bash
# shellcheck disable=SC2034  # SQL_DIR and friends are read by the modules sourced below
# Sourced at the top of every unit test: loads the modules without starting anything.
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ROOT_DIR="$(cd "$TESTS_DIR/.." && pwd -P)"
LIB_DIR="$ROOT_DIR/lib"
SQL_DIR="$ROOT_DIR/sql"
export NO_COLOR=1   # stable output

# shellcheck source=../../lib/odoo-mirror.sh
source "$LIB_DIR/odoo-mirror.sh"
# shellcheck source=assert.sh
source "$TESTS_DIR/lib/assert.sh"

# A fresh temporary directory, removed when the test ends.
TMP="$(mktemp -d "${TMPDIR:-/tmp}/odoo-mirror-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
