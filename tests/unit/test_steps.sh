#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2016  # the tests set globals read by the sourced modules; $ in single quotes is intended
# shellcheck source=../lib/bootstrap.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/bootstrap.sh"

steps_for() { # command [steps] [skip]
    COMMAND=$1 STEPS_ARG=${2:-} SKIP_ARG=${3:-}
    resolve_steps
    echo "${ACTIVE_STEPS[*]}"
}

assert_eq "connect inspect dump filestore assemble restore sanitize verify cleanup" "$(steps_for all)" "all runs every step, in order"
assert_eq "connect inspect dump filestore assemble" "$(steps_for backup)" "backup stops after the zip"
assert_eq "restore sanitize verify cleanup" "$(steps_for restore)" "restore starts from the zip"
assert_eq "connect" "$(steps_for discover)" "discover only connects"
assert_eq "" "$(steps_for check)" "check runs no step"

assert_eq "dump assemble" "$(steps_for all "assemble,dump")" "--steps keeps the canonical order"
assert_eq "connect inspect dump assemble" "$(steps_for backup "" "filestore")" "--skip removes a step"
assert_eq "connect inspect dump" "$(steps_for backup "" "filestore,assemble")" "--skip accepts a list"

assert_fails "an unknown step is refused" bash -c "
    source '$TESTS_DIR/lib/bootstrap.sh'; COMMAND=all STEPS_ARG=nope SKIP_ARG=; resolve_steps"

COMMAND=backup STEPS_ARG="" SKIP_ARG=""; resolve_steps
assert_eq "5" "$STEP_TOTAL" "STEP_TOTAL matches the selection"
assert_ok "step_active finds a selected step" step_active dump
assert_fails "step_active refuses a step that is not selected" step_active restore
assert_ok "backup needs the server" needs_remote
assert_fails "backup does not need a local restore" needs_local_restore

finish
