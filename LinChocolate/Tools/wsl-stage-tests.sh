#!/usr/bin/env bash
# Staged bring-up of the WSL1 + X11 loop. Each stage isolates ONE layer, so a
# failure names its own cause instead of leaving "Linux doesn't work".
#
#   1  swiftc            — compiler + runtime, no libraries        (hello world)
#   2a X11 from C        — X server transport, no Swift            (clang -lX11)
#   2b X11 from Swift    — Swift C-interop + runtime over X11      (swiftc -lX11)
#   3  GTK4 from C       — GTK stack itself, no Swift              (clang gtk4)
#
# Anything above the first failure is not worth running. Every stage is
# timeout-wrapped: the failure mode on this machine is a SILENT SPIN, not an
# error, so an unbounded stage tells us nothing.
#
# Run:  wsl.exe -- bash /mnt/c/.../LinChocolate/Tools/wsl-stage-tests.sh
set -uo pipefail

TOOLS="/mnt/c/AIResearch/WinChocolate/Code/WinChocolate/LinChocolate/Tools"
export PATH="$HOME/.local/share/swift-toolchains/current/usr/bin:$PATH"
export DISPLAY="${DISPLAY:-127.0.0.1:0}"
export SWIFT_BACKTRACE=enable=no

pass=0
fail=0
note() { echo; echo "=== $1 ==="; }
verdict() { # verdict <name> <exit>
    if [[ "$2" -eq 0 ]]; then echo "STAGE $1: PASS"; pass=$((pass + 1));
    else echo "STAGE $1: FAIL (exit $2${3:+, $3})"; fail=$((fail + 1)); fi
}

# Build the window lister once; every windowing stage asserts through it.
clang "$TOOLS/x11-window-list.c" -lX11 -o /tmp/xlist 2>/dev/null

note "1. swiftc hello world (compiler + runtime)"
printf 'print("hello from wsl1")\n' > /tmp/hello.swift
timeout 180 swiftc /tmp/hello.swift -o /tmp/hello
build1=$?
if [[ $build1 -eq 0 ]]; then
    out=$(timeout 30 /tmp/hello)
    echo "output: $out"
    [[ "$out" == "hello from wsl1" ]]
    verdict 1 $?
else
    verdict 1 $build1 "compile timed out or failed"
fi

if [[ $fail -gt 0 ]]; then
    echo; echo "SUMMARY: pass=$pass fail=$fail — stopping, the compiler itself is the blocker."
    exit 1
fi

note "2a. X11 window from C (server transport, no Swift)"
timeout 120 clang "$TOOLS/x11-c-window.c" -lX11 -o /tmp/xcwin
if [[ $? -eq 0 ]]; then
    /tmp/xcwin > /tmp/xcwin.log 2>&1 &
    cpid=$!
    sleep 4
    if /tmp/xlist | grep -q "wsl1-x11-c-test"; then verdict 2a 0; else verdict 2a 1 "no window mapped"; fi
    kill $cpid 2>/dev/null; wait $cpid 2>/dev/null
    echo "app log: $(cat /tmp/xcwin.log)"
else
    verdict 2a 1 "clang failed"
fi

note "2b. X11 window from SWIFT (Swift C-interop + runtime)"
timeout 300 swiftc "$TOOLS/x11-swift-window.swift" -lX11 -o /tmp/xswin 2>/tmp/xswin-build.log
build2b=$?
if [[ $build2b -eq 0 ]]; then
    /tmp/xswin > /tmp/xswin.log 2>&1 &
    spid=$!
    sleep 5
    if /tmp/xlist | grep -q "wsl1-x11-swift-test"; then verdict 2b 0; else verdict 2b 1 "no window mapped"; fi
    kill $spid 2>/dev/null; wait $spid 2>/dev/null
    echo "app log: $(cat /tmp/xswin.log)"
else
    verdict 2b $build2b "swiftc failed/timed out"
    echo "--- build log ---"; tail -10 /tmp/xswin-build.log
fi

note "3. GTK4 window from C (the GTK stack itself, no Swift)"
cat > /tmp/gtkwin.c <<'CEOF'
#include <gtk/gtk.h>
static void on_activate(GtkApplication *app, gpointer _u) {
    GtkWidget *w = gtk_application_window_new(app);
    gtk_window_set_title(GTK_WINDOW(w), "wsl1-gtk4-c-test");
    gtk_window_set_default_size(GTK_WINDOW(w), 420, 260);
    gtk_window_present(GTK_WINDOW(w));
}
/* G_APPLICATION_DEFAULT_FLAGS is GLib 2.74+; GTK 4.6.9 here ships with an
 * older GLib, where the spelling is G_APPLICATION_FLAGS_NONE. */
#ifndef G_APPLICATION_DEFAULT_FLAGS
#define G_APPLICATION_DEFAULT_FLAGS G_APPLICATION_FLAGS_NONE
#endif
int main(int argc, char **argv) {
    GtkApplication *app = gtk_application_new("org.winchocolate.wsltest", G_APPLICATION_DEFAULT_FLAGS);
    g_signal_connect(app, "activate", G_CALLBACK(on_activate), NULL);
    int s = g_application_run(G_APPLICATION(app), argc, argv);
    g_object_unref(app);
    return s;
}
CEOF
timeout 180 clang /tmp/gtkwin.c $(pkg-config --cflags --libs gtk4) -o /tmp/gtkwin 2>/tmp/gtkwin-build.log
build3=$?
if [[ $build3 -eq 0 ]]; then
    GDK_BACKEND=x11 GSK_RENDERER=cairo GDK_DISABLE=gl GTK_A11Y=none /tmp/gtkwin > /tmp/gtkwin.log 2>&1 &
    gpid=$!
    sleep 8
    if /tmp/xlist | grep -q "wsl1-gtk4-c-test"; then verdict 3 0; else verdict 3 1 "no window mapped"; fi
    kill $gpid 2>/dev/null; wait $gpid 2>/dev/null
    echo "app log: $(tail -5 /tmp/gtkwin.log)"
else
    verdict 3 $build3 "clang/gtk build failed"
    echo "--- build log ---"; tail -10 /tmp/gtkwin-build.log
fi

echo
echo "SUMMARY: pass=$pass fail=$fail"
[[ $fail -eq 0 ]]
