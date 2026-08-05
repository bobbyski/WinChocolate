#!/usr/bin/env bash
# Build and run a LinChocolate demo on WSL1 WITHOUT SwiftPM.
#
# Why this exists (measured 2026-08-05): `swift build` hangs forever on this
# module — zombie swift-frontend, 0 objects, on a clean machine and on the
# native filesystem. The identical sources compile with swiftc in ~25s:
#
#     typecheck 77 files ....... exit 0, <=15s
#     whole-module + emit ...... exit 0, <=10s  -> libLinChocolate.so
#
# So SwiftPM's per-file invocation is the blocker, and driving swiftc directly
# is a working local Linux loop on this VM. Everything below it is verified:
# swiftc, X11 from C and Swift, GTK4 from C and Swift (Tools/wsl-stage-tests.sh,
# wsl-stage4-swift-gtk.sh).
#
# Usage:  wsl.exe -- bash /mnt/c/.../LinChocolate/Tools/wsl-build-demo-direct.sh [LinChocolateDemo|RealDemo]
set -uo pipefail

TARGET="${1:-LinChocolateDemo}"
SRC="$HOME/linchoc-native/WinChocolate/LinChocolate"
OUT=/tmp/lcbuild
COMPAT=/tmp/cgtkcompat
export PATH="$HOME/.local/share/swift-toolchains/current/usr/bin:$PATH"
export DISPLAY="${DISPLAY:-127.0.0.1:0}"
export SWIFT_BACKTRACE=enable=no

alive=$(pgrep -f 'swift-frontend|swiftc |swift-build|swift-package' 2>/dev/null | wc -l)
[[ "$alive" -eq 0 ]] || { echo "ABORT: $alive swift processes running — a starved VM makes timings meaningless"; exit 1; }

[[ -f "$OUT/libLinChocolate.so" ]] || {
    echo "Missing $OUT/libLinChocolate.so — run wsl-direct-target-build.sh first."; exit 1; }

GTK_CFLAGS=$(pkg-config --cflags gtk4)
GTK_LIBS=$(pkg-config --libs gtk4)
XCC=(); for f in $GTK_CFLAGS; do XCC+=(-Xcc "$f"); done

mapfile -t DEMO_SOURCES < <(find "$SRC/Sources/$TARGET" -name '*.swift' | sort)
[[ ${#DEMO_SOURCES[@]} -gt 0 ]] || { echo "no sources under Sources/$TARGET"; exit 1; }
echo "$TARGET sources: ${#DEMO_SOURCES[@]} files"

echo
echo "=== compile + link $TARGET against libLinChocolate.so ==="
START=$(date +%s)
swiftc -module-name "${TARGET}Main" \
    -I "$OUT" -I "$SRC/Sources/CGTK" -I "$COMPAT" \
    "${XCC[@]}" \
    -L "$OUT" -lLinChocolate -Xlinker -rpath -Xlinker "$OUT" \
    $GTK_LIBS "$COMPAT/cgtkcompat.o" \
    "${DEMO_SOURCES[@]}" -o "$OUT/$TARGET" > /tmp/demo-build.log 2>&1
RC=$?
echo "swiftc exit=$RC in $(( $(date +%s) - START ))s"
if [[ $RC -ne 0 ]]; then
    echo "--- first errors ---"; grep -m8 'error:' /tmp/demo-build.log || head -12 /tmp/demo-build.log
    exit 1
fi
ls -la "$OUT/$TARGET"

echo
echo "=== run it (X11 + cairo, the WSL1-proven env) ==="
clang "$SRC/Tools/x11-window-list.c" -lX11 -o /tmp/xlist 2>/dev/null || \
    clang /mnt/c/AIResearch/WinChocolate/Code/WinChocolate/LinChocolate/Tools/x11-window-list.c -lX11 -o /tmp/xlist 2>/dev/null

GDK_BACKEND=x11 GSK_RENDERER=cairo GDK_DISABLE=gl GTK_A11Y=none \
    "$OUT/$TARGET" > /tmp/demo-run.log 2>&1 &
PID=$!
MAPPED=1
for i in $(seq 1 20); do
    sleep 1
    if ! kill -0 $PID 2>/dev/null; then
        echo "process exited after ${i}s"; break
    fi
    if /tmp/xlist > /tmp/xlist-demo.out 2>&1; then
        echo "window mapped after ~${i}s:"; cat /tmp/xlist-demo.out; MAPPED=0; break
    fi
done
kill $PID 2>/dev/null; wait $PID 2>/dev/null
echo "--- app log (last 10) ---"; tail -10 /tmp/demo-run.log

[[ $MAPPED -eq 0 ]] && echo "RESULT: $TARGET RUNS ON WSL1" || echo "RESULT: no window mapped"
