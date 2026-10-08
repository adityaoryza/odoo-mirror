# shellcheck shell=bash
# Usage and argument parsing
#
# parse_args only sets variables; validation is in validate.sh.
# This file is sourced by lib/odoo-mirror.sh: it only defines functions and constants.

usage() {
    cat <<EOF
${PROG} ${VERSION} — back up a remote Odoo DB over SSH and restore it locally (neutralized)

USAGE
  ${0##*/} [command] [options]

COMMANDS
  all         every step (default)             backup  connect → … → assemble (writes the zip)
  restore     restore an existing zip locally   discover  list the filestores / DBs on the server
  check       only verify local prerequisites   profiles  list the saved profiles
  update      install the newest release        help      this text
              (update --check: only look)

PROFILE SHORTCUT
  ${0##*/} staging                run the saved profile 'staging' (same as --profile staging)
  ${0##*/} backup staging         the same profile, but only the download

With no arguments in a terminal, a menu asks what to do and a wizard asks for every value.

REMOTE
  --host HOST            ssh host or alias from ~/.ssh/config
  --port N | --user U | --key FILE     ssh port / user / identity file (optional)
  --remote-db NAME       database to back up
  --remote-fs-root DIR   directory that contains the filestore of that DB
                         (empty = search it on the server)
  --no-sudo              run pg_dump / tar without sudo on the server
  --pg-os-user USER      os user that may run pg_dump (default: postgres)

LOCAL
  --local-db NAME        database to create (default: <remote-db>_local)
  --out-dir DIR          where backups and logs go (default: \$HOME/odoo-mirror)
  --odoo-bin FILE  --odoo-python FILE  --odoo-conf FILE
  --zip FILE             restore this zip instead of downloading
  --workdir DIR          write the files of this run in DIR (a run is not resumable yet)

STEPS    ${ALL_STEPS[*]}
  --steps a,b,c          run only these steps
  --skip a,b             run everything except these

SAFETY
  --no-neutralize        do NOT neutralize (needs --i-understand-emails-will-be-live)
  --no-sanitize          keep S3/backup credentials of the copy
  --anonymize            OPTIONAL: replace the personal data of private individuals
                         (default: the real customer data is kept, e.g. to test with real cases)
  --sanitize-sql FILE    extra SQL run on the copy (team specific)
  --force                replace the local database if it exists
  --keep-build           keep the intermediate files (dump.sql, filestore/)

OTHER
  --profile NAME         load ${CONFIG_HOME}/profiles/NAME.conf
  --save-profile NAME    save the (non secret) settings and continue
  -y, --yes              assume "yes" to confirmations
  --non-interactive      never prompt (fail when a value is missing)
  --dry-run              show the plan, do nothing
  --version, -h, --help

SECRETS
  ssh password/passphrase  asked by ssh itself, once (connection is reused)
  sudo password            asked here (hidden), or ODOO_MIRROR_SUDO_PASSWORD (discouraged)
  Nothing secret is written to disk, to the log or to the process list.

EXAMPLES
  ${0##*/}                                          # wizard
  ${0##*/} --profile staging                        # saved settings
  ${0##*/} backup --host myserver --remote-db mydb  # download only
  ${0##*/} restore --zip ~/odoo-mirror/mydb/x.zip --local-db mydb_local
EOF
}

need_val() { [[ $# -ge 2 && -n "$2" ]] || die "Option $1 needs a value"; }

parse_args() {
    while (( $# )); do
        case "$1" in
            all|backup|restore|discover|check|profiles|update|help) COMMAND=$1 ;;
            --host) need_val "$@"; REMOTE_HOST=$2; shift ;;
            --port) need_val "$@"; SSH_PORT=$2; shift ;;
            --user) need_val "$@"; SSH_USER=$2; shift ;;
            --key) need_val "$@"; SSH_KEY=$2; shift ;;
            --remote-db) need_val "$@"; REMOTE_DB=$2; shift ;;
            --remote-fs-root) need_val "$@"; REMOTE_FS_ROOT=$2; shift ;;
            --no-sudo) USE_SUDO=0 ;;
            --pg-os-user) need_val "$@"; REMOTE_PG_OSUSER=$2; shift ;;
            --local-db) need_val "$@"; LOCAL_DB=$2; shift ;;
            --out-dir) need_val "$@"; OUT_DIR=$2; shift ;;
            --odoo-bin) need_val "$@"; ODOO_BIN=$2; shift ;;
            --odoo-python) need_val "$@"; ODOO_PYTHON=$2; shift ;;
            --odoo-conf) need_val "$@"; ODOO_CONF=$2; shift ;;
            --odoo-version-tag) need_val "$@"; ODOO_VERSION_TAG=$2; shift ;;
            --zip) need_val "$@"; ZIP_IN=$2; shift ;;
            --workdir) need_val "$@"; WORK_DIR=$2; shift ;;
            --steps) need_val "$@"; STEPS_ARG=$2; shift ;;
            --skip) need_val "$@"; SKIP_ARG=$2; shift ;;
            --no-neutralize) NEUTRALIZE=0 ;;
            --i-understand-emails-will-be-live) I_UNDERSTAND_LIVE_EMAILS=1 ;;
            --no-sanitize) SANITIZE=0 ;;
            --anonymize) ANONYMIZE=1 ;;
            --sanitize-sql) need_val "$@"; SANITIZE_SQL_FILE=$2; shift ;;
            --force) FORCE=1 ;;
            --keep-build) KEEP_BUILD=1 ;;
            --profile) need_val "$@"; PROFILE=$2; shift ;;
            --save-profile) need_val "$@"; SAVE_PROFILE=$2; shift ;;
            -y|--yes) ASSUME_YES=1 ;;
            --non-interactive) INTERACTIVE="no" ;;
            --dry-run) DRY_RUN=1 ;;
            --check) UPDATE_CHECK_ONLY=1 ;;
            --version) echo "${PROG} ${VERSION}"; exit 0 ;;
            -h|--help) COMMAND=help ;;
            -*) die "Unknown option: $1 (see --help)" ;;
            *)  # a bare word: the name of a saved profile
                if valid_name "$1" && [[ -f "$CONFIG_HOME/profiles/$1.conf" ]]; then
                    PROFILE=$1
                else
                    die "Unknown command or profile: $1 (saved profiles: $(list_profile_names | tr '\n' ' '); see --help)"
                fi ;;
        esac
        shift
    done
}
