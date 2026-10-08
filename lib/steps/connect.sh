# shellcheck shell=bash
# Step: connect
#
# One step of a run. Registered in ALL_STEPS (globals.sh) and in resolve_steps (plan.sh).
# This file is sourced by lib/odoo-mirror.sh: it only defines functions and constants.

step_connect() {
    step_begin connect "Connect to ${REMOTE_HOST}"
    connect_remote
    step_end
}

# Opens the SSH connection and checks sudo. Safe to call twice (the database picker connects first).
connect_remote() {
    if (( SSH_CONNECTED )); then log_info "already connected to ${REMOTE_HOST}"; return 0; fi
    build_ssh_opts
    log_info "SSH password / passphrase is asked once; the connection is then reused."
    if ! "$SSH_BIN" "${SSH_OPTS[@]}" -fN "$REMOTE_HOST"; then
        die "SSH connection failed"
    fi
    SSH_CONNECTED=1
    if (( USE_SUDO )); then
        if [[ -n "${ODOO_MIRROR_SUDO_PASSWORD:-}" ]]; then
            SUDO_PW=$ODOO_MIRROR_SUDO_PASSWORD
            log_warn "Using ODOO_MIRROR_SUDO_PASSWORD from the environment."
        else
            ask_secret SUDO_PW "sudo password on ${REMOTE_HOST} (hidden)"
        fi
        if ! rsudo true >/dev/null 2>>"$LOG_FILE"; then
            die "sudo check failed on the server (wrong password, or this user cannot use sudo; try --no-sudo)"
        fi
        log_ok "ssh + sudo OK"
    else
        ssh_run true || die "Remote command failed"
        log_ok "ssh OK (no sudo)"
    fi
}
