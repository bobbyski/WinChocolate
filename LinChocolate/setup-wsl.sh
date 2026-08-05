#!/usr/bin/env bash
#
# Prepare a WSL/WSLg Ubuntu environment for running LinChocolate with GTK4 over
# Wayland. This intentionally does not touch the Docker/XQuartz Mac harness.
#
# Usage:
#   ./setup-wsl.sh
#   ./setup-wsl.sh --skip-swift
#
set -euo pipefail

if ! grep -qi microsoft /proc/version 2>/dev/null; then
    echo "warning: this does not look like WSL; continuing anyway." >&2
fi

if ! command -v apt-get >/dev/null 2>&1; then
    echo "error: setup-wsl.sh currently supports apt-based WSL distros such as Ubuntu or Debian." >&2
    exit 1
fi

SKIP_SWIFT=0
for arg in "$@"; do
    case "$arg" in
        --skip-swift)
            SKIP_SWIFT=1
            ;;
        *)
            echo "error: unknown option: $arg" >&2
            exit 1
            ;;
    esac
done

echo "Installing LinChocolate WSL dependencies..."
sudo apt-get update
sudo apt-get install -y \
    bash \
    build-essential \
    ca-certificates \
    clang \
    curl \
    git \
    gnupg \
    libcurl4-openssl-dev \
    libgtk-4-dev \
    libicu-dev \
    libsqlite3-dev \
    libxml2-dev \
    libx11-dev \
    pkg-config \
    tar \
    zlib1g-dev

if [[ "$SKIP_SWIFT" == "0" ]]; then
    if command -v swift >/dev/null 2>&1; then
        echo "Swift is already installed:"
        swift --version
    else
        echo "Installing Swift with Swiftly..."
        workdir="$(mktemp -d)"
        trap 'rm -rf "$workdir"' EXIT
        (
            cd "$workdir"
            curl -L -O "https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz"
            tar zxf "swiftly-$(uname -m).tar.gz"
            ./swiftly init --quiet-shell-followup
        )
    fi

    if [[ -f "${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}/env.sh" ]]; then
        # shellcheck disable=SC1090
        . "${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}/env.sh"
    fi

    if [[ -f "$HOME/.local/share/swiftly/env.sh" ]] && ! grep -Fq ".local/share/swiftly/env.sh" "$HOME/.bashrc" 2>/dev/null; then
        {
            echo ""
            echo "# Swiftly"
            echo '[ -f "$HOME/.local/share/swiftly/env.sh" ] && . "$HOME/.local/share/swiftly/env.sh"'
        } >> "$HOME/.bashrc"
    fi

    command -v swift >/dev/null 2>&1 || {
        echo "error: Swift install finished, but swift is still not on PATH." >&2
        echo "       Close and reopen WSL, or run: source ~/.local/share/swiftly/env.sh" >&2
        exit 1
    }
fi

echo ""
echo "WSL setup complete."
if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    echo "Wayland display detected: WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
else
    echo "warning: WAYLAND_DISPLAY is not set. WSLg GUI apps may not be available in this distro/session." >&2
fi
echo "Run the main demo from Windows with: .\\run-wsl.bat"
