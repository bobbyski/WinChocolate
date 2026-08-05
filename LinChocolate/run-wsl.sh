#!/usr/bin/env bash
#
# Run LinChocolate demos directly under WSLg using Wayland.
#
# Usage:
#   ./run-wsl.sh                 # swift run RealDemo
#   ./run-wsl.sh LinChocolateDemo
#   ./run-wsl.sh RealDemo --dark # extra args pass to the executable
#   ./run-wsl.sh --shell         # interactive shell in this package directory
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

if [[ "${1:-}" == "--shell" ]]; then
    exec "${SHELL:-/bin/bash}"
fi

TARGET="${1:-RealDemo}"
if [[ $# -gt 0 ]]; then
    shift
fi

export GDK_BACKEND="${GDK_BACKEND:-wayland}"

if [[ -f "${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}/env.sh" ]]; then
    # shellcheck disable=SC1090
    . "${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}/env.sh"
fi

if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi

if [[ "$GDK_BACKEND" == "wayland" && -z "${WAYLAND_DISPLAY:-}" ]]; then
    echo "warning: WAYLAND_DISPLAY is not set; WSLg may not be available." >&2
fi

command -v swift >/dev/null 2>&1 || {
    echo "error: swift was not found inside WSL." >&2
    exit 1
}

pkg-config --exists gtk4 2>/dev/null || {
    echo "error: GTK4 development files were not found inside WSL." >&2
    echo "       Install them with: sudo apt install libgtk-4-dev pkg-config" >&2
    exit 1
}

swift build --product "$TARGET"

# RealDemo loads artwork via Bundle.main, so stage the shared demo resources
# beside the built executable before launch.
if [[ "$TARGET" == "RealDemo" ]]; then
    for directory in .build/*/debug; do
        [[ -d "$directory" ]] || continue
        mkdir -p "$directory/Resources"
        cp -f ../Demo/DemoApplication/Resources/* "$directory/Resources/" 2>/dev/null || true
    done
fi

exec swift run "$TARGET" "$@"
