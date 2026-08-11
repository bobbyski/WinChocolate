import WinChocolate

@MainActor
func testToolbarCustomizationDragOutTintsPreviewForRemoval() {
    clearApplicationWindows()

    let toolbar = NSToolbar(identifier: "removalTint")
    for name in ["one", "two"] {
        let item = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier(rawValue: name))
        item.label = name
        toolbar.addItem(item)
    }
    toolbar.allowsUserCustomization = true
    toolbar.runCustomizationPalette(nil)

    guard let panel = NSApplication.shared.windows.compactMap({ $0 as? NSPanel }).last,
          let contentView = panel.contentView else {
        expect(false, "Toolbar customization palette did not create a panel.")
        return
    }

    let previewBlue = NSColor(calibratedRed: 0.84, green: 0.89, blue: 0.96, alpha: 1.0)
    let removalRed = NSColor(calibratedRed: 0.96, green: 0.85, blue: 0.84, alpha: 1.0)
    func preview() -> NSView? {
        contentView.subviews.first { !$0.isHidden && ($0.winBackgroundColor == previewBlue || $0.winBackgroundColor == removalRed) }
    }

    let strip = contentView.subviews.first { $0.tag == 1_103 }
    guard let tile = (strip?.subviews ?? []).first(where: { $0.toolTip == "Drag to reorder or drag out to remove." }) else {
        expect(false, "The mirrored strip did not build tiles.")
        return
    }
    let start = tile.convert(NSMakePoint(tile.bounds.size.width / 2, tile.bounds.size.height / 2), to: nil)
    let overStrip = contentView.convert(NSMakePoint(contentView.frame.size.width - 40, 20), to: nil)
    let outside = contentView.convert(NSMakePoint(contentView.frame.size.width / 2, 220), to: nil)

    // Over the strip: the standard blue preview. Outside: the removal tint.
    tile.mouseDown(with: NSEvent(type: .leftMouseDown, locationInWindow: start))
    tile.mouseDragged(with: NSEvent(type: .leftMouseDragged, locationInWindow: overStrip))
    expect(preview()?.winBackgroundColor == previewBlue, "The in-strip drag preview should use the standard tint.")
    tile.mouseDragged(with: NSEvent(type: .leftMouseDragged, locationInWindow: outside))
    expect(preview()?.winBackgroundColor == removalRed, "Dragging out of the strip did not tint the preview for removal.")
    tile.mouseUp(with: NSEvent(type: .leftMouseUp, locationInWindow: outside))
    expect(toolbar.items.count == 1, "The drag-out did not remove the item.")

    clearApplicationWindows()
}

@MainActor
func testToolbarPopupAndFieldItemsAlignVertically() {
    let backend = InMemoryNativeControlBackend()
    let toolbar = NSToolbar(identifier: "alignment")

    // A popup declared 28pt tall next to a 24pt field: the native closed
    // combo only renders ~24pt anchored to its frame top, so the layout must
    // center it by its visible height or it reads high next to the field.
    let popupItem = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("pages"))
    let popup = NSPopUpButton(frame: NSMakeRect(0, 0, 168, 28), pullsDown: false)
    popupItem.view = popup
    popupItem.minSize = NSMakeSize(168, 28)
    popupItem.maxSize = NSMakeSize(168, 28)
    toolbar.addItem(popupItem)

    let fieldItem = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("search"))
    let field = NSTextField(string: "", frame: NSMakeRect(0, 0, 160, 24))
    fieldItem.view = field
    fieldItem.minSize = NSMakeSize(160, 24)
    fieldItem.maxSize = NSMakeSize(160, 24)
    toolbar.addItem(fieldItem)

    let toolbarView = NSToolbarView(frame: NSMakeRect(0, 0, 500, 40))
    toolbarView.toolbar = toolbar
    _ = toolbarView.realizeNativePeer(in: backend, parent: nil)

    let popupMidY = popup.frame.origin.y + popup.frame.size.height / 2
    let fieldMidY = field.frame.origin.y + field.frame.size.height / 2
    expect(abs(popupMidY - fieldMidY) <= 1,
           "The popup and field are not vertically aligned. popup midY \(popupMidY), field midY \(fieldMidY).")
    expect(popup.frame.size.height <= 25,
           "The popup's layout height should match its visible closed-combo height. Got \(popup.frame.size.height).")
}

@MainActor
func testWinPresentationSelectionAndModernSeparators() {
    // The modern default (8.4) is asserted at suite startup, before the
    // classic pin; here the pin should be in effect.
    expect(WinPresentation.selected == .classic, "The suite should be pinned to the classic presentation.")

    func separatorViews(in toolbarView: NSToolbarView) -> Int {
        toolbarView.subviews.filter { $0 is NSToolbarSeparatorView }.count
    }
    func makeToolbarView() -> NSToolbarView {
        let toolbar = NSToolbar(identifier: "presentation")
        let item = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("doc"))
        item.label = "Doc"
        toolbar.addItem(item)
        toolbar.addItem(NSToolbarItem(itemIdentifier: .separator))
        let toolbarView = NSToolbarView(frame: NSMakeRect(0, 0, 300, 40))
        toolbarView.toolbar = toolbar
        return toolbarView
    }

    // Classic: an .automatic separator renders as a vertical bar.
    expect(separatorViews(in: makeToolbarView()) == 1,
           "The classic presentation should render an automatic separator bar.")

    // Modern: it resolves to a blank gap (no bar view), like current Apple
    // toolbars.
    WinPresentation.selected = .modern
    defer { WinPresentation.selected = .classic }
    expect(separatorViews(in: makeToolbarView()) == 0,
           "The modern presentation should render automatic separators as gaps.")
}

@MainActor
func testDarkAppearanceDrivesDynamicColorsAndDrawnTable() {
    // Route the app through a scriptable backend reporting a dark system
    // theme, with no appearance override (drop the suite's light pin).
    let appBackend = InMemoryNativeControlBackend()
    appBackend.simulatedDarkAppearance = true
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = appBackend
    NSApplication.shared.appearance = nil
    defer {
        NSApplication.shared.nativeBackend = previousBackend
        NSApplication.shared.appearance = NSAppearance(named: .aqua)
    }

    // Dynamic system colors resolve to the dark palette...
    expect(NSColor.windowBackgroundColor.whiteComponent < 0.3,
           "The dark window background should be dark.")
    expect(NSColor.textColor.whiteComponent > 0.8,
           "The dark text color should be light.")
    expect(NSColor.selectedTextColor == .white,
           "Dark selections should use light text.")
    expect(NSColor.unemphasizedSelectedContentBackgroundColor.whiteComponent < 0.5,
           "The unemphasized (non-key) selection fill should darken under dark mode, not stay a light island.")

    // ...and flip back with an explicit light override.
    NSApplication.shared.appearance = NSAppearance(named: .aqua)
    expect(NSColor.windowBackgroundColor == .white,
           "The light window background should be white.")
    expect(NSColor.unemphasizedSelectedContentBackgroundColor.whiteComponent > 0.7,
           "The unemphasized selection fill should be a light gray under light mode.")
    NSApplication.shared.appearance = nil

    // The drawn table renders its dark skin: a dark body fill and light
    // header-title/cell text.
    let backend = InMemoryNativeControlBackend()
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 200, 100))
    let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("a"))
    column.title = "Alpha"
    column.width = 80
    tableView.addTableColumn(column)
    let dataSource = ManyRowTableDataSource(count: 1)
    tableView.dataSource = dataSource
    tableView.winUsesViewBasedCells = true
    let handle = tableView.realizeNativePeer(in: backend, parent: nil)
    let recording = backend.performDraw(for: handle, in: tableView.bounds)
    guard let bodyFill = recording.fills.first?.color else {
        fatalError("The dark drawn table recorded no body fill.")
    }
    expect(bodyFill.whiteComponent < 0.3, "The dark drawn table body should be dark.")
    guard let title = recording.texts.first(where: { $0.text == "Alpha" }) else {
        fatalError("The dark drawn table recorded no header title.")
    }
    expect(title.color.whiteComponent > 0.5, "The dark header title should be light.")
}

final class AppearanceProbeView: NSView {
    var drawnAppearance: NSAppearance.Name?
    override func draw(_ dirtyRect: NSRect) {
        drawnAppearance = NSAppearance.currentDrawing().name
    }
}

final class DataImageProbeView: NSView {
    var image: NSImage?
    override func draw(_ dirtyRect: NSRect) {
        image?.draw(in: NSMakeRect(0, 0, 20, 20))
    }
}

@MainActor
func testDataBackedNSImageDecodesAndDrawsPixels() {
    // A data-backed NSImage decodes through WinCoreGraphics (13.6) and draws
    // its pixels, closing the 3.13 in-memory boundary. Build a 2×2 BMP.
    let pixels: [UInt8] = [255, 0, 0, 255,   0, 255, 0, 255,
                           0, 0, 255, 255,   255, 255, 0, 255]
    guard let source = CGImage(width: 2, height: 2, rgbaPixels: pixels) else {
        expect(false, "CGImage should build from RGBA."); return
    }
    let bmp = Data(source.encodeBMP())
    guard let image = NSImage(data: bmp) else {
        expect(false, "NSImage(data:) should accept BMP data."); return
    }

    // Decoding populates the CGImage and the (previously zero) logical size.
    expect(image.winCGImage?.width == 2, "Data-backed NSImage should decode a 2-wide CGImage.")
    expect(image.size == NSSize(width: 2, height: 2),
        "NSImage.size should come from the decoded bitmap: got \(image.size).")

    // Drawing records an in-memory bitmap blit (not a file path).
    let backend = InMemoryNativeControlBackend()
    let view = DataImageProbeView(frame: NSMakeRect(0, 0, 20, 20))
    view.image = image
    let handle = view.realizeNativePeer(in: backend, parent: nil)
    let recording = backend.performDraw(for: handle, in: view.bounds)
    expect(recording.bitmapImages.count == 1, "The data-backed image should draw once as a bitmap.")
    if let drawn = recording.bitmapImages.first {
        expect(drawn.width == 2 && drawn.height == 2 && drawn.byteCount == 16,
            "The recorded bitmap should be 2×2 RGBA: got \(drawn.width)×\(drawn.height), \(drawn.byteCount) bytes.")
        expect(winClose(drawn.rect.size.width, 20) && drawn.tint == nil,
            "The bitmap should draw untinted into the 20-pt destination rect.")
    }
    expect(recording.images.isEmpty, "A data-backed image should not take the file-path draw.")
}

@MainActor
func testCurrentDrawingAppearanceFollowsTheDrawingView() {
    // Outside a draw pass, currentDrawing falls back to the application's
    // effective appearance (the suite's light pin).
    expect(NSAppearance.currentDrawing().name == .aqua,
           "Outside a draw pass currentDrawing should be the app appearance.")

    // During a draw pass it is the drawing view's effective appearance —
    // here an explicit per-view dark override on a light app.
    let backend = InMemoryNativeControlBackend()
    let view = AppearanceProbeView(frame: NSMakeRect(0, 0, 40, 40))
    view.appearance = NSAppearance(named: .darkAqua)
    let handle = view.realizeNativePeer(in: backend, parent: nil)
    _ = backend.performDraw(for: handle, in: view.bounds)
    expect(view.drawnAppearance == .darkAqua,
           "currentDrawing inside draw should be the view's effective appearance.")
    expect(NSAppearance.currentDrawing().name == .aqua,
           "currentDrawing should restore after the draw pass.")
}

@MainActor
func testToolbarStripGoesDarkUnderDarkAppearance() {
    NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
    defer { NSApplication.shared.appearance = NSAppearance(named: .aqua) }

    let toolbar = NSToolbar(identifier: "dark-strip")
    toolbar.winAppleLook = .unified // this test is about the unified strip's dark chrome
    let item = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("doc"))
    item.label = "Doc"
    toolbar.addItem(item)
    let toolbarView = NSToolbarView(frame: NSMakeRect(0, 0, 300, 40))
    toolbarView.toolbar = toolbar

    guard let strip = toolbarView.winBackgroundColor else {
        fatalError("The toolbar strip should have a background color.")
    }
    expect(strip.whiteComponent < 0.3,
           "The unified toolbar strip should be dark under the dark appearance. Got \(strip).")
}

@MainActor
func testSystemAccentColorDrivesAccentAndSelection() {
    let backend = InMemoryNativeControlBackend()
    let previous = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer { NSApplication.shared.nativeBackend = previous }

    // No system accent → the blue base and the stock selection pair.
    expect(NSColor.controlAccentColor == .systemBlue,
           "Without a system accent the control accent should be the blue base.")
    let stockSelection = NSColor.selectedTextBackgroundColor

    // A scripted accent drives the accent color and tints the selection.
    let accent = NSColor(calibratedRed: 0.8, green: 0.2, blue: 0.4, alpha: 1)
    backend.simulatedAccentColor = accent
    expect(NSColor.controlAccentColor == accent,
           "The control accent should be the system accent color.")
    let tinted = NSColor.selectedTextBackgroundColor
    expect(tinted != stockSelection,
           "The selection background should follow the accent color.")
    expect(tinted.redComponent > tinted.blueComponent,
           "The selection tint should keep the accent's hue balance.")
    expect(tinted.whiteComponent > accent.whiteComponent,
           "The light-appearance selection tint should be lighter than the accent.")
}

@MainActor
func testWrappedTextMeasurementBreaksIntoLines() {
    let backend = InMemoryNativeControlBackend()
    let text = "The quick brown fox jumps over the lazy dog"
    let font = NativeFontSpec(family: "Segoe UI", size: 12)
    let single = backend.measureText(text, font: font)

    // Wrapping at a narrow width produces several lines: the height grows past
    // one line and the width stays within the cap.
    let narrow = backend.measureText(text, font: font, wrappingAt: 80)
    expect(narrow.height > single.height, "Wrapped text should be taller than a single line.")
    expect(narrow.width <= 80 + 0.5, "Wrapped width should not exceed the wrap width. Got \(narrow.width).")
    expect(narrow.height.truncatingRemainder(dividingBy: single.height) < 0.01,
           "Wrapped height should be a whole multiple of the line height.")

    // A generous width keeps it a single line (same height as unwrapped).
    let wide = backend.measureText(text, font: font, wrappingAt: 4000)
    expect(abs(wide.height - single.height) < 0.01, "Text fitting the wrap width should stay one line.")

    // A non-positive wrap width falls back to single-line measurement.
    let zero = backend.measureText(text, font: font, wrappingAt: 0)
    expect(abs(zero.width - single.width) < 0.01 && abs(zero.height - single.height) < 0.01,
           "A non-positive wrap width should measure as a single line.")
}

@MainActor
func testFireDueTimersPumpsScheduledTimers() {
    let backend = InMemoryNativeControlBackend()
    var firedA = 0
    var firedB = 0
    let idA = backend.scheduleNativeTimer(intervalMilliseconds: 16) { firedA += 1 }
    _ = backend.scheduleNativeTimer(intervalMilliseconds: 32) { firedB += 1 }

    // fireTimer pumps one specific scheduled timer (the coalesced-path hook).
    backend.fireTimer(idA)
    expect(firedA == 1 && firedB == 0, "fireTimer should fire only the named timer.")

    // fireDueTimers pumps every scheduled timer once (a whole tick).
    backend.fireDueTimers()
    expect(firedA == 2 && firedB == 1, "fireDueTimers should fire every scheduled timer once.")
}

@MainActor
func testControlFontAppliesToButtons() {
    // AppKit declares `font` on NSControl, so buttons take it — set before
    // realization it applies at realize; set after, it applies immediately.
    let backend = InMemoryNativeControlBackend()
    let button = NSButton(title: "Bold", frame: NSMakeRect(0, 0, 80, 24))
    button.font = NSFont.boldSystemFont(ofSize: 16)
    let handle = button.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[handle]?.font == NSFont.boldSystemFont(ofSize: 16),
           "A pre-realize control font should apply at realize.")

    button.font = NSFont.systemFont(ofSize: 11)
    expect(backend.records[handle]?.font == NSFont.systemFont(ofSize: 11),
           "A post-realize control font should apply immediately.")
}

@MainActor
func testStringEncodingIORoundTrips() {
    #if os(Windows)
    let sample = "Héllo, 世界 – ¡ok!"

    // UTF-8 round trip; invalid UTF-8 fails to decode.
    guard let utf8 = sample.data(using: .utf8) else {
        fatalError("UTF-8 encoding failed.")
    }
    expect(String(data: utf8, encoding: .utf8) == sample, "UTF-8 did not round-trip.")
    expect(String(data: Data([0xC3, 0x28]), encoding: .utf8) == nil,
           "Invalid UTF-8 bytes should fail to decode.")

    // .utf16 writes a little-endian BOM and round-trips; the explicit
    // endian variants round-trip without one.
    guard let utf16 = sample.data(using: .utf16) else {
        fatalError("UTF-16 encoding failed.")
    }
    expect(Array(utf16.array.prefix(2)) == [0xFF, 0xFE], "UTF-16 should lead with the LE BOM.")
    expect(String(data: utf16, encoding: .utf16) == sample, "UTF-16 did not round-trip.")
    guard let utf16be = sample.data(using: .utf16BigEndian) else {
        fatalError("UTF-16BE encoding failed.")
    }
    expect(String(data: utf16be, encoding: .utf16BigEndian) == sample,
           "UTF-16BE did not round-trip.")

    // ASCII is strict; lossy conversion substitutes '?'.
    expect(sample.data(using: .ascii) == nil, "Accented text should not encode as strict ASCII.")
    expect("é!".data(using: .ascii, allowLossyConversion: true)?.array == [UInt8(ascii: "?"), UInt8(ascii: "!")],
           "Lossy ASCII should substitute '?'.")

    // Latin-1 is one byte per character across its repertoire.
    guard let latin = "café".data(using: .isoLatin1) else {
        fatalError("Latin-1 encoding failed.")
    }
    expect(latin.count == 4 && String(data: latin, encoding: .isoLatin1) == "café",
           "Latin-1 did not round-trip.")

    // File round trip, including BOM detection on the encoding-less read.
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("winchocolate-stringio-test.txt")
    do {
        try sample.write(to: url, atomically: true, encoding: .utf16)
        let sniffed = try String(contentsOf: url)
        expect(sniffed == sample, "The BOM-sniffing read did not recover the UTF-16 file.")
        try sample.write(to: url, atomically: false, encoding: .utf8)
        let reread = try String(contentsOf: url, encoding: .utf8)
        expect(reread == sample, "The UTF-8 file round trip failed.")
    } catch {
        fatalError("String file I/O threw: \(error)")
    }
    try? FileManager.default.removeItem(atPath: url.path)
    #endif
}

@MainActor
func testAppearanceResolvesSystemThemeAndOverrides() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    // Drop the suite's light pin so the system-follow path is exercised
    // against the scriptable backend; restore the pin on the way out.
    NSApplication.shared.appearance = nil
    defer {
        NSApplication.shared.nativeBackend = previousBackend
        NSApplication.shared.appearance = NSAppearance(named: .aqua)
    }

    // Standard names resolve to shared appearance objects; unknown names fail.
    expect(NSAppearance(named: .aqua)?.name == .aqua, "The aqua appearance should resolve.")
    expect(NSAppearance(named: .darkAqua)?.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua, "darkAqua should report as dark.")
    expect(NSAppearance(named: NSAppearance.Name("NSAppearanceNameNeon")) == nil,
           "An unknown appearance name should not resolve.")

    // With no overrides the effective appearance follows the system theme.
    expect(NSApplication.shared.effectiveAppearance.name == .aqua,
           "A light system theme should resolve to aqua.")
    backend.simulatedDarkAppearance = true
    expect(NSApplication.shared.effectiveAppearance.name == .darkAqua,
           "A dark system theme should resolve to darkAqua.")

    // The chain flows app → view for an unattached view...
    let view = NSView(frame: NSMakeRect(0, 0, 10, 10))
    expect(view.effectiveAppearance.name == .darkAqua,
           "A view should inherit the application's effective appearance.")

    // ...an application override beats the system theme...
    NSApplication.shared.appearance = NSAppearance(named: .aqua)
    expect(view.effectiveAppearance.name == .aqua,
           "The application appearance override should win over the system theme.")

    // ...and a view override wins and flows down to its subviews.
    view.appearance = NSAppearance(named: .darkAqua)
    let child = NSView(frame: NSMakeRect(0, 0, 5, 5))
    view.addSubview(child)
    expect(child.effectiveAppearance.name == .darkAqua,
           "A subview should inherit its ancestor's appearance override.")

    // bestMatch: exact name first, dark falls back to the light base.
    expect(NSAppearance(named: .darkAqua)?.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua,
           "bestMatch should prefer the exact name.")
    expect(NSAppearance(named: .darkAqua)?.bestMatch(from: [.aqua]) == .aqua,
           "bestMatch should fall dark back to the light base.")
}

@MainActor
func testDrawnTableModernPresentationRestylesHeaderChrome() {
    // Renders a one-column drawn table and returns the header chrome the draw
    // pass recorded: the header slab's fill color and the title's font weight.
    func headerChrome() -> (fill: NSColor?, titleWeight: Int?) {
        let backend = InMemoryNativeControlBackend()
        let tableView = NSTableView(frame: NSMakeRect(0, 0, 200, 100))
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("a"))
        column.title = "Alpha"
        column.width = 80
        tableView.addTableColumn(column)
        let dataSource = ManyRowTableDataSource(count: 1)
        tableView.dataSource = dataSource
        tableView.winUsesViewBasedCells = true
        let handle = tableView.realizeNativePeer(in: backend, parent: nil)
        let recording = backend.performDraw(for: handle, in: tableView.bounds)
        // Draw order: full-bounds background first, then (no row highlights for
        // a single unselected row) the header slab.
        let headerFill = recording.fills.count > 1 ? recording.fills[1].color : nil
        let title = recording.texts.first { $0.text == "Alpha" }
        return (headerFill, title?.weight)
    }

    // Classic: the native-look gray header slab with a bold title.
    let classic = headerChrome()
    expect(classic.fill == NSColor(white: 0.93, alpha: 1),
           "The classic drawn header should paint the gray slab.")
    expect(classic.titleWeight == NSFont.Weight.bold.rawValue,
           "The classic drawn header title should be bold.")

    // Modern: a flat header on the body background with a regular-weight title
    // (the themed Windows list-view look).
    WinPresentation.selected = .modern
    defer { WinPresentation.selected = .classic }
    let modern = headerChrome()
    expect(modern.fill == .white,
           "The modern drawn header should be flat on the body background.")
    expect(modern.titleWeight == NSFont.Weight.regular.rawValue,
           "The modern drawn header title should be regular weight.")
}

@MainActor
func testToolbarOverflowCollapsesLowPriorityItems() {
    func makeToolbar() -> NSToolbar {
        let toolbar = NSToolbar(identifier: "overflow")
        for name in ["alpha", "beta", "gamma", "delta"] {
            let item = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier(rawValue: name))
            item.label = name
            toolbar.addItem(item)
        }
        toolbar.item(withIdentifier: NSToolbarItem.Identifier("beta"))?.visibilityPriority = .low
        return toolbar
    }

    // Narrow strip: the low-priority item collapses into the overflow menu first.
    let narrowView = NSToolbarView(frame: NSMakeRect(0, 0, 150, 36))
    let narrowToolbar = makeToolbar()
    narrowView.toolbar = narrowToolbar
    let visible = narrowToolbar.visibleItems?.map(\.itemIdentifier.rawValue) ?? []
    expect(!visible.contains("beta"),
           "The low-priority item did not overflow first. Visible: \(visible).")
    expect(visible.count < 4, "A 150pt strip should not fit all four items.")

    // Wide strip: everything fits, nothing overflows.
    let wideView = NSToolbarView(frame: NSMakeRect(0, 0, 600, 36))
    let wideToolbar = makeToolbar()
    wideView.toolbar = wideToolbar
    expect(wideToolbar.visibleItems?.count == 4,
           "A wide strip overflowed items it could fit. Visible: \(wideToolbar.visibleItems?.count ?? -1).")
}

@MainActor
func testWindowToolbarCreatesDockedComposedHostAndReservesContent() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(20, 30, 320, 220),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 320, 220))
    let toolbar = NSToolbar(identifier: "windowToolbar")
    let item = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("open"))

    item.label = "Open"
    toolbar.addItem(item)
    window.toolbar = toolbar
    window.contentView = contentView

    let windowHandle = window.realizeNativePeer()
    let toolbarRecords = backend.records.filter { $0.value.kind == "view" && $0.value.parent == windowHandle && $0.value.frame == NSMakeRect(0, 0, 320, 40) }

    expect(toolbarRecords.count == 1, "Window toolbar did not create exactly one composed toolbar host view.")
    guard let toolbarRecord = toolbarRecords.first else {
        return
    }

    expect(toolbarRecord.value.toolbarItems.isEmpty, "Composed toolbar host should not pass item descriptors to a native toolbar peer.")
    expect(
        backend.records.contains { $0.value.text.hasPrefix("__WinChocolateToolbarItem\tOpen") },
        "Window toolbar did not compose a label for the toolbar item."
    )
    expect(window.contentLayoutRect == NSMakeRect(0, 40, 320, 180), "Window toolbar did not reserve layout space.")
    expect(contentView.frame == NSMakeRect(0, 40, 320, 180), "Content view did not move below the toolbar strip.")

    item.label = "Open File"

    expect(
        backend.records.contains { $0.value.text.hasPrefix("__WinChocolateToolbarItem\tOpen File") },
        "Toolbar item label changes did not refresh the window-owned toolbar."
    )
}

