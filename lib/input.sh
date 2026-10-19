# shellcheck shell=bash
# Questions, secrets and the wizard
#
# Interactive input. Nothing typed here as a secret is echoed, logged or stored.
# This file is sourced by lib/odoo-mirror.sh: it only defines functions and constants.

is_interactive() {
    [[ "$INTERACTIVE" == "yes" ]] && return 0
    [[ "$INTERACTIVE" == "no" ]] && return 1
    [[ -t 0 && -t 2 ]]
}

# Reads one answer into the variable named by $1: from the terminal, or from stdin when ODOO_MIRROR_MENU_INPUT=-
# (what the tests use). The prompt is $2.
read_answer() {
    local __var=$1 __line=""
    if [[ "${ODOO_MIRROR_MENU_INPUT:-}" == - ]]; then
        printf '%s' "$2" >&2
        read -r __line || true
    else
        read -r -p "$2" __line </dev/tty || true
    fi
    printf -v "$__var" '%s' "$__line"
}

ask() { # varname "Question" [default]   (keeps a value that is already set)
    local var=$1 question=$2 default=${3:-} current answer
    current=${!var:-}
    if [[ -n "$current" ]]; then return 0; fi
    if ! is_interactive; then
        [[ -n "$default" ]] && { printf -v "$var" '%s' "$default"; return 0; }
        return 1
    fi
    if [[ -n "$default" ]]; then
        read_answer answer "  ${question} [${default}]: "
        answer=${answer:-$default}
    else
        read_answer answer "  ${question}: "
    fi
    printf -v "$var" '%s' "$answer"
    [[ -n "$answer" ]]
}

ask_yn() { # "Question" default(y|n)  -> 0 = yes
    local question=$1 default=${2:-y} answer
    if (( ASSUME_YES )); then return 0; fi
    if ! is_interactive; then [[ "$default" == y ]]; return; fi
    read_answer answer "  ${question} [$([[ $default == y ]] && echo 'Y/n' || echo 'y/N')]: "
    answer=${answer:-$default}
    [[ "${answer,,}" == y* ]]
}

ask_secret() { # varname "Prompt"
    local var=$1 prompt=$2 value
    is_interactive || die "A secret is needed ($prompt) but there is no terminal. Use --no-sudo or ODOO_MIRROR_SUDO_PASSWORD."
    read -r -s -p "  ${prompt}: " value </dev/tty || true
    printf '\n' >&2
    printf -v "$var" '%s' "$value"
}

wizard() {
    printf '\n%s%s — configuration wizard%s\n' "$C_BLD" "$PROG" "$C_OFF" >&2
    printf '%sPress Enter to accept the value in brackets. Nothing secret is stored.%s\n\n' "$C_DIM" "$C_OFF" >&2

    if (( ! MENU_USED )) && [[ -z "$PROFILE" && -d "$CONFIG_HOME/profiles" ]] && ls "$CONFIG_HOME/profiles"/*.conf >/dev/null 2>&1; then
        printf '  Saved profiles: %s\n' "$(find "$CONFIG_HOME/profiles" -maxdepth 1 -name '*.conf' -printf '%f ' | sed 's/\.conf//g')" >&2
        local p=""
        ask p "Profile to load (empty = new setup)" "" || true
        if [[ -n "$p" ]]; then PROFILE=$p; load_profile "$PROFILE"; fi
    fi

    if [[ -z "$COMMAND" ]]; then
        printf '  What do you want to do?\n    1) Full run: download + restore\n    2) Backup only (download + build the zip)\n    3) Restore only (from an existing zip)\n    4) Choose the steps myself\n' >&2
        local choice=""
        ask choice "Choice" "1"
        case "$choice" in
            1) COMMAND=all ;;
            2) COMMAND=backup ;;
            3) COMMAND=restore ;;
            4) COMMAND=all; local custom=""
               ask custom "Steps, comma separated (${ALL_STEPS[*]})" "" || true
               STEPS_ARG=$custom ;;
            *) die "Invalid choice: $choice" ;;
        esac
    fi
}
