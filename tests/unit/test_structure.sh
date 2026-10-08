#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2016
# shellcheck source=../lib/bootstrap.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/bootstrap.sh"

# --- a function is defined once, in one module ----------------------------------------------------
dups=$(grep -rhoE '^[a-zA-Z_][a-zA-Z0-9_]*\(\) *\{' "$LIB_DIR" | sed 's/() *{//' | sort | uniq -d | tr '\n' ' ')
assert_eq "" "$dups" "no function is defined twice"

# --- every module is loaded, and every loaded module exists ---------------------------------------
orphans=""
while IFS= read -r f; do
    rel=${f#"$LIB_DIR"/}
    [[ "$rel" == "odoo-mirror.sh" ]] && continue
    grep -q "source \"\$LIB_DIR/$rel\"" "$LIB_DIR/odoo-mirror.sh" || orphans+="$rel "
done < <(find "$LIB_DIR" -name '*.sh' | sort)
assert_eq "" "$orphans" "every module under lib/ is loaded by lib/odoo-mirror.sh"

missing=""
while IFS= read -r rel; do
    [[ -f "$LIB_DIR/$rel" ]] || missing+="$rel "
done < <(sed -nE 's#^source "\$LIB_DIR/(.*)"$#\1#p' "$LIB_DIR/odoo-mirror.sh")
assert_eq "" "$missing" "every module that is loaded exists"

# --- every step has its function and its file -----------------------------------------------------
bad=""
for s in "${ALL_STEPS[@]}"; do
    [[ -f "$LIB_DIR/steps/$s.sh" ]] || bad+="file:$s "
    declare -F "step_$s" >/dev/null || bad+="function:$s "
done
assert_eq "" "$bad" "every step in ALL_STEPS has lib/steps/<name>.sh and step_<name>()"

# --- a step file holds its step and nothing else of the same kind ---------------------------------
extra=""
for f in "$LIB_DIR"/steps/*.sh; do
    n=$(basename "$f" .sh)
    others=$(grep -oE '^step_[a-z]+\(\)' "$f" | grep -v "^step_${n}()" | tr '\n' ' ')
    [[ -z "$others" ]] || extra+="$n:$others"
done
assert_eq "" "$extra" "a step file defines only its own step function"

# --- nothing runs when a module is sourced (the colors are the one documented exception) ----------
assert_eq "0" "$(grep -rcE '^(main|install_traps|trap) ' "$LIB_DIR" | awk -F: '{s+=$2} END {print s}')" "no module starts anything at load time"

finish
