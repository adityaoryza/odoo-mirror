# shellcheck shell=bash
# Step: verify
#
# One step of a run. Registered in ALL_STEPS (globals.sh) and in resolve_steps (plan.sh).
# This file is sourced by lib/odoo-mirror.sh: it only defines functions and constants.

step_verify() {
    step_begin verify "Verify the restored copy"
    local fails=0
    chk() { # label ok(0/1) detail
        if [[ "$2" == 0 ]]; then printf '  %s✔%s %-26s %s\n' "$C_GRN" "$C_OFF" "$1" "$3" >&2
        else printf '  %s✘%s %-26s %s\n' "$C_RED" "$C_OFF" "$1" "$3" >&2; fails=$((fails + 1)); fi
        log_file_only "verify $1 ok=$2 $3"
    }
    local neut crons mails
    neut=$(psql_local "$LOCAL_DB" -Atc "select value from ir_config_parameter where key='database.is_neutralized'" 2>/dev/null || true)
    if (( NEUTRALIZE )); then
        if [[ "$neut" == "True" || "$neut" == "true" || "$neut" == "t" ]]; then
            chk neutralized 0 "database.is_neutralized = $neut"
        else
            chk neutralized 1 "flag missing"
        fi
        crons=$(psql_local "$LOCAL_DB" -Atc "select count(*) from ir_cron c where active and not exists (select 1 from ir_model_data d where d.model='ir.cron' and d.res_id=c.id and d.name='autovacuum_job')")
        if [[ "$crons" == 0 ]]; then
            chk "active crons" 0 "0 (autovacuum excluded)"
        else
            chk "active crons" 1 "$crons still active"
        fi
        mails=$(psql_local "$LOCAL_DB" -Atc "select coalesce(string_agg(name||' @'||coalesce(smtp_host,'-'), '; '), '') from ir_mail_server where active")
        if [[ "$mails" == *"neutralization"* && "$mails" != *";"* ]]; then
            chk "outgoing mail" 0 "$mails"
        else
            chk "outgoing mail" 1 "active servers: ${mails:-none}"
        fi
    else
        chk neutralized 0 "(not requested)"
    fi
    if (( SANITIZE )); then
        local s3; s3=$(psql_local "$LOCAL_DB" -Atc "select count(*) from ir_config_parameter where key ilike 's3.%'")
        if [[ "$s3" == 0 ]]; then
            chk "object storage keys" 0 "none"
        else
            chk "object storage keys" 1 "$s3 left"
        fi
    fi
    if (( ANONYMIZE )); then
        local real
        real=$(psql_local "$LOCAL_DB" -Atc "select count(*) from res_partner p where type='contact' and not is_company and email is not null and email not like '%@example.invalid' and not exists (select 1 from res_users u where u.partner_id=p.id)")
        if [[ "$real" == 0 ]]; then
            chk "personal data" 0 "anonymized (private individuals)"
        else
            chk "personal data" 1 "$real contacts still hold a real e-mail"
        fi
    else
        chk "personal data" 0 "real customer data kept (as requested)"
    fi
    local so tk
    so=$(psql_local "$LOCAL_DB" -Atc "select count(*) from sale_order" 2>/dev/null || echo "-")
    tk=$(psql_local "$LOCAL_DB" -Atc "select count(*) from project_task" 2>/dev/null || echo "-")
    chk "data present" 0 "sale orders: $so, tasks: $tk"
    local fsdir; fsdir="$(filestore_root_local)/$LOCAL_DB"
    if [[ -d "$fsdir" ]]; then
        chk filestore 0 "$(du -sh "$fsdir" | cut -f1) in $fsdir"
    else
        chk filestore 1 "folder missing: $fsdir (the zip had no filestore?)"
    fi
    (( fails == 0 )) || die "$fails verification check(s) failed"
    step_end
}
