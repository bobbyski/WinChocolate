import WinChocolate

@MainActor
func testAlertAccessoryViewJoinsComposedPanel() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
        clearApplicationWindows()
    }

    let alert = NSAlert()
    alert.messageText = "Accessory host"
    alert.addButton(withTitle: "OK")
    let accessory = RealizationRecordingView(frame: NSMakeRect(0, 0, 200, 30))
    alert.accessoryView = accessory
    backend.nextModalResponseCode = NSApplication.ModalResponse.alertFirstButtonReturn.rawValue

    let response = alert.runModal()

    expect(response == .alertFirstButtonReturn, "Accessory alert did not return the scripted button response.")
    expect(backend.modalSessions.count == 1, "Accessory alert did not run exactly one modal session.")
    // The panel and its content view deallocate when runModal returns, so the
    // weak superview link cannot be asserted here; realization proves the
    // accessory joined the composed panel hierarchy.
    expect(accessory.didRealize, "Accessory view was never realized into the composed panel.")
    expect(accessory.frame.origin.x == 80, "Accessory view was not indented to the alert text column.")
}

final class RecordingMenuValidator: NSMenuItemValidation {
    var allowed = false
    var validatedTitles: [String] = []

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        validatedTitles.append(menuItem.title)
        return allowed
    }
}

@MainActor
func testSavePanelSheetPassesAnchorFrame() {
    clearApplicationWindows()

    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
        clearApplicationWindows()
    }

    let parent = NSWindow(
        contentRect: NSMakeRect(120, 80, 700, 500),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let panel = NSSavePanel.savePanel()
    backend.scriptedFileDialogPaths = [["C:\\Temp\\anchored.txt"]]

    var received: NSApplication.ModalResponse?
    panel.beginSheetModal(for: parent) { response in
        received = response
    }

    expect(received == .OK, "Sheet save panel did not deliver the response.")
    expect(backend.fileDialogRequests.last?.anchorFrame == parent.frame, "Sheet presentation did not pass the parent frame as the dialog anchor.")

    backend.scriptedFileDialogPaths = [["C:\\Temp\\plain.txt"]]
    _ = panel.runModal()
    expect(backend.fileDialogRequests.last?.anchorFrame == nil, "Plain runModal should not anchor the dialog.")
}

@MainActor
func testMenuUpdateRunsValidationAndAutoenables() {
    let menu = NSMenu(title: "Edit")
    let validator = RecordingMenuValidator()

    let validated = NSMenuItem(title: "Paste", action: nil, keyEquivalent: "")
    validated.target = validator
    validated.isEnabled = true
    menu.addItem(validated)

    let actionless = NSMenuItem(title: "Broken", action: nil, keyEquivalent: "")
    menu.addItem(actionless)

    let wired = NSMenuItem(title: "Copy", action: nil, keyEquivalent: "")
    wired.onAction = { _ in }
    menu.addItem(wired)

    menu.update()

    expect(validator.validatedTitles == ["Paste"], "Menu update did not consult the item's validation target.")
    expect(validated.isEnabled == false, "Menu update did not apply the validator's refusal.")
    expect(actionless.isEnabled == false, "Autoenable did not disable an item with no action.")
    expect(wired.isEnabled == true, "Autoenable disabled an item with an action.")

    validator.allowed = true
    menu.update()
    expect(validated.isEnabled == true, "Menu update did not re-enable after validation allowed it.")

    menu.autoenablesItems = false
    validated.isEnabled = false
    menu.update()
    expect(validated.isEnabled == false, "Manual enablement was overridden with autoenablesItems off.")
}

@MainActor
func testStringSizeUsesBackendTextMetrics() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
    }

    let size = "Hello".size(withAttributes: [.font: NSFont.boldSystemFont(ofSize: 20)])
    expect(size.width == 5 * 20 * 0.55, "String measurement did not route through the backend metrics.")
    expect(size.height == 20 * 1.35, "String measurement height did not route through the backend metrics.")
}

@MainActor
func testWindowSheetPositionsRunsModalAndEndsWithCode() {
    clearApplicationWindows()

    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
        clearApplicationWindows()
    }

    let parent = NSWindow(
        contentRect: NSMakeRect(100, 100, 600, 400),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let sheet = NSWindow(
        contentRect: NSMakeRect(0, 0, 300, 150),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )

    backend.nextModalResponseCode = NSApplication.ModalResponse.OK.rawValue
    var received: NSApplication.ModalResponse?
    parent.beginSheet(sheet) { response in
        received = response
    }

    expect(received == .OK, "Sheet completion handler did not receive the modal response.")
    expect(sheet.frame.origin.x == 250, "Sheet was not centered on the parent window.")
    expect(sheet.frame.origin.y == 156, "Sheet was not positioned under the parent title area.")
    expect(backend.modalSessions.contains(sheet.nativeHandle ?? NativeHandle(rawValue: 0)), "Sheet did not run a modal session.")

    parent.endSheet(sheet, returnCode: .cancel)
    expect(backend.modalStopCodes.last == NSApplication.ModalResponse.cancel.rawValue, "endSheet did not forward its return code.")
    expect(sheet.nativeHandle == nil, "endSheet did not close the sheet window.")
}

@MainActor
func testAlertBeginSheetModalDeliversResponse() {
    clearApplicationWindows()

    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
        clearApplicationWindows()
    }

    let parent = NSWindow(
        contentRect: NSMakeRect(50, 50, 500, 300),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let alert = NSAlert()
    alert.messageText = "Sheet?"
    alert.addButton(withTitle: "Yes")
    alert.addButton(withTitle: "No")
    backend.nextModalResponseCode = NSApplication.ModalResponse.alertSecondButtonReturn.rawValue

    var received: NSApplication.ModalResponse?
    alert.beginSheetModal(for: parent) { response in
        received = response
    }

    expect(received == .alertSecondButtonReturn, "Alert sheet did not deliver the scripted response.")
    expect(backend.modalSessions.count == 1, "Alert sheet did not run a modal session.")
}

@MainActor
func testSourceCompatGeometrySurface() {
    // Geometry: CoreGraphics aliases and Swift-idiomatic rect members.
    let rect: CGRect = CGRect(x: 10, y: 20, width: 100, height: 40)
    expect(rect.midX == 60 && rect.midY == 40, "CGRect midX/midY computed properties are wrong.")
    expect(rect.insetBy(dx: 10, dy: 5) == NSRect(x: 20, y: 25, width: 80, height: 30), "insetBy(dx:dy:) is wrong.")
    expect(rect.offsetBy(dx: 5, dy: -5) == NSRect(x: 15, y: 15, width: 100, height: 40), "offsetBy(dx:dy:) is wrong.")
    expect(rect.contains(CGPoint(x: 15, y: 25)), "contains(point) missed an interior point.")
    expect(!rect.contains(CGPoint(x: 200, y: 25)), "contains(point) accepted an exterior point.")
    let a = NSRect(x: 0, y: 0, width: 50, height: 50)
    let b = NSRect(x: 25, y: 25, width: 50, height: 50)
    expect(a.intersects(b) && NSIntersectsRect(a, b), "intersects/NSIntersectsRect failed on overlapping rects.")
    expect(a.intersection(b) == NSRect(x: 25, y: 25, width: 25, height: 25), "intersection produced the wrong overlap.")
    expect(NSUnionRect(a, b) == NSRect(x: 0, y: 0, width: 75, height: 75), "NSUnionRect produced the wrong bounds.")
    expect(NSContainsRect(a, NSRect(x: 10, y: 10, width: 5, height: 5)), "NSContainsRect missed a contained rect.")
    var slice = NSZeroRect, remainder = NSZeroRect
    NSDivideRect(NSRect(x: 0, y: 0, width: 100, height: 100), &slice, &remainder, 30, .minX)
    expect(slice == NSRect(x: 0, y: 0, width: 30, height: 100), "NSDivideRect slice is wrong.")
    expect(remainder == NSRect(x: 30, y: 0, width: 70, height: 100), "NSDivideRect remainder is wrong.")
    let insets = NSEdgeInsets(top: 1, left: 2, bottom: 3, right: 4)
    expect(insets.top == 1 && insets.left == 2 && insets.bottom == 3 && insets.right == 4, "NSEdgeInsetsMake stored the wrong sides.")
    expect(CGRect.zero == NSZeroRect && CGPoint.zero == NSZeroPoint, "CoreGraphics .zero constants disagree with NSZero*.")
}

@MainActor
func testSourceCompatColorFontImageViewSurface() {
    // Color: constructors, derived colors, component readback, system palette.
    let gray = NSColor(white: 0.5, alpha: 1)
    expect(gray.redComponent == 0.5 && gray.greenComponent == 0.5 && gray.blueComponent == 0.5, "NSColor(white:alpha:) did not fill RGB evenly.")
    expect(NSColor.red.withAlphaComponent(0.25).alphaComponent == 0.25, "withAlphaComponent did not set alpha.")
    let blend = NSColor.black.blended(withFraction: 0.5, of: .white)
    expect(blend?.redComponent == 0.5, "blended(withFraction:of:) did not mix halfway.")
    let hsb = NSColor(hue: 0, saturation: 1, brightness: 1, alpha: 1)
    expect(hsb.redComponent == 1 && hsb.greenComponent == 0 && hsb.blueComponent == 0, "HSB hue 0 did not resolve to red.")
    var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0, al: CGFloat = 0
    NSColor.systemBlue.getRed(&r, green: &g, blue: &bl, alpha: &al)
    expect(bl == 1 && al == 1, "getRed(_:green:blue:alpha:) did not read systemBlue back.")
    expect(NSColor.linkColor == NSColor.systemBlue, "linkColor should alias systemBlue.")

    // Font: named factories, sizes, family accessor.
    expect(NSFont.systemFontSize == 13 && NSFont.smallSystemFontSize == 11, "System font sizes changed unexpectedly.")
    expect(NSFont.monospacedSystemFont(ofSize: 12, weight: .regular).fontName == "Consolas", "monospacedSystemFont did not pick a fixed-pitch face.")
    expect(NSFont.labelFont(ofSize: 11).familyName == "Segoe UI", "labelFont familyName is wrong.")

    // Image: size, template flag, naming.
    let image = NSImage(size: NSSize(width: 32, height: 24))
    expect(image.size == NSSize(width: 32, height: 24), "NSImage(size:) did not store the size.")
    image.isTemplate = true
    expect(image.isTemplate, "NSImage.isTemplate did not round-trip.")
    expect(image.setName("badge") && image.name == "badge", "NSImage.setName did not accept and store the name.")

    // View: frame setters, coordinate flags, identity, hit testing, intrinsic size.
    let view = NSView(frame: NSRect(x: 0, y: 0, width: 10, height: 10))
    view.setFrameOrigin(NSPoint(x: 5, y: 6))
    view.setFrameSize(NSSize(width: 20, height: 30))
    expect(view.frame == NSRect(x: 5, y: 6, width: 20, height: 30), "setFrameOrigin/setFrameSize did not update the frame.")
    expect(view.isFlipped, "WinChocolate views should report a flipped (top-left) coordinate system.")
    view.identifier = NSUserInterfaceItemIdentifier("canvas")
    expect(view.identifier?.rawValue == "canvas", "NSView.identifier did not round-trip.")
    view.alphaValue = 0.4
    expect(view.alphaValue == 0.4, "NSView.alphaValue did not round-trip.")
    expect(view.mouse(NSPoint(x: 5, y: 5), in: view.bounds), "mouse(_:in:) missed a point in bounds.")
    expect(view.intrinsicContentSize.width == NSView.noIntrinsicMetric, "Base view should report no intrinsic width.")

    // Control: highlight flag and default sizeThatFits.
    let control = NSControl(frame: NSRect(x: 0, y: 0, width: 44, height: 22))
    control.isHighlighted = true
    expect(control.isHighlighted, "NSControl.isHighlighted did not round-trip.")
    expect(control.sizeThatFits(NSSize(width: 999, height: 999)) == control.frame.size, "Default sizeThatFits should return the frame size.")

    // Event: legacy delta aliases.
    let scroll = NSEvent(type: .scrollWheel, locationInWindow: NSZeroPoint, scrollingDeltaX: 3, scrollingDeltaY: -7)
    expect(scroll.deltaX == 3 && scroll.deltaY == -7, "NSEvent deltaX/deltaY did not alias the scrolling deltas.")
}

@MainActor
func testSourceCompatSurfaceGeometryColorFontImageView() {
    testSourceCompatGeometrySurface()
    testSourceCompatColorFontImageViewSurface()
}

@MainActor
func testAlertButtonsCarryTagsKeyEquivalentsAndErrorInit() {
    // Buttons array holds the real button objects with AppKit response tags and
    // default key equivalents.
    let alert = NSAlert()
    alert.messageText = "Discard changes?"
    let discard = alert.addButton(withTitle: "Discard")
    let cancel = alert.addButton(withTitle: "Cancel")
    expect(alert.buttons.count == 2, "NSAlert.buttons did not retain the added buttons.")
    expect(alert.buttons[0] === discard && alert.buttons[1] === cancel, "NSAlert.buttons is not the objects addButton returned.")
    expect(discard.tag == NSApplication.ModalResponse.alertFirstButtonReturn.rawValue, "First alert button did not get the alertFirstButtonReturn tag.")
    expect(cancel.tag == NSApplication.ModalResponse.alertSecondButtonReturn.rawValue, "Second alert button did not get the incrementing response tag.")
    expect(discard.keyEquivalent == "\r", "The default alert button should respond to Return.")
    expect(cancel.keyEquivalent == "\u{1b}", "A Cancel alert button should respond to Escape.")
    expect(alert.buttonTitles == ["Discard", "Cancel"], "buttonTitles drifted from the added buttons.")

    // NSAlert(error:) reads the error's localized strings and adds one OK button.
    let error = NSError(domain: "WinChocolate.Test", code: 42, userInfo: [
        NSLocalizedDescriptionKey: "Could not open the file.",
        NSLocalizedFailureReasonErrorKey: "The file is locked."
    ])
    let errorAlert = NSAlert(error: error)
    expect(errorAlert.messageText == "Could not open the file.", "NSAlert(error:) did not use the error's localized description.")
    expect(errorAlert.informativeText == "The file is locked.", "NSAlert(error:) did not use the error's failure reason.")
    expect(errorAlert.buttons.count == 1 && errorAlert.buttons[0].title == "OK", "NSAlert(error:) did not add a single OK button.")

    // A buttonless alert forced onto the composed panel (here, by a suppression
    // checkbox) synthesizes a default OK so it can be dismissed.
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
        clearApplicationWindows()
    }
    let suppressible = NSAlert()
    suppressible.messageText = "Heads up"
    suppressible.showsSuppressionButton = true
    backend.nextModalResponseCode = NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
    _ = suppressible.runModal()
    expect(suppressible.buttons.count == 1 && suppressible.buttons[0].title == "OK", "Buttonless composed alert did not synthesize a default OK button.")
}

@MainActor
func testColorPanelHSBModeAndAlpha() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
        clearApplicationWindows()
    }

    let panel = NSColorPanel(nativeBackend: backend)
    panel.makeKeyAndOrderFront(nil)

    expect(panel.mode == .RGB, "Color panel did not default to RGB mode.")
    expect(panel.alpha == 1, "Alpha should be 1 while the opacity slider is hidden.")

    // Switch to HSB and drive the H/S/B sliders to pure red (H=0, S=100, B=100).
    panel.mode = .HSB
    var sliderHandles = backend.records.filter { $0.value.kind == "slider" }.keys.sorted { $0.rawValue < $1.rawValue }
    expect(sliderHandles.count == 3, "HSB mode should still show three component sliders.")
    backend.setSliderValue(0, for: sliderHandles[0]); backend.actions[sliderHandles[0]]?()
    backend.setSliderValue(100, for: sliderHandles[1]); backend.actions[sliderHandles[1]]?()
    backend.setSliderValue(100, for: sliderHandles[2]); backend.actions[sliderHandles[2]]?()
    expect(panel.color == NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 1), "HSB sliders did not recompose pure red.")

    // Enabling alpha adds a fourth slider that drives the color's opacity.
    panel.showsAlpha = true
    sliderHandles = backend.records.filter { $0.value.kind == "slider" }.keys.sorted { $0.rawValue < $1.rawValue }
    expect(sliderHandles.count == 4, "Enabling showsAlpha did not add an opacity slider.")
    backend.setSliderValue(50, for: sliderHandles[3]); backend.actions[sliderHandles[3]]?()
    expect(abs(panel.color.alphaComponent - 0.5) < 0.001, "The opacity slider did not set the color's alpha.")
    expect(abs(panel.alpha - 0.5) < 0.001, "panel.alpha did not reflect the opacity slider.")

    // Switching back to RGB relabels/rescales without losing the color.
    panel.mode = .RGB
    expect(panel.mode == .RGB, "Color panel did not switch back to RGB mode.")
    expect(abs(panel.color.redComponent - 1) < 0.001 && panel.color.greenComponent < 0.001, "Mode switch back to RGB lost the selected color.")
}

@MainActor
func testSpinningIndicatorUsesCustomViewAndTimerSweep() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
    }

    let spinner = NSProgressIndicator(frame: NSMakeRect(0, 0, 32, 32))
    spinner.style = .spinning
    let handle = spinner.realizeNativePeer(in: backend, parent: nil)

    // A creation-time spinning style realizes the framework-drawn view peer,
    // not a native progress bar.
    expect(backend.records[handle]?.kind == "view", "Spinning indicator did not realize a custom view peer.")

    // Starting the animation schedules the sweep timer; each tick advances the
    // phase and invalidates the view.
    spinner.startAnimation(nil)
    expect(backend.scheduledTimers.count == 1, "startAnimation did not schedule the spinner sweep timer.")
    if let timer = backend.scheduledTimers.first {
        spinner.needsDisplay = false
        backend.fireTimer(timer.identifier)
        expect(spinner.needsDisplay, "A spinner timer tick did not invalidate the view.")

        // Stopping cancels the timer.
        spinner.stopAnimation(nil)
        expect(backend.canceledTimerIdentifiers.contains(timer.identifier), "stopAnimation did not cancel the sweep timer.")
    }

    // A bar-style indicator keeps the native progress peer (regression guard).
    let bar = NSProgressIndicator(frame: NSMakeRect(0, 0, 120, 18))
    let barHandle = bar.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[barHandle]?.kind == "progressIndicator", "Bar indicator no longer realizes a native progress peer.")
}

final class TemplateImageDrawingTestView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let template = NSImage(contentsOfFile: "C:\\Art\\gear.png")
        template?.isTemplate = true
        NSColor.systemBlue.setFill()
        template?.draw(in: NSMakeRect(0, 0, 24, 24))

        NSImage(contentsOfFile: "C:\\Art\\photo.png")?.draw(in: NSMakeRect(0, 30, 24, 24))
    }
}

@MainActor
func testTemplateImagesTintInDrawAndImageView() {
    let backend = InMemoryNativeControlBackend()

    // Custom drawing: a template image carries the current fill color as its
    // tint; a plain image carries none.
    let view = TemplateImageDrawingTestView(frame: NSMakeRect(0, 0, 60, 60))
    let handle = view.realizeNativePeer(in: backend, parent: nil)
    let recording = backend.performDraw(for: handle, in: NSMakeRect(0, 0, 60, 60))
    expect(recording.images.count == 2, "Draw pass did not record both image commands.")
    expect(recording.images.first?.tint == NSColor.systemBlue, "Template image draw did not carry the fill-color tint.")
    expect(recording.images.last?.tint == nil, "Plain image draw should carry no tint.")

    // Image view: a template image bakes the content tint into the native
    // image; swapping to a non-template image clears it.
    guard let gear = NSImage(contentsOfFile: "C:\\Art\\gear.png") else {
        expect(false, "Test image failed to construct.")
        return
    }
    gear.isTemplate = true
    let imageView = NSImageView(image: gear)
    imageView.contentTintColor = .systemRed
    let imageViewHandle = imageView.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[imageViewHandle]?.imageTint == NSColor.systemRed, "Template image view did not push its content tint to the backend.")

    imageView.image = NSImage(contentsOfFile: "C:\\Art\\photo.png")
    expect(backend.records[imageViewHandle]?.imageTint == nil, "Non-template image should not be tinted.")
}

@MainActor
func testParagraphStyleAlignmentAndRTFRoundTrip() {
    // Paragraph styles: mutable copy semantics and value equality.
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineSpacing = 4
    expect(paragraph.alignment == .center && paragraph.lineSpacing == 4, "NSMutableParagraphStyle did not store its properties.")
    expect(NSParagraphStyle.default.alignment == .natural, "Default paragraph style should be naturally aligned.")

    // Build a rich string: bold red centered headline + plain body with unicode.
    let content = NSMutableAttributedString(string: "")
    content.append(NSAttributedString(string: "Headline\n", attributes: [
        .font: NSFont.boldSystemFont(ofSize: 16),
        .foregroundColor: NSColor.red,
        .paragraphStyle: paragraph,
    ]))
    content.append(NSAttributedString(string: "Body Grüße", attributes: [
        .underlineStyle: NSUnderlineStyle.single.rawValue,
    ]))

    // Write RTF and read it back.
    guard let rtfData = content.rtf(from: NSMakeRange(0, content.length)) else {
        expect(false, "RTF writer produced no data.")
        return
    }
    let rtfString = String(decoding: rtfData, as: UTF8.self)
    expect(rtfString.contains("\\qc"), "RTF writer did not emit the center-alignment control.")

    guard let readBack = NSAttributedString(rtf: rtfData) else {
        expect(false, "RTF reader failed on the writer's own output.")
        return
    }
    expect(readBack.string == "Headline\nBody Grüße", "RTF round-trip changed the text. Got: \(readBack.string)")

    let headlineAttributes = readBack.attributes(at: 0, effectiveRange: nil)
    let headlineFont = headlineAttributes[.font] as? NSFont
    expect(headlineFont?.weight.isBold == true, "RTF round-trip lost the bold trait.")
    expect(headlineFont?.pointSize == 16, "RTF round-trip lost the font size.")
    expect((headlineAttributes[.foregroundColor] as? NSColor) == NSColor.red, "RTF round-trip lost the color.")
    expect((headlineAttributes[.paragraphStyle] as? NSParagraphStyle)?.alignment == .center, "RTF round-trip lost the paragraph alignment.")

    let bodyAttributes = readBack.attributes(at: readBack.length - 1, effectiveRange: nil)
    expect((bodyAttributes[.underlineStyle] as? Int) == NSUnderlineStyle.single.rawValue, "RTF round-trip lost the underline.")
    expect((bodyAttributes[.paragraphStyle] as? NSParagraphStyle) == nil, "Body should carry no paragraph style after \\pard-free left runs.")

    // Native alignment: setAlignment(_:range:) reaches the backend, and the
    // text-storage sync re-applies paragraph styles.
    let backend = InMemoryNativeControlBackend()
    let textView = NSTextView(frame: NSMakeRect(0, 0, 200, 100))
    textView.isRichText = true
    let handle = textView.realizeNativePeer(in: backend, parent: nil)
    textView.setAlignment(.center, range: NSMakeRange(0, 8))
    expect(backend.textRangeAlignments[handle.rawValue]?.last == InMemoryNativeControlBackend.TextRangeAlignment(alignment: .center, location: 0, length: 8), "setAlignment(_:range:) did not reach the backend.")

    textView.textStorage?.append(content)
    expect(backend.textRangeAlignments[handle.rawValue]?.last?.alignment == .center, "Text-storage sync did not re-apply the paragraph alignment.")
}

@MainActor
func testPasteboardObjectsAndFileURLs() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
    }

    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()

    // writeObjects with file URLs lands on the platform file list.
    #if os(Windows)
    let filePaths = ["C:\\Docs\\a.txt", "C:\\Docs\\b.txt"]
    #else
    let filePaths = ["/Docs/a.txt", "/Docs/b.txt"]
    #endif
    let urls = filePaths.map { URL(fileURLWithPath: $0) }
    expect(pasteboard.writeObjects(urls), "writeObjects rejected file URLs.")
    expect(backend.clipboardFileList == filePaths,
           "File URLs did not reach the clipboard file list. Got: \(backend.clipboardFileList)")
    expect(pasteboard.types?.contains(.fileURL) == true, "types did not report the file list as .fileURL.")

    // readObjects(forClasses: [NSURL.self]) returns the file URLs.
    let readURLs = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL]
    expect(readURLs?.count == 2, "readObjects did not return both file URLs.")
    expect(readURLs?.first?.isFileURL == true, "readObjects did not return file URLs.")

    // pasteboardItems: one item per file, each carrying a .fileURL string.
    let fileItems = pasteboard.pasteboardItems
    expect(fileItems?.count == 2, "pasteboardItems did not build one item per file.")
    expect(fileItems?.first?.types == [.fileURL], "File pasteboard item did not carry the .fileURL type.")

    // An attributed string writes text + RTF together; items group them.
    pasteboard.clearContents()
    let attributed = NSAttributedString(string: "Rich", attributes: [.font: NSFont.boldSystemFont(ofSize: 13)])
    expect(pasteboard.writeObjects([attributed]), "writeObjects rejected an attributed string.")
    expect(backend.clipboardText == "Rich", "Attributed write did not stage the plain text.")
    expect(backend.clipboardDataRepresentations["Rich Text Format"] != nil, "Attributed write did not stage RTF.")

    let items = pasteboard.pasteboardItems
    expect(items?.count == 1, "Text+RTF should form a single pasteboard item.")
    expect(items?.first?.string(forType: .string) == "Rich", "The pasteboard item did not carry the text.")
    expect(items?.first?.data(forType: .rtf) != nil, "The pasteboard item did not carry the RTF data.")

    // readObjects for attributed strings parses the staged RTF back.
    let readAttributed = pasteboard.readObjects(forClasses: [NSAttributedString.self])?.first as? NSAttributedString
    expect(readAttributed?.string == "Rich", "readObjects did not parse the RTF back into an attributed string.")
    expect((readAttributed?.attributes(at: 0, effectiveRange: nil)[.font] as? NSFont)?.weight.isBold == true, "Read-back attributed string lost the bold trait.")

    pasteboard.clearContents()
}

final class HoverRecordingView: NSView {
    var enteredCount = 0
    var exitedCount = 0

    override func mouseEntered(with event: NSEvent) {
        enteredCount += 1
    }

    override func mouseExited(with event: NSEvent) {
        exitedCount += 1
    }
}

