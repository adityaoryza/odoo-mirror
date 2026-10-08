#!/usr/bin/env bash
# shellcheck disable=SC2034
# shellcheck source=../lib/bootstrap.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/bootstrap.sh"

# The numbered menu (no whiptail): the answers come from a file instead of the terminal.
export ODOO_MIRROR_MENU=plain
export ODOO_MIRROR_MENU_INPUT=-   # the answers are read from stdin (a here-string per call)

menu_choose "T" "" a "First" b "Second" c "Third" <<<"3" 2>/dev/null
assert_eq "c" "$MENU_CHOICE" "a number picks the matching entry"

menu_choose "T" "" a "First" b "Second" <<<$'x\n9\n2' 2>"$TMP/err"
assert_eq "b" "$MENU_CHOICE" "wrong answers are asked again"
assert_contains "$(cat "$TMP/err")" "Please type a number" "...with a hint"

menu_choose "T" "" a "First" <<<"q" 2>/dev/null
assert_eq "1" "$?" "q cancels"

# The main menu sets the command.
COMMAND=""; menu_main <<<"2" 2>/dev/null
assert_eq "backup" "$COMMAND" "main menu: second entry is the backup"
assert_eq "1" "$MENU_USED" "...and the wizard is told the menu was used"

COMMAND=""; menu_main <<<"7" 2>/dev/null
assert_eq "update" "$COMMAND" "main menu: update"

COMMAND=""; menu_main <<<"4" 2>/dev/null
assert_eq "discover" "$COMMAND" "main menu: list the databases"

# Saved profiles: none, then one.
CONFIG_HOME="$TMP/cfg"
( COMMAND=""; menu_main ) <<<$'5\nq' >/dev/null 2>"$TMP/none"; rc=$?
assert_eq "0" "$rc" "no profile saved: back to the menu, then q quits cleanly"
assert_contains "$(cat "$TMP/none")" "No saved profile yet" "...and says why"

mkdir -p "$CONFIG_HOME/profiles"
printf 'COMMAND="backup"\nREMOTE_HOST="h"\n' >"$CONFIG_HOME/profiles/prod.conf"
COMMAND=""; PROFILE=""; menu_main <<<$'5\n1' 2>/dev/null
assert_eq "prod" "$PROFILE" "a saved profile can be chosen from the menu"

# ODOO_MIRROR_NO_MENU skips it.
COMMAND=""; ODOO_MIRROR_NO_MENU=1 menu_main
assert_eq "" "$COMMAND" "ODOO_MIRROR_NO_MENU=1 skips the menu"

finish
