# shellcheck shell=bash
# Steps and the plan
#
# Which steps run for a command, --steps and --skip, and the plan shown before anything starts.
# This file is sourced by lib/odoo-mirror.sh: it only defines functions and constants.

resolve_steps() {
    local want=() s k found
    case "$COMMAND" in
        backup)   want=(connect inspect dump filestore assemble) ;;
        restore)  want=(restore sanitize verify cleanup) ;;
        discover) want=(connect) ;;
        check)    want=() ;;
        *)        want=("${ALL_STEPS[@]}") ;;
    esac
    if [[ -n "$STEPS_ARG" ]]; then
        IFS=',' read -r -a want <<<"$STEPS_ARG"
    fi
    if [[ -n "$SKIP_ARG" ]]; then
        local skip=() out=()
        IFS=',' read -r -a skip <<<"$SKIP_ARG"
        for s in "${want[@]}"; do
            found=0; for k in "${skip[@]}"; do [[ "$s" == "$k" ]] && found=1; done
            (( found )) || out+=("$s")
        done
        want=("${out[@]}")
    fi
    for s in "${want[@]}"; do
        found=0; for k in "${ALL_STEPS[@]}"; do [[ "$s" == "$k" ]] && found=1; done
        (( found )) || die "Unknown step: $s (valid: ${ALL_STEPS[*]})"
    done
    # keep the canonical order whatever the user typed
    ACTIVE_STEPS=()
    for k in "${ALL_STEPS[@]}"; do
        for s in "${want[@]}"; do [[ "$s" == "$k" ]] && ACTIVE_STEPS+=("$k"); done
    done
    STEP_TOTAL=${#ACTIVE_STEPS[@]}
}

step_active() { local s; for s in "${ACTIVE_STEPS[@]}"; do [[ "$s" == "$1" ]] && return 0; done; return 1; }

needs_remote() { step_active connect || step_active inspect || step_active dump || step_active filestore; }
needs_local_restore() { step_active restore || step_active sanitize || step_active verify; }

# One line of the plan: the label is dimmed so the values stand out.
_plan_row() { printf '  %s%-14s%s %s\n' "$C_DIM" "$1" "$C_OFF" "$2"; }

print_plan() {
    {
        printf '\n%sPlan%s\n' "$C_BLD" "$C_OFF"
        _plan_row command "${COMMAND:-all}"
        _plan_row steps "${ACTIVE_STEPS[*]:-(none)}"
        if needs_remote; then
            _plan_row server "$REMOTE_HOST${SSH_PORT:+ :$SSH_PORT}${SSH_USER:+ user=$SSH_USER}${SSH_KEY:+ key=$SSH_KEY}"
            _plan_row "remote db" "${REMOTE_DB:-—}   (sudo: $([[ $USE_SUDO == 1 ]] && echo yes || echo no))"
            _plan_row "filestore root" "${REMOTE_FS_ROOT:-auto-detect}"
        fi
        if needs_local_restore; then
            _plan_row "local db" "$LOCAL_DB   ($([[ ${LOCAL_DB_AUTO:-0} == 1 ]] && echo 'automatic name, ')neutralize: $([[ $NEUTRALIZE == 1 ]] && echo yes || echo NO), sanitize: $([[ $SANITIZE == 1 ]] && echo yes || echo no))"
            local lov; lov=$(local_odoo_version)
            _plan_row odoo "$ODOO_BIN -c $ODOO_CONF${lov:+   (Odoo $lov)}"
            if (( ANONYMIZE )); then
                _plan_row "personal data" "anonymized (private individuals); companies and addresses are kept"
            else
                _plan_row "personal data" "real customer data kept (add --anonymize to replace the personal data of individuals)"
            fi
        fi
        _plan_row "work dir" "$WORK_DIR"
        _plan_row "log file" "$LOG_FILE"
        printf '\n'
    } >&2
    # keep the plan in the log as well (no secrets in it)
    {
        echo "command=${COMMAND:-all} steps=${ACTIVE_STEPS[*]:-} host=$REMOTE_HOST remote_db=$REMOTE_DB local_db=$LOCAL_DB"
    } >>"$LOG_FILE"
}
