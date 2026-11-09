#!/usr/bin/env bash
# Install the Umbriel port without replacing the user's compositor configuration.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cfg=${XDG_CONFIG_HOME:-$HOME/.config}
dry=0
install_deps=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) dry=1 ;;
        --deps) install_deps=1 ;;
        --no-deps) install_deps=0 ;;
        --yes|-y) ;;
        -h|--help) echo 'Usage: ./install.sh [--dry-run] [--yes] [--deps|--no-deps]'; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done
dest="$cfg/quickshell/sekaipop"
printf 'Install SekaiPop for Umbriel to %s\n' "$dest"
if ((dry)); then
    echo 'Would back up the existing shell, copy the shell and inactive Umbriel examples, and compile shaders if qsb is available.'
    ((install_deps)) && echo 'Would run install-deps.sh first.'
    exit 0
fi
if ((install_deps)); then
    bash "$here/install-deps.sh" --no-session
fi
mkdir -p "$cfg/quickshell" "$cfg/umbriel"
stage=$(mktemp -d "$cfg/quickshell/.sekaipop-install.XXXXXX")
trap 'rm -rf -- "$stage"' EXIT
cp -a "$here/sekaipop/." "$stage/"
# Keep the updater on this fork even when installed as a plain copy.
commit=$(git -C "$here" rev-parse HEAD 2>/dev/null || echo unknown)
ref=${SEKAIPOP_REF:-$(git -C "$here" symbolic-ref --short HEAD 2>/dev/null || echo main)}
printf 'repo=https://github.com/kawaiiepic/SekaiPop.git\nref=%s\ncommit=%s\n' "$ref" "$commit" > "$stage/.source"
# Fail shader compilation before replacing an existing installation.
if command -v qsb >/dev/null 2>&1 || [[ -x /usr/lib/qt6/bin/qsb || -x /usr/lib/qt6-shadertools/bin/qsb ]]; then
    bash "$stage/shaders/compile-shaders.sh"
else
    echo 'qsb not found: shipped shaders require Qt 6.12. Install Qt Shader Tools and run shaders/compile-shaders.sh for another Qt version.' >&2
fi
if [[ -e "$dest" || -L "$dest" ]]; then
    backup="$dest.backup-$(date +%Y%m%d-%H%M%S)-$$"
    mv -- "$dest" "$backup"
    printf 'Previous shell saved as %s\n' "$backup"
fi
if ! mv -- "$stage" "$dest"; then
    [[ -n ${backup:-} ]] && mv -- "$backup" "$dest"
    exit 1
fi
# An example is safe to overwrite; the user's config.toml is never changed.
cp "$here/umbriel/sekaipop.toml" "$cfg/umbriel/sekaipop.example.toml"
cp "$here/umbriel/theme.example.toml" "$cfg/umbriel/sekaipop-theme.example.toml"
# The theme example is comment-only and is deliberately NOT included or applied.
mkdir -p "$cfg/sekaipop"
# This is the existing updater's configuration location.
printf '%s\n' 'https://github.com/kawaiiepic/SekaiPop.git' > "$cfg/sekaipop/update-repo"
printf '\nInstalled. Merge %s/umbriel/sekaipop.example.toml into your Umbriel config.\n' "$cfg"
printf 'Check dependencies: ./check-deps.sh\nStart: qs -c sekaipop\n'
printf 'Theme support scaffold: sekaipop-theme.example.toml (inactive; no theme is applied).\n'
