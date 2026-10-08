# shellcheck shell=bash
# Loads every module, in dependency order. Sourced by bin/odoo-mirror (and by the unit tests).
#
# Required before sourcing: ROOT_DIR, LIB_DIR and SQL_DIR.
#
# Order matters only for what runs at load time: globals first (the variables), then the
# logger (it sets the colors). Functions are resolved when they are called.

# shellcheck source=globals.sh
source "$LIB_DIR/globals.sh"
# shellcheck source=log.sh
source "$LIB_DIR/log.sh"
# shellcheck source=progress.sh
source "$LIB_DIR/progress.sh"
# shellcheck source=input.sh
source "$LIB_DIR/input.sh"
# shellcheck source=profile.sh
source "$LIB_DIR/profile.sh"
# shellcheck source=validate.sh
source "$LIB_DIR/validate.sh"
# shellcheck source=local.sh
source "$LIB_DIR/local.sh"
# shellcheck source=ssh.sh
source "$LIB_DIR/ssh.sh"
# shellcheck source=plan.sh
source "$LIB_DIR/plan.sh"
# shellcheck source=config.sh
source "$LIB_DIR/config.sh"
# shellcheck source=cli.sh
source "$LIB_DIR/cli.sh"

# One file per step.
# shellcheck source=steps/connect.sh
source "$LIB_DIR/steps/connect.sh"
# shellcheck source=steps/inspect.sh
source "$LIB_DIR/steps/inspect.sh"
# shellcheck source=steps/dump.sh
source "$LIB_DIR/steps/dump.sh"
# shellcheck source=steps/filestore.sh
source "$LIB_DIR/steps/filestore.sh"
# shellcheck source=steps/assemble.sh
source "$LIB_DIR/steps/assemble.sh"
# shellcheck source=steps/restore.sh
source "$LIB_DIR/steps/restore.sh"
# shellcheck source=steps/sanitize.sh
source "$LIB_DIR/steps/sanitize.sh"
# shellcheck source=steps/verify.sh
source "$LIB_DIR/steps/verify.sh"
# shellcheck source=steps/cleanup.sh
source "$LIB_DIR/steps/cleanup.sh"

# shellcheck source=commands.sh
source "$LIB_DIR/commands.sh"
# shellcheck source=runtime.sh
source "$LIB_DIR/runtime.sh"
# shellcheck source=main.sh
source "$LIB_DIR/main.sh"
