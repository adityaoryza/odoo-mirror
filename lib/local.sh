# shellcheck shell=bash
# Local Odoo and PostgreSQL
#
# Reads odoo.conf, talks to the local PostgreSQL, drops a local database.
# This file is sourced by lib/odoo-mirror.sh: it only defines functions and constants.

conf_get() { # key  -> value from ODOO_CONF ('' when missing or False)
    [[ -f "$ODOO_CONF" ]] || return 0
    local v
    v=$(awk -F'[[:space:]]*=[[:space:]]*' -v k="$1" '$1 == k {print $2; exit}' "$ODOO_CONF" | tr -d '\r')
    [[ "$v" == "False" || "$v" == "false" ]] && v=""
    printf '%s' "$v"
}

detect_local_defaults() {
    local root had_bin=$ODOO_BIN had_python=$ODOO_PYTHON had_conf=$ODOO_CONF
    for root in "$PWD" "$HOME/project-19" "$HOME/odoo"; do
        [[ -z "$ODOO_BIN" && -f "$root/odoo/odoo-bin" ]] && ODOO_BIN="$root/odoo/odoo-bin"
        [[ -z "$ODOO_BIN" && -f "$root/odoo-bin" ]] && ODOO_BIN="$root/odoo-bin"
        [[ -z "$ODOO_CONF" && -f "$root/odoo.conf" ]] && ODOO_CONF="$root/odoo.conf"
    done
    if [[ -z "$ODOO_PYTHON" ]]; then
        # Pick the virtualenv of the same Odoo major version as odoo-bin.
        local major="" rel cand
        rel="$(dirname "${ODOO_BIN:-/nonexistent}")/odoo/release.py"
        [[ -f "$rel" ]] && major=$(sed -n 's/^version_info = (\([0-9]*\),.*/\1/p' "$rel" | head -1)
        for cand in ${major:+"$HOME/venv-odoo-${major}.0/bin/python3"} ${major:+"$HOME"/venv-odoo-"${major}"*/bin/python3} \
                    "$(dirname "${ODOO_BIN:-/x}")/../venv/bin/python3" "$HOME/venv/bin/python3" "$(command -v python3 || true)"; do
            [[ -x "$cand" ]] && { ODOO_PYTHON=$cand; break; }
        done
    fi
    [[ ( -z "$had_bin" && -n "$ODOO_BIN" ) || ( -z "$had_python" && -n "$ODOO_PYTHON" ) || ( -z "$had_conf" && -n "$ODOO_CONF" ) ]] \
        && ODOO_LOCAL_AUTO=1
    return 0
}

parse_odoo_version() { # "17.0.1.3" -> "17.0"; prints nothing when the value is empty or not a version
    local v=${1:-}
    if [[ "$v" =~ ^([0-9]+\.[0-9]+)(\.|\+|$) ]]; then printf '%s' "${BASH_REMATCH[1]}"; fi
}

local_odoo_version() { # [odoo-bin]  MAJOR.MINOR of the chosen odoo-bin (from odoo/release.py); nothing when unknown
    local rel; rel="$(dirname "${1:-${ODOO_BIN:-/nonexistent}}")/odoo/release.py"
    [[ -f "$rel" ]] || return 0
    local v; v=$(sed -n 's/^version_info = (\([0-9]*\), *\([0-9]*\).*/\1.\2/p' "$rel" | head -1)
    parse_odoo_version "$v"
}

zip_odoo_version() { # zip -> MAJOR.MINOR recorded in its manifest.json; nothing when absent or odd
    local v
    v=$(unzip -p "$1" manifest.json 2>/dev/null | sed -n 's/.*"major_version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1) || true
    parse_odoo_version "$v"
}

# The version tag written in a manifest follows the local Odoo: "17.0" + the suffix of the current tag ("+e" when enterprise).
refresh_version_tag() {
    local v; v=$(local_odoo_version)
    [[ -n "$v" ]] || return 0
    local suffix=""; [[ "$ODOO_VERSION_TAG" == *+* ]] && suffix="+${ODOO_VERSION_TAG#*+}"
    ODOO_VERSION_TAG="${v}${suffix}"
}

# ask_path VAR "Question" f|x [default]: asks until the path exists as a file (f) or an executable (x); empty = give up.
ask_path() {
    local var=$1 question=$2 kind=$3 default=${4:-} tries=0
    while (( tries++ < 3 )); do
        printf -v "$var" '%s' ""
        ask "$var" "$question" "$default" || return 1
        expand_paths
        if [[ "$kind" == x ]]; then [[ -x "${!var}" && -f "${!var}" ]] && return 0
        else [[ -f "${!var}" ]] && return 0; fi
        printf '  Not found: %s\n' "${!var}" >&2
        default=""
    done
    return 1
}

# Asks for odoo-bin, python and odoo.conf by hand (the three are asked again, whatever they were).
ask_local_odoo_by_hand() {
    ask_path ODOO_BIN    "Path to odoo-bin" f || die "odoo-bin is required"
    ask_path ODOO_PYTHON "Python interpreter for Odoo" x || die "A python interpreter is required"
    ask_path ODOO_CONF   "Path to odoo.conf" f || die "odoo.conf is required"
}

# Odoo checkouts under $HOME (read only, bounded): odoo-bin files, one per line.
find_odoo_bins() {
    [[ -d "${HOME:-}" ]] || return 0
    find "$HOME" -mindepth 1 -maxdepth 4 \( -path /mnt -o -path '/mnt/*' -o -name node_modules -o -name .cache -o -name .git \
        -o -name .npm -o -name site-packages -o -name venv -o -name '.venv' -o -name 'venv-*' -o -name 'venv[0-9]*' \) -prune \
        -o -name odoo-bin -type f -print 2>/dev/null | sort
}

# suggest_python MAJOR -> a virtualenv python made for that Odoo major, when one exists
suggest_python() {
    local c
    for c in "$HOME/venv-odoo-$1.0/bin/python3" "$HOME/venv-odoo-$1/bin/python3" "$HOME/venv$1/bin/python3"; do
        [[ -x "$c" ]] && { printf '%s' "$c"; return 0; }
    done
}

# suggest_conf ODOO_BIN -> the first *.conf next to odoo-bin or one level above (odoo.conf first)
suggest_conf() {
    local d c
    for d in "$(dirname "$1")" "$(dirname "$1")/.."; do
        for c in "$d/odoo.conf" "$d"/*.conf; do
            [[ -f "$c" ]] && { (cd "$(dirname "$c")" && printf '%s/%s' "$PWD" "$(basename "$c")"); return 0; }
        done
    done
}

# Interactive rescue after a version mismatch: lists the Odoo of the wanted major found under $HOME and switches the run to
# the one picked. Returns 1 when nothing was found or chosen.
rescue_local_odoo() { # DB_VERSION
    local major=${1%%.*} bin v
    local -a found=() labels=()
    log_info "Looking for odoo-bin under $HOME (read only, 4 levels deep)..."
    while IFS= read -r bin; do
        v=$(local_odoo_version "$bin")
        [[ -n "$v" && "${v%%.*}" == "$major" ]] || continue
        found+=("$bin"); labels+=("$bin  (Odoo $v)")
    done < <(find_odoo_bins)
    if (( ${#found[@]} == 0 )); then
        log_warn "No Odoo $major found under $HOME."
        return 1
    fi
    local i
    for i in "${!found[@]}"; do printf '  %2d) %s\n' $((i + 1)) "${labels[i]}" >&2; done
    printf '  %2d) Type the paths by hand\n' $((${#found[@]} + 1)) >&2
    local answer=""
    read_answer answer "  Choice [1-$((${#found[@]} + 1)), empty = cancel]: "
    [[ -n "$answer" ]] || return 1
    if [[ "$answer" =~ ^[0-9]+$ ]] && (( answer >= 1 && answer <= ${#found[@]} )); then
        local py conf
        ODOO_BIN=${found[answer - 1]}
        py=$(suggest_python "$major"); conf=$(suggest_conf "$ODOO_BIN")
        printf -v ODOO_PYTHON '%s' ""; printf -v ODOO_CONF '%s' ""
        ask_path ODOO_PYTHON "Python interpreter for Odoo" x "$py" || die "A python interpreter is required"
        ask_path ODOO_CONF "Path to odoo.conf" f "$conf" || die "odoo.conf is required"
    elif [[ "$answer" =~ ^[0-9]+$ ]] && (( answer == ${#found[@]} + 1 )); then
        ask_local_odoo_by_hand
    else
        return 1
    fi
    validate_local_odoo
    return 0
}

# check_odoo_version DB_VERSION LOCAL_VERSION: dies (or warns with --allow-version-mismatch) when the majors differ;
# an unknown version on either side skips the check. In a terminal it first offers to look for the matching Odoo.
check_odoo_version() {
    local dbv=${1:-} lov=${2:-}
    [[ -n "$dbv" && -n "$lov" ]] || { log_file_only "Odoo version check skipped (database: '${dbv}', local: '${lov}')"; return 0; }
    [[ "${dbv%%.*}" != "${lov%%.*}" ]] || return 0
    local msg="The database on the server is Odoo $dbv but the local Odoo (${ODOO_BIN:-?}) is $lov: pick the matching Odoo with --odoo-bin/--odoo-python/--odoo-conf (or a profile that has them)."
    if (( ALLOW_VERSION_MISMATCH )); then
        log_warn "$msg Continuing because of --allow-version-mismatch."
        return 0
    fi
    if is_interactive && (( ! ASSUME_YES )); then
        log_warn "$msg"
        if ask_yn "Look for an Odoo ${dbv%%.*} on this machine?" y && rescue_local_odoo "$dbv"; then
            local nv; nv=$(local_odoo_version)
            if [[ -n "$nv" && "${nv%%.*}" != "${dbv%%.*}" ]]; then
                log_error "That Odoo is $nv, not ${dbv%%.*}."
            else
                refresh_version_tag
                load_local_pg
                log_ok "local Odoo: $ODOO_BIN${nv:+ (Odoo $nv)}"
                offer_profile_update
                return 0
            fi
        fi
    fi
    FAILURE_HINT="Use the Odoo that matches the database (--odoo-bin, --odoo-python, --odoo-conf or a profile that has them), or add --allow-version-mismatch to go on anyway."
    die "$msg"
}

load_local_pg() {
    LOCAL_PG_HOST=$(conf_get db_host); LOCAL_PG_HOST=${LOCAL_PG_HOST:-localhost}
    LOCAL_PG_PORT=$(conf_get db_port); LOCAL_PG_PORT=${LOCAL_PG_PORT:-5432}
    LOCAL_PG_USER=$(conf_get db_user); LOCAL_PG_USER=${LOCAL_PG_USER:-${USER:-postgres}}
    LOCAL_PG_PASSWORD=$(conf_get db_password)
}

psql_local() { # database psql-args...
    local db=$1; shift
    PGPASSWORD="$LOCAL_PG_PASSWORD" psql -X -q -h "$LOCAL_PG_HOST" -p "$LOCAL_PG_PORT" \
        -U "$LOCAL_PG_USER" -d "$db" "$@"
}

local_db_exists() {
    [[ "$(psql_local postgres -Atc "select 1 from pg_database where datname='${1//\'/}'")" == 1 ]]
}

drop_local_db() { # name — psql based, also removes its filestore
    local db=$1
    valid_name "$db" || die "Invalid database name: $db"
    psql_local postgres -Atc "select pg_terminate_backend(pid) from pg_stat_activity where datname='${db}'" >/dev/null
    psql_local postgres -c "DROP DATABASE IF EXISTS \"${db}\"" >>"$LOG_FILE" 2>&1 || die "Could not drop database $db"
    rm -rf "$(filestore_root_local)/${db:?}"
}

filestore_root_local() {
    local d; d=$(conf_get data_dir); d=${d:-$HOME/.local/share/Odoo}
    printf '%s/filestore' "$d"
}

psql_min_for_restrict() { # psql major -> minimum minor that understands \restrict
    case "$1" in 13) echo 22;; 14) echo 19;; 15) echo 14;; 16) echo 10;; 17) echo 6;; *) echo 0;; esac
}

# odoo.conf is read by Odoo with a strict parser: an option written twice stops Odoo at startup, after the download.
conf_duplicate_options() { # -> "name (lines 9, 10)" for each option that appears twice in the file; nothing when fine
    [[ -f "$ODOO_CONF" ]] || return 0
    awk -F'[[:space:]]*=[[:space:]]*' '
        /^[[:space:]]*[#;]/ || !/=/ { next }
        { key = $1; gsub(/^[[:space:]]+|[[:space:]]+$/, "", key); lines[key] = lines[key] (lines[key] ? ", " : "") NR; seen[key]++ }
        END { for (k in seen) if (seen[k] > 1) printf "%s (lines %s)\n", k, lines[k] }
    ' "$ODOO_CONF" | sort
}

# <server database>_<YYMMDD>, then _2, _3... while the name is taken (a database, a filestore folder, or the db_name of odoo.conf).
auto_local_db_name() {
    local base=${REMOTE_DB:-}
    if [[ -z "$base" && -n "${ZIP_IN:-}" ]]; then
        base=$(basename "$ZIP_IN" .zip)
        base=${base%_20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]}   # the date that odoo-mirror puts in the zip name
    fi
    base=${base:-odoo_mirror}
    base=${base//[^A-Za-z0-9_]/_}
    base=${base:0:40}                                      # PostgreSQL names stop at 63 characters
    local stamp active fs candidate n=1
    stamp=$(date +%y%m%d); active=$(conf_get db_name); fs=$(filestore_root_local)
    candidate="${base}_${stamp}"
    while [[ "$candidate" == "$active" ]] || local_db_exists "$candidate" || [[ -e "$fs/$candidate" ]]; do
        n=$((n + 1)); candidate="${base}_${stamp}_${n}"
    done
    printf '%s' "$candidate"
}

# --local-db auto (or nothing): pick the name now that the server database is known.
resolve_local_db() {
    needs_local_restore || return 0
    [[ -z "$LOCAL_DB" || "$LOCAL_DB" == auto ]] || return 0
    load_local_pg
    LOCAL_DB=$(auto_local_db_name)
    LOCAL_DB_AUTO=1
    log_ok "local database: $LOCAL_DB (automatic: <server database>_<date>, then _2, _3... when the name is taken)"
}
