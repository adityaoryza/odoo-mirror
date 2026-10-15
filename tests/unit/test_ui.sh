#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2016,SC2329
# shellcheck source=../lib/bootstrap.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/bootstrap.sh"

LOG_FILE="$TMP/run.log"; : > "$LOG_FILE"
export COLUMNS=80

# --- box: a frame whose lines all have the same width ----------------------------------------------------
out=$(box "Title" "short" "a longer line of text" 2>&1)
assert_contains "$out" "Title" "the box shows its title"
widths=$(printf '%s\n' "$out" | awk '{print length($0)}' | sort -u | wc -l)
assert_eq "1" "$widths" "every line of the box has the same width"
assert_eq "+" "$(printf '%s' "$out" | head -1 | cut -c1)" "outside a terminal the frame is plain ASCII"

long=$(printf 'word %.0s' {1..40})
out=$(box "Wrap" "$long" 2>&1)
maxw=$(printf '%s\n' "$out" | awk '{ if (length($0) > m) m = length($0) } END { print m }')
assert_eq "1" "$(( maxw <= 80 ))" "a long line is wrapped: the box is never wider than the terminal"

# --- steps: quick ones are silent, slow ones say how long, both are kept for the summary -------------------
STEP_LOG=(); STEP_NOTES=(); STEP_TOTAL=3; STEP_INDEX=0
step_begin connect "Connect" >/dev/null 2>&1
step_end >"$TMP/quick.out" 2>&1; quick=$(cat "$TMP/quick.out")   # not in $(...): the step list must survive
assert_eq "" "$quick" "a step under 2 seconds prints no 'done in' line"
step_begin dump "Dump" >/dev/null 2>&1; STEP_START=$((SECONDS - 5))
step_end >"$TMP/slow.out" 2>&1; slow=$(cat "$TMP/slow.out")
assert_contains "$slow" "done in 00:05" "a slower step says how long it took"
assert_eq "connect dump" "$(printf '%s\n' "${STEP_LOG[@]}" | cut -d'|' -f1 | tr '\n' ' ' | sed 's/ $//')" "both steps are recorded in order"
assert_contains "$(cat "$LOG_FILE")" "done in 00:00" "...and the quick one still reaches the log file"

# --- warnings raised during a step are kept for the summary ------------------------------------------------
CURRENT_STEP=filestore; STEP_NOTES=()
log_warn "2 files changed while they were copied" 2>/dev/null
assert_eq "filestore|2 files changed while they were copied" "${STEP_NOTES[0]}" "a warning is attached to the step that raised it"

# --- the summary ----------------------------------------------------------------------------------------------
STEP_LOG=("filestore|561" "restore|512"); STEP_NOTES=("filestore|2 files changed while they were copied")
LOCAL_DB=mirror_copy; ZIP_OUT=""; RUN_START=$((SECONDS - 90)); psql_local() { echo "468 MB"; }
sum=$(print_summary 2>&1)
assert_contains "$sum" "filestore" "the summary lists the steps that ran"
assert_contains "$sum" "09:21" "...with their duration"
assert_contains "$sum" "2 files changed while they were copied" "...the warning under its step"
assert_contains "$sum" "Done in 01:30" "...and the total time in the title of the frame"
assert_contains "$sum" "Database  mirror_copy  (468 MB)" "...the database that was created, with its size"
assert_contains "$sum" "db_name = mirror_copy" "...and what to do with it"
STEP_LOG=("dump|3"); LOCAL_DB=""
sum=$(print_summary 2>&1)
assert_eq "no" "$([[ "$sum" == *"Database "* ]] && echo yes || echo no)" "a backup run does not mention a database it did not create"

# --- failures ---------------------------------------------------------------------------------------------------
for s in connect inspect dump filestore assemble restore sanitize verify other; do
    [[ -n "$(failure_hint "$s" 1)" ]] || echo "no hint for $s"
done > "$TMP/hints"
assert_eq "" "$(cat "$TMP/hints")" "every step has a hint for a failure"
CURRENT_STEP=filestore
fail=$(print_failure 1 15 2>&1)
assert_contains "$fail" "step 'filestore' failed (line 15, exit 1)" "the failure names the step"
assert_contains "$fail" "Hint:" "...gives a hint"
assert_contains "$fail" "$LOG_FILE" "...and the log file"

# A pipeline or a subshell fails in several processes: only one report is printed.
cat > "$TMP/prog.sh" <<PROG
#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR='$ROOT_DIR'; LIB_DIR='$LIB_DIR'; SQL_DIR='$SQL_DIR'; export NO_COLOR=1
source "\$LIB_DIR/odoo-mirror.sh"
install_traps
LOG_FILE='$TMP/prog.log'; CURRENT_STEP=filestore
( false ) | cat
echo NOT-REACHED
PROG
chmod +x "$TMP/prog.sh"
"$TMP/prog.sh" > "$TMP/prog.out" 2>&1; rc=$?
assert_eq "1" "$rc" "a failing pipeline still ends the run with its status"
assert_eq "1" "$(grep -c "failed (line" "$TMP/prog.out")" "the failure is reported once, not once per process"
assert_eq "1" "$(grep -c "failed (line" "$TMP/prog.log")" "...and once in the log file"

# A step that stops the run with die() also gets the failure frame (no ERR trap fires for it).
cat > "$TMP/die.sh" <<PROG
#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR='$ROOT_DIR'; LIB_DIR='$LIB_DIR'; SQL_DIR='$SQL_DIR'; export NO_COLOR=1
source "\$LIB_DIR/odoo-mirror.sh"
install_traps
LOG_FILE='$TMP/die.log'; CURRENT_STEP=connect
die "SSH connection failed"
PROG
rc=0; bash "$TMP/die.sh" > "$TMP/die.out" 2>&1 || rc=$?
assert_eq "1" "$rc" "die() ends the run with status 1"
assert_contains "$(cat "$TMP/die.out")" "step 'connect' failed (exit 1)" "die() prints the failure frame"
assert_eq "1" "$(grep -c "failed (exit" "$TMP/die.log")" "...and writes it once in the log file"

finish
