#!/usr/bin/env bash
#
# Build & run the shared WinChocolate demo against real Apple AppKit on macOS —
# the third leg of the tri-target compatibility proof (Linux/GTK via
# LinChocolate/run-linux.sh, Windows/Win32 via WinChocolate, and macOS/AppKit
# here). The *same* Demo/DemoApplication/main.swift compiles unmodified against
# genuine AppKit; the ergonomic conveniences both chocolate frameworks add
# (frame initializers, `onAction`, …) are re-expressed over Apple's types by the
# macOS shims — Demo/AppKitCompat.swift and Demo/DemoApplication/PlatformShims.swift.
#
# Usage:
#   ./run-mac.sh                 # build the .app, launch it
#   ./run-mac.sh --dark          # demo flags pass straight through …
#   ./run-mac.sh --page 3        # … (--light/--dark/--page N/--stress/--test)
#   ./run-mac.sh --test          # run headless self-test, print to the terminal
#   ./run-mac.sh --build         # build only, don't launch
#   ./run-mac.sh --clean         # wipe the build dir first
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_DIR="$HERE/Demo/DemoApplication"
SHIM="$HERE/Demo/AppKitCompat.swift"
BUILD="$HERE/.build-mac"
APP="$BUILD/WinChocolateDemo.app"
BIN="$APP/Contents/MacOS/WinChocolateDemo"
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

# --- 2. Sources: all of DemoApplication (main.swift + PlatformShims.swift) plus
#        the AppKit convenience shim. main.swift carries the top-level code. ----
SOURCES=("$DEMO_DIR"/*.swift "$SHIM")

# --- 3. App-bundle skeleton --------------------------------------------------
# NSApplication apps want a bundle: it gives the process a real Bundle.main (the
# demo loads its artwork via Bundle.main.path(forResource:inDirectory:"Resources"))
# and lets LaunchServices activate the window, show a Dock icon, and drive menus.
rm -rf "$APP"
mkdir -p "$(dirname "$BIN")" "$RES/Resources"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>WinChocolateDemo</string>
    <key>CFBundleIdentifier</key><string>com.winchocolate.demo</string>
    <key>CFBundleName</key><string>WinChocolate Demo</string>
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

# --- 4. Compile against the macOS SDK ---------------------------------------
echo "• Building the shared demo against AppKit…"
echo "  SDK: $SDK"
LOG="$BUILD/build.log"
if ! swiftc -sdk "$SDK" -target arm64-apple-macos13.0 \
        -o "$BIN" "${SOURCES[@]}" 2> "$LOG"; then
    n=$(grep -c "error:" "$LOG" 2>/dev/null || echo 0)
    echo
    echo "✗ Build failed with $n error(s)." >&2
    echo "  The macOS AppKit-compatibility shim is still incomplete (plan L15.1)." >&2
    echo "  Extend Demo/AppKitCompat.swift + Demo/DemoApplication/PlatformShims.swift" >&2
    echo "  to re-express the demo's conveniences over Apple's AppKit types." >&2
    echo "  Full log: $LOG" >&2
    echo >&2
    echo "  Top error categories:" >&2
    grep "error:" "$LOG" | sed -E 's/^.*error: //' | sort | uniq -c | sort -rn | head -12 >&2
    exit 1
fi
echo "✓ Built $APP"

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
