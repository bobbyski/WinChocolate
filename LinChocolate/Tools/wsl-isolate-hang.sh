#!/usr/bin/env bash
# Which swiftc invocation triggers the WSL1 "zombie frontend + spinning driver"?
#
# Known: hello.swift and a hand-declared X11 Swift file BOTH compile fine, but
# the Package.swift manifest compile and a Swift+GTK module compile both hang
# with a defunct swift-frontend child while swiftc spins at ~97% CPU.
#
# Isolates the variables one at a time, each timeout-bounded and each reporting
# whether a zombie child appeared — that signature is the actual diagnosis, not
# the exit code.
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
        echo "VERDICT: HUNG after ${elapsed}s  (zombie frontend seen: $zombie)"
        pkill -9 -P $pid 2>/dev/null; kill -9 $pid 2>/dev/null
    else
        wait $pid; local rc=$?
        echo "VERDICT: finished exit=$rc in <=${elapsed}s  (zombie frontend seen: $zombie)"
    fi
    [[ -s /tmp/probe.log ]] && { echo "  log: $(head -3 /tmp/probe.log)"; }
}

cd /tmp || exit 1
mkdir -p /tmp/iso && cd /tmp/iso || exit 1

# A: baseline — trivial file, plain swiftc (expected PASS, re-confirm)
printf 'print("A")\n' > a.swift
probe "A: trivial swiftc" 60 swiftc a.swift -o /tmp/iso/a

# B: trivial file but TYPECHECK ONLY (does -typecheck alone change anything?)
probe "B: trivial -typecheck" 60 swiftc -typecheck a.swift

# C: import a TINY C module via module map (isolates ClangImporter, not GTK size)
mkdir -p tinymod
cat > tinymod/module.modulemap <<'MEOF'
module TinyC [system] {
    header "tiny.h"
    export *
}
MEOF
printf 'static inline int tiny_add(int a, int b) { return a + b; }\n' > tinymod/tiny.h
printf 'import TinyC\nprint(tiny_add(2, 3))\n' > c.swift
probe "C: import tiny C module" 90 swiftc -I /tmp/iso/tinymod c.swift -o /tmp/iso/c

# D: import GTK module, TYPECHECK ONLY (isolates ClangImporter on the GTK tree)
mkdir -p gtkmod
cat > gtkmod/module.modulemap <<'MEOF'
module CGTKProbe [system] {
    header "shim.h"
    export *
}
MEOF
printf '#include <gtk/gtk.h>\n' > gtkmod/shim.h
printf 'import CGTKProbe\nprint("gtk imported")\n' > d.swift
GTK_CFLAGS=$(pkg-config --cflags gtk4)
XCC=()
for f in $GTK_CFLAGS; do XCC+=(-Xcc "$f"); done
probe "D: import GTK module (-typecheck)" 240 swiftc -typecheck -I /tmp/iso/gtkmod "${XCC[@]}" d.swift

echo
echo "=== interpretation ==="
echo "A/B pass + C hangs      => ClangImporter/module maps are broken under WSL1"
echo "A/B/C pass + D hangs    => specifically the GTK header tree (size/complexity)"
echo "all pass                => the trigger is SwiftPM's own invocation, not modules"
