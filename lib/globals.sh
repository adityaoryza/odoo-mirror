# shellcheck shell=bash
# Constants, settings and runtime state
#
# Every default lives here; a profile, the environment or a flag overrides them (see cli.sh and profile.sh).
# This file is sourced by lib/odoo-mirror.sh: it only defines functions and constants.

readonly VERSION="1.1.0"
readonly PROG="odoo-mirror"


###############################################################################
# Settings (every one can come from a profile, an environment variable or a flag)
###############################################################################
CONFIG_HOME="${ODOO_MIRROR_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/odoo-mirror}"
PROFILE=""
SAVE_PROFILE=""

COMMAND=""
REMOTE_HOST="${REMOTE_HOST:-}"
SSH_PORT="${SSH_PORT:-}"
SSH_USER="${SSH_USER:-}"
SSH_KEY="${SSH_KEY:-}"
REMOTE_DB="${REMOTE_DB:-}"
REMOTE_FS_ROOT="${REMOTE_FS_ROOT:-}"
USE_SUDO="${USE_SUDO:-1}"
REMOTE_PG_OSUSER="${REMOTE_PG_OSUSER:-postgres}"

LOCAL_DB="${LOCAL_DB:-}"
OUT_DIR="${OUT_DIR:-$HOME/odoo-mirror}"
ODOO_BIN="${ODOO_BIN:-}"
ODOO_PYTHON="${ODOO_PYTHON:-}"
ODOO_CONF="${ODOO_CONF:-}"
ODOO_VERSION_TAG="${ODOO_VERSION_TAG:-19.0+e}"
SANITIZE_SQL_FILE="${SANITIZE_SQL_FILE:-}"

NEUTRALIZE=1
SANITIZE=1
ANONYMIZE="${ANONYMIZE:-0}"
KEEP_BUILD=0
FORCE=0
ASSUME_YES=0
DRY_RUN=0
UPDATE_CHECK_ONLY=0
INTERACTIVE="auto"
ZIP_IN=""
WORK_DIR=""
STEPS_ARG=""
SKIP_ARG=""
I_UNDERSTAND_LIVE_EMAILS=0

# Keys a profile file may set (profiles are parsed, never sourced).
readonly PROFILE_KEYS=(COMMAND REMOTE_HOST SSH_PORT SSH_USER SSH_KEY REMOTE_DB REMOTE_FS_ROOT
    USE_SUDO REMOTE_PG_OSUSER LOCAL_DB OUT_DIR ODOO_BIN ODOO_PYTHON ODOO_CONF
    ODOO_VERSION_TAG SANITIZE_SQL_FILE NEUTRALIZE SANITIZE ANONYMIZE KEEP_BUILD)

# Words that name a command: a profile cannot take one of them as its name.
readonly COMMAND_NAMES=(all backup restore discover check profiles update help)
readonly ALL_STEPS=(connect inspect dump filestore assemble restore sanitize verify cleanup)
declare -a ACTIVE_STEPS=()

# Runtime state
LOG_FILE=""
SUDO_PW=""
CTL_PATH=""
SSH_CONNECTED=0
REMOTE_DB_PICK=0   # 1 = the user left the database name empty: list the server databases and pick
STEP_TOTAL=0
STEP_INDEX=0
STEP_START=0
RUN_START=$SECONDS
CURRENT_STEP="(init)"
REMOTE_DB_BYTES=0
REMOTE_FS_BYTES=0
REMOTE_FS_FILES=0
REMOTE_PG_VERSION=""
LOCAL_PG_HOST="" LOCAL_PG_PORT="" LOCAL_PG_USER="" LOCAL_PG_PASSWORD=""
SSH_BIN="${ODOO_MIRROR_SSH_BIN:-ssh}"
declare -a PARTIAL_FILES=()

# Paths of the current run (set by the steps).
BUILD_DIR=""
SQL_GZ=""
ZIP_OUT=""
