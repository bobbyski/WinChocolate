# LinChocolate — Ring 1 Harness (Mac + Docker + XQuartz)

This is the Phase L2.2/L2.3 harness from [`../Docs/LinChocolatePlan.md`](../Docs/LinChocolatePlan.md):
a reproducible **inner loop** where Swift + GTK4 build and run inside a Linux
container, and GUI windows display on the Mac desktop through XQuartz (X11).

It now contains the first real framework slice plus the original harness spike:

- **`LinChocolate`** — the AppKit-shaped library: `NSApplication`, `NSWindow`,
  `NSView`, `NSButton`, `NSTextField`, behind a narrow `NativeControlBackend`
  seam with a **GTK4 backend** and an **in-memory backend** (mirrors WinChocolate).
- **`LinChocolateDemo`** — a Controls page (button, checkbox, radio group,
  slider, stepper, progress bar, level bar, dropdown, editable/secure/search
  text, combo box, color well, calendar date picker, multiline text view)
  written against the AppKit API, rendered as native GTK controls.

Headless verification: the demo can be rendered and screenshotted without any
display via Xvfb (baked into the image) — useful when the window is taller than
the XQuartz screen, whose off-screen pixels X11 cannot capture:

```sh
docker run --rm -v "$PWD":/work -w /work linchocolate-dev bash -c \
  'Xvfb :99 -screen 0 900x1600x24 & sleep 1; export DISPLAY=:99 GSK_RENDERER=cairo; \
   (timeout 20 swift run LinChocolateDemo &) ; sleep 12; \
   import -window "$(xwininfo -root -tree | grep -oE \"^ *0x[0-9a-f]+\" | head -1)" /work/shot.png'
```
- **`LinChocolateContractTests`** — hermetic, no-display tests proving the API is
  backend-swappable (spike **S4**, 13/13 green).
- **`GTKHelloSpike`** — the original raw-GTK4 smoke test.

```sh
./run-linux.sh LinChocolateDemo                       # native window on the Mac
docker run --rm -v "$PWD":/work -w /work \
  linchocolate-dev swift run LinChocolateContractTests # hermetic tests, no display
```

> **Note on location.** This lives nested under `WinChocolate/LinChocolate/`
> for now (same pattern as the nested `WinFoundation/` package) so it rides the
> `feature/LinChocolate` branch. When it graduates (plan L2.5) it can move to a
> true sibling directory next to WinChocolate.

## What the rings are

| Ring | Where | Covers | Not covered |
|---|---|---|---|
| **1 (this harness)** | Mac + Docker + XQuartz | build, contract tests, **X11** rendering, event bridge | Wayland, real GPU, packaging |
| 2 | Linux VMs | X11 **and** Wayland, packaging | Pi hardware limits |
| 3 | Raspberry Pi | real GPU/RAM, Pi compositor, perf | — |

A green run here is **necessary but not sufficient**: XQuartz is X11-only, so
Wayland is never proven here (that's Rings 2–3).

## One-time setup

```sh
brew install --cask docker xquartz
```

Start **Docker Desktop** (the harness targets the running daemon). That's it —
`run-linux.sh` handles the rest of XQuartz for you: it enables TCP listening
(`nolisten_tcp=false`), restarts XQuartz if needed, authorizes the connection
(`xhost +`), and points `DISPLAY` at your Mac's LAN IP.

On Apple Silicon the container builds **arm64/aarch64**, matching the Pi.

> **Why LAN IP and `xhost +`, not `host.docker.internal`?** The container's X
> connection arrives from Docker's internal NAT address, so per-IP `xhost` rules
> don't match — access control is disabled for the session (re-tighten with
> `DISPLAY=:0 xhost -`). And `host.docker.internal` resolved IPv6-only and was
> unreachable here, so the script dials the host's `en0`/`en1` IPv4 address.

## Run it

```sh
./run-linux.sh                 # build the image, then `swift run GTKHelloSpike`
./run-linux.sh --shell         # interactive container shell
./run-linux.sh SomeExecutable  # run a different executable target
./verify.sh                    # CI-style: build + contract tests + headless captures
```

Expected result: a small GTK4 window titled **"Hello LinChocolate"** appears on
your Mac. That is S1 (interop builds) and S2 (renders over XQuartz) both proven.

The script authorizes XQuartz (`xhost + 127.0.0.1`), builds the image, then runs
the container with `DISPLAY=host.docker.internal:0` and the source bind-mounted
at `/work` for incremental rebuilds.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `cannot open display` / `Broken pipe` | XQuartz not running, or "Allow connections from network clients" is off. Enable it, restart XQuartz, re-run. |
| `libEGL warning: DRI3 ...` / `glx: failed to create drisw screen` | **Benign.** GTK probes GL when opening the X display; XQuartz's GLX is limited, so the probe fails and GTK falls back to the Cairo renderer (which draws the window). Safe to ignore. |
| Window is blank or fails with a GL error | The GL renderer over XQuartz. The harness already forces `GSK_RENDERER=cairo`; confirm it's set (`./run-linux.sh --shell` then `echo $GSK_RENDERER`). |
| `xhost: unable to open display ""` | XQuartz hadn't finished launching. The script retries; if it persists, `open -a XQuartz` manually first. |
| `pkg-config gtk4 not found` during build | The image build failed to install `libgtk-4-dev`; re-run `docker build` and check network. |
| Very slow first run | First build downloads the Swift base image + GTK. Subsequent runs are cached. |

## Files

```
Package.swift              SwiftPM manifest (library + demo + tests + spike)
Dockerfile                 Swift 6 + GTK4 on Ubuntu Noble (arm64 on Apple Silicon)
run-linux.sh               XQuartz bridge + build + run
docker-compose.yml         Same loop via `docker compose run`
Sources/CGTK/              Hand-written GTK4 module map (pkg-config gtk4)
Sources/LinChocolate/      AppKit-shaped API + NativeControlBackend (GTK + in-memory)
Sources/LinChocolateDemo/  The click-counter demo (AppKit API over GTK)
Sources/GTKHelloSpike/     The raw-GTK4 S1/S2 smoke test
Tests/LinChocolateContractTests/  Hermetic backend/API contract tests (S4)
```
