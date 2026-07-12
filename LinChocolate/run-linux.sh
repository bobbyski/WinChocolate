#!/usr/bin/env bash
#
# LinChocolate Ring 1 harness — build the Linux container and run a Swift/GTK4
# binary with its window displayed on the Mac through XQuartz.
#
# Usage:
#   ./run-linux.sh                 # build image, then `swift run GTKHelloSpike`
#   ./run-linux.sh <Executable>    # run a different executable target
#   ./run-linux.sh --shell         # drop into an interactive container shell
#
# One-time prerequisite: XQuartz installed (brew install --cask xquartz).
# This script handles the rest — it enables XQuartz TCP listening, (re)starts
# it if needed, and authorizes the local X connection automatically.
#
set -euo pipefail

IMAGE="linchocolate-dev"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Mount the *repo root* (parent of LinChocolate) so the shared demo source that
# RealDemo symlinks to (../Demo/DemoApplication) resolves inside the container.
REPO="$(cd "$HERE/.." && pwd)"
export PATH="/opt/X11/bin:$PATH"   # XQuartz ships xhost/Xquartz here

command -v xhost >/dev/null 2>&1 || {
    echo "error: XQuartz not found. Install it: brew install --cask xquartz" >&2
    exit 1
}

x_is_listening() { lsof -nP -iTCP:6000 -sTCP:LISTEN >/dev/null 2>&1; }

# --- 1. Ensure XQuartz is configured to listen on TCP -----------------------
# Docker containers reach the X server over TCP (port 6000); XQuartz ships with
# TCP disabled (-nolisten tcp) by default.
need_restart=0
if [[ "$(defaults read org.xquartz.X11 nolisten_tcp 2>/dev/null || echo 1)" != "0" ]]; then
    echo "• Enabling XQuartz TCP listening (one-time setting)…"
    defaults write org.xquartz.X11 nolisten_tcp -bool false
    need_restart=1
fi

# --- 2. (Re)start XQuartz until it is actually listening on 6000 ------------
if ! x_is_listening || [[ "$need_restart" == "1" ]]; then
    echo "• (Re)starting XQuartz…"
    # A plain 'quit' is a no-op on the launchd-managed server, so stop the
    # X server processes directly, then relaunch so it re-reads the pref.
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
    echo "       Open XQuartz ▸ Settings ▸ Security ▸ 'Allow connections from" >&2
    echo "       network clients', then re-run this script." >&2
    exit 1
}

# --- 3. Authorize the container's X connection ------------------------------
# The container connects from Docker's internal NAT address (not your LAN IP),
# so per-IP xhost rules don't match; disable access control for this session.
# Re-tighten any time with:  DISPLAY=:0 xhost -
export DISPLAY=:0
xhost + >/dev/null

# --- 4. Host IP the container dials for the X server ------------------------
HOST_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"
[[ -n "$HOST_IP" ]] || { echo "error: could not determine host IP (en0/en1)." >&2; exit 1; }

# --- 5. Build the image (cached after first run) and run --------------------
docker build -t "$IMAGE" "$HERE"

run_args=(
    --rm -it
    -e "DISPLAY=${HOST_IP}:0"
    -e "GSK_RENDERER=${GSK_RENDERER:-cairo}"
    -v "$REPO":/work -w /work/LinChocolate
    "$IMAGE"
)

echo "• XQuartz listening, access authorized, DISPLAY=${HOST_IP}:0"
if [[ "${1:-}" == "--shell" ]]; then
    exec docker run "${run_args[@]}" bash
fi
exec docker run "${run_args[@]}" swift run "${1:-GTKHelloSpike}"
