#!/usr/bin/env bash
# shellcheck disable=SC2034
# shellcheck source=../lib/bootstrap.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/bootstrap.sh"

# Release, install and update, entirely on this machine: releases are read from a folder (file://), HOME is a
# temporary directory, nothing is downloaded.
export HOME="$TMP/home" SHELL=/bin/bash PATH="/usr/bin:/bin"
mkdir -p "$HOME"; : >"$HOME/.bashrc"
BASE="$TMP/base"
export ODOO_MIRROR_RELEASE_BASE="file://$BASE" ODOO_MIRROR_PREFIX="$TMP/share"

# A release of this tree (1.0.0 or whatever VERSION says) ...
current_version=$(sed -n 's/^readonly VERSION="\(.*\)"$/\1/p' "$ROOT_DIR/lib/globals.sh")
"$ROOT_DIR/scripts/release.sh" "$TMP/dist1" >/dev/null
mkdir -p "$BASE/v$current_version"; cp "$TMP/dist1"/* "$BASE/v$current_version/"; echo "v$current_version" >"$BASE/latest"
assert_eq "yes" "$([[ -s "$TMP/dist1/SHA256SUMS" ]] && echo yes || echo no)" "release.sh writes SHA256SUMS"
assert_eq "no" "$(tar -tzf "$TMP/dist1/odoo-mirror-v$current_version.tar.gz" | grep -c '/tests/' | grep -q '^0$' && echo no || echo yes)" "the archive does not carry the tests"

# ... installed from a pipe, like `curl | bash`.
out=$(cat "$ROOT_DIR/scripts/install.sh" | bash 2>&1); rc=$?
assert_eq "0" "$rc" "the one-line install works"
assert_contains "$out" "checksum OK" "...after checking the checksum"
assert_eq "odoo-mirror $current_version" "$("$HOME/.local/bin/odoo-mirror" --version)" "...and the command runs"
assert_contains "$(cat "$HOME/.bashrc")" ">>> odoo-mirror >>>" "...and PATH is set up"

# A second run changes nothing.
assert_contains "$(bash "$ROOT_DIR/scripts/install.sh" remote 2>&1)" "already up to date" "installing again says it is up to date"
assert_contains "$(bash "$ROOT_DIR/scripts/install.sh" remote --check 2>&1)" "up to date" "--check agrees"

# A newer release appears: a copy of the tree with a higher version.
newer=9.9.9
cp -R "$ROOT_DIR" "$TMP/newer" && rm -rf "$TMP/newer/dist" "$TMP/newer/.git"
sed -i "s/^readonly VERSION=.*/readonly VERSION=\"$newer\"/" "$TMP/newer/lib/globals.sh"
"$TMP/newer/scripts/release.sh" "$TMP/dist2" >/dev/null
mkdir -p "$BASE/v$newer"; cp "$TMP/dist2"/* "$BASE/v$newer/"; echo "v$newer" >"$BASE/latest"

assert_contains "$("$HOME/.local/bin/odoo-mirror" update --check 2>&1)" "update available: $current_version -> $newer" "update --check sees the new release"
assert_eq "odoo-mirror $current_version" "$("$HOME/.local/bin/odoo-mirror" --version)" "...without installing it"
"$HOME/.local/bin/odoo-mirror" update >/dev/null 2>&1
assert_eq "odoo-mirror $newer" "$("$HOME/.local/bin/odoo-mirror" --version)" "update installs it"
assert_eq "yes" "$([[ -d "$TMP/share/v$current_version" ]] && echo yes || echo no)" "...and keeps the previous release for a rollback"

# A tampered archive is refused and leaves the installation alone.
mkdir -p "$TMP/bad/v9.9.10"; cp "$TMP/dist2"/* "$TMP/bad/v9.9.10/"
mv "$TMP/bad/v9.9.10/odoo-mirror-v9.9.9.tar.gz" "$TMP/bad/v9.9.10/odoo-mirror-v9.9.10.tar.gz"
sed -i 's/v9.9.9/v9.9.10/' "$TMP/bad/v9.9.10/SHA256SUMS"
echo "tampered" >>"$TMP/bad/v9.9.10/odoo-mirror-v9.9.10.tar.gz"
echo "v9.9.10" >"$TMP/bad/latest"
bad_out=$(ODOO_MIRROR_RELEASE_BASE="file://$TMP/bad" "$HOME/.local/bin/odoo-mirror" update 2>&1); bad_rc=$?
assert_contains "$bad_out" "CHECKSUM MISMATCH" "a tampered archive is refused"
assert_eq "odoo-mirror $newer" "$("$HOME/.local/bin/odoo-mirror" --version)" "...and the installed version is untouched"

# A source checkout is never updated.
assert_contains "$("$ROOT_DIR/bin/odoo-mirror" update 2>&1)" "source checkout" "a checkout points to git pull"

# Uninstall removes the link and the PATH lines.
bash "$ROOT_DIR/scripts/install.sh" uninstall >/dev/null 2>&1
assert_eq "no" "$([[ -e "$HOME/.local/bin/odoo-mirror" || -L "$HOME/.local/bin/odoo-mirror" ]] && echo yes || echo no)" "uninstall removes the command"
assert_eq "0" "$(grep -c 'odoo-mirror' "$HOME/.bashrc")" "...and the PATH lines"

finish
