#!/usr/bin/env bash
# Full cycle against the fake remote (no server involved).
#   SOURCE_DB  local database used as the "remote" one   (required)
#   SOURCE_FS  its local filestore folder                (required, any folder with files)
#   ODOO_*     how to reach your local Odoo               (required)
set -Eeuo pipefail
here=$(cd "$(dirname "$0")" && pwd)
: "${SOURCE_DB:?set SOURCE_DB}" "${SOURCE_FS:?set SOURCE_FS}"
: "${ODOO_BIN:?}" "${ODOO_PYTHON:?}" "${ODOO_CONF:?}"
TARGET_DB=${TARGET_DB:-odoo_mirror_selftest}
WORK=$(mktemp -d /tmp/odoo-mirror-selftest.XXXXXX)
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/remote/filestore/$SOURCE_DB"
# sed reads everything: with pipefail a "head" would kill find with SIGPIPE
( cd "$SOURCE_FS" && find . -type f | sed -n '1,300p' | cpio -pdm --quiet "$WORK/remote/filestore/$SOURCE_DB" )

export ODOO_MIRROR_SSH_BIN="$here/fake-remote/ssh" PATH="$here/fake-remote:$PATH" ODOO_MIRROR_SUDO_PASSWORD=unused
export PGHOST=${PGHOST:-localhost} PGUSER=${PGUSER:-$USER}

"$here/../../bin/odoo-mirror" all --non-interactive --yes \
    --host fake --remote-db "$SOURCE_DB" --remote-fs-root "$WORK/remote/filestore" \
    --local-db "$TARGET_DB" --out-dir "$WORK/out" \
    --odoo-bin "$ODOO_BIN" --odoo-python "$ODOO_PYTHON" --odoo-conf "$ODOO_CONF"

echo "self-test passed; dropping $TARGET_DB"
PGPASSWORD=${PGPASSWORD:-} psql -h "$PGHOST" -U "$PGUSER" -d postgres -Atc "select pg_terminate_backend(pid) from pg_stat_activity where datname='$TARGET_DB'" >/dev/null
PGPASSWORD=${PGPASSWORD:-} psql -h "$PGHOST" -U "$PGUSER" -d postgres -c "DROP DATABASE IF EXISTS \"$TARGET_DB\""
rm -rf "${DATA_DIR:-$HOME/.local/share/Odoo}/filestore/$TARGET_DB"
