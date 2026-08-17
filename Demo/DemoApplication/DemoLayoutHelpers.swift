// Part of the shared demo, split out of main.swift by topic.
//
// Only DECLARATIONS live here. main.swift is Swift's top-level-code file:
// its statements run in written order, and moving one here would turn it
// into a lazily-initialized global that never runs. Declarations have no
// such ordering, so they move freely.

#if canImport(WASMChocolate)
import WASMChocolate
#elseif canImport(LinChocolate)
import LinChocolate
#elseif canImport(WinChocolate)
import WinChocolate
#else
import AppKit
#endif

@MainActor
func showDemoPage(_ index: Int) {
    controlsPage.isHidden = index != 0
    valuesPage.isHidden = index != 1
    tablesPage.isHidden = index != 2
    drawingPage.isHidden = index != 3
    showcasePage.isHidden = index != 4
    listsPage.isHidden = index != 5
    bezelsPage.isHidden = index != 6
    layoutPage.isHidden = index != 7
    coreGraphicsPage.isHidden = index != 8
    stressPage.isHidden = index != 9
    nibPage.isHidden = index != 10
    updateFocusDisplay()
}

@MainActor
func scrollClipDemo(to origin: NSPoint, name: String) {
    clipView.scroll(to: origin)
    let visible = clipView.documentVisibleRect
    clipOriginLabel.stringValue = "origin \(Int(visible.origin.x)),\(Int(visible.origin.y))"
    updateFocusDisplay()
    statusLabel.stringValue = "Clip view: \(name) visible \(Int(visible.origin.x)),\(Int(visible.origin.y))"
}

@MainActor
func showcaseSectionLabel(_ text: String, _ frame: NSRect) -> NSTextField {
    let label = NSTextField(string: text, frame: frame)
    label.isBordered = false
    label.drawsBackground = false
    label.font = NSFont.boldSystemFont(ofSize: 13)
    return label
}

// ---------------------------------------------------------------------------
// Bezels (8.3) page — showcases the framework-drawn NSButton bezel styles, the
// NSSegmentedControl styles, and the accent-aware drawn controls added in 8.3.
// Toggle to dark mode (run with --dark, or set Windows to dark) to see the
// appearance-aware fills.
// ---------------------------------------------------------------------------
@MainActor
func bezelCaption(_ text: String, _ frame: NSRect) -> NSTextField {
    let label = NSTextField(string: text, frame: frame)
    label.isBordered = false
    label.drawsBackground = false
    label.font = NSFont.systemFont(ofSize: 11)
    return label
}

func layoutDemoContainer(at x: CGFloat) -> NSView {
    let container = DemoFilledView(frame: NSMakeRect(x, 84, 250, 150))
    container.backgroundColor = NSColor(calibratedWhite: 0.30, alpha: 1)
    return container
}

func layoutBox(_ color: NSColor) -> NSView {
    let box = DemoFilledView(frame: .zero)
    box.translatesAutoresizingMaskIntoConstraints = false
    box.backgroundColor = color
    return box
}

// NSGridView (9.5): a label-and-field form — column 0 sizes to the widest label
// and right-aligns them, column 1 is a fixed width the field boxes fill.
func formLabel(_ text: String) -> NSTextField {
    let label = NSTextField(string: text, frame: .zero)
    label.isEditable = false
    label.isBordered = false
    label.drawsBackground = false
    return label
}

func fieldBox() -> NSTextField {
    // A real editable field so the form actually accepts focus and typing.
    let field = NSTextField(string: "", frame: NSMakeRect(0, 0, 120, 22))
    field.isEditable = true
    field.isBezeled = true
    field.isBordered = true
    return field
}

// Reflow the whole Auto Layout page from the current width: the four top demos
// become equal columns, the resize strip spans full width, and on the bottom
// row the form pins right, the vertical stack sits to its left, and the
// horizontal stack fills the remaining space. Each container re-runs the solver
// so its constraint-driven contents adapt. Called at startup and on resize.
@MainActor
func reflowAutoLayoutPage(width pageWidth: CGFloat) {
    let margin: CGFloat = 24
    let gap: CGFloat = 18
    let available = max(pageWidth - margin * 2, 240)

    // Top row: four equal-width demo columns.
    let colWidth = max((available - gap * 3) / 4, 120)
    let topCaptions = [demo1Caption, demo2Caption, demo3Caption, demo4Caption]
    let topContainers = [demo1, demo2, demo3, demo4]
    for i in 0..<4 {
        let x = margin + CGFloat(i) * (colWidth + gap)
        topCaptions[i].frame = NSMakeRect(x, 60, colWidth, 18)
        topContainers[i].frame = NSMakeRect(x, 84, colWidth, 150)
        topContainers[i].layoutSubtreeIfNeeded()
    }

    // Middle: the live-reflow strip spans the full width.
    resizeDemoCaption.frame = NSMakeRect(margin, 250, available, 18)
    resizeContainer.frame = NSMakeRect(margin, 274, available, 80)
    resizeContainer.layoutSubtreeIfNeeded()

    // Bottom row: form pinned to the right, vertical stack to its left, and the
    // horizontal stack filling everything left of them. Sits high enough that the
    // taller grid (a merged header row + three fields) clears the window bottom.
    let formWidth: CGFloat = 270
    let vStackWidth: CGFloat = 130
    let formX = pageWidth - margin - formWidth
    let vStackX = formX - 30 - vStackWidth
    gridCaption.frame = NSMakeRect(formX, 394, formWidth, 18)
    formGrid.frame = NSMakeRect(formX, 416, formWidth, 130)
    formGrid.layoutSubtreeIfNeeded()
    vStackCaption.frame = NSMakeRect(vStackX, 394, 200, 18)
    vStack.frame = NSMakeRect(vStackX, 416, vStackWidth, 110)
    vStack.layoutSubtreeIfNeeded()
    let hStackWidth = max(vStackX - 20 - margin, 200)
    hStackCaption.frame = NSMakeRect(margin, 394, hStackWidth, 18)
    hStack.frame = NSMakeRect(margin, 416, hStackWidth, 56)
    hStack.layoutSubtreeIfNeeded()
}

// Follow a live system dark/light switch (8.5). The framework re-themes and
// repaints its own windows/controls; the demo re-applies the few colors it
// caches at startup (the status/focus bands) and redraws. Skipped implicitly
// when --light/--dark pin an override, since the framework won't post then.
// Body of the appearance-change handler, factored out so the observer block can
// dispatch to it. Real Foundation (LinChocolate/AppKit) types the observer block
// @Sendable, so it can't touch the main-actor UI globals directly — it hops to
// the main actor below; WinChocolate's block inherits the main actor and calls
// this synchronously.
@MainActor
func applyLiveAppearanceRefresh() {
    let dark = NSApplication.shared.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    // The content view was given a background resolved at launch; re-resolve it
    // (windowBackgroundColor is dynamic) so the page surface follows the switch.
    contentView.backgroundColor = NSColor.windowBackgroundColor
    statusLabel.textColor = dark ? NSColor(calibratedRed: 0.55, green: 0.78, blue: 1.0, alpha: 1) : .blue
    statusLabel.backgroundColor = dark
        ? NSColor(white: 0.16, alpha: 1)
        : NSColor(calibratedRed: 0.94, green: 0.97, blue: 1.0, alpha: 1.0)
    focusLabel.textColor = dark ? NSColor(calibratedRed: 1.0, green: 0.83, blue: 0.4, alpha: 1) : .black
    focusLabel.backgroundColor = dark
        ? NSColor(white: 0.16, alpha: 1)
        : NSColor(calibratedRed: 1.0, green: 0.98, blue: 0.86, alpha: 1.0)

    // The demo caches a number of appearance-tuned colors at launch and sets
    // them on views scattered across every page. Setting a view's
    // backgroundColor builds a solid brush at that shade, so a live switch has
    // to re-set each one to rebuild the brush — a plain repaint keeps the old
    // color. Re-derive every cached color from the live appearance here.
    let valueText = dark
        ? NSColor(calibratedRed: 0.45, green: 0.68, blue: 1.0, alpha: 1.0)
        : NSColor.blue
    for label in [stepperValueLabel, scrollerValueLabel, dateValueLabel,
                  clipOriginLabel, listsBrowserPathLabel] {
        label.textColor = valueText
    }

    // Clip-view page: document surface + four demonstrative quadrant tiles.
    clipView.backgroundColor = dark
        ? NSColor(calibratedRed: 0.14, green: 0.14, blue: 0.15, alpha: 1.0) : .white
    clipDocumentView.backgroundColor = dark
        ? NSColor(calibratedRed: 0.17, green: 0.17, blue: 0.18, alpha: 1.0)
        : NSColor(calibratedRed: 0.97, green: 0.97, blue: 0.97, alpha: 1.0)
    clipTopLeftPane.backgroundColor = dark
        ? NSColor(calibratedRed: 0.16, green: 0.24, blue: 0.36, alpha: 1.0)
        : NSColor(calibratedRed: 0.84, green: 0.92, blue: 1.0, alpha: 1.0)
    clipTopRightPane.backgroundColor = dark
        ? NSColor(calibratedRed: 0.34, green: 0.29, blue: 0.14, alpha: 1.0)
        : NSColor(calibratedRed: 1.0, green: 0.94, blue: 0.72, alpha: 1.0)
    clipBottomLeftPane.backgroundColor = dark
        ? NSColor(calibratedRed: 0.16, green: 0.30, blue: 0.18, alpha: 1.0)
        : NSColor(calibratedRed: 0.86, green: 1.0, blue: 0.86, alpha: 1.0)
    clipBottomRightPane.backgroundColor = dark
        ? NSColor(calibratedRed: 0.34, green: 0.18, blue: 0.20, alpha: 1.0)
        : NSColor(calibratedRed: 1.0, green: 0.86, blue: 0.88, alpha: 1.0)

    // Split-view page: the two demonstrative panes.
    splitLeftPane.backgroundColor = dark
        ? NSColor(calibratedRed: 0.16, green: 0.25, blue: 0.37, alpha: 1.0)
        : NSColor(calibratedRed: 0.86, green: 0.93, blue: 1.0, alpha: 1.0)
    splitRightPane.backgroundColor = dark
        ? NSColor(calibratedRed: 0.35, green: 0.28, blue: 0.17, alpha: 1.0)
        : NSColor(calibratedRed: 1.0, green: 0.92, blue: 0.84, alpha: 1.0)

    // A focused field is tinted with the (cached) focus color; re-apply so a
    // switch while a field holds focus rebuilds its brush too.
    updateFocusDisplay()

    // The collection views' section header/footer bands are supplementary
    // views built once from the launch appearance and not recreated on a
    // repaint — reload so the delegate rebuilds them for the live appearance.
    collectionView.reloadData()
    listsCollectionView.reloadData()

    contentView.needsDisplay = true
}
