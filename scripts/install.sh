#!/usr/bin/env bash
# Install, update or remove the `odoo-mirror` command, for any shell (bash, zsh, fish, sh).
#
#   curl -fsSL https://github.com/adityaoryza/odoo-mirror/releases/latest/download/install.sh | bash
#   scripts/install.sh [install|remote|uninstall] [options]
#
# Actions:
#   remote      download the latest release, check its SHA-256, install it (default when run from a pipe)
#   install     link this checkout (a git clone) as the command (default when run from a checkout)
#   uninstall   remove the command link and the PATH lines
#
# Options:
#   --prefix DIR   put the command in DIR/bin (for example /usr/local: every user, no rc file touched; needs sudo)
#   --version TAG  remote: install this release (for example v1.0.0) instead of the latest
#   --check        remote: only say whether a newer release exists
#
# Where the command link goes:
#   1. --prefix DIR/bin
#   2. a folder under $HOME that is already in your PATH (~/.local/bin, ~/bin)
#   3. otherwise ~/.local/bin, which is then added to PATH in the rc files of the shells you have.
# Nothing is edited twice: the PATH lines sit between two marker comments.
#
# Environment (all optional):
#   ODOO_MIRROR_REPO          GitHub repository, default adityaoryza/odoo-mirror
#   ODOO_MIRROR_PREFIX        where releases are unpacked, default ~/.local/share/odoo-mirror
#   ODOO_MIRROR_RELEASE_BASE  read releases from here instead of GitHub (a URL or file:// path; used by the tests)
set -euo pipefail

readonly MARK_BEGIN="# >>> odoo-mirror >>>"
readonly MARK_END="# <<< odoo-mirror <<<"
readonly REPO="${ODOO_MIRROR_REPO:-adityaoryza/odoo-mirror}"
readonly INSTALL_ROOT="${ODOO_MIRROR_PREFIX:-$HOME/.local/share/odoo-mirror}"
readonly RELEASE_BASE="${ODOO_MIRROR_RELEASE_BASE:-}"

# Empty when the script is read from a pipe (curl | bash): then there is no checkout around it.
SELF="${BASH_SOURCE[0]:-}"
ROOT=""
if [[ -n "$SELF" && -f "$SELF" ]]; then
    ROOT=$(cd "$(dirname "$(readlink -f "$SELF")")/.." && pwd)
fi

ACTION=""
PREFIX=""
WANT_TAG=""
CHECK_ONLY=0

usage() { sed -n '2,26p' "${SELF:-/dev/null}" 2>/dev/null | sed 's/^# \{0,1\}//'; }
die() { echo "install: $*" >&2; exit 1; }
say() { echo "$*" >&2; }

while (( $# )); do
    case "$1" in
        install|remote|uninstall) ACTION=$1 ;;
        --prefix) PREFIX=${2:?--prefix needs a directory}; shift ;;
        --version) WANT_TAG=${2:?--version needs a tag}; shift ;;
        --check) CHECK_ONLY=1 ;;
        -h|--help) usage; exit 0 ;;
        *) die "unknown argument: $1" ;;
    esac
    shift
done

if [[ -z "$ACTION" ]]; then
    if [[ -n "$ROOT" && -x "$ROOT/bin/odoo-mirror" && -d "$ROOT/.git" ]]; then ACTION=install; else ACTION=remote; fi
fi

in_path() { case ":$PATH:" in *":$1:"*) return 0 ;; *) return 1 ;; esac; }

choose_bin_dir() {
    if [[ -n "$PREFIX" ]]; then echo "$PREFIX/bin"; return; fi
    local d
    for d in "$HOME/.local/bin" "$HOME/bin"; do
        if in_path "$d"; then echo "$d"; return; fi
    done
    echo "$HOME/.local/bin"
}

rc_files() { # the rc files of the shells this user has (bash, zsh, sh login), plus the one in use
    local f
    for f in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do [[ -f "$f" ]] && echo "$f"; done
    case "${SHELL:-}" in *zsh) echo "$HOME/.zshrc" ;; *bash) echo "$HOME/.bashrc" ;; esac
}

add_path_block() { # rc file, bin dir
    local rc=$1 dir=$2
    if grep -qsF "$MARK_BEGIN" "$rc"; then return 0; fi
    {
        printf '\n%s\n' "$MARK_BEGIN"
        # shellcheck disable=SC2016  # the $PATH must stay literal: it is expanded by the user's shell
        printf 'case ":$PATH:" in *":%s:"*) ;; *) export PATH="%s:$PATH" ;; esac\n' "$dir" "$dir"
        printf '%s\n' "$MARK_END"
    } >>"$rc"
    say "  PATH added in $rc"
}

remove_path_block() {
    local rc=$1
    grep -qsF "$MARK_BEGIN" "$rc" || return 0
    sed -i "/$MARK_BEGIN/,/$MARK_END/d" "$rc"
    say "  PATH block removed from $rc"
}

fish_conf() { echo "${XDG_CONFIG_HOME:-$HOME/.config}/fish/conf.d/odoo-mirror.fish"; }

# Link TARGET as the `odoo-mirror` command and make sure its folder is on the PATH.
link_command() {
    local target=$1 dir
    dir=$(choose_bin_dir)
    mkdir -p "$dir"
    ln -sfn "$target" "$dir/odoo-mirror"
    say "installed: $dir/odoo-mirror -> $target"
    if in_path "$dir"; then say "$dir is already in your PATH: it works in this terminal."; return 0; fi
    local rc
    while IFS= read -r rc; do add_path_block "$rc" "$dir"; done < <(rc_files | sort -u)
    if command -v fish >/dev/null 2>&1; then
        mkdir -p "$(dirname "$(fish_conf)")"
        printf 'fish_add_path -g %s\n' "$dir" >"$(fish_conf)"
        say "  PATH added for fish: $(fish_conf)"
    fi
    say "Open a new terminal (or run:  export PATH=\"$dir:\$PATH\")."
}

do_install() {
    [[ -n "$ROOT" && -x "$ROOT/bin/odoo-mirror" ]] || die "no checkout here: use 'remote' to install a release"
    link_command "$ROOT/bin/odoo-mirror"
}

# ---------------------------------------------------------------------------------------------------------------
# Releases
# ---------------------------------------------------------------------------------------------------------------

fetch() { # url dest
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --retry 2 -o "$2" "$1"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$2" "$1"
    else
        die "curl or wget is needed"
    fi
}

latest_tag() {
    if [[ -n "$RELEASE_BASE" ]]; then
        local tmp; tmp=$(mktemp)
        fetch "$RELEASE_BASE/latest" "$tmp" || { rm -f "$tmp"; die "cannot read $RELEASE_BASE/latest"; }
        tr -d '[:space:]' <"$tmp"; rm -f "$tmp"
        return
    fi
    command -v curl >/dev/null 2>&1 || die "curl is needed to find the latest release"
    local url
    url=$(curl -fsSIL -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest") || die "cannot reach GitHub"
    case "$url" in */releases/tag/*) echo "${url##*/}" ;; *) die "no release found for $REPO" ;; esac
}

asset_url() { # tag file
    if [[ -n "$RELEASE_BASE" ]]; then echo "$RELEASE_BASE/$1/$2"; else echo "https://github.com/$REPO/releases/download/$1/$2"; fi
}

sha256_check() { # dir file  (reads dir/SHA256SUMS)
    local dir=$1 file=$2 line
    line=$(awk -v f="$file" '$2 == f || $2 == "*" f { print; exit }' "$dir/SHA256SUMS")
    [[ -n "$line" ]] || die "no checksum for $file in SHA256SUMS"
    if command -v sha256sum >/dev/null 2>&1; then
        (cd "$dir" && printf '%s\n' "$line" | sha256sum -c - >/dev/null 2>&1)
    else
        (cd "$dir" && printf '%s\n' "$line" | shasum -a 256 -c - >/dev/null 2>&1)
    fi
}

installed_version() { # the version of the release that `current` points to
    local f="$INSTALL_ROOT/current/RELEASE"
    [[ -f "$f" ]] && tr -d '[:space:]' <"$f" || true
}

# true when A is a lower version than B (both dotted, no leading v)
version_lt() { [[ "$1" != "$2" && "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" == "$1" ]]; }

do_remote() {
    local tag cur tmp archive
    tag=${WANT_TAG:-$(latest_tag)}
    [[ "$tag" =~ ^v?[0-9]+(\.[0-9]+)*([.+-][0-9A-Za-z.]+)?$ ]] || die "unexpected release tag: '$tag'"
    cur=$(installed_version)

    if (( CHECK_ONLY )); then
        if [[ -z "$cur" ]]; then say "not installed from a release; latest is $tag"
        elif version_lt "$cur" "${tag#v}"; then say "update available: $cur -> ${tag#v}"
        else say "up to date ($cur)"; fi
        return 0
    fi

    if [[ -n "$cur" && -z "$WANT_TAG" && "$cur" == "${tag#v}" && -d "$INSTALL_ROOT/$tag" ]]; then
        say "already up to date ($cur)"
        link_command "$INSTALL_ROOT/current/bin/odoo-mirror"
        return 0
    fi

    say "Installing odoo-mirror $tag"
    tmp=$(mktemp -d "${TMPDIR:-/tmp}/odoo-mirror-install.XXXXXX")
    # shellcheck disable=SC2064  # expanded now on purpose: $tmp is local and gone when the trap fires
    trap "rm -rf '$tmp'" EXIT
    archive="odoo-mirror-$tag.tar.gz"
    fetch "$(asset_url "$tag" "$archive")" "$tmp/$archive" || die "cannot download $archive"
    fetch "$(asset_url "$tag" SHA256SUMS)" "$tmp/SHA256SUMS" || die "cannot download SHA256SUMS"
    sha256_check "$tmp" "$archive" || die "CHECKSUM MISMATCH for $archive: nothing was installed"
    say "  checksum OK"

    # Refuse an archive that would write outside its own folder.
    if tar -tzf "$tmp/$archive" | grep -qE '(^/|(^|/)\.\.(/|$))'; then die "unsafe path inside $archive: nothing was installed"; fi
    mkdir -p "$INSTALL_ROOT"
    rm -rf "${INSTALL_ROOT:?}/$tag.part"
    mkdir "$INSTALL_ROOT/$tag.part"
    tar -xzf "$tmp/$archive" -C "$INSTALL_ROOT/$tag.part" --strip-components=1 --no-same-owner
    [[ -x "$INSTALL_ROOT/$tag.part/bin/odoo-mirror" ]] || { rm -rf "${INSTALL_ROOT:?}/$tag.part"; die "the archive has no bin/odoo-mirror"; }
    rm -rf "${INSTALL_ROOT:?}/$tag"
    mv "$INSTALL_ROOT/$tag.part" "$INSTALL_ROOT/$tag"
    ln -sfn "$INSTALL_ROOT/$tag" "$INSTALL_ROOT/current.new"
    mv -T "$INSTALL_ROOT/current.new" "$INSTALL_ROOT/current"
    prune_old "$tag"
    link_command "$INSTALL_ROOT/current/bin/odoo-mirror"
    say "odoo-mirror ${tag#v} is ready.  Run: odoo-mirror"
}

# Keep the release in use and the one before it.
prune_old() { # tag in use
    local keep=$1 d n=0
    while IFS= read -r d; do
        [[ "$d" == "$keep" ]] && continue
        n=$((n + 1))
        if (( n > 1 )); then rm -rf "${INSTALL_ROOT:?}/$d"; fi
    done < <(cd "$INSTALL_ROOT" && find . -mindepth 1 -maxdepth 1 -type d -name 'v[0-9]*' -printf '%f\n' | sort -rV)
}

do_uninstall() {
    local dir
    for dir in "${PREFIX:+$PREFIX/bin}" "$HOME/.local/bin" "$HOME/bin"; do
        [[ -n "$dir" && -L "$dir/odoo-mirror" ]] && { rm -f "$dir/odoo-mirror"; say "removed: $dir/odoo-mirror"; }
    done
    local rc
    while IFS= read -r rc; do remove_path_block "$rc"; done < <(rc_files | sort -u)
    rm -f "$(fish_conf)"
    if [[ -L "$INSTALL_ROOT/current" ]]; then say "The downloaded releases are still in $INSTALL_ROOT (delete that folder to remove them)."; fi
}

"do_$ACTION"
