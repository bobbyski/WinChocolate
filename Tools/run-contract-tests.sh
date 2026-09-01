#!/usr/bin/env bash
#
# Run the headless contract suite on this Mac, with no Docker and no Windows VM.
#
#   Tools/run-contract-tests.sh              # build for wasm32-wasi, then run
#   Tools/run-contract-tests.sh --build      # compile only
#   Tools/run-contract-tests.sh --only Document   # run only tests whose call
#                                                 # name contains "Document"
#   Tools/run-contract-tests.sh --skip-env        # skip tests needing a
#                                                 # UserDefaults store WASI lacks
#   Tools/run-contract-tests.sh --skip a|b        # skip named tests as well
#
# HOW, and what it does and does not prove.
#
# The suite's real homes are Windows (`buildandrun.bat`) and the Linux container
# (`./run-linux.sh --tests`). This is a third way in, not a replacement: the
# same sources are built for wasm32-unknown-wasip1 and run under Node's WASI
# with `CHOCOLATE_BACKEND=inmemory`, so the framework logic executes for real
# against the recording backend.
#
# It therefore proves LOGIC, not RENDERING — no Win32 window and no GTK widget
# is involved, and the gated `FileWrapper` it exercises is the core's own copy
# rather than corelibs'. Landing a change still means running the Linux and
# Windows gates. What this buys is the fast loop in between.
#
# Known: a few tests need a UserDefaults backing store that WASI does not
# provide (toolbar and window-frame autosave). `--skip-env` steps around exactly
# those; a full green run belongs to the Linux and Windows gates.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
cd "$REPO"

SCRATCH_PATH="$REPO/.build-wasm-tests"
WASM="$SCRATCH_PATH/wasm32-unknown-wasip1/debug/WinChocolateContractTests.wasm"
SANDBOX="${TMPDIR:-/tmp}/chocolate-contract-sandbox"
MAIN="Tests/WinChocolateContractTests/main.swift"
BACKUP="$SCRATCH_PATH/main.swift.original"

BUILD_ONLY=0
ONLY=""
SKIP=""

# The tests that assert values survive in `UserDefaults`. WASI has no store
# behind it, so they fail for reasons that have nothing to do with the code
# under test. The Linux and Windows gates are where they actually run.
readonly ENV_LIMITED="testToolbarAutosaveRoundTripsConfiguration|testWindowFrameAutosaveRoundTrips"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --build) BUILD_ONLY=1; shift ;;
        --only) ONLY="${2:-}"; shift 2 ;;
        --skip-env) SKIP="${SKIP:+$SKIP|}$ENV_LIMITED"; shift ;;
        --skip) SKIP="${SKIP:+$SKIP|}${2:-}"; shift 2 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

command -v node >/dev/null 2>&1 || {
    echo "error: node not found; it supplies the WASI host." >&2
    exit 1
}

mkdir -p "$SCRATCH_PATH"

# `--only` narrows the suite by commenting out top-level calls. The original is
# restored on ANY exit — including a failure or a Ctrl-C — because leaving a
# gutted suite behind would silently weaken every later run.
restore_main() {
    if [[ -f "$BACKUP" ]]; then
        cp "$BACKUP" "$MAIN"
        rm -f "$BACKUP"
    fi
}

if [[ -n "$ONLY" || -n "$SKIP" ]]; then
    trap restore_main EXIT INT TERM
    cp "$MAIN" "$BACKUP"
    ONLY="$ONLY" SKIP="$SKIP" python3 - "$MAIN" <<'PY'
import os, re, sys
path = sys.argv[1]
needle = os.environ.get("ONLY", "")
skipped_names = {name + "()" for name in os.environ.get("SKIP", "").split("|") if name}
call = re.compile(r'^([A-Za-z_][A-Za-z0-9_]*\(\))\s*$')
kept = skipped = 0
out = []
for line in open(path).read().split('\n'):
    match = call.match(line)
    name = match.group(1) if match else ""
    drop = bool(match) and (
        (needle != "" and needle.lower() not in name.lower())
        or name in skipped_names)
    if drop:
        out.append('// narrowed by Tools/run-contract-tests.sh: ' + line)
        skipped += 1
    else:
        kept += 1 if match else 0
        out.append(line)
open(path, 'w').write('\n'.join(out))
print(f"• Running {kept} test(s); skipped {skipped}.")
PY
fi

echo "• Building the contract suite for wasm32-unknown-wasip1…"
CHOCOLATE_WASM=1 swift build \
    --swift-sdk swift-6.3.1-RELEASE_wasm \
    --product WinChocolateContractTests \
    --scratch-path "$SCRATCH_PATH"

if [[ "$BUILD_ONLY" == "1" ]]; then
    echo "✓ Built $WASM"
    exit 0
fi

# WASI grants no filesystem access at all unless a directory is preopened, and
# the document tests genuinely write and read files.
rm -rf "$SANDBOX"
mkdir -p "$SANDBOX"

echo "• Running under Node's WASI (in-memory backend)…"
# Deliberately NOT `exec`: exec replaces this shell, and an EXIT trap does not
# run when the process it belongs to is replaced. With `--only` in play that
# would leave the suite gutted on disk. Run it as a child and pass the status on.
set +e
node "$HERE/wasi-contract-runner.mjs" "$WASM" "$SANDBOX"
STATUS=$?
set -e
exit "$STATUS"
