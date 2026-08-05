#!/usr/bin/env bash
# Does `swift build` work on WSL1 once nothing is already spinning?
#
# Everything below SwiftPM is now proven working (Tools/wsl-stage-tests.sh 1-3,
# wsl-stage4-swift-gtk.sh): swiftc, X11 from C and Swift, GTK4 from C and Swift.
# The one remaining suspect is SwiftPM's manifest compile, which twice left a
# zombie swift-frontend and a driver spinning at 97% CPU — and that spinner
# starves the VM, which is what made every later measurement look like a hang.
#
# So: start from a verified-clean process table, and bound every step.
set -uo pipefail
export PATH="$HOME/.local/share/swift-toolchains/current/usr/bin:$PATH"
export SWIFT_BACKTRACE=enable=no
DST="$HOME/linchoc-native/WinChocolate/LinChocolate"

# Match only real toolchain processes. A bare "swift" match also catches app
# binaries whose PATH contains it (/tmp/swiftgtk/probe from the stage-4 test
# tripped exactly that), which aborts the run for no reason.
# `pgrep -c` prints 0 AND exits 1 when nothing matches, so a `|| echo 0`
# fallback yields "0\n0" and the guard fires on a clean machine. Count lines.
alive=$(pgrep -f 'swift-frontend|swiftc |swift-build|swift-package|swift-driver' 2>/dev/null | wc -l)
echo "swift processes before start: $alive (must be 0 for a valid measurement)"
if [[ "$alive" != "0" ]]; then
    echo "ABORT: something is already running; kill it first or the result is meaningless."
    exit 1
fi

watch_for() { # watch_for <pid> <limit> ; echoes VERDICT, returns 1 if hung
    local pid=$1 limit=$2 elapsed=0 zombie=no
    while [[ $elapsed -lt $limit ]]; do
        sleep 5
        elapsed=$((elapsed + 5))
        kill -0 "$pid" 2>/dev/null || break
        for c in $(pgrep -P "$pid" 2>/dev/null); do
            grep -q '^State:.*Z' /proc/$c/status 2>/dev/null && zombie=yes
        done
    done
    if kill -0 "$pid" 2>/dev/null; then
        echo "VERDICT: HUNG after ${elapsed}s (zombie frontend: $zombie)"
        pkill -9 -P "$pid" 2>/dev/null; kill -9 "$pid" 2>/dev/null
        pkill -9 -f swiftc 2>/dev/null; pkill -9 -f swift-frontend 2>/dev/null
        return 1
    fi
    wait "$pid"; local rc=$?
    echo "VERDICT: finished exit=$rc in <=${elapsed}s (zombie frontend: $zombie)"
    return 0
}

cd "$DST" || { echo "no native copy at $DST"; exit 1; }
rm -rf .build

echo
echo "=== 1. manifest only: swift package dump-package (the stage that hung twice) ==="
swift package dump-package > /tmp/dump.json 2>/tmp/dump.err &
watch_for $! 180
echo "  dump.json bytes: $(wc -c < /tmp/dump.json 2>/dev/null || echo 0)"
[[ -s /tmp/dump.err ]] && echo "  err: $(head -3 /tmp/dump.err)"

echo
echo "=== 2. full build, serial (-j 1), streamed to log ==="
swift build --product LinChocolateDemo -j 1 > /tmp/spm-build.log 2>&1 &
watch_for $! 1500
echo "--- last 12 log lines ---"
tail -12 /tmp/spm-build.log 2>/dev/null
echo "--- objects produced: $(find .build -name '*.o' 2>/dev/null | wc -l) ---"

if ls .build/*/debug/LinChocolateDemo >/dev/null 2>&1; then
    ls -la .build/*/debug/LinChocolateDemo
    echo "RESULT: SWIFTPM BUILD OK ON WSL1"
else
    echo "RESULT: no binary"
fi
