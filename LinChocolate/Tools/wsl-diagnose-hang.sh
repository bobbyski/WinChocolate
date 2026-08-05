#!/usr/bin/env bash
# Forensics for the WSL1 build hang, then staged retest.
# Snapshot the spinning processes BEFORE killing them, then run each stage of
# a SwiftPM build separately with timeouts, so we learn WHICH stage dies
# instead of watching a silent spin.
set -uo pipefail
export PATH="$HOME/.local/share/swift-toolchains/current/usr/bin:$PATH"
DST="$HOME/linchoc-native/WinChocolate/LinChocolate"

echo "=== 1. snapshot spinning processes ==="
for pid in $(pgrep -f 'swift-build|linchocolate-manifest|swiftc' 2>/dev/null); do
    [[ -d /proc/$pid ]] || continue
    echo "--- pid $pid: $(tr '\0' ' ' < /proc/$pid/cmdline | cut -c1-100)"
    grep -E '^(State|Threads|VmRSS)' /proc/$pid/status 2>/dev/null
    echo "wchan: $(cat /proc/$pid/wchan 2>/dev/null)"
    # A zombie child means the frontend exited and the driver never reaped it.
    for c in $(pgrep -P "$pid" 2>/dev/null); do
        echo "  child $c state: $(grep '^State' /proc/$c/status 2>/dev/null)"
    done
done

echo
echo "=== 2. kill them all ==="
pkill -9 -f 'swift-build' 2>/dev/null
pkill -9 -f 'linchocolate-manifest' 2>/dev/null
pkill -9 -f 'swiftc' 2>/dev/null
sleep 1
pgrep -f 'swift' >/dev/null 2>&1 && echo "still alive: $(pgrep -f swift | tr '\n' ' ')" || echo "all swift processes gone"

echo
echo "=== 3a. trivial swiftc (known-good 2026-07-26 — does it still hold?) ==="
printf 'print("hello from wsl1")\n' > /tmp/hello.swift
timeout 120 swiftc /tmp/hello.swift -o /tmp/hello 2>&1 | tail -3
echo "swiftc exit: $? (124 = timeout)"
timeout 20 /tmp/hello
echo "run exit: $?"

echo
echo "=== 3b. manifest compile alone (the stage pid 1415 died in) ==="
cd "$DST" || exit 1
rm -rf .build
timeout 300 swift package describe --type text 2>&1 | head -5
echo "describe exit: $? (124 = timeout)"

echo
echo "=== 3c. serial build, verbose, streamed (only if 3b survived) ==="
timeout 900 swift build --product LinChocolateDemo -j 1 -v > /tmp/linchoc-build-verbose.log 2>&1
echo "build exit: $? (124 = timeout)"
echo "--- last 15 log lines ---"
tail -15 /tmp/linchoc-build-verbose.log
echo "--- object files produced ---"
find .build -name '*.o' 2>/dev/null | wc -l
