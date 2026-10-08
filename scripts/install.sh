#!/usr/bin/env bash
# Install or remove the `odoo-mirror` command, for any shell (bash, zsh, fish, sh).
#
#   scripts/install.sh [install|uninstall] [--prefix DIR]
#
# Where the link goes:
#   1. --prefix DIR/bin  (for example --prefix /usr/local: every user, every shell, no rc file touched; needs sudo)
#   2. otherwise a folder under $HOME that is already in your PATH (~/.local/bin, ~/bin)
#   3. otherwise ~/.local/bin, and that folder is added to PATH in the rc files of the shells you have.
# Nothing is edited twice: the PATH lines sit between two marker comments.
set -euo pipefail

readonly MARK_BEGIN="# >>> odoo-mirror >>>"
readonly MARK_END="# <<< odoo-mirror <<<"
ROOT=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
ACTION=install
PREFIX=""

while (( $# )); do
    case "$1" in
        install|uninstall) ACTION=$1 ;;
        --prefix) PREFIX=${2:?--prefix needs a directory}; shift ;;
        -h|--help) sed -n '2,11p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
    shift
done

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
    echo "  PATH added in $rc"
}

remove_path_block() {
    local rc=$1
    grep -qsF "$MARK_BEGIN" "$rc" || return 0
    sed -i "/$MARK_BEGIN/,/$MARK_END/d" "$rc"
    echo "  PATH block removed from $rc"
}

fish_conf() { echo "${XDG_CONFIG_HOME:-$HOME/.config}/fish/conf.d/odoo-mirror.fish"; }

do_install() {
    local dir; dir=$(choose_bin_dir)
    mkdir -p "$dir"
    ln -sf "$ROOT/bin/odoo-mirror" "$dir/odoo-mirror"
    echo "installed: $dir/odoo-mirror"
    if in_path "$dir"; then echo "$dir is already in your PATH: it works in this terminal."; return 0; fi
    local rc
    while IFS= read -r rc; do add_path_block "$rc" "$dir"; done < <(rc_files | sort -u)
    if command -v fish >/dev/null 2>&1; then
        mkdir -p "$(dirname "$(fish_conf)")"
        printf 'fish_add_path -g %s\n' "$dir" >"$(fish_conf)"
        echo "  PATH added for fish: $(fish_conf)"
    fi
    echo "Open a new terminal (or run:  export PATH=\"$dir:\$PATH\")."
}

do_uninstall() {
    local dir
    for dir in "${PREFIX:+$PREFIX/bin}" "$HOME/.local/bin" "$HOME/bin"; do
        [[ -n "$dir" && -L "$dir/odoo-mirror" ]] && { rm -f "$dir/odoo-mirror"; echo "removed: $dir/odoo-mirror"; }
    done
    local rc
    while IFS= read -r rc; do remove_path_block "$rc"; done < <(rc_files | sort -u)
    rm -f "$(fish_conf)"
}

"do_$ACTION"
