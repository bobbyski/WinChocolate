#!/usr/bin/env bash
# LinChocolate CI-style verification: build + contract tests + headless demo
# captures. Runs everything inside the dev container; writes captures next to
# this script and a summary to stdout.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

echo "=== build ==="
docker run --rm -v "$PWD":/work -w /work linchocolate-dev swift build 2>&1 | grep -E "error:|Build complete" | head -15 || true

echo "=== tests ==="
docker run --rm -v "$PWD":/work -w /work linchocolate-dev swift run LinChocolateContractTests 2>&1 | grep -E "FAIL:|All contract|FAILED" | head -10 || true

echo "=== headless demo captures ==="
docker run --rm -v "$PWD":/work -w /work linchocolate-dev bash -c '
  Xvfb :99 -screen 0 900x1200x24 >/dev/null 2>&1 &
  sleep 1
  export DISPLAY=:99 GSK_RENDERER=cairo
  ( timeout 90 swift run LinChocolateDemo >/tmp/d.log 2>&1 ) &
  sleep 12
  WID=$(xwininfo -root -tree | grep -i "\"LinChocolate Controls\"" | head -1 | awk "{print \$1}")
  if [ -z "$WID" ]; then echo "NO WINDOW"; tail -4 /tmp/d.log; exit 1; fi
  import -window "$WID" /work/verify-basics.png && echo "cap basics"
  xdotool mousemove --sync 505 92 click 1; sleep 3
  import -window "$WID" /work/verify-drawing.png && echo "cap drawing"
  echo "criticals: $(grep -c CRITICAL /tmp/d.log)"
'
echo "=== VERIFY DONE ==="
