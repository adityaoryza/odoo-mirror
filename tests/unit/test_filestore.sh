#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2016,SC2329
# shellcheck source=../lib/bootstrap.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/bootstrap.sh"

# A tiny filestore on the "server", and a fake rsudo that streams it like `tar cf -` and exits with $FAKE_TAR_RC.
mkdir -p "$TMP/remote/mydb/ab" "$TMP/work"
echo one > "$TMP/remote/mydb/ab/f1"; echo two > "$TMP/remote/mydb/ab/f2"

run_step() { # exit status of the remote tar -> prints the output of the step
    FAKE_TAR_RC=$1 bash -c '
        set -Eeuo pipefail
        ROOT_DIR="$1"; LIB_DIR="$ROOT_DIR/lib"; SQL_DIR="$ROOT_DIR/sql"; export NO_COLOR=1
        source "$LIB_DIR/odoo-mirror.sh"; install_traps
        rsudo() { tar cf - -C "$TMP_REMOTE" mydb; return "$FAKE_TAR_RC"; }
        progress_pipe() { cat; }
        WORK_DIR="$2"; LOG_FILE="$2/log"; REMOTE_FS_ROOT="$TMP_REMOTE"; REMOTE_DB=mydb; REMOTE_FS_FILES=2; REMOTE_FS_BYTES=0
        step_filestore
        echo "FILES-LOCAL: $(find "$2/build/filestore" -type f | wc -l)"
    ' _ "$ROOT_DIR" "$TMP/work" 2>&1
}
export TMP_REMOTE="$TMP/remote"

rm -rf "$TMP/work/build"; out=$(run_step 0); rc=$?
assert_eq "0" "$rc" "the server tar succeeds: the step succeeds"
assert_contains "$out" "FILES-LOCAL: 2" "...and every file is there"
assert_eq "no" "$([[ "$out" == *"changed while they were read"* ]] && echo yes || echo no)" "...without any warning"

rm -rf "$TMP/work/build"; out=$(run_step 1); rc=$?
assert_eq "0" "$rc" "files changed while read (server tar exit 1): the step still succeeds"
assert_contains "$out" "changed while they were read" "...with a warning that says so"
assert_contains "$out" "FILES-LOCAL: 2" "...and the copy is kept"

rm -rf "$TMP/work/build"; out=$(run_step 2); rc=$?
assert_eq "1" "$rc" "a fatal tar error (exit 2): the step fails"
assert_contains "$out" "The filestore copy failed" "...and says why"

finish
