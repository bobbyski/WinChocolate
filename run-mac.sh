#!/usr/bin/env bash
#
# Build & run the shared WinChocolate demo against real Apple AppKit on macOS —
# the third leg of the tri-target compatibility proof (Linux/GTK via
# LinChocolate/run-linux.sh, Windows/Win32 via WinChocolate, and macOS/AppKit
# here). The *same* Demo/DemoApplication sources compile unmodified against
# genuine AppKit — NO shim (set in stone, Phase 18): the framework surface IS
# Apple's, and the demo's ergonomic sugar lives in DemoConveniences.swift,
# built only on real AppKit primitives so it compiles on all three targets.
#
# Usage:
#   ./run-mac.sh                 # build the main demo .app, launch it
#   ./run-mac.sh runloop         # build & launch the RunLoop/Timer demo instead
#   ./run-mac.sh runloop --build # …compile it only (the faithfulness gate)
#   ./run-mac.sh --dark          # demo flags pass straight through …
#   ./run-mac.sh --page 3        # … (--light/--dark/--page N/--stress/--test)
#   ./run-mac.sh --test          # run headless self-test, print to the terminal
#   ./run-mac.sh --build         # build only, don't launch
#   ./run-mac.sh --clean         # wipe the build dir first
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Optional first argument selects which demo to build (mirrors buildandrun.bat):
#   (default) / demo / winchocolate  → the main WinChocolate demo
#   runloop / runloopdemo            → the RunLoop / Timer demo
# Anything else is left for the demo (e.g. --dark), so `./run-mac.sh --dark`
# still builds and runs the main demo as before.
APP_NAME="WinChocolateDemo"
APP_SUBDIR="DemoApplication"
case "${1:-}" in
    runloop|runloopdemo) APP_NAME="RunLoopDemo"; APP_SUBDIR="RunLoopDemo"; shift ;;
    demo|winchocolate)   APP_NAME="WinChocolateDemo"; APP_SUBDIR="DemoApplication"; shift ;;
esac

DEMO_DIR="$HERE/Demo/$APP_SUBDIR"
BUILD="$HERE/.build-mac"
APP="$BUILD/$APP_NAME.app"
BIN="$APP/Contents/MacOS/$APP_NAME"
RES="$APP/Contents/Resources"

# --- flags handled by the script (everything else passes to the demo) --------
BUILD_ONLY=0
RUN_ARGS=()
for arg in "$@"; do
    case "$arg" in
        --build) BUILD_ONLY=1 ;;
        --clean) rm -rf "$BUILD"; echo "• Cleaned $BUILD" ;;
        *) RUN_ARGS+=("$arg") ;;
    esac
done

# --- 1. Toolchain ------------------------------------------------------------
command -v swiftc >/dev/null 2>&1 || {
    echo "error: swiftc not found. Install Xcode (or the Command Line Tools)." >&2
    exit 1
}
SDK="$(xcrun --show-sdk-path --sdk macosx)"

# --- 2. Sources: all of DemoApplication (main.swift carries the top-level
#        code; DemoConveniences.swift is the demo's own sugar — no shim). ------
SOURCES=("$DEMO_DIR"/*.swift)

# --- 3. App-bundle skeleton --------------------------------------------------
# NSApplication apps want a bundle: it gives the process a real Bundle.main (the
# demo loads its artwork via Bundle.main.path(forResource:inDirectory:"Resources"))
# and lets LaunchServices activate the window, show a Dock icon, and drive menus.
rm -rf "$APP"
mkdir -p "$(dirname "$BIN")" "$RES/Resources"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>com.winchocolate.${APP_NAME}</string>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# The demo resolves resources via `inDirectory: "Resources"`, i.e. it looks in
# <bundle>/Contents/Resources/Resources — so nest the artwork one level in.
cp "$DEMO_DIR"/Resources/* "$RES/Resources/" 2>/dev/null || true

# --- 3a. Compile the xib -----------------------------------------------------
# A .xib is Interface Builder *source*; AppKit's NSNib loads the *compiled* .nib, which is
# what Xcode's build phase produces. WinChocolate/LinChocolate parse the xib XML directly
# at runtime (they have no ibtool), so the demo ships the .xib and each target consumes it
# the way its own toolchain does — this step is macOS's half of that, not a workaround.
if [[ -f "$DEMO_DIR/Resources/DemoNibPanel.xib" ]]; then
    if ibtool --errors --warnings --output-format human-readable-text \
              --compile "$RES/Resources/DemoNibPanel.nib" \
              "$DEMO_DIR/Resources/DemoNibPanel.xib" >/dev/null 2>&1; then
        echo "• Compiled DemoNibPanel.xib → DemoNibPanel.nib (ibtool)"
    else
        echo "  warning: ibtool could not compile DemoNibPanel.xib — the Nib page will report it" >&2
    fi
fi

# --- 4. Compile against the macOS SDK ---------------------------------------
echo "• Building the shared demo against AppKit…"
echo "  SDK: $SDK"
LOG="$BUILD/build.log"
# -swift-version 6 matches the Windows/Linux builds (Package.swift is
# swift-tools-version 6.0): same language mode → same isolation model for
# top-level code, so the demo means the same thing on all three targets.
if ! swiftc -sdk "$SDK" -target arm64-apple-macos13.0 -swift-version 6 \
        -o "$BIN" "${SOURCES[@]}" 2> "$LOG"; then
    n=$(grep -c "error:" "$LOG" 2>/dev/null || echo 0)
    echo
    echo "✗ Build failed with $n error(s)." >&2
    echo "  Each error is an AppKit-faithfulness divergence (Phase 18): fix it by" >&2
    echo "  correcting WinChocolate/LinChocolate toward Apple's exact surface or" >&2
    echo "  rewriting the demo line to plain AppKit — NEVER by adding a shim" >&2
    echo "  (set in stone; see Docs/AppKitFaithfulnessIssues.md)." >&2
    echo "  Full log: $LOG" >&2
    echo >&2
    echo "  Top error categories:" >&2
    grep "error:" "$LOG" | sed -E 's/^.*error: //' | sort | uniq -c | sort -rn | head -12 >&2
    echo >&2
    echo "  Unique error sites (file:line: message):" >&2
    grep "error:" "$LOG" | sed -E 's|^.*/Demo/DemoApplication/||' | sort -u | head -50 >&2
    exit 1
fi
echo "✓ Built $APP"

# --- 4a. "nearly matches" = a silently dead delegate method -------------------
# AppKit protocols are @objc with *optional* members, which it discovers at runtime via
# respondsToSelector:. A method whose signature is a near-miss of the requirement is not a
# witness, is never exposed to Objective-C, and is NEVER CALLED — while compiling cleanly
# and looking perfectly correct. It is the single most expensive bug class in this port:
# it cost four "it's still broken" rounds on row drag alone, and it silently disabled the
# Auto Layout page's entire resize story.
#
# Swift emits exactly one signal for it — "nearly matches optional requirement" — and it is
# a warning, so it drowns in the ~180 routine warnings this build produces. Surface it.
# `grep -c` prints 0 AND exits 1 when there are no matches, so `|| echo 0` would append a
# second 0 and break the arithmetic test below. Swallow the exit status, keep the count.
NEARLY=$(grep -c "nearly matches" "$LOG" 2>/dev/null || true)
if [[ "$NEARLY" -gt 0 ]]; then
    echo
    echo "⚠️  $NEARLY DEAD DELEGATE METHOD(S) — these compile but AppKit never calls them." >&2
    echo "   A near-miss signature is not an @objc witness. Match Apple's declaration exactly" >&2
    echo "   (e.g. 'Notification' not 'NSNotification'; 'NSPasteboardWriting?' not 'Any?')," >&2
    echo "   or the method is silently inert at runtime:" >&2
    echo >&2
    grep "nearly matches" "$LOG" \
        | sed -E "s/^.*warning: instance method '([^']*)' nearly matches optional requirement '([^']*)' of protocol '([^']*)'.*/     • \3.\2  ←  demo declares '\1'/" \
        | sort -u >&2
    echo >&2
    echo "   Verify any one with: obj.responds(to: NSSelectorFromString(\"…\"))" >&2
    echo >&2
fi

[[ "$BUILD_ONLY" == "1" ]] && exit 0

# --- 5. Run ------------------------------------------------------------------
# `--test` mode prints diagnostics and exits, so run the binary directly to keep
# stdout on the terminal. Otherwise hand the .app to `open` for proper GUI
# activation (front window, Dock icon, menu bar).
if [[ " ${RUN_ARGS[*]:-} " == *" --test "* ]]; then
    echo "• Running headless self-test…"
    exec "$BIN" "${RUN_ARGS[@]}"
else
    echo "• Launching WinChocolate Demo…"
    open "$APP" ${RUN_ARGS[@]:+--args "${RUN_ARGS[@]}"}
fi
