#!/usr/bin/env bash
# One-off: apply the RealDemo relink fix to an ALREADY-COPIED native tree
# (wsl-native-build-test.sh now does this during the copy; this exists so the
# in-flight copy from before that change does not need a full re-copy).
set -uo pipefail
DST_ROOT="$HOME/linchoc-native/WinChocolate"
for f in "$DST_ROOT/LinChocolate/Sources/RealDemo"/*.swift; do
    [[ -L "$f" ]] && { echo "already a link: $(basename "$f")"; continue; }
    [[ $(wc -c < "$f") -lt 200 ]] || { echo "skipping (too big to be a path): $(basename "$f")"; continue; }
    target=$(tr -d '\r\n' < "$f")
    case "$target" in
    ../*Demo/DemoApplication/*.swift)
        rm "$f" && ln -s "$target" "$f"
        echo "relinked: $(basename "$f") -> $target"
        ;;
    *)
        echo "skipping (unexpected content): $(basename "$f")"
        ;;
    esac
done
