#!/usr/bin/env bash
#
# Build a Chocolate demo for the browser (Docs/WASMChocolatePlan.md).
#
#   ./build-wasm.sh                    # build CounterDemo and serve it
#   ./build-wasm.sh --build            # build only
#   ./build-wasm.sh RunLoopDemo        # a different executable target
#   ./build-wasm.sh WinChocolateDemo   # the 11-page catalog
#   ./build-wasm.sh --release ...      # optimized; much smaller .wasm
#
# Use --release once the demo is big. A debug CounterDemo is a 76 MB .wasm and
# the catalog is larger still; the download is the dominant cost of every
# look-at-it iteration, and it is paid on each reload.
#
# The pipeline is the official Swift WASM SDK plus JavaScriptKit's PackageToJS
# plugin — no carton. `CHOCOLATE_WASM` is what makes this package name SwiftDOM
# at all; without it the manifest has no browser dependencies, which is how the
# Windows and Linux builds stay untouched by any of this.
#
# NOTE: always build an *executable* target. A library-only wasm build trips a
# JavaScriptKit C-shim problem and fails for reasons that have nothing to do
# with your code.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

SWIFT_BIN="${SWIFT_BIN:-swift}"
SWIFT_WASM_SDK="${SWIFT_WASM_SDK:-swift-6.3.1-RELEASE_wasm}"
PORT="${PORT:-8080}"

BUILD_ONLY=0
CONFIGURATION="debug"
TARGET="CounterDemo"
for arg in "$@"; do
    case "$arg" in
        --build) BUILD_ONLY=1 ;;
        --release) CONFIGURATION="release" ;;
        --debug) CONFIGURATION="debug" ;;
        -*) echo "unknown option: $arg" >&2; exit 2 ;;
        *) TARGET="$arg" ;;
    esac
done

OUT="Demo/$TARGET/WebBuild"

# SwiftPM keeps one Package.resolved per package, but this package has two
# dependency graphs: the default one, and the larger one CHOCOLATE_WASM turns
# on. Resolving the wasm graph rewrites the file with SwiftDOM and
# JavaScriptKit pins, and the next Windows or Linux build then fails trying to
# reconcile pins its manifest never mentions.
#
# So the wasm pins are treated as scratch: the default file is put back on the
# way out, whether the build succeeded, failed, or was interrupted.
RESOLVED_BACKUP="$(mktemp)"
if [[ -f Package.resolved ]]; then
    cp Package.resolved "$RESOLVED_BACKUP"
fi
restore_resolved() {
    if [[ -s "$RESOLVED_BACKUP" ]]; then
        mv -f "$RESOLVED_BACKUP" Package.resolved
    else
        rm -f Package.resolved "$RESOLVED_BACKUP"
    fi
}
trap restore_resolved EXIT

export CHOCOLATE_WASM=1

echo "• Building $TARGET for wasm32 ($CONFIGURATION, SDK: $SWIFT_WASM_SDK)"
"$SWIFT_BIN" build -c "$CONFIGURATION" --swift-sdk "$SWIFT_WASM_SDK" --product "$TARGET"

# The configuration has to match on both calls: PackageToJS copies the binary
# out of the build directory it is pointed at, so packaging a release build with
# a debug flag silently ships the debug .wasm.
echo "• Packaging with PackageToJS into $OUT"
"$SWIFT_BIN" package -c "$CONFIGURATION" --swift-sdk "$SWIFT_WASM_SDK" \
    --allow-writing-to-package-directory js \
    --product "$TARGET" --output "$OUT" --use-cdn

if [[ "$BUILD_ONLY" == "1" ]]; then
    echo "• Built. Serve with: python3 -m http.server $PORT --directory Demo/$TARGET"
    exit 0
fi

echo "• Serving http://localhost:$PORT/ (Ctrl-C to stop)"
exec python3 -m http.server "$PORT" --directory "Demo/$TARGET"
