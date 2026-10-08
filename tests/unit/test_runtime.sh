#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2016
# shellcheck source=../lib/bootstrap.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/bootstrap.sh"

# A small program that loads the modules, installs the traps and runs a pipeline.
cat > "$TMP/prog.sh" <<PROG
#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR='$ROOT_DIR'; LIB_DIR='$LIB_DIR'; SQL_DIR='$SQL_DIR'
source "\$LIB_DIR/odoo-mirror.sh"
install_traps
CURRENT_STEP=filestore
PARTIAL_FILES+=('$TMP/partial')
: > '$TMP/partial'
eval "\$PIPELINE"
echo NOT-REACHED
PROG
chmod +x "$TMP/prog.sh"

# --- a real failure is reported as one -------------------------------------------------------------
PIPELINE='false | cat' "$TMP/prog.sh" > "$TMP/fail.out" 2>&1
fail_rc=$?
assert_eq "1" "$fail_rc" "a failing command ends the run with its status"
assert_contains "$(cat "$TMP/fail.out")" "step 'filestore' failed" "...and names the step that failed"
assert_eq "no" "$([[ -e "$TMP/partial" ]] && echo yes || echo no)" "...and the partial files are removed"

# --- Ctrl+C is not a failure -----------------------------------------------------------------------
: > "$TMP/partial"
# ssh traps SIGINT and exits 255, the other end of the pipe then ends normally: that used to look like a failure
python3 - "$TMP/prog.sh" "$TMP/int.out" <<'PY'
import os, signal, subprocess, sys, time
prog, out = sys.argv[1:3]
env = dict(os.environ, PIPELINE='bash -c \'trap "exit 255" INT; sleep 30 & wait\' | cat')
with open(out, 'w') as fh:
    p = subprocess.Popen([prog], stdout=fh, stderr=subprocess.STDOUT, env=env,
                         preexec_fn=lambda: (os.setsid(), signal.signal(signal.SIGINT, signal.SIG_DFL)))
    time.sleep(2)
    os.killpg(p.pid, signal.SIGINT)
    sys.exit(p.wait(timeout=15))
PY
int_rc=$?
assert_eq "130" "$int_rc" "Ctrl+C ends the run with status 130"
assert_contains "$(cat "$TMP/int.out")" "interrupted" "...and says so"
assert_eq "0" "$(grep -c 'failed' "$TMP/int.out" || true)" "...without reporting a failed step"
assert_eq "no" "$([[ -e "$TMP/partial" ]] && echo yes || echo no)" "...and the partial files are removed"

finish
