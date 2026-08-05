#!/usr/bin/env bash
# Stage 4 of the WSL1 bring-up ladder (Tools/wsl-stage-tests.sh runs 1..3).
#
# Stages 1-3 proved: swiftc works, X11 works from C AND from Swift, GTK4 works
# from C. The remaining suspect is SwiftPM itself — `swift build` spins forever
# with a zombie swift-frontend child, on the NATIVE filesystem, which kills the
# old DrvFs-lock theory.
#
# So this stage asks the decisive question: does Swift + GTK4 work when built
# with swiftc DIRECTLY, no SwiftPM? If yes, the WSL1 loop is viable by
# bypassing `swift build`. If no, GTK-from-Swift is the wall and docker is the
# only path.
#
# Run:  wsl.exe -- bash /mnt/c/.../LinChocolate/Tools/wsl-stage4-swift-gtk.sh
set -uo pipefail

export PATH="$HOME/.local/share/swift-toolchains/current/usr/bin:$PATH"
export DISPLAY="${DISPLAY:-127.0.0.1:0}"
export SWIFT_BACKTRACE=enable=no
REPO="/mnt/c/AIResearch/WinChocolate/Code/WinChocolate"
CGTK_DIR="$REPO/LinChocolate/Sources/CGTK"

clang "$REPO/LinChocolate/Tools/x11-window-list.c" -lX11 -o /tmp/xlist 2>/dev/null

echo "=== CGTK module map (what SwiftPM would have used) ==="
ls -la "$CGTK_DIR" 2>/dev/null
echo "--- module.modulemap ---"
cat "$CGTK_DIR/module.modulemap" 2>/dev/null || echo "(none found)"

echo
echo "=== build Swift+GTK4 with swiftc directly (no SwiftPM) ==="
mkdir -p /tmp/swiftgtk
# Hand-roll the same module map SwiftPM's systemLibrary target provides, so the
# only difference from a package build is the BUILD DRIVER.
cat > /tmp/swiftgtk/module.modulemap <<'MEOF'
module CGTKProbe [system] {
    header "shim.h"
    link "gtk-4"
    export *
}
MEOF
cat > /tmp/swiftgtk/shim.h <<'HEOF'
#include <gtk/gtk.h>
HEOF

cat > /tmp/swiftgtk/main.swift <<'SEOF'
import CGTKProbe
#if canImport(Glibc)
import Glibc
#endif

// GTK 4.6-era GLib spells the default flags G_APPLICATION_FLAGS_NONE; the
// newer G_APPLICATION_DEFAULT_FLAGS may not be imported. 0 is the same value
// and avoids depending on which name this GLib exports.
let app = gtk_application_new("org.winchocolate.wslstage4", GApplicationFlags(rawValue: 0))

// GTK's C types import as distinct pointer types, so the widget->window
// narrowing has to go through the raw pointer rather than OpaquePointer.
func asWindow(_ widget: UnsafeMutablePointer<GtkWidget>!) -> UnsafeMutablePointer<GtkWindow>! {
    UnsafeMutableRawPointer(widget).assumingMemoryBound(to: GtkWindow.self)
}

let onActivate: @convention(c) (UnsafeMutablePointer<GtkApplication>?, gpointer?) -> Void = { appPtr, _ in
    let win = gtk_application_window_new(appPtr)
    gtk_window_set_title(asWindow(win), "wsl1-gtk4-swift-test")
    gtk_window_set_default_size(asWindow(win), 420, 260)
    gtk_window_present(asWindow(win))
    print("swift: window presented")
    fflush(stdout)
}

_ = g_signal_connect_data(
    UnsafeMutableRawPointer(app!), "activate",
    unsafeBitCast(onActivate, to: GCallback.self),
    nil, nil, GConnectFlags(rawValue: 0))

let status = g_application_run(
    UnsafeMutableRawPointer(app!).assumingMemoryBound(to: GApplication.self), 0, nil)
print("swift: g_application_run returned \(status)")
SEOF

GTK_CFLAGS=$(pkg-config --cflags gtk4)
GTK_LIBS=$(pkg-config --libs gtk4)

timeout 420 swiftc \
    -I /tmp/swiftgtk \
    $(for f in $GTK_CFLAGS; do echo -Xcc $f; done) \
    $GTK_LIBS \
    /tmp/swiftgtk/main.swift -o /tmp/swiftgtk/probe \
    > /tmp/swiftgtk/build.log 2>&1
BUILD=$?
echo "swiftc exit: $BUILD (124 = timed out => SwiftPM is NOT the only spinner)"
if [[ $BUILD -ne 0 ]]; then
    echo "--- build log (last 25) ---"
    tail -25 /tmp/swiftgtk/build.log
    echo "RESULT: SWIFT+GTK DIRECT BUILD FAILED"
    exit 1
fi

echo
echo "=== run it ==="
GDK_BACKEND=x11 GSK_RENDERER=cairo GDK_DISABLE=gl GTK_A11Y=none \
    /tmp/swiftgtk/probe > /tmp/swiftgtk/run.log 2>&1 &
PID=$!
MAPPED=1
for i in $(seq 1 12); do
    sleep 1
    if ! kill -0 $PID 2>/dev/null; then
        echo "process died after ${i}s"; break
    fi
    if /tmp/xlist | grep -q "wsl1-gtk4-swift-test"; then
        echo "window mapped after ~${i}s"; MAPPED=0; break
    fi
done
kill $PID 2>/dev/null; wait $PID 2>/dev/null
echo "--- app log ---"; cat /tmp/swiftgtk/run.log

if [[ $MAPPED -eq 0 ]]; then
    echo "RESULT: SWIFT+GTK4 ON WSL1 WORKS — SwiftPM is the sole blocker"
else
    echo "RESULT: built but no window — GTK-from-Swift is the wall"
fi
