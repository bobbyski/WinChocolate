#!/usr/bin/env bash
#
# Build and run the document-architecture ground-truth probe against REAL
# AppKit — Docs/NSDOCUMENT_PLAN.md item 0.1.
#
# Runs from anywhere: the script resolves its own directory, so `cd` state and
# the caller's working directory are irrelevant.
#
#   Tools/document-ground-truth.sh          # build, run, print to the terminal
#   Tools/document-ground-truth.sh --build  # compile only
#
# Every number it prints is a value ChocolateKit has to reproduce. The house
# rule is that we measure Apple rather than assume it — this script is how.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$HERE/DocumentGroundTruthProbe.swift"
BIN="${TMPDIR:-/tmp}/chocolate-docprobe"

command -v swiftc >/dev/null 2>&1 || {
    echo "error: swiftc not found. Install Xcode (or the Command Line Tools)." >&2
    exit 1
}

# This probe is the control group: it must compile against Apple's own SDK,
# never against ChocolateKit.
SDK="$(xcrun --show-sdk-path --sdk macosx)"

echo "• Building the probe against $SDK"
swiftc -sdk "$SDK" -target arm64-apple-macos13.0 -o "$BIN" "$SOURCE"

if [[ "${1:-}" == "--build" ]]; then
    echo "✓ Built $BIN"
    exit 0
fi

echo "• Running…"
exec "$BIN"
