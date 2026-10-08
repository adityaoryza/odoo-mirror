# shellcheck shell=bash
# A tiny assertion library: no dependency, one process per test file.
#
#   assert_eq EXPECTED ACTUAL LABEL
#   assert_ok LABEL CMD...        the command succeeds
#   assert_fails LABEL CMD...     the command exits non-zero
#   assert_contains TEXT NEEDLE LABEL
#   finish                        prints the summary, exits non-zero when something failed

T_PASS=0
T_FAIL=0

_t_ok() { T_PASS=$((T_PASS + 1)); printf '  \033[32m✔\033[0m %s\n' "$1"; }
_t_ko() { T_FAIL=$((T_FAIL + 1)); printf '  \033[31m✘\033[0m %s\n' "$1"; shift; [[ $# -gt 0 ]] && printf '      %s\n' "$@"; return 0; }

assert_eq() {
    if [[ "$1" == "$2" ]]; then _t_ok "$3"; else _t_ko "$3" "expected: [$1]" "     got: [$2]"; fi
}

assert_ok() {
    local label=$1; shift
    if ( "$@" ) >/dev/null 2>&1; then _t_ok "$label"; else _t_ko "$label" "command failed: $*"; fi
}

assert_fails() {
    local label=$1; shift
    if ( "$@" ) >/dev/null 2>&1; then _t_ko "$label" "command should have failed: $*"; else _t_ok "$label"; fi
}

assert_contains() {
    if [[ "$1" == *"$2"* ]]; then _t_ok "$3"; else _t_ko "$3" "missing: [$2]" "in: [${1:0:200}]"; fi
}

finish() {
    printf '  %d passed, %d failed\n' "$T_PASS" "$T_FAIL"
    [[ "$T_FAIL" -eq 0 ]]
}
