# shellcheck shell=bash
# Main
#
# The only function that wires the others together.
# This file is sourced by lib/odoo-mirror.sh: it only defines functions and constants.

main() {
    parse_args "$@"
    [[ "$COMMAND" == help ]] && { usage; exit 0; }
    [[ "$COMMAND" == profiles ]] && { command_profiles; exit 0; }
    [[ "$COMMAND" == update ]] && { command_update; exit 0; }

    local wizard_ran=0 run_wizard=0
    if [[ $# -eq 0 ]] && is_interactive; then
        run_wizard=1
        menu_main
        [[ "$COMMAND" == help ]] && { usage; exit 0; }
        [[ "$COMMAND" == update ]] && { command_update; exit 0; }
        # A profile chosen in the menu already holds every answer: no wizard then.
        [[ -z "$PROFILE" ]] || run_wizard=0
    fi
    if [[ -n "$PROFILE" ]]; then load_profile "$PROFILE"; fi
    if (( run_wizard )); then wizard; wizard_ran=1; fi
    COMMAND=${COMMAND:-all}
    detect_local_defaults
    resolve_steps
    collect_config
    validate_config
    resolve_remote_db
    # After the wizard, offer to keep the answers (never a secret) for the next run.
    if (( wizard_ran )) && [[ -z "$SAVE_PROFILE" && -z "$PROFILE" ]]; then
        ask SAVE_PROFILE "Save these answers as a profile for next time? (a name, empty = no)" "" || true
    fi
    make_workspace
    log_info "${PROG} ${VERSION} — log: $LOG_FILE"
    preflight_tools

    [[ -z "$SAVE_PROFILE" ]] || save_profile "$SAVE_PROFILE"
    if [[ "$COMMAND" == check ]]; then
        needs_local_restore || true
        detect_local_defaults; load_local_pg
        log_ok "tools OK. odoo-bin=${ODOO_BIN:-?}  python=${ODOO_PYTHON:-?}  conf=${ODOO_CONF:-?}"
        exit 0
    fi
    print_plan
    if (( DRY_RUN )); then log_info "dry run: nothing was executed"; exit 0; fi
    if is_interactive && ! (( ASSUME_YES )); then
        ask_yn "Proceed?" y || { log_warn "cancelled"; exit 1; }
    fi

    if needs_local_restore; then load_local_pg; fi

    if [[ "$COMMAND" == discover ]]; then command_discover; exit 0; fi

    local s
    for s in "${ACTIVE_STEPS[@]}"; do
        case "$s" in
            connect)   step_connect ;;
            inspect)   step_inspect ;;
            dump)      step_dump ;;
            filestore) step_filestore ;;
            assemble)  step_assemble ;;
            restore)   step_restore ;;
            sanitize)  step_sanitize ;;
            verify)    step_verify ;;
            cleanup)   step_cleanup ;;
        esac
    done
}
