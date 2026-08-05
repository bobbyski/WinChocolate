#!/usr/bin/env bash
# Diagnostic: does LinChocolate build on the NATIVE WSL filesystem?
#
# Theory under test: building from /mnt/c (DrvFs) on WSL1 fails because DrvFs
# does not implement flock/fcntl advisory locks reliably, so SwiftPM blocks on a
# stale `.build/.lock` that no process holds. Copying the package onto the WSL
# root filesystem (real Linux semantics) should build normally.
#
# Run:  wsl.exe -- bash /mnt/c/.../LinChocolate/Tools/wsl-native-build-test.sh
set -uo pipefail

SRC_ROOT="/mnt/c/AIResearch/WinChocolate/Code/WinChocolate"
DST_ROOT="$HOME/linchoc-native/WinChocolate"

export PATH="$HOME/.local/share/swift-toolchains/current/usr/bin:$PATH"
export CC="${CC:-/usr/bin/clang}"
export CXX="${CXX:-/usr/bin/clang++}"
export SWIFT_BACKTRACE=enable=no

echo "=== 1. copy package to native fs (bounded: only the two source trees) ==="
rm -rf "$DST_ROOT"
mkdir -p "$DST_ROOT"
# Copy ONLY what the LinChocolate package needs: its own tree plus the shared
# Demo sources its RealDemo target symlinks into. Never copy from / by accident.
for sub in LinChocolate Demo; do
    if [[ -d "$SRC_ROOT/$sub" ]]; then
        mkdir -p "$DST_ROOT/$sub"
        tar -C "$SRC_ROOT/$sub" --exclude=.build --exclude=.git -cf - . \
            | tar -C "$DST_ROOT/$sub" -xf -
    fi
done
echo "copied: $(du -sh "$DST_ROOT" 2>/dev/null | cut -f1)"

echo
echo "=== 2. build on native fs ==="
cd "$DST_ROOT/LinChocolate" || exit 1
START=$(date +%s)
swift build --product LinChocolateDemo 2>&1 | tail -12
STATUS=${PIPESTATUS[0]}
END=$(date +%s)
echo "swift build exit=$STATUS  elapsed=$((END - START))s"

echo
echo "=== 3. binary present? ==="
if ls .build/*/debug/LinChocolateDemo >/dev/null 2>&1; then
    ls -la .build/*/debug/LinChocolateDemo
    echo "RESULT: NATIVE-FS BUILD OK"
else
    echo "NO BINARY"
    echo "RESULT: NATIVE-FS BUILD FAILED"
fi
