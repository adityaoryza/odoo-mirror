# shellcheck shell=bash
# Profiles
#
# A profile is a KEY="value" file parsed against a whitelist (PROFILE_KEYS). It is never sourced or executed.
# This file is sourced by lib/odoo-mirror.sh: it only defines functions and constants.

load_profile() {
    local file="$CONFIG_HOME/profiles/$1.conf" line key value k allowed
    [[ -f "$file" ]] || die "Profile not found: $file"
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^[[:space:]]*# || -z "${line//[[:space:]]/}" ]] && continue
        [[ "$line" =~ ^([A-Z_]+)=(.*)$ ]] || { log_warn "Ignored profile line: $line"; continue; }
        key=${BASH_REMATCH[1]}; value=${BASH_REMATCH[2]}
        value=${value%\"}; value=${value#\"}; value=${value%\'}; value=${value#\'}
        allowed=0
        for k in "${PROFILE_KEYS[@]}"; do [[ "$k" == "$key" ]] && allowed=1; done
        (( allowed )) || { log_warn "Ignored unknown profile key: $key"; continue; }
        if [[ "$key" == COMMAND && -n "$value" ]] && ! is_command_name "$value"; then
            log_warn "Ignored unknown command in the profile: $value"; continue
        fi
        # explicit flags win over the profile
        [[ -n "${!key:-}" && "$key" != NEUTRALIZE && "$key" != SANITIZE && "$key" != KEEP_BUILD && "$key" != USE_SUDO ]] && continue
        printf -v "$key" '%s' "$value"
    done <"$file"
}

save_profile() {
    local name=$1 file k
    valid_name "$name" || die "Invalid profile name: $name (letters, digits, _ . - ; no leading - or .)"
    ! is_command_name "$name" || die "'$name' is a command word: choose another profile name"
    mkdir -p "$CONFIG_HOME/profiles"
    file="$CONFIG_HOME/profiles/$name.conf"
    {
        echo "# odoo-mirror profile '$name' — saved $(_stamp). No secrets are stored here."
        for k in "${PROFILE_KEYS[@]}"; do
            [[ "${!k:-}" != *[\"\\$'\n']* ]] || die "Cannot save $k: the value contains a quote, backslash or newline"
            printf '%s="%s"\n' "$k" "${!k:-}"
        done
    } >"$file"
    chmod 600 "$file"
    log_ok "Profile saved: $file"
}

is_command_name() { # word -> 0 when it names a command (all, backup, ...)
    local c
    for c in "${COMMAND_NAMES[@]}"; do [[ "$c" == "$1" ]] && return 0; done
    return 1
}

list_profile_names() { # one name per line, sorted
    [[ -d "$CONFIG_HOME/profiles" ]] || return 0
    find "$CONFIG_HOME/profiles" -maxdepth 1 -name '*.conf' -printf '%f\n' | sed 's/\.conf$//' | sort
}
