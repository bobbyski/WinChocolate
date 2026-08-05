#!/usr/bin/env bash
# Narrowing round 2: is LINKING the WSL1 blocker?
#
# Round 1 established: trivial compile, -typecheck, tiny C module import, and
# even importing the whole GTK header tree all finish in ~2s. But a full
# Swift+GTK compile-AND-LINK hung past 420s, and the Package.swift manifest
# compile — which also links (-lPackageDescription, -Xlinker -rpath) — hangs
# with a zombie swift-frontend. Meanwhile hello.swift (links nothing extra) and
# the X11 probe (links exactly -lX11) both succeed.
#
# Hypothesis: the driver hangs spawning/reaping the LINKER, and it scales with
# how much linking there is to do.
set -uo pipefail
export PATH="$HOME/.local/share/swift-toolchains/current/usr/bin:$PATH"
export SWIFT_BACKTRACE=enable=no

probe() { # probe <name> <timeout> <command...>
    local name="$1" limit="$2"; shift 2
    echo
    echo "--- $name (limit ${limit}s) ---"
    "$@" > /tmp/probe.log 2>&1 &
    local pid=$!
    local zombie=no elapsed=0
    while [[ $elapsed -lt $limit ]]; do
        sleep 2
        elapsed=$((elapsed + 2))
        kill -0 $pid 2>/dev/null || break
        for c in $(pgrep -P $pid 2>/dev/null); do
            grep -q '^State:.*Z' /proc/$c/status 2>/dev/null && zombie=yes
        done
    done
    if kill -0 $pid 2>/dev/null; then
        echo "VERDICT: HUNG after ${elapsed}s  (zombie child: $zombie)"
        pkill -9 -P $pid 2>/dev/null; kill -9 $pid 2>/dev/null
        return 1
    fi
    wait $pid; local rc=$?
    echo "VERDICT: finished exit=$rc in <=${elapsed}s  (zombie child: $zombie)"
    [[ -s /tmp/probe.log ]] && echo "  log: $(head -3 /tmp/probe.log)"
    return 0
}

cd /tmp/iso 2>/dev/null || { mkdir -p /tmp/iso && cd /tmp/iso; } || exit 1

GTK_CFLAGS=$(pkg-config --cflags gtk4)
GTK_LIBS=$(pkg-config --libs gtk4)
XCC=(); for f in $GTK_CFLAGS; do XCC+=(-Xcc "$f"); done
echo "gtk4 links with: $(echo "$GTK_LIBS" | wc -w) flags"

printf 'import CGTKProbe\nprint("gtk")\n' > e.swift

# E: GTK module, compile to OBJECT ONLY — no linking at all.
probe "E: swiftc -c with GTK module (no link)" 240 \
    swiftc -c -I /tmp/iso/gtkmod "${XCC[@]}" e.swift -o /tmp/iso/e.o

# F: same thing but compile AND LINK against gtk4.
probe "F: swiftc compile+link with GTK libs" 240 \
    swiftc -I /tmp/iso/gtkmod "${XCC[@]}" $GTK_LIBS e.swift -o /tmp/iso/e

# G: link the ALREADY-BUILT object (isolates the link step by itself).
if [[ -f /tmp/iso/e.o ]]; then
    probe "G: link pre-built .o against GTK libs" 240 \
        swiftc /tmp/iso/e.o $GTK_LIBS -o /tmp/iso/g
fi

# H: control — clang links the same libraries fine (proved by stage 3), so if
# swiftc hangs where clang does not, it is the SWIFT DRIVER, not the linker.
printf 'int main(void){return 0;}\n' > h.c
probe "H: clang link against same GTK libs" 120 \
    bash -c "clang h.c $GTK_LIBS -o /tmp/iso/h"

echo
echo "=== interpretation ==="
echo "E pass + F/G hang  => the LINK step is the blocker"
echo "E and F both pass  => the earlier 420s hang was load/contention, retry stage 4"
echo "H passes + G hangs => swift driver's linker invocation, not the system linker"
