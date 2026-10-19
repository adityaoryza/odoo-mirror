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
        local value
        for k in "${PROFILE_KEYS[@]}"; do
            value=${!k:-}
            # A name picked by odoo-mirror is saved as "auto": the next run must pick its own, not reuse this one.
            [[ "$k" == LOCAL_DB && "${LOCAL_DB_AUTO:-0}" == 1 ]] && value=auto
            [[ "$value" != *[\"\\$'\n']* ]] || die "Cannot save $k: the value contains a quote, backslash or newline"
            printf '%s="%s"\n' "$k" "$value"
        done
    } >"$file"
    chmod 600 "$file"
    log_ok "Profile saved: $file"
}

# update_profile_keys NAME KEY...: rewrites only these keys in an existing profile (adds them when missing); the rest is kept.
update_profile_keys() {
    local name=$1 file k line value; shift
    file="$CONFIG_HOME/profiles/$name.conf"
    [[ -f "$file" ]] || { save_profile "$name"; return 0; }
    for k in "$@"; do
        value=${!k:-}
        [[ "$value" != *[\"\\$'\n']* ]] || die "Cannot save $k: the value contains a quote, backslash or newline"
    done
    local tmp; tmp=$(mktemp "$file.XXXXXX") || die "Cannot write the profile $file"
    local -A done_keys=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        for k in "$@"; do
            if [[ "$line" == "$k="* ]]; then line="$k=\"${!k:-}\""; done_keys[$k]=1; fi
        done
        printf '%s\n' "$line"
    done <"$file" >"$tmp"
    for k in "$@"; do [[ -n "${done_keys[$k]:-}" ]] || printf '%s="%s"\n' "$k" "${!k:-}" >>"$tmp"; done
    chmod 600 "$tmp"; mv "$tmp" "$file"
    log_ok "Profile updated: $file"
}

# After a rescued version mismatch: offers to keep the new Odoo in the profile of this run, so the next run does not ask again.
offer_profile_update() {
    local name=${PROFILE:-$SAVE_PROFILE}
    [[ -n "$name" ]] || return 0
    ask_yn "Save this Odoo in the profile '$name'?" y || return 0
    update_profile_keys "$name" ODOO_BIN ODOO_PYTHON ODOO_CONF ODOO_VERSION_TAG
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
