#!/usr/bin/env bash
#
# Prepare a WSL/WSLg Ubuntu environment for running LinChocolate with GTK4 over
# Wayland. This intentionally does not touch the Docker/XQuartz Mac harness.
#
# Usage:
#   ./setup-wsl.sh                  # install deps + Swift in WSL only
#   ./setup-wsl.sh --skip-swift     # install deps only
#
set -euo pipefail

if ! grep -qi microsoft /proc/version 2>/dev/null; then
    echo "warning: this does not look like WSL; continuing anyway." >&2
fi

if ! uname -r | grep -qi "microsoft-standard"; then
    echo "warning: this appears to be WSL1. WSLg/Wayland requires WSL2." >&2
    echo "         From PowerShell, run: wsl --set-version Ubuntu 2" >&2
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

echo "Installing ChocolateKit WSL dependencies..."
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
    rsync \
    tar \
    zlib1g-dev

add_line_once() {
    local file="$1"
    local marker="$2"
    local line="$3"

    touch "$file"
    if ! grep -Fq "$marker" "$file" 2>/dev/null; then
        {
            echo ""
            echo "$line"
        } >> "$file"
    fi
}

source_installed_swift() {
    if [[ -f "${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}/env.sh" ]]; then
        # shellcheck disable=SC1090
        . "${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}/env.sh"
    fi

    if [[ -d "$HOME/.local/share/swift-toolchains/current/usr/bin" ]]; then
        export PATH="$HOME/.local/share/swift-toolchains/current/usr/bin:$PATH"
    fi
}

install_swift_with_swiftly() {
    echo "Installing Swift with Swiftly..."
    local workdir
    local status
    workdir="$(mktemp -d)"
    (
        cd "$workdir"
        curl -fL -O "https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz"
        tar zxf "swiftly-$(uname -m).tar.gz"
        ./swiftly init --quiet-shell-followup
    )
    status=$?
    rm -rf "$workdir"
    return "$status"
}

install_swift_tarball_fallback() {
    local swift_version="6.3.2"
    local ubuntu_version
    local ubuntu_id
    local arch
    local platform
    local filename
    local url
    local install_root="$HOME/.local/share/swift-toolchains"
    local install_dir="$install_root/swift-$swift_version-RELEASE"

    ubuntu_version="$(. /etc/os-release && printf "%s" "$VERSION_ID")"
    ubuntu_id="${ubuntu_version/./}"
    arch="$(uname -m)"

    case "$arch" in
        aarch64|arm64)
            platform="ubuntu${ubuntu_id}-aarch64"
            filename="swift-$swift_version-RELEASE-ubuntu${ubuntu_version}-aarch64.tar.gz"
            ;;
        x86_64)
            platform="ubuntu${ubuntu_id}"
            filename="swift-$swift_version-RELEASE-ubuntu${ubuntu_version}.tar.gz"
            ;;
        *)
            echo "error: unsupported Swift fallback architecture: $arch" >&2
            return 1
            ;;
    esac

    case "$ubuntu_version" in
        22.04|24.04)
            ;;
        *)
            echo "error: Swift tarball fallback supports Ubuntu 22.04 or 24.04 WSL; found $ubuntu_version." >&2
            return 1
            ;;
    esac

    url="https://download.swift.org/swift-$swift_version-release/${platform}/swift-$swift_version-RELEASE/${filename}"
    echo "Installing Swift $swift_version fallback tarball for Ubuntu $ubuntu_version/$arch..."

    local workdir
    local status
    workdir="$(mktemp -d)"
    (
        cd "$workdir"
        curl -fL -O "$url"
        tar zxf "$filename"
        mkdir -p "$install_root"
        rm -rf "$install_dir"
        extracted_dir="$(find . -maxdepth 1 -type d -name "swift-$swift_version-RELEASE-ubuntu${ubuntu_version}*" -print -quit)"
        if [[ -z "$extracted_dir" ]]; then
            echo "error: could not find extracted Swift toolchain directory." >&2
            exit 1
        fi
        mv "$extracted_dir" "$install_dir"
        ln -sfn "$install_dir" "$install_root/current"
    )
    status=$?
    rm -rf "$workdir"
    if [[ "$status" != "0" ]]; then
        return "$status"
    fi

    export PATH="$install_root/current/usr/bin:$PATH"
    add_line_once "$HOME/.bashrc" "swift-toolchains/current/usr/bin" \
        'export PATH="$HOME/.local/share/swift-toolchains/current/usr/bin:$PATH"'
}

if [[ "$SKIP_SWIFT" == "0" ]]; then
    source_installed_swift
    if command -v swift >/dev/null 2>&1; then
        echo "Swift is already installed:"
        swift --version
    else
        if install_swift_with_swiftly; then
            source_installed_swift
        else
            echo "warning: Swiftly failed; falling back to the official Swift tarball." >&2
            install_swift_tarball_fallback
        fi
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
