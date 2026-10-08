# shellcheck shell=bash
# Commands that are not a run of steps
#
# Today: discover.
# This file is sourced by lib/odoo-mirror.sh: it only defines functions and constants.

command_discover() {
    step_connect
    printf '\n%sFilestore folders on the server%s\n' "$C_BLD" "$C_OFF" >&2
    local dirs d
    dirs=$(remote_find_filestores "-name filestore")
    while IFS= read -r d; do
        [[ -n "$d" ]] && rsudo "sh -c $(q "du -sh $(q "$d")/* 2>/dev/null")" 2>>"$LOG_FILE" | sed 's/^/  /' >&2
    done <<<"$dirs"
    printf '\n%sDatabases%s\n' "$C_BLD" "$C_OFF" >&2
    list_remote_databases | awk -F'\t' '{printf "  %-40s %s\n", $1, $2}' >&2
}

command_profiles() {
    local names name file
    names=$(list_profile_names)
    if [[ -z "$names" ]]; then
        echo "No saved profile. Save one with --save-profile NAME (or at the end of the wizard)." >&2
        return 0
    fi
    printf '%-20s %-10s %s\n' "PROFILE" "COMMAND" "SERVER / DATABASE" >&2
    while IFS= read -r name; do
        file="$CONFIG_HOME/profiles/$name.conf"
        printf '%-20s %-10s %s\n' "$name" \
            "$(sed -n 's/^COMMAND="\(.*\)"$/\1/p' "$file")" \
            "$(sed -n 's/^REMOTE_HOST="\(.*\)"$/\1/p' "$file") / $(sed -n 's/^REMOTE_DB="\(.*\)"$/\1/p' "$file")" >&2
    done <<<"$names"
}
