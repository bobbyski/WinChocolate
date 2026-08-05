#!/usr/bin/env bash
#
# Unified Chocolate — run a demo on Linux from the MERGED tree (root package).
#
# This is the sibling of LinChocolate/run-linux.sh and is deliberately
# command-compatible with it, so muscle memory and old notes keep working:
#
#   ./run-linux.sh                    # build image, then run WinChocolateDemo
#   ./run-linux.sh <Executable>       # run a different executable target
#   ./run-linux.sh --shell            # interactive container shell
#   ./run-linux.sh <Exe> --page 3     # extra args pass through to the app
#
# THE DIFFERENCE THAT MATTERS
# ---------------------------
# LinChocolate/run-linux.sh sets `-w /work/LinChocolate`, so it builds
# LinChocolate/Package.swift — a manifest with **zero** references to
# ChocolateKit. A green run there says nothing about the merge.
#
# This script sets `-w /work` and builds the ROOT Package.swift, i.e. the
# shared `ChocolateKit` core with the GTK backend behind
# `#if canImport(CGTK)`. That is the thing the merge needs proven.
#
# Targets in the root package:
#   WinChocolateDemo  the frozen AppKit-correct demo (Demo/DemoApplication),
#                     which on Linux resolves `import LinChocolate` -> the
#                     Linux façade -> ChocolateKit. THE headline test.
#   RunLoopDemo       run loop + timers app (Demo/RunLoopDemo)
#   WinChocolateContractTests   headless suite (in-memory backend, no display)
#
# Same one-time prerequisite as the old script: XQuartz.
set -euo pipefail

IMAGE="linchocolate-dev"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$HERE"                       # the repo root IS the package root now
DOCKER_CTX="$HERE/LinChocolate"    # Dockerfile still lives there; image is fine
export PATH="/opt/X11/bin:$PATH"

command -v xhost >/dev/null 2>&1 || {
    echo "error: XQuartz not found. Install it: brew install --cask xquartz" >&2
    exit 1
}

x_is_listening() { lsof -nP -iTCP:6000 -sTCP:LISTEN >/dev/null 2>&1; }

# --- 1. XQuartz must listen on TCP (containers reach X over port 6000) ------
need_restart=0
if [[ "$(defaults read org.xquartz.X11 nolisten_tcp 2>/dev/null || echo 1)" != "0" ]]; then
    echo "• Enabling XQuartz TCP listening (one-time setting)…"
    defaults write org.xquartz.X11 nolisten_tcp -bool false
    need_restart=1
fi

if ! x_is_listening || [[ "$need_restart" == "1" ]]; then
    echo "• (Re)starting XQuartz…"
    osascript -e 'tell application "XQuartz" to quit' >/dev/null 2>&1 || true
    pkill -f "xinit /opt/X11"  >/dev/null 2>&1 || true
    pkill -f "Xquartz :0"      >/dev/null 2>&1 || true
    pkill -x  quartz-wm        >/dev/null 2>&1 || true
    sleep 2
    open -a XQuartz
    for _ in $(seq 1 40); do x_is_listening && break; sleep 0.5; done
fi

x_is_listening || {
    echo "error: XQuartz is still not listening on TCP 6000." >&2
    echo "       XQuartz ▸ Settings ▸ Security ▸ 'Allow connections from" >&2
    echo "       network clients', then re-run." >&2
    exit 1
}

# --- 2. Authorize the container's X connection ------------------------------
export DISPLAY=:0
xhost + >/dev/null

HOST_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"
[[ -n "$HOST_IP" ]] || { echo "error: could not determine host IP (en0/en1)." >&2; exit 1; }

# --- 3. Build the image (cached) and assemble the run ----------------------
docker build -t "$IMAGE" "$DOCKER_CTX"

run_args=(
    --rm -it
    -e "DISPLAY=${HOST_IP}:0"
    -e "GSK_RENDERER=${GSK_RENDERER:-cairo}"
)

# Forward only diagnostics that are actually SET on the host. `-e VAR=` would
# define it empty in the container, and any "is this set" feature check then
# reads as enabled on every run.
for var in LINCHOCOLATE_ZOOM_DEBUG LINCHOCOLATE_GEOMETRY_AUDIT LINCHOCOLATE_PRINT_EXPORT \
           LINCHOCOLATE_NO_PANEL_PARENT LINCHOCOLATE_PAINT_TRACE LINCHOCOLATE_NO_LAYOUT_WAIT \
           LINCHOCOLATE_TIMER_DEBUG WINCHOCOLATE_DIAG \
           SPIKE_NO_SYNC LINCHOCOLATE_KEEP_WM_SYNC GDK_DEBUG GSK_DEBUG GTK_DEBUG; do
    if [[ -n "${!var:-}" ]]; then
        run_args+=(-e "$var=${!var}")
    fi
done

# The one real difference from the old script: work in the REPO ROOT, so
# `swift build` picks up the merged Package.swift and ChocolateKit.
run_args+=(
    -v "$REPO":/work -w /work
    "$IMAGE"
)

echo "• XQuartz listening, access authorized, DISPLAY=${HOST_IP}:0"
echo "• Building the MERGED root package (ChocolateKit), not LinChocolate/"

if [[ "${1:-}" == "--shell" ]]; then
    exec docker run "${run_args[@]}" bash
fi

# Headless suite: no display needed, and the fastest signal that the shared
# core is sane on Linux. Worth running before any windowed target.
if [[ "${1:-}" == "--tests" ]]; then
    exec docker run "${run_args[@]}" bash -c '
        set -e
        swift build --product WinChocolateContractTests 2>&1 | tail -3
        swift run WinChocolateContractTests
    '
fi

TARGET="${1:-WinChocolateDemo}"
shift || true

# The demo loads artwork and DemoNibPanel.xib through Bundle.main (the
# executable directory). Copy the whole Resources folder — enumerating
# extensions is how the .xib silently stopped being staged on Windows.
exec docker run "${run_args[@]}" bash -c '
    set -e
    swift build --product '"$TARGET"' 2>&1 | tail -3
    if [ "'"$TARGET"'" = "WinChocolateDemo" ]; then
        for d in .build/*/debug; do
            [ -d "$d" ] || continue
            mkdir -p "$d/Resources"
            cp -f Demo/DemoApplication/Resources/* "$d/Resources/" 2>/dev/null || true
        done
    fi
    swift run '"$TARGET"' '"$*"'
'
