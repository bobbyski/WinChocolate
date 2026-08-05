#!/usr/bin/env bash
# Diagnostic: does a LinChocolate app PUT A WINDOW UP on the WSL1 X11 loop?
#
# Companion to wsl-native-build-test.sh (which proves the native-fs *build*).
# This proves the *run*: launch a target from the native-fs copy against the
# Windows-side X server, then use Tools/x11-window-list.c to assert a named,
# viewable window actually mapped — "the process didn't die" is not evidence
# on a display we cannot see.
#
# Run:  wsl.exe -- bash /mnt/c/.../LinChocolate/Tools/wsl-x11-run-test.sh [Target]
# Target defaults to LinChocolateDemo. Everything is written to files under
# /tmp so the Windows side can read results without shell-quoting round trips
# (inline `wsl bash -c '...$?...'` gets mangled between Git Bash and WSL —
# proven again 2026-08-05).
set -uo pipefail

TARGET="${1:-LinChocolateDemo}"
DST_ROOT="$HOME/linchoc-native/WinChocolate"
export PATH="$HOME/.local/share/swift-toolchains/current/usr/bin:$PATH"

# The environment proven to work on this VM (see the no-local-linux-loop notes):
# WSL1 has no Wayland/WSLg, so force X11 to the Windows-side server; GL over
# this transport is unreliable, so use the Cairo software renderer.
export GDK_BACKEND=x11
export DISPLAY="${DISPLAY:-127.0.0.1:0}"
export GSK_RENDERER=cairo
export GDK_DISABLE=gl
export GTK_A11Y=none

cd "$DST_ROOT/LinChocolate" || { echo "RESULT: NO NATIVE COPY (run wsl-native-build-test.sh first)"; exit 1; }

BIN=$(ls .build/*/debug/"$TARGET" 2>/dev/null | head -1)
if [[ -z "$BIN" ]]; then
    echo "RESULT: NO BINARY for $TARGET (build it first)"
    exit 1
fi

echo "=== baseline window list ==="
/tmp/xlist
echo "(baseline exit: $?)"

echo
echo "=== launching $TARGET ==="
"$BIN" > /tmp/linchoc-run.log 2>&1 &
APP_PID=$!

# Give GTK time to connect, realize, and map. The Ring-1 notes measured multi-
# second first-window latency on this transport, so be generous.
WINDOW_UP=1
for i in $(seq 1 15); do
    sleep 1
    if ! kill -0 "$APP_PID" 2>/dev/null; then
        echo "RESULT: PROCESS DIED after ${i}s"
        echo "--- last log lines ---"
        tail -8 /tmp/linchoc-run.log
        exit 1
    fi
    if /tmp/xlist > /tmp/xlist-after.out 2>&1; then
        WINDOW_UP=0
        echo "window mapped after ~${i}s:"
        cat /tmp/xlist-after.out
        break
    fi
done

kill "$APP_PID" 2>/dev/null
wait "$APP_PID" 2>/dev/null

if [[ $WINDOW_UP -eq 0 ]]; then
    echo "RESULT: X11 RUN OK — window mapped and process stayed alive"
    exit 0
fi

echo "RESULT: NO WINDOW after 15s (process alive but nothing mapped)"
echo "--- last log lines ---"
tail -8 /tmp/linchoc-run.log
exit 1
