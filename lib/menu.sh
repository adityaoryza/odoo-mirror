# shellcheck shell=bash
# Main menu
#
# Shown when odoo-mirror is started without arguments in a terminal. It only chooses what to do: it sets COMMAND
# (and PROFILE) and then the normal flow (wizard, plan, steps) takes over. It uses `whiptail` (arrows + Enter) when it
# is installed, otherwise a numbered list. ODOO_MIRROR_MENU=plain forces the numbered list;
# ODOO_MIRROR_NO_MENU=1 skips the menu.
# This file is sourced by lib/odoo-mirror.sh: it only defines functions and constants.

MENU_CHOICE=""
MENU_ANSWER=""
MENU_USED=0   # 1 once the menu has asked what to do (the wizard then skips its own questions)

menu_use_whiptail() {
    [[ "${ODOO_MIRROR_MENU:-auto}" != plain ]] || return 1
    command -v whiptail >/dev/null 2>&1 || return 1
    [[ "${TERM:-dumb}" != dumb && -t 0 && -t 2 ]]
}

# Reads one answer from the terminal (from stdin when ODOO_MIRROR_MENU_INPUT=-, which is what the tests use).
menu_read() {
    MENU_ANSWER=""
    if [[ "${ODOO_MIRROR_MENU_INPUT:-}" == - ]]; then
        read -r -p "$1" MENU_ANSWER || return 1
    else
        read -r -p "$1" MENU_ANSWER </dev/tty || return 1
    fi
}

# menu_choose TITLE TEXT KEY LABEL [KEY LABEL ...]  -> MENU_CHOICE (return 1 = cancelled)
menu_choose() {
    local title=$1 text=$2; shift 2
    local -a keys=() labels=() items=()
    while (( $# >= 2 )); do keys+=("$1"); labels+=("$2"); items+=("$1" "$2"); shift 2; done

    if menu_use_whiptail; then
        MENU_CHOICE=$(whiptail --title "$title" --notags --menu "$text" 20 78 "${#keys[@]}" "${items[@]}" 3>&1 1>&2 2>&3) || return 1
        return 0
    fi

    local i answer
    printf '\n%s%s%s\n' "$C_BLD" "$title" "$C_OFF" >&2
    [[ -z "$text" ]] || printf '%s%s%s\n' "$C_DIM" "$text" "$C_OFF" >&2
    for i in "${!keys[@]}"; do printf '  %d) %s\n' $((i + 1)) "${labels[i]}" >&2; done
    while true; do
        menu_read "  Choice [1-${#keys[@]}, q = quit]: " || return 1
        answer=$MENU_ANSWER
        case "$answer" in
            q|Q|"") return 1 ;;
            *[!0-9]*) ;;
            *) if (( answer >= 1 && answer <= ${#keys[@]} )); then MENU_CHOICE=${keys[answer - 1]}; return 0; fi ;;
        esac
        printf '  Please type a number from the list.\n' >&2
    done
}

menu_pick_profile() { # -> PROFILE (return 1 = none chosen)
    local names; names=$(list_profile_names)
    if [[ -z "$names" ]]; then
        log_info "No saved profile yet. Run a mirror or a backup and save its answers at the end."
        return 1
    fi
    local -a items=(); local n
    while IFS= read -r n; do items+=("$n" "$n"); done <<<"$names"
    menu_choose "Saved profiles" "Runs the profile with the settings you saved (no password is stored)." "${items[@]}" || return 1
    PROFILE=$MENU_CHOICE
}

menu_main() {
    [[ "${ODOO_MIRROR_NO_MENU:-0}" != 1 ]] || return 0
    MENU_USED=1
    while true; do
        menu_choose "$PROG $VERSION" "Copy an Odoo database from a server to this machine." \
            all      "Mirror a database  (download + restore here)" \
            backup   "Back up a database to a zip  (download only)" \
            restore  "Restore a zip into a local database" \
            discover "List the databases on a server" \
            profile  "Run a saved profile" \
            check    "Check that this machine has what is needed" \
            update   "Update odoo-mirror" \
            help     "Show all commands and options" \
            || { log_info "bye"; exit 0; }
        case "$MENU_CHOICE" in
            profile) menu_pick_profile && return 0 ;;
            *) COMMAND=$MENU_CHOICE; return 0 ;;
        esac
    done
}
