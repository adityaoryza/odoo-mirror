# shellcheck shell=bash
# Update
#
# `odoo-mirror update` installs the newest release (checksum verified) with the installer that ships with this copy.
# A source checkout (git clone) is never touched: update it with git.
# This file is sourced by lib/odoo-mirror.sh: it only defines functions and constants.

# True when this copy was installed from a release (the archive contains a RELEASE file).
is_release_install() { [[ -f "$ROOT_DIR/RELEASE" ]]; }

command_update() {
    local installer="$ROOT_DIR/scripts/install.sh"
    if ! is_release_install; then
        log_info "This copy is a source checkout ($ROOT_DIR): update it with  git pull."
        log_info "To install the released version instead:  curl -fsSL https://github.com/adityaoryza/odoo-mirror/releases/latest/download/install.sh | bash"
        return 0
    fi
    [[ -x "$installer" ]] || die "installer not found: $installer"
    local args=(remote)
    (( UPDATE_CHECK_ONLY )) && args+=(--check)
    "$installer" "${args[@]}"
}
