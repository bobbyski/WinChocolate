#!/usr/bin/env bash
# Build and run the combined root ChocolateKit package under WSL/WSLg.
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="WinChocolateDemo"
MODE="run"
DISPLAY_BACKEND="wayland"

if ! uname -r | grep -qi microsoft-standard; then
    DISPLAY_BACKEND="x11"
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tests) MODE="tests"; shift ;;
        --build) MODE="build"; shift ;;
        --diagnose) MODE="diagnose"; shift ;;
        --shell) MODE="shell"; shift ;;
        --x11) DISPLAY_BACKEND="x11"; shift ;;
        --wayland) DISPLAY_BACKEND="wayland"; shift ;;
        runloop|RunLoopDemo) TARGET="RunLoopDemo"; shift ;;
        demo|WinChocolateDemo) TARGET="WinChocolateDemo"; shift ;;
        --*) break ;;
        *) TARGET="$1"; shift; break ;;
    esac
done
APP_ARGS=("$@")

if [[ -f "${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}/env.sh" ]]; then
    # shellcheck disable=SC1090
    . "${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}/env.sh"
fi
if [[ -d "$HOME/.local/share/swift-toolchains/current/usr/bin" ]]; then
    export PATH="$HOME/.local/share/swift-toolchains/current/usr/bin:$PATH"
fi

if [[ "$MODE" == "diagnose" ]]; then
    echo "WinChocolate combined-framework WSL diagnostics"
    echo "  source: $SOURCE_ROOT"
    echo "  kernel: $(uname -r)"
    echo "  architecture: $(uname -m)"
    echo "  backend: $DISPLAY_BACKEND"
    echo "  swift: $(command -v swift 2>/dev/null || echo '<missing>')"
    command -v swift >/dev/null 2>&1 && swift --version
    echo "  gtk4: $(pkg-config --modversion gtk4 2>/dev/null || echo '<missing>')"
    echo "  WAYLAND_DISPLAY: ${WAYLAND_DISPLAY:-<unset>}"
    echo "  DISPLAY: ${DISPLAY:-<unset>}"
    exit 0
fi

command -v swift >/dev/null 2>&1 || {
    echo "error: Swift was not found inside WSL. Run .\\setup-wsl.bat first." >&2
    exit 1
}
pkg-config --exists gtk4 2>/dev/null || {
    echo "error: GTK4 development files were not found inside WSL." >&2
    echo "       Run .\\setup-wsl.bat first." >&2
    exit 1
}

# SwiftPM is substantially more reliable and faster on WSL's native filesystem
# than on /mnt/c. Keep a disposable mirror; the Windows checkout remains the
# source of truth.
WORK_ROOT="$SOURCE_ROOT"
case "$SOURCE_ROOT" in
    /mnt/*)
        command -v rsync >/dev/null 2>&1 || {
            echo "error: rsync is required inside WSL. Run .\\setup-wsl.bat." >&2
            exit 1
        }
        WORK_ROOT="${WINCHOCOLATE_WSL_COPY:-$HOME/.cache/winchocolate-wsl/WinChocolate}"
        mkdir -p "$WORK_ROOT"
        echo "Syncing combined framework to WSL native storage..."
        rsync -a --delete \
            --exclude .git \
            --exclude .build \
            "$SOURCE_ROOT/" "$WORK_ROOT/"
        ;;
esac
cd "$WORK_ROOT"

if [[ "$MODE" == "shell" ]]; then
    exec "${SHELL:-/bin/bash}"
fi

export CC="${CC:-/usr/bin/clang}"
export CXX="${CXX:-/usr/bin/clang++}"
if [[ "$DISPLAY_BACKEND" == "x11" ]]; then
    export GDK_BACKEND="${GDK_BACKEND:-x11}"
    export DISPLAY="${DISPLAY:-:0}"
    export GSK_RENDERER="${GSK_RENDERER:-cairo}"
else
    export GDK_BACKEND="${GDK_BACKEND:-wayland}"
fi

if [[ "$MODE" == "tests" ]]; then
    swift build --product WinChocolateContractTests
    exec swift run --skip-build WinChocolateContractTests
fi

echo "Building combined root product $TARGET..."
swift build --product "$TARGET"
BIN_PATH="$(swift build --show-bin-path)"
if [[ "$TARGET" == "WinChocolateDemo" ]]; then
    mkdir -p "$BIN_PATH/Resources"
    cp -f Demo/DemoApplication/Resources/* "$BIN_PATH/Resources/"
fi
if [[ "$MODE" == "build" ]]; then
    echo "Built $TARGET successfully."
    exit 0
fi
exec swift run --skip-build "$TARGET" "${APP_ARGS[@]}"
