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

print_plan() {
    {
        printf '\n%sPlan%s\n' "$C_BLD" "$C_OFF"
        printf '  command        %s\n' "${COMMAND:-all}"
        printf '  steps          %s\n' "${ACTIVE_STEPS[*]:-(none)}"
        if needs_remote; then
            printf '  server         %s%s%s%s\n' "$REMOTE_HOST" "${SSH_PORT:+ :$SSH_PORT}" "${SSH_USER:+ user=$SSH_USER}" "${SSH_KEY:+ key=$SSH_KEY}"
            printf '  remote db      %s   (sudo: %s)\n' "${REMOTE_DB:-—}" "$([[ $USE_SUDO == 1 ]] && echo yes || echo no)"
            printf '  filestore root %s\n' "${REMOTE_FS_ROOT:-auto-detect}"
        fi
        if needs_local_restore; then
            printf '  local db       %s   (neutralize: %s, sanitize: %s)\n' "$LOCAL_DB" "$([[ $NEUTRALIZE == 1 ]] && echo yes || echo NO)" "$([[ $SANITIZE == 1 ]] && echo yes || echo no)"
            printf '  odoo           %s -c %s\n' "$ODOO_BIN" "$ODOO_CONF"
            if (( ANONYMIZE )); then
                printf '  personal data  anonymized (private individuals); companies and addresses are kept\n'
            else
                printf '  personal data  real customer data kept (add --anonymize to replace the personal data of individuals)\n'
            fi
        fi
        printf '  work dir       %s\n' "$WORK_DIR"
        printf '  log file       %s\n\n' "$LOG_FILE"
    } >&2
    # keep the plan in the log as well (no secrets in it)
    {
        echo "command=${COMMAND:-all} steps=${ACTIVE_STEPS[*]:-} host=$REMOTE_HOST remote_db=$REMOTE_DB local_db=$LOCAL_DB"
    } >>"$LOG_FILE"
}
