#!/usr/bin/env bash
#
# Run LinChocolate demos directly under WSLg using Wayland.
#
# Usage:
#   ./run-wsl.sh                 # swift run RealDemo
#   ./run-wsl.sh LinChocolateDemo
#   ./run-wsl.sh RealDemo --dark # extra args pass to the executable
#   ./run-wsl.sh --x11           # run RealDemo through a Windows X server
#   ./run-wsl.sh --x11 RealDemo
#   ./run-wsl.sh --wsl-copy --x11 RealDemo
#   ./run-wsl.sh --shell         # interactive shell in this package directory
#   ./run-wsl.sh --diagnose      # print WSLg/Swift environment details
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

if [[ "${1:-}" == "--shell" ]]; then
    exec "${SHELL:-/bin/bash}"
fi

DISPLAY_BACKEND="wayland"
USE_WSL_COPY=0
while [[ "${1:-}" == --* ]]; do
    case "${1:-}" in
        --x11)
            DISPLAY_BACKEND="x11"
            shift
            ;;
        --wayland)
            DISPLAY_BACKEND="wayland"
            shift
            ;;
        --wsl-copy)
            USE_WSL_COPY=1
            shift
            ;;
        --diagnose)
            break
            ;;
        *)
            break
            ;;
    esac
done

diagnose_environment() {
    echo "LinChocolate WSL diagnostics"
    echo "  pwd: $PWD"
    echo "  uname: $(uname -a)"
    if uname -r | grep -qi "microsoft-standard"; then
        echo "  wsl: WSL2-style kernel detected"
    else
        echo "  wsl: WSL1-style kernel detected; WSLg/Wayland requires WSL2"
    fi
    echo "  PATH: $PATH"
    echo "  requested backend: $DISPLAY_BACKEND"
    echo "  use WSL copy: $USE_WSL_COPY"
    echo "  GDK_BACKEND: ${GDK_BACKEND:-<unset>}"
    echo "  WAYLAND_DISPLAY: ${WAYLAND_DISPLAY:-<unset>}"
    echo "  DISPLAY: ${DISPLAY:-<unset>}"
    echo "  XDG_RUNTIME_DIR: ${XDG_RUNTIME_DIR:-<unset>}"

    if command -v swift >/dev/null 2>&1; then
        echo "  swift: $(command -v swift)"
        swift --version
    else
        echo "  swift: <not found>"
    fi

    if pkg-config --exists gtk4 2>/dev/null; then
        echo "  gtk4: $(pkg-config --modversion gtk4)"
    else
        echo "  gtk4: <not found by pkg-config>"
    fi
}

TARGET="${1:-RealDemo}"
if [[ $# -gt 0 ]]; then
    shift
fi

if [[ "$DISPLAY_BACKEND" == "x11" ]]; then
    export GDK_BACKEND="${GDK_BACKEND:-x11}"
    if [[ -z "${DISPLAY:-}" ]]; then
        if uname -r | grep -qi "microsoft-standard"; then
            export DISPLAY=":0"
        else
            export DISPLAY="127.0.0.1:0"
        fi
    fi
    export GSK_RENDERER="${GSK_RENDERER:-cairo}"
else
    export GDK_BACKEND="${GDK_BACKEND:-wayland}"
fi

if [[ -f "${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}/env.sh" ]]; then
    # shellcheck disable=SC1090
    . "${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}/env.sh"
fi

if [[ -d "$HOME/.local/share/swift-toolchains/current/usr/bin" ]]; then
    export PATH="$HOME/.local/share/swift-toolchains/current/usr/bin:$PATH"
fi

if [[ "$TARGET" == "--diagnose" ]]; then
    diagnose_environment
    exit 0
fi

if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi

if [[ "$GDK_BACKEND" == "wayland" && -z "${WAYLAND_DISPLAY:-}" ]]; then
    echo "warning: WAYLAND_DISPLAY is not set; WSLg may not be available." >&2
    if ! uname -r | grep -qi "microsoft-standard"; then
        echo "         This appears to be WSL1. From PowerShell, run: wsl --set-version Ubuntu 2" >&2
    fi
fi

if [[ "$GDK_BACKEND" == "x11" && -z "${DISPLAY:-}" ]]; then
    echo "error: DISPLAY is not set for X11 mode." >&2
    echo "       Start a Windows X server and try: .\\run-wsl.bat --x11" >&2
    exit 1
fi

command -v swift >/dev/null 2>&1 || {
    echo "error: swift was not found inside WSL." >&2
    echo "       Run .\\setup-wsl.bat, then try .\\run-wsl.bat --diagnose." >&2
    exit 1
}

pkg-config --exists gtk4 2>/dev/null || {
    echo "error: GTK4 development files were not found inside WSL." >&2
    echo "       Install them with: sudo apt install libgtk-4-dev pkg-config" >&2
    exit 1
}

if [[ "$USE_WSL_COPY" == "1" ]]; then
    if ! command -v rsync >/dev/null 2>&1; then
        echo "error: --wsl-copy needs rsync inside WSL." >&2
        echo "       Install it with: sudo apt install rsync" >&2
        exit 1
    fi

    WORK_COPY="${LINCHOCOLATE_WSL_COPY:-$HOME/.cache/linchocolate-wsl/WinChocolate}"
    mkdir -p "$WORK_COPY"
    rsync -a --delete \
        --exclude ".git" \
        --exclude ".build" \
        --exclude "LinChocolate/.build" \
        "$HERE/../" "$WORK_COPY/"
    if [[ -d "$WORK_COPY/Demo/DemoApplication" && -d "$WORK_COPY/LinChocolate/Sources/RealDemo" ]]; then
        cp -f "$WORK_COPY/Demo/DemoApplication/main.swift" \
            "$WORK_COPY/LinChocolate/Sources/RealDemo/main.swift"
        cp -f "$WORK_COPY/Demo/DemoApplication/DemoConveniences.swift" \
            "$WORK_COPY/LinChocolate/Sources/RealDemo/DemoConveniences.swift"
        cp -f "$WORK_COPY/Demo/DemoApplication/DemoNibConveniences.swift" \
            "$WORK_COPY/LinChocolate/Sources/RealDemo/DemoNibConveniences.swift"
    fi
    cd "$WORK_COPY/LinChocolate"
fi

export CC="${CC:-/usr/bin/clang}"
export CXX="${CXX:-/usr/bin/clang++}"

BUILD_LOG="${LINCHOCOLATE_BUILD_LOG:-/tmp/linchocolate-${TARGET}-build.log}"
echo "Building $TARGET..."
echo "Build log: $BUILD_LOG"
if ! swift build --product "$TARGET" -v >"$BUILD_LOG" 2>&1; then
    echo "error: swift build failed. Last 80 log lines:" >&2
    tail -80 "$BUILD_LOG" >&2 || true
    exit 1
fi

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
