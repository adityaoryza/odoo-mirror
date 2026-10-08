#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2016  # the tests set globals read by the sourced modules; $ in single quotes is intended
# shellcheck source=../lib/bootstrap.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/bootstrap.sh"

# --- progress.py copies the data untouched ---------------------------------------------------
head -c 3000000 /dev/urandom > "$TMP/in.bin"
python3 "$LIB_DIR/py/progress.py" test 3000000 < "$TMP/in.bin" > "$TMP/out.bin" 2> "$TMP/progress.err"
assert_eq "$(md5sum < "$TMP/in.bin")" "$(md5sum < "$TMP/out.bin")" "progress.py does not alter the data"
assert_contains "$(cat "$TMP/progress.err")" "100%" "progress.py reaches 100% when the total is known"
python3 "$LIB_DIR/py/progress.py" unknown 0 < "$TMP/in.bin" > /dev/null 2> "$TMP/progress2.err"
assert_contains "$(cat "$TMP/progress2.err")" "unknown" "progress.py works without a known total"
assert_ok "progress.py stops quietly when the reader closes the pipe" bash -c "python3 '$LIB_DIR/py/progress.py' x 0 < '$TMP/in.bin' | head -c 10 >/dev/null"

# --- build_zip.py builds what Odoo expects ---------------------------------------------------
mkdir -p "$TMP/build/filestore/ab"
echo "-- PostgreSQL database dump complete" > "$TMP/build/dump.sql"
echo '{"odoo_dump":"1"}' > "$TMP/build/manifest.json"
echo "attachment" > "$TMP/build/filestore/ab/abcdef"
python3 "$LIB_DIR/py/build_zip.py" "$TMP/out.zip" "$TMP/build" 2>/dev/null
names=$(python3 -c "import sys,zipfile; print(' '.join(zipfile.ZipFile(sys.argv[1]).namelist()))" "$TMP/out.zip")
assert_eq "dump.sql manifest.json filestore/ab/abcdef" "$names" "the zip holds dump.sql first, then manifest.json and filestore/"
assert_ok "the zip passes its integrity test" python3 -c "import sys,zipfile; sys.exit(0 if zipfile.ZipFile(sys.argv[1]).testzip() is None else 1)" "$TMP/out.zip"

# --- the SQL files are present and scoped ----------------------------------------------------
assert_contains "$(cat "$SQL_DIR/sanitize.sql")" "s3.%" "sanitize.sql removes the object storage keys"
assert_contains "$(cat "$SQL_DIR/anonymize-persons.sql")" "NOT p.is_company" "anonymize-persons.sql leaves companies alone"

finish
