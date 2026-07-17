# Toolbar icon credits

The demo's four toolbar icons are **[Tabler Icons](https://tabler.io/icons)** by Paweł Kuna,
used under the **MIT License** (Copyright © 2020–2026 Paweł Kuna).

| Demo file | Tabler icon | Toolbar item |
|---|---|---|
| `ToolbarOpen.png` | `outline/folder-open.svg` | Open |
| `ToolbarSave.png` | `outline/device-floppy.svg` | Save |
| `ToolbarToggle.png` | `outline/ban.svg` | Disable Save |
| `ToolbarCustomize.png` | `outline/adjustments-horizontal.svg` | Customize |

## How they were produced

Tabler ships 24×24 SVGs stroked in `currentColor`. Each was rendered to a **64px PNG,
black on transparent**:

```
NSImage(contentsOfFile: "…/folder-open.svg")   // macOS 11+ reads SVG natively (_NSSVGImageRep)
  → draw into an NSBitmapImageRep at 64×64
  → representation(using: .png)
```

Two properties of that output matter, and both are deliberate:

- **Black on transparent + `isTemplate = true`.** Each framework tints the artwork for the
  current appearance, so the demo ships **one** copy rather than a light and a dark one.
  (`currentColor` with no CSS context renders black — verified, not assumed.)
- **64px for a 32pt item.** That is exactly 1:1 on a Retina display, so no `NSImage.size`
  assignment is needed — which matters, because LinChocolate's `NSImage` has no `size`
  property.

To re-render or swap an icon, point the same two steps at a different file in
`tabler-icons/icons/outline/`.

## Why not ship the SVGs directly

macOS reads SVG, but WinChocolate and LinChocolate do not — their image codecs are
BMP/PNG/ICO. PNG is the one format all three read, so the SVGs are rasterised at build-prep
time rather than shipped. (See the MUST FIX list in `DEMO_CHANGES.md`: LinChocolate's
`NSImage.draw(in:)` is currently a no-op stub, so these icons will not render there until
that lands, regardless of format.)
