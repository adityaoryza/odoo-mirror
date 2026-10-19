#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2016  # the tests set globals read by the sourced modules
# shellcheck source=../lib/bootstrap.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/bootstrap.sh"

# Plain output, a temporary HOME, answers read from stdin: no dependency on the terminal or on the real machine.
UI_TTY=0; UI_UTF=0
I_INFO="INFO "; I_OK="OK   "; I_WARN="WARN "; I_ERROR="ERROR"; I_STEP=""
export ODOO_MIRROR_MENU_INPUT=- HOME="$TMP/home"
LOG_FILE="$TMP/run.log"; : >"$LOG_FILE"
CONFIG_HOME="$TMP/cfg"
INTERACTIVE=yes; ASSUME_YES=0; ALLOW_VERSION_MISMATCH=0
ACTIVE_STEPS=(restore sanitize verify)

# mk_odoo DIR MAJOR: a fake checkout (odoo-bin + odoo/release.py) with a virtualenv and a conf next to it
mk_odoo() {
    mkdir -p "$1/odoo"
    : >"$1/odoo-bin"
    printf "version_info = (%s, 0, 0, FINAL, 0, '')\n" "$2" >"$1/odoo/release.py"
}
mk_odoo "$HOME/src/odoo19" 19
mk_odoo "$HOME/src/odoo17" 17
mk_odoo "$HOME/work/old/odoo17b" 17
mk_odoo "$HOME/node_modules/x/odoo17" 17      # pruned
mk_odoo "$HOME/a/b/c/d/odoo17deep" 17         # deeper than 4 levels
printf '[options]\ndb_name = x\n' >"$HOME/src/odoo17/odoo.conf"
mkdir -p "$HOME/venv-odoo-17.0/bin"; printf '#!/bin/sh\n' >"$HOME/venv-odoo-17.0/bin/python3"; chmod +x "$HOME/venv-odoo-17.0/bin/python3"
mkdir -p "$TMP/bin"; printf '#!/bin/sh\n' >"$TMP/bin/py"; chmod +x "$TMP/bin/py"
printf '[options]\n' >"$TMP/bin/my.conf"

reset_odoo() { ODOO_BIN="$HOME/src/odoo19/odoo-bin"; ODOO_PYTHON="$TMP/bin/py"; ODOO_CONF="$TMP/bin/my.conf"; ODOO_VERSION_TAG="19.0+e"; LOCAL_DB=copy; ODOO_LOCAL_AUTO=0; PROFILE=""; SAVE_PROFILE=""; }

# --- A. the plan shows the local version ------------------------------------------------------------------------------
reset_odoo; WORK_DIR=w; REMOTE_HOST=h; COMMAND=restore
out=$(print_plan 2>&1)
assert_contains "$out" "$HOME/src/odoo19/odoo-bin -c $TMP/bin/my.conf   (Odoo 19.0)" "the plan shows the local Odoo version"
ODOO_BIN="$TMP/none/odoo-bin"; out=$(print_plan 2>&1)
assert_contains "$out" "$TMP/none/odoo-bin -c $TMP/bin/my.conf"$'\n' "unknown version: nothing extra on the odoo row"
assert_not_contains "$out" "(Odoo " "...no version in brackets"

# --- search: only the wanted major, bounded, pruned ---------------------------------------------------------------------
found=$(find_odoo_bins)
assert_contains "$found" "$HOME/src/odoo17/odoo-bin" "the search finds an Odoo checkout"
assert_not_contains "$found" "node_modules" "node_modules is not searched"
assert_not_contains "$found" "odoo17deep" "the search is bounded to 4 levels"
assert_eq "$HOME/venv-odoo-17.0/bin/python3" "$(suggest_python 17)" "a venv-odoo-<major>.0 python is suggested"
assert_eq "" "$(suggest_python 16)" "no venv, no suggestion"
assert_eq "$HOME/src/odoo17/odoo.conf" "$(suggest_conf "$HOME/src/odoo17/odoo-bin")" "the conf next to odoo-bin is suggested"

# --- B. the wizard question -----------------------------------------------------------------------------------------------
COMMAND=restore; OUT_DIR="$TMP/out"; REMOTE_HOST=h
# auto-detected -> asked, y keeps it (LOCAL_DB is given: not asked)
reset_odoo; ODOO_LOCAL_AUTO=1
( collect_config 2>"$TMP/err" >/dev/null; echo "$ODOO_BIN" >"$TMP/bin.out" ) <<<$'y\n\n'
err=$(cat "$TMP/err")
assert_contains "$err" "Local Odoo: $HOME/src/odoo19/odoo-bin (Odoo 19.0)" "auto-detected Odoo is shown with its version"
assert_contains "$err" "Use this Odoo?" "...and confirmed"
assert_eq "$HOME/src/odoo19/odoo-bin" "$(cat "$TMP/bin.out")" "y keeps the detected Odoo"

# given by a flag or a profile -> not asked
reset_odoo; ODOO_LOCAL_AUTO=0
( collect_config 2>"$TMP/err" >/dev/null ) <<<$'\n'
assert_not_contains "$(cat "$TMP/err")" "Use this Odoo?" "a value from a flag or a profile is not questioned"

# plain backup -> not asked
reset_odoo; ODOO_LOCAL_AUTO=1; ACTIVE_STEPS=(connect inspect dump filestore assemble); COMMAND=backup
( collect_config 2>"$TMP/err" >/dev/null ) <<<$'\n\n'
assert_not_contains "$(cat "$TMP/err")" "Use this Odoo?" "a plain backup does not ask for a local Odoo"
ACTIVE_STEPS=(restore sanitize verify); COMMAND=restore

# non interactive -> not asked
reset_odoo; ODOO_LOCAL_AUTO=1
( INTERACTIVE=no; collect_config 2>"$TMP/err" >/dev/null ) </dev/null
assert_not_contains "$(cat "$TMP/err")" "Use this Odoo?" "non-interactive: no new question"

# n -> three paths, version shown
reset_odoo; ODOO_LOCAL_AUTO=1
( collect_config 2>"$TMP/err" >/dev/null
  echo "$ODOO_BIN|$ODOO_PYTHON|$ODOO_CONF|$ODOO_VERSION_TAG" >"$TMP/n.out"
) <<<$'n\n~/src/odoo17/odoo-bin\n'"$TMP/bin/py"$'\n'"$HOME/src/odoo17/odoo.conf"$'\n\n'
assert_eq "$HOME/src/odoo17/odoo-bin|$TMP/bin/py|$HOME/src/odoo17/odoo.conf|17.0+e" "$(cat "$TMP/n.out")" "n: the three paths are asked (~ expanded), the tag follows"
err=$(cat "$TMP/err")
assert_contains "$err" "Path to odoo-bin" "n asks odoo-bin"
assert_contains "$err" "Python interpreter for Odoo" "n asks python"
assert_contains "$err" "Path to odoo.conf" "n asks odoo.conf"
assert_contains "$err" "local Odoo: $HOME/src/odoo17/odoo-bin (Odoo 17.0)" "n shows the new version"

# --- C. the mismatch rescue -------------------------------------------------------------------------------------------------
run_check() { # stdin answers
    check_odoo_version 17.0 19.0 2>"$TMP/err" >/dev/null
}
reset_odoo
( run_check; echo "$ODOO_BIN|$ODOO_PYTHON|$ODOO_CONF|$ODOO_VERSION_TAG" >"$TMP/r.out" ) <<<$'y\n1\n\n\n'
err=$(cat "$TMP/err")
assert_contains "$err" "The database on the server is Odoo 17.0 but the local Odoo" "the rescue starts with the mismatch message"
assert_contains "$err" "$HOME/src/odoo17/odoo-bin  (Odoo 17.0)" "a matching candidate is listed with its version"
assert_contains "$err" "$HOME/work/old/odoo17b/odoo-bin  (Odoo 17.0)" "...all matching ones"
assert_not_contains "$err" "odoo19/odoo-bin  (" "another major is not listed"
assert_contains "$err" "Type the paths by hand" "the hand entry is offered"
assert_eq "$HOME/src/odoo17/odoo-bin|$HOME/venv-odoo-17.0/bin/python3|$HOME/src/odoo17/odoo.conf|17.0+e" "$(cat "$TMP/r.out")" "the choice sets bin, suggested python, suggested conf and the tag"
assert_contains "$err" "local Odoo: $HOME/src/odoo17/odoo-bin (Odoo 17.0)" "the new choice is logged"

# by hand
reset_odoo
( run_check; echo "$ODOO_BIN" >"$TMP/r.out" ) <<<$'y\n3\n'"$HOME/src/odoo17/odoo-bin"$'\n'"$TMP/bin/py"$'\n'"$TMP/bin/my.conf"$'\n'
assert_eq "$HOME/src/odoo17/odoo-bin" "$(cat "$TMP/r.out")" "type the paths by hand"

# n, empty choice, nothing found -> same death as today
reset_odoo
out=$( ( run_check; echo continued ) <<<$'n\n' 2>&1 || true )
assert_not_contains "$out" "continued" "n: the run still stops"
reset_odoo
out=$( ( check_odoo_version 17.0 19.0; echo continued ) <<<$'y\n\n' 2>&1 || true )
assert_contains "$out" "The database on the server is Odoo 17.0" "an empty choice dies with the usual message"
assert_not_contains "$out" "continued" "...and stops"
reset_odoo
out=$( ( check_odoo_version 16.0 19.0; echo continued ) <<<$'y\n' 2>&1 || true )
assert_contains "$out" "No Odoo 16 found" "no candidate of that major: said so"
assert_not_contains "$out" "continued" "...and stops"

# invalid conf (duplicate option) is refused like validate_config does
printf '[options]\na = 1\na = 2\n' >"$TMP/bin/dup.conf"
reset_odoo
out=$( ( check_odoo_version 17.0 19.0; echo continued ) <<<$'y\n3\n'"$HOME/src/odoo17/odoo-bin"$'\n'"$TMP/bin/py"$'\n'"$TMP/bin/dup.conf"$'\n' 2>&1 || true )
assert_contains "$out" "an option written twice" "a conf with a duplicate option is refused"
assert_not_contains "$out" "continued" "...and stops"

# non-interactive and -y: dies at once, no question
for mode in no yes; do
    reset_odoo
    out=$( ( [[ $mode == no ]] && INTERACTIVE=no; [[ $mode == yes ]] && ASSUME_YES=1; check_odoo_version 17.0 19.0; echo continued ) </dev/null 2>&1 || true )
    assert_contains "$out" "The database on the server is Odoo 17.0" "mode $mode: the error is the same"
    assert_not_contains "$out" "Look for an Odoo" "mode $mode: no question"
    assert_not_contains "$out" "continued" "mode $mode: the run stops"
done

# --allow-version-mismatch still only warns
reset_odoo
out=$( ( ALLOW_VERSION_MISMATCH=1; check_odoo_version 17.0 19.0; echo continued ) </dev/null 2>&1 )
assert_contains "$out" "continued" "--allow-version-mismatch continues without a question"
assert_not_contains "$out" "Look for an Odoo" "...and does not search"

# --- D. profiles --------------------------------------------------------------------------------------------------------------
mkdir -p "$CONFIG_HOME/profiles"
printf '# profile\nREMOTE_HOST="h"\nODOO_BIN="/old/odoo-bin"\nODOO_VERSION_TAG="19.0+e"\n' >"$CONFIG_HOME/profiles/p.conf"
reset_odoo; PROFILE=p
( run_check ) <<<$'y\n1\n\n\ny\n'
prof=$(cat "$CONFIG_HOME/profiles/p.conf")
assert_contains "$prof" "ODOO_BIN=\"$HOME/src/odoo17/odoo-bin\"" "the profile gets the new odoo-bin"
assert_contains "$prof" "ODOO_PYTHON=\"$HOME/venv-odoo-17.0/bin/python3\"" "...python (added)"
assert_contains "$prof" "ODOO_CONF=\"$HOME/src/odoo17/odoo.conf\"" "...conf"
assert_contains "$prof" 'ODOO_VERSION_TAG="17.0+e"' "...and the tag"
assert_contains "$prof" 'REMOTE_HOST="h"' "other keys are kept"
assert_eq "600" "$(stat -c %a "$CONFIG_HOME/profiles/p.conf")" "the profile stays private"

printf 'ODOO_BIN="/old/odoo-bin"\n' >"$CONFIG_HOME/profiles/q.conf"
reset_odoo; PROFILE=q
( run_check ) <<<$'y\n1\n\n\nn\n'
assert_eq 'ODOO_BIN="/old/odoo-bin"' "$(cat "$CONFIG_HOME/profiles/q.conf")" "n: the profile is left as it was"

finish
