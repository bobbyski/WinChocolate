#!/usr/bin/env bash
# Can the LinChocolate TARGET be built with swiftc directly, bypassing SwiftPM?
#
# State of knowledge (2026-08-05):
#  - swiftc, X11-from-C, X11-from-Swift, GTK4-from-C, GTK4-from-Swift: ALL WORK.
#  - `swift package dump-package` on a clean machine: works, <5s.
#  - `swift build --product LinChocolateDemo -j 1` on a clean machine: HANGS,
#    zombie swift-frontend, 0 object files. So the target compile is the real
#    blocker, not starvation and not the manifest.
#
# Open question this answers: is it SwiftPM's frontend invocation, or is it
# something about compiling these 70+ files at all? swiftc on the whole module
# at once distinguishes them. Bounded, and reports the zombie signature.
set -uo pipefail
export PATH="$HOME/.local/share/swift-toolchains/current/usr/bin:$PATH"
export SWIFT_BACKTRACE=enable=no
SRC="$HOME/linchoc-native/WinChocolate/LinChocolate"

alive=$(pgrep -f 'swift-frontend|swiftc |swift-build|swift-package' 2>/dev/null | wc -l)
[[ "$alive" -eq 0 ]] || { echo "ABORT: $alive swift processes already running"; exit 1; }

run_bounded() { # run_bounded <name> <limit> <command...>
    local name="$1" limit="$2"; shift 2
    echo; echo "--- $name (limit ${limit}s) ---"
    "$@" > /tmp/direct.log 2>&1 &
    local pid=$! elapsed=0 zombie=no
    while [[ $elapsed -lt $limit ]]; do
        sleep 5; elapsed=$((elapsed + 5))
        kill -0 $pid 2>/dev/null || break
        for c in $(pgrep -P $pid 2>/dev/null); do
            grep -q '^State:.*Z' /proc/$c/status 2>/dev/null && zombie=yes
        done
    done
    if kill -0 $pid 2>/dev/null; then
        echo "VERDICT: HUNG after ${elapsed}s (zombie frontend: $zombie)"
        pkill -9 -P $pid 2>/dev/null; kill -9 $pid 2>/dev/null
        pkill -9 -f swift-frontend 2>/dev/null
        echo "--- log head ---"; head -5 /tmp/direct.log
        return 1
    fi
    wait $pid; local rc=$?
    echo "VERDICT: exit=$rc in <=${elapsed}s (zombie frontend: $zombie)"
    [[ $rc -ne 0 ]] && { echo "--- log (first errors) ---"; grep -m5 'error:' /tmp/direct.log || head -8 /tmp/direct.log; }
    return $rc
}

GTK_CFLAGS=$(pkg-config --cflags gtk4)
XCC=(); for f in $GTK_CFLAGS; do XCC+=(-Xcc "$f"); done
mapfile -t SOURCES < <(find "$SRC/Sources/LinChocolate" -name '*.swift' | sort)
echo "LinChocolate sources: ${#SOURCES[@]} files"

# CGTKCompat is a regular C target, so SwiftPM synthesizes its module map at
# build time; driving swiftc by hand means writing it out. Compile its .c too —
# the Swift module needs the symbols at link time.
COMPAT=/tmp/cgtkcompat
mkdir -p "$COMPAT"
cp "$SRC/Sources/CGTKCompat/include/cgtkcompat.h" "$COMPAT/"
cat > "$COMPAT/module.modulemap" <<'MEOF'
module CGTKCompat {
    header "cgtkcompat.h"
    export *
}
MEOF
clang -c "$SRC/Sources/CGTKCompat/cgtkcompat.c" -I "$COMPAT" $GTK_CFLAGS \
    -o "$COMPAT/cgtkcompat.o" 2>/tmp/compat-build.log \
    && echo "CGTKCompat.o built" || { echo "CGTKCompat C build failed:"; head -5 /tmp/compat-build.log; }

# 1. Just TYPECHECK the whole module — no codegen, no linking. If even this
#    hangs, the problem is in the frontend's handling of the module itself.
run_bounded "typecheck whole LinChocolate module" 600 \
    swiftc -typecheck -module-name LinChocolate \
    -I "$SRC/Sources/CGTK" -I /tmp/cgtkcompat \
    "${XCC[@]}" "${SOURCES[@]}"
TYPECHECK=$?

# 2. If typecheck survived, emit a real module + object (whole-module mode).
if [[ $TYPECHECK -eq 0 ]]; then
    mkdir -p /tmp/lcbuild
    run_bounded "emit object, whole-module" 900 \
        swiftc -wmo -module-name LinChocolate -emit-library -emit-module \
        -module-link-name LinChocolate \
        -I "$SRC/Sources/CGTK" -I /tmp/cgtkcompat \
        "${XCC[@]}" $(pkg-config --libs gtk4) "$COMPAT/cgtkcompat.o" \
        -o /tmp/lcbuild/libLinChocolate.so "${SOURCES[@]}"
    echo "artifacts:"; ls -la /tmp/lcbuild 2>/dev/null | head -5
fi

echo
echo "=== interpretation ==="
echo "typecheck hangs        => frontend cannot process this module under WSL1 (deep)"
echo "typecheck OK, wmo OK   => SwiftPM's per-file invocation is the blocker; build without it"
echo "typecheck OK, wmo hang => codegen/linking at module scale is the blocker"
