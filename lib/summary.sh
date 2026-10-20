# shellcheck shell=bash
# Boxes, the failure report and the summary at the end of a run
#
# Everything here only prints. This file is sourced by lib/odoo-mirror.sh: it only defines functions and constants.

# box TITLE LINE...  — a framed block on stderr: rounded corners on a UTF-8 terminal, plain + - | everywhere else.
# BOX_COLOR (optional) colors the frame.
box() {
    local title=$1; shift
    local tl="+" tr="+" bl="+" br="+" h="-" v="|"
    (( UI_TTY && UI_UTF )) && { tl="╭"; tr="╮"; bl="╰"; br="╯"; h="─"; v="│"; }
    # No line is wider than the terminal (at most 120 columns): a long one is wrapped at a space.
    local cols=${COLUMNS:-$(tput cols 2>/dev/null || echo 100)} limit
    limit=$(( cols - 4 )); (( limit > 120 )) && limit=120; (( limit < 40 )) && limit=40
    local -a rows=()
    local raw wrapped
    for raw in "$@"; do
        while IFS= read -r wrapped; do rows+=("$wrapped"); done < <(printf '%s\n' "$raw" | fold -s -w "$limit")
    done
    local width=$(( ${#title} + 3 )) line pad fill
    for line in "${rows[@]:-}"; do (( ${#line} > width )) && width=${#line}; done
    printf -v fill '%*s' $(( width - ${#title} - 1 )) ''; fill=${fill// /$h}
    printf -v pad '%*s' $(( width + 2 )) ''; pad=${pad// /$h}
    printf '%s%s%s %s %s%s%s\n' "${BOX_COLOR:-}" "$tl$h" "$C_OFF${C_BLD}" "$title" "$C_OFF${BOX_COLOR:-}" "$fill$tr" "$C_OFF" >&2
    for line in "${rows[@]:-}"; do
        printf '%s%s%s %-*s %s%s%s\n' "${BOX_COLOR:-}" "$v" "$C_OFF" "$width" "$line" "${BOX_COLOR:-}" "$v" "$C_OFF" >&2
    done
    printf '%s%s%s\n' "${BOX_COLOR:-}" "$bl$pad$br" "$C_OFF" >&2
}

# A short, plain-words guess of what went wrong in a step.
failure_hint() { # step exit-code
    case "$1" in
        connect)   echo "Check the host, the port, the user and the SSH password." ;;
        inspect)   echo "Check the sudo password and that the database exists on the server." ;;
        dump)      echo "Check the sudo password and that the PostgreSQL user can read the database." ;;
        filestore) echo "Run it again: a server in use can change files while they are copied. See the log for the tar message." ;;
        assemble)  echo "Check the free disk space in the output directory." ;;
        restore)   echo "Read odoo-load.log in the work directory: it holds the Odoo output." ;;
        sanitize)  echo "Read the log: a SQL statement of the clean-up failed." ;;
        verify)    echo "Read the log: the restored copy did not pass a safety check." ;;
        *)         echo "Read the log for details." ;;
    esac
}

# The only report of a failed run: one frame, and the same facts in the log file.
print_failure() { # exit-code line
    local rc=$1 line=$2
    local what="step '${CURRENT_STEP}' failed (exit ${rc})"
    [[ -n "$line" ]] && what="step '${CURRENT_STEP}' failed (line ${line}, exit ${rc})"
    FAILURE_REPORTED=1
    [[ -n "$LOG_FILE" ]] && printf '%s [ERROR] %s\n' "$(_stamp)" "$what" >>"$LOG_FILE"
    _eol
    printf '\n' >&2
    BOX_COLOR=$C_RED box "$I_ERROR Failed" \
        "$what" \
        "Hint: ${FAILURE_HINT:-$(failure_hint "$CURRENT_STEP" "$rc")}" \
        "Log:  ${LOG_FILE:-(no log file yet)}"
}

# The steps that ran with their duration, the warnings they raised, and what to do next.
print_summary() {
    # A dry run or a command without steps (check, profiles...) has nothing to summarize.
    (( DRY_RUN )) && return 0
    (( ${#STEP_LOG[@]} )) || return 0
    local total=$((SECONDS - RUN_START)) entry name secs note tick=${I_OK// /} restored=0 assembled=0
    local warn=${I_WARN// /}
    printf '\n' >&2
    for entry in "${STEP_LOG[@]:-}"; do
        [[ -n "$entry" ]] || continue
        name=${entry%%|*}; secs=${entry##*|}
        printf '  %s%s%s %-11s %s\n' "$C_GRN" "$tick" "$C_OFF" "$name" "$(fmt_dur "$secs")" >&2
        for note in "${STEP_NOTES[@]:-}"; do
            [[ -n "$note" && "${note%%|*}" == "$name" ]] && printf '      %s%s %s%s\n' "$C_YEL" "$warn" "${note#*|}" "$C_OFF" >&2
        done
        [[ "$name" == restore ]] && restored=1
        [[ "$name" == assemble ]] && assembled=1
    done
    local -a lines=()
    if (( restored )) && [[ -n "$LOCAL_DB" ]]; then
        local size=""
        size=$(psql_local postgres -Atc "select pg_size_pretty(pg_database_size('${LOCAL_DB//\'/}'))" 2>/dev/null || true)
        lines+=("Database  $LOCAL_DB${size:+  ($size)}")
        lines+=("Use it    set  db_name = $LOCAL_DB  in odoo.conf, then restart Odoo")
    fi
    if (( assembled )) && [[ -n "$ZIP_OUT" && -f "$ZIP_OUT" ]]; then
        lines+=("Zip       $ZIP_OUT  ($(fmt_bytes "$(stat -c %s "$ZIP_OUT" 2>/dev/null || echo 0)"))")
    fi
    [[ -z "$LOG_FILE" ]] || lines+=("Log       $LOG_FILE")
    printf '\n' >&2
    BOX_COLOR=$C_GRN box "$I_OK Done in $(fmt_dur "$total")" "${lines[@]:-}"
    # The name of the restored database is the one fact needed next: it gets a bar of its own (black on green), between two
    # rules, last under the frame.
    if (( restored )) && [[ -n "$LOCAL_DB" ]]; then
        local text=" LOCAL DATABASE  $LOCAL_DB " rule fill="="
        (( UI_TTY && UI_UTF )) && fill="━"
        printf -v rule '%*s' "${#text}" ''; rule=${rule// /$fill}
        printf '\n  %s%s%s\n  %s%s%s\n  %s%s%s\n\n' "$C_GRN" "$rule" "$C_OFF" "$C_HL" "$text" "$C_OFF" "$C_GRN" "$rule" "$C_OFF" >&2
    fi
}
