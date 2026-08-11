import WinChocolate

@MainActor
func testFontTraitsWeightsAndDescriptor() {
    // Italic and the extended weight scale round-trip through NSFont.
    let base = NSFont(name: "Georgia", size: 14, weight: .regular)
    expect(!base.italic && base.weight == .regular, "Default font carried unexpected traits.")
    expect(base.withItalic(true).italic, "withItalic did not set the italic trait.")
    expect(base.withWeight(.semibold).weight == .semibold, "withWeight did not change the weight.")
    expect(base.withWeight(.semibold).isBold, "Semibold did not report as bold.")
    expect(!base.withWeight(.light).isBold, "Light incorrectly reported as bold.")
    expect(NSFont.Weight.closest(toLogFontWeight: 620) == .semibold, "Closest weight mapping was wrong.")
    expect(NSFont.Weight.allCases.count == 9, "Weight scale is not the standard nine steps.")

    // Descriptor captures and reconstructs symbolic traits.
    let descriptor = NSFont(name: "Consolas", size: 12, weight: .bold, italic: true).fontDescriptor
    expect(descriptor.symbolicTraits.contains(.bold), "Descriptor dropped the bold trait.")
    expect(descriptor.symbolicTraits.contains(.italic), "Descriptor dropped the italic trait.")
    guard let rebuilt = NSFont(descriptor: descriptor, size: 0) else {
        expect(false, "NSFont(descriptor:size:) returned nil.")
        return
    }
    expect(rebuilt.fontName == "Consolas" && rebuilt.pointSize == 12, "Descriptor lost family or size.")
    expect(rebuilt.isBold && rebuilt.italic, "Descriptor did not rebuild the traits.")
    let plainDescriptor = NSFontDescriptor(name: "Arial", size: 10)
    let withItalic = plainDescriptor.withSymbolicTraits(.italic)
    expect(withItalic.symbolicTraits.contains(.italic), "withSymbolicTraits did not add the trait.")

    // NSFontManager trait conversion toggles bold and italic.
    let manager = NSFontManager.shared
    let bolded = manager.convert(base, toHaveTrait: .bold)
    expect(bolded.weight == .bold, "toHaveTrait: .bold did not bold the font.")
    let italicized = manager.convert(bolded, toHaveTrait: .italic)
    expect(italicized.italic && italicized.weight == .bold, "toHaveTrait: .italic dropped the existing bold.")
    let unbolded = manager.convert(italicized, toHaveTrait: .unbold)
    expect(unbolded.weight == .regular && unbolded.italic, ".unbold did not clear bold while keeping italic.")
    expect(manager.traits(of: italicized) == [.bold, .italic], "traits(of:) did not report both traits.")

    // Italic reaches the native rich-text peer as a character format.
    let backend = InMemoryNativeControlBackend()
    let textView = NSTextView(frame: NSMakeRect(0, 0, 200, 80))
    textView.isRichText = true
    textView.string = "styled"
    let handle = textView.realizeNativePeer(in: backend, parent: nil)
    textView.setFont(NSFont(name: "Georgia", size: 13, weight: .bold, italic: true), range: NSMakeRange(0, 6))
    let format = backend.records[handle]?.textRangeFormats.last
    expect(format?.font?.italic == true, "Italic font did not reach the native formatting.")
    expect(format?.font?.weight == .bold, "Bold-italic font lost its weight.")
}

@MainActor
func testMutableAttributedStringRunsAndEnumeration() {
    let text = NSMutableAttributedString(string: "Hello World")
    expect(text.length == 11, "Length did not count UTF-16 units.")
    expect(text.string == "Hello World", "String contents were lost.")

    // Attributes apply per range and report effective ranges.
    let boldFont = NSFont.boldSystemFont(ofSize: 14)
    text.addAttribute(.font, value: boldFont, range: NSMakeRange(0, 5))
    text.addAttribute(.foregroundColor, value: NSColor.red, range: NSMakeRange(6, 5))
    text.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSMakeRange(0, 11))

    var effective = NSRange(location: 0, length: 0)
    withUnsafeMutablePointer(to: &effective) { pointer in
        expect((text.attribute(.font, at: 2, effectiveRange: pointer) as? NSFont) == boldFont, "Font attribute did not read back.")
    }
    expect(effective == NSMakeRange(0, 5), "Effective range did not match the font run.")
    expect(text.attribute(.font, at: 8, effectiveRange: nil) == nil, "Font leaked past its range.")
    expect((text.attribute(.underlineStyle, at: 8, effectiveRange: nil) as? Int) == 1, "Underline did not cover the whole string.")

    // Enumeration walks the distinct runs in order.
    var enumeratedRanges: [NSRange] = []
    text.enumerateAttributes(in: NSMakeRange(0, text.length)) { _, range, _ in
        enumeratedRanges.append(range)
    }
    expect(enumeratedRanges == [NSMakeRange(0, 5), NSMakeRange(5, 1), NSMakeRange(6, 5)], "Enumeration did not yield the attribute runs.")

    // setAttributes replaces; removeAttribute deletes one key.
    text.setAttributes([.foregroundColor: NSColor.blue], range: NSMakeRange(0, 5))
    expect(text.attribute(.font, at: 2, effectiveRange: nil) == nil, "setAttributes kept a replaced attribute.")
    text.removeAttribute(.foregroundColor, range: NSMakeRange(0, 5))
    expect(text.attribute(.foregroundColor, at: 2, effectiveRange: nil) == nil, "removeAttribute left the attribute behind.")

    // Replacement text inherits the attributes at the replaced location.
    let styled = NSMutableAttributedString(string: "abc", attributes: [.foregroundColor: NSColor.green])
    styled.replaceCharacters(in: NSMakeRange(1, 1), with: "XY")
    expect(styled.string == "aXYc", "replaceCharacters mangled the text.")
    expect((styled.attribute(.foregroundColor, at: 1, effectiveRange: nil) as? NSColor) == .green, "Replacement did not inherit attributes.")

    // Append, insert, and delete keep runs consistent.
    styled.append(NSAttributedString(string: "!", attributes: [.foregroundColor: NSColor.red]))
    expect(styled.string == "aXYc!", "append lost text.")
    expect((styled.attribute(.foregroundColor, at: 4, effectiveRange: nil) as? NSColor) == .red, "append lost its attributes.")
    styled.insert(NSAttributedString(string: ">>"), at: 0)
    expect(styled.string == ">>aXYc!", "insert lost text.")
    styled.deleteCharacters(in: NSMakeRange(0, 2))
    expect(styled.string == "aXYc!", "deleteCharacters removed the wrong range.")

    // attributedSubstring carries the overlapping runs.
    let substring = styled.attributedSubstring(from: NSMakeRange(3, 2))
    expect(substring.string == "c!", "attributedSubstring took the wrong text.")
    expect((substring.attribute(.foregroundColor, at: 1, effectiveRange: nil) as? NSColor) == .red, "attributedSubstring dropped run attributes.")
}

@MainActor
func testTextStorageAppliesRunsToTextView() {
    let backend = InMemoryNativeControlBackend()
    let textView = NSTextView(frame: NSMakeRect(0, 0, 300, 100))
    textView.isRichText = true
    textView.string = "plain"
    let handle = textView.realizeNativePeer(in: backend, parent: nil)

    guard let storage = textView.textStorage else {
        expect(false, "Text view did not vend a text storage.")
        return
    }
    expect(storage.string == "plain", "Text storage was not seeded with the view's text.")

    // A batched edit applies once: new text plus its attribute runs.
    storage.beginEditing()
    storage.replaceCharacters(in: NSMakeRange(0, storage.length), with: "Styled note")
    storage.addAttribute(.font, value: NSFont(name: "Georgia", size: 16, weight: .bold), range: NSMakeRange(0, 6))
    storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSMakeRange(7, 4))
    storage.endEditing()

    expect(textView.string == "Styled note", "Storage edits did not update the view text.")
    let formats = backend.records[handle]?.textRangeFormats ?? []
    expect(formats.contains { $0.font?.fontName == "Georgia" && $0.location == 0 && $0.length == 6 }, "Font run did not reach the native peer.")
    expect(formats.contains { $0.underline == true && $0.location == 7 && $0.length == 4 }, "Underline run did not reach the native peer.")

    // Native edits sync the storage's plain text.
    backend.textChangeActions[handle]?("typed text")
    expect(storage.string == "typed text", "Native editing did not sync the text storage.")
}

@MainActor
func testRTFWriterEmitsTablesRunsAndEscapes() {
    let text = NSMutableAttributedString(string: "Bold red — ok")
    text.addAttribute(.font, value: NSFont(name: "Georgia", size: 14, weight: .bold), range: NSMakeRange(0, 4))
    text.addAttribute(.foregroundColor, value: NSColor.red, range: NSMakeRange(5, 3))
    text.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSMakeRange(11, 2))

    guard let data = text.rtf(from: NSMakeRange(0, text.length)) else {
        expect(false, "RTF writer returned nil.")
        return
    }
    let rtf = String(decoding: Array(data), as: UTF8.self)

    expect(rtf.hasPrefix("{\\rtf1\\ansi\\deff0"), "RTF header is missing.")
    expect(rtf.contains("Georgia;"), "Font table is missing the run font.")
    expect(rtf.contains("\\red255\\green0\\blue0;"), "Color table is missing the run color.")
    expect(rtf.contains("\\b Bold"), "Bold run controls are missing.")
    expect(rtf.contains("\\cf1 red"), "Color run controls are missing.")
    expect(rtf.contains("\\strike ok"), "Strikethrough run controls are missing.")
    expect(rtf.contains("\\u8212?"), "Non-ASCII characters were not escaped.")
    expect(rtf.hasSuffix("}"), "RTF is not closed.")

    // A rich text view copy stages RTF alongside the plain string.
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
    }

    let textView = NSTextView(frame: NSMakeRect(0, 0, 200, 80))
    textView.isRichText = true
    _ = textView.realizeNativePeer(in: backend, parent: nil)
    textView.textStorage?.replaceCharacters(in: NSMakeRange(0, 0), with: "Rich copy")
    textView.textStorage?.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 13), range: NSMakeRange(0, 4))
    textView.selectedRange = NSMakeRange(0, 9)
    textView.copy(nil)

    expect(NSPasteboard.general.string(forType: .string) == "Rich copy", "Rich copy did not stage the plain string.")
    expect(NSPasteboard.general.data(forType: .rtf) != nil, "Rich copy did not stage RTF data.")
}

@MainActor
func testPasteboardAndTextViewClipboardActions() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
    }

    // The general pasteboard reads and writes the backend clipboard.
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    expect(pasteboard.string(forType: .string) == nil, "Cleared pasteboard still returned a string.")
    expect(pasteboard.types == nil, "Cleared pasteboard still reported types.")

    let countBeforeWrite = pasteboard.changeCount
    expect(pasteboard.setString("Chocolate", forType: .string), "Writing a string was rejected.")
    expect(pasteboard.string(forType: .string) == "Chocolate", "Written string did not read back.")
    expect(pasteboard.types == [.string], "String type was not reported after writing.")
    expect(pasteboard.changeCount > countBeforeWrite, "Writing did not advance the change count.")
    expect(!pasteboard.setString("x", forType: NSPasteboard.PasteboardType(rawValue: "public.png")), "An unsupported type was accepted.")

    // declareTypes clears, matching the old AppKit contract.
    pasteboard.declareTypes([.string], owner: nil)
    expect(pasteboard.string(forType: .string) == nil, "declareTypes did not clear the pasteboard.")

    // One logical copy can stage several representations together.
    pasteboard.clearContents()
    let rtfBytes = Data(Array("{\\rtf1 Hi}".utf8))
    let pngBytes = Data([0x89, 0x50, 0x4e, 0x47])
    expect(pasteboard.setString("Hi", forType: .string), "Staged string write was rejected.")
    expect(pasteboard.setData(rtfBytes, forType: .rtf), "RTF data write was rejected.")
    expect(pasteboard.setData(pngBytes, forType: .png), "PNG data write was rejected.")
    expect(pasteboard.string(forType: .string) == "Hi", "Staged string was lost by later data writes.")
    expect(pasteboard.data(forType: .rtf) == rtfBytes, "RTF data did not read back.")
    expect(pasteboard.data(forType: .png) == pngBytes, "PNG data did not read back.")
    expect(pasteboard.types == [.string, .rtf, .png], "Combined representations were not all reported.")
    expect(pasteboard.data(forType: .string) == nil, "data(forType:) accepted the plain-text type.")

    // Clearing drops every staged representation.
    pasteboard.clearContents()
    expect(pasteboard.data(forType: .rtf) == nil, "clearContents left RTF data behind.")
    expect(pasteboard.types == nil, "clearContents left types behind.")

    testTextViewClipboardActions(backend: backend, pasteboard: pasteboard)
}

@MainActor
func testTextViewClipboardActions(backend: InMemoryNativeControlBackend, pasteboard: NSPasteboard) {
    // Text view copy/cut/paste run over the general pasteboard.
    let textView = NSTextView(frame: NSMakeRect(0, 0, 300, 100))
    textView.string = "Hello World"
    _ = textView.realizeNativePeer(in: backend, parent: nil)

    textView.selectedRange = NSMakeRange(0, 5)
    textView.copy(nil)
    expect(pasteboard.string(forType: .string) == "Hello", "Copy did not place the selection on the pasteboard.")
    expect(textView.string == "Hello World", "Copy changed the text.")

    textView.selectedRange = NSMakeRange(6, 5)
    textView.cut(nil)
    expect(pasteboard.string(forType: .string) == "World", "Cut did not place the selection on the pasteboard.")
    expect(textView.string == "Hello ", "Cut did not delete the selection.")

    textView.selectedRange = NSMakeRange(0, 0)
    textView.paste(nil)
    expect(textView.string == "WorldHello ", "Paste did not insert at the selection.")

    // Paste replaces a non-empty selection.
    textView.selectedRange = NSMakeRange(0, 5)
    textView.paste(nil)
    expect(textView.string == "WorldHello ", "Paste over a selection did not replace it.")

    // selectAll covers the whole text; read-only views refuse cut/paste.
    textView.selectAll(nil)
    expect(textView.selectedRange == NSMakeRange(0, textView.string.utf16.count), "selectAll did not select the whole text.")
    textView.isEditable = false
    textView.cut(nil)
    expect(textView.string == "WorldHello ", "Cut modified a read-only text view.")
}

@MainActor
func testRichTextViewAppliesRangeFormatting() {
    let backend = InMemoryNativeControlBackend()
    let manager = NSFontManager.shared
    defer {
        manager.selectedFont = nil
    }

    let textView = NSTextView(frame: NSMakeRect(0, 0, 300, 120))
    textView.isRichText = true
    textView.string = "Rich text attributes"
    let handle = textView.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.isRichText == true, "Rich text view did not request a rich-edit peer.")

    // Per-range font and color formatting reach the backend.
    let rangeFont = NSFont(name: "Georgia", size: 18, weight: .bold)
    textView.setFont(rangeFont, range: NSMakeRange(0, 4))
    textView.setTextColor(.red, range: NSMakeRange(5, 4))

    let formats = backend.records[handle]?.textRangeFormats ?? []
    expect(formats.count == 2, "Range formatting did not reach the backend.")
    expect(formats.first?.font == rangeFont, "Range font was not recorded.")
    expect(formats.first?.location == 0 && formats.first?.length == 4, "Font range was not recorded.")
    expect(formats.last?.color == .red, "Range color was not recorded.")
    expect(formats.last?.location == 5 && formats.last?.length == 4, "Color range was not recorded.")

    // changeFont converts the selection when one exists.
    manager.selectedFont = NSFont(name: "Consolas", size: 12, weight: .regular)
    textView.selectedRange = NSMakeRange(0, 9)
    textView.changeFont(nil)
    let selectionFormat = backend.records[handle]?.textRangeFormats.last
    expect(selectionFormat?.font?.fontName == "Consolas", "changeFont did not format the selected range.")
    expect(selectionFormat?.location == 0 && selectionFormat?.length == 9, "changeFont did not use the selection range.")
    expect(textView.font == nil, "Selection-scoped changeFont overwrote the whole-view font.")

    // Plain text views still convert the whole view's font.
    let plain = NSTextView(frame: NSMakeRect(0, 0, 100, 50))
    _ = plain.realizeNativePeer(in: backend, parent: nil)
    plain.changeFont(nil)
    expect(plain.font?.fontName == "Consolas", "Plain-text changeFont did not convert the view font.")
    expect(backend.records[handle]?.textRangeFormats.count == 3, "Plain-text changeFont leaked range formatting.")
}

@MainActor
func testScrollViewWheelScrollingMovesContent() {
    let backend = InMemoryNativeControlBackend()
    let scrollView = NSScrollView(frame: NSMakeRect(0, 0, 200, 100))
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = true
    scrollView.documentView = NSView(frame: NSMakeRect(0, 0, 600, 400))
    let handle = scrollView.realizeNativePeer(in: backend, parent: nil)

    // One wheel notch down scrolls three lines of the default line scroll.
    scrollView.scrollWheel(with: NSEvent(type: .scrollWheel, locationInWindow: NSMakePoint(10, 10), scrollingDeltaY: -1))
    expect(scrollView.contentView.boundsOrigin.y == 48, "Wheel notch did not scroll three default lines.")
    expect(backend.records[handle]?.scrollViewContentOffset.y == 48, "Wheel scroll did not sync the native scrollbar offset.")

    // Scrolling above the top clamps at zero.
    scrollView.scrollWheel(with: NSEvent(type: .scrollWheel, locationInWindow: NSMakePoint(10, 10), scrollingDeltaY: 5))
    expect(scrollView.contentView.boundsOrigin.y == 0, "Wheel scroll did not clamp at the document top.")

    // Shift converts a vertical wheel into horizontal scrolling.
    scrollView.scrollWheel(with: NSEvent(type: .scrollWheel, locationInWindow: NSMakePoint(10, 10), modifierFlags: [.shift], scrollingDeltaY: -1))
    expect(scrollView.contentView.boundsOrigin.x == 48, "Shift-wheel did not scroll horizontally.")
    expect(scrollView.contentView.boundsOrigin.y == 0, "Shift-wheel still scrolled vertically.")

    // Horizontal wheel deltas scroll horizontally on their own.
    scrollView.scrollWheel(with: NSEvent(type: .scrollWheel, locationInWindow: NSMakePoint(10, 10), scrollingDeltaX: -1))
    expect(scrollView.contentView.boundsOrigin.x == 96, "Horizontal wheel delta did not scroll horizontally.")

    // Line scroll distances are adjustable.
    scrollView.lineScroll = 8
    scrollView.scrollWheel(with: NSEvent(type: .scrollWheel, locationInWindow: NSMakePoint(10, 10), scrollingDeltaY: -1))
    expect(scrollView.contentView.boundsOrigin.y == 24, "Adjusted line scroll was not honored.")

    // A large scroll clamps at the document end.
    scrollView.scrollWheel(with: NSEvent(type: .scrollWheel, locationInWindow: NSMakePoint(10, 10), scrollingDeltaY: -100))
    expect(scrollView.contentView.boundsOrigin.y == 300, "Wheel scroll did not clamp at the document bottom.")
}

@MainActor
func testScrollViewMagnificationScalesGeometryAndDrawing() {
    let backend = InMemoryNativeControlBackend()
    let scrollView = NSScrollView(frame: NSMakeRect(0, 0, 200, 100))
    scrollView.hasVerticalScroller = true
    let document = NSView(frame: NSMakeRect(0, 0, 400, 300))
    scrollView.documentView = document
    let handle = scrollView.realizeNativePeer(in: backend, parent: nil)
    guard let documentHandle = document.nativeHandle else {
        expect(false, "Document view did not realize a native peer.")
        return
    }

    scrollView.setMagnification(2, centeredAt: NSMakePoint(0, 0))

    expect(scrollView.magnification == 2, "setMagnification did not update the magnification.")
    expect(backend.records[documentHandle]?.contentScale == 2, "Magnification did not reach the document view's content scale.")
    expect(backend.records[documentHandle]?.frame.size == NSMakeSize(800, 600), "Magnification did not scale the document's native frame.")
    expect(backend.records[handle]?.scrollViewContentSize == NSMakeSize(800, 600), "Scrollbar content size did not scale with magnification.")
    expect(scrollView.contentView.documentVisibleRect.size == NSMakeSize(100, 50), "Visible document range did not shrink under magnification.")

    // Scrolling clamps to the magnified extent and syncs scaled pixels.
    scrollView.scroll(NSMakePoint(1_000, 1_000))
    expect(scrollView.contentView.boundsOrigin == NSMakePoint(300, 250), "Magnified scroll did not clamp to the reduced document range.")
    expect(backend.records[handle]?.scrollViewContentOffset == NSMakePoint(600, 500), "Native offset did not scale with magnification.")

    // Wheel distances stay constant on screen: one notch is 48 screen
    // points, which is 24 document units at 2x.
    scrollView.scroll(NSMakePoint(0, 0))
    scrollView.scrollWheel(with: NSEvent(type: .scrollWheel, locationInWindow: NSMakePoint(10, 10), scrollingDeltaY: -1))
    expect(scrollView.contentView.boundsOrigin.y == 24, "Wheel scroll distance did not adjust for magnification.")

    // The magnification range clamps, and 1x removes the content scale.
    scrollView.setMagnification(100, centeredAt: NSMakePoint(0, 0))
    expect(scrollView.magnification == scrollView.maxMagnification, "Magnification did not clamp to maxMagnification.")
    scrollView.setMagnification(1, centeredAt: NSMakePoint(0, 0))
    expect(backend.records[documentHandle]?.contentScale == 1, "Returning to 1x did not clear the content scale.")
    expect(backend.records[documentHandle]?.frame.size == NSMakeSize(400, 300), "Returning to 1x did not restore the native frame.")

    // magnify(toFit:) picks the scale that fits the rectangle.
    scrollView.magnify(toFit: NSMakeRect(0, 0, 100, 50))
    expect(scrollView.magnification == 2, "magnify(toFit:) did not compute the fitting magnification.")
}

@MainActor
func testFloatingPanelStateReachesBackend() {
    let backend = InMemoryNativeControlBackend()
    let panel = NSPanel(
        contentRect: NSMakeRect(100, 100, 200, 150),
        styleMask: [.titled, .closable, .utilityWindow],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    panel.isFloatingPanel = true
    panel.hidesOnDeactivate = true
    panel.orderFrontRegardless()

    guard let handle = panel.nativeHandle else {
        expect(false, "Panel did not realize a native window.")
        return
    }

    expect(backend.records[handle]?.kind == "window", "Panel did not use a window peer.")
    expect(backend.records[handle]?.windowLevel == NSWindow.Level.floating.rawValue, "Floating panel level was not applied at realization.")
    expect(backend.records[handle]?.hidesOnDeactivate == true, "hidesOnDeactivate was not applied at realization.")
    expect(backend.records[handle]?.isHidden == false, "orderFrontRegardless did not show the panel.")

    // Level changes after realization flow through immediately.
    panel.isFloatingPanel = false
    expect(backend.records[handle]?.windowLevel == NSWindow.Level.normal.rawValue, "Clearing isFloatingPanel did not return the level to normal.")
    panel.level = .floating
    expect(backend.records[handle]?.windowLevel == NSWindow.Level.floating.rawValue, "Setting level directly did not reach the backend.")

    // orderOut hides without destroying; orderFront shows the same peer again.
    panel.orderOut(nil)
    expect(backend.records[handle]?.isHidden == true, "orderOut did not hide the panel.")
    expect(panel.nativeHandle != nil, "orderOut destroyed the panel peer.")
    panel.orderFront(nil)
    expect(backend.records[handle]?.isHidden == false, "orderFront did not reshow the hidden panel.")

    // Panels never become the application's main window.
    panel.makeMain()
    expect(NSApplication.shared.mainWindow !== panel, "A panel became the application's main window.")
}

@MainActor
func testColorPanelFloatsAndAppliesColorsLive() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
    }

    // A document window whose first responder listens for changeColor.
    let documentWindow = NSWindow(
        contentRect: NSMakeRect(50, 50, 400, 300),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let recorder = ColorChangeRecordingView(frame: NSMakeRect(0, 0, 400, 300))
    documentWindow.contentView = recorder
    documentWindow.makeKeyAndOrderFront(nil)
    documentWindow.makeFirstResponder(recorder)

    let panel = NSColorPanel(nativeBackend: backend)
    panel.color = .red

    panel.makeKeyAndOrderFront(nil)
    guard let handle = panel.nativeHandle else {
        expect(false, "Color panel did not realize a native window.")
        return
    }

    expect(backend.records[handle]?.windowLevel == NSWindow.Level.floating.rawValue, "Color panel is not a floating window.")
    expect(backend.records[handle]?.hidesOnDeactivate == true, "Color panel does not hide on deactivate.")
    expect(backend.records[handle]?.isHidden == false, "Presented color panel is hidden.")
    expect(NSApplication.shared.mainWindow === documentWindow, "The color panel displaced the main window.")

    // Dragging a component slider recomposes the color and applies it live.
    // Programmatic color sets also dispatch, so start observing here.
    recorder.receivedColors.removeAll()
    let sliderHandles = backend.records.filter { $0.value.kind == "slider" }.keys.sorted { $0.rawValue < $1.rawValue }
    expect(sliderHandles.count == 3, "Color panel did not realize three component sliders.")
    if sliderHandles.count == 3 {
        backend.setSliderValue(255, for: sliderHandles[2])
        backend.actions[sliderHandles[2]]?()
    }

    let magenta = NSColor(calibratedRed: 1, green: 0, blue: 1, alpha: 1)
    expect(panel.color == magenta, "Slider change did not recompose the panel color.")
    expect(recorder.receivedColors == [magenta], "changeColor did not reach the document window's first responder.")

    // A title-bar close hides the shared-style panel instead of destroying it.
    let closed = backend.requestWindowClose(handle)
    expect(!closed, "Title-bar close destroyed the color panel instead of hiding it.")
    expect(backend.records[handle]?.isHidden == true, "Close request did not hide the color panel.")
    expect(panel.nativeHandle != nil, "Close request destroyed the color panel peer.")
    expect(NSApplication.shared.keyWindow === documentWindow, "Hiding the key panel did not return key status to the document window.")

    panel.makeKeyAndOrderFront(nil)
    expect(backend.records[handle]?.isHidden == false, "Re-presenting did not show the hidden color panel.")

    testSharedColorPanelAndWell()
}

@MainActor
func testSharedColorPanelAndWell() {
    // The shared panel feeds the active color well live and lets go on deactivate.
    let colorWell = NSColorWell(frame: NSMakeRect(0, 0, 32, 24))
    colorWell.color = .green
    colorWell.activate(true)
    expect(NSColorPanel.shared.color == .green, "Activating a color well did not seed the shared panel color.")
    NSColorPanel.shared.color = .white
    expect(colorWell.color == .white, "Shared panel color did not flow into the active color well.")
    colorWell.deactivate()
    NSColorPanel.shared.color = .black
    expect(colorWell.color == .white, "Deactivated color well still received panel colors.")
}

@MainActor
func testFontPanelLiveApplyThroughFontManager() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    let manager = NSFontManager.shared
    defer {
        NSApplication.shared.nativeBackend = previousBackend
        manager.target = nil
    }

    // A document window whose first responder converts changeFont sends.
    let documentWindow = NSWindow(
        contentRect: NSMakeRect(50, 50, 400, 300),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let recorder = FontChangeRecordingView(frame: NSMakeRect(0, 0, 400, 300))
    documentWindow.contentView = recorder
    documentWindow.makeKeyAndOrderFront(nil)
    documentWindow.makeFirstResponder(recorder)

    let seedFont = NSFont(name: "Georgia", size: 14, weight: .regular)
    manager.selectedFont = seedFont

    let panel = NSFontPanel(nativeBackend: backend)
    panel.setPanelFont(seedFont, isMultiple: false)
    expect(panel.winSelectedFont == seedFont, "setPanelFont did not seed the panel selection.")

    panel.makeKeyAndOrderFront(nil)
    guard let handle = panel.nativeHandle else {
        expect(false, "Font panel did not realize a native window.")
        return
    }

    expect(backend.records[handle]?.windowLevel == NSWindow.Level.floating.rawValue, "Font panel is not a floating window.")
    expect(backend.records[handle]?.hidesOnDeactivate == true, "Font panel does not hide on deactivate.")

    testFontPanelFamilySelection(panel: panel, manager: manager, recorder: recorder, backend: backend)

    // Editing the size combo re-applies with the new point size.
    let comboHandle = backend.records.first { $0.value.kind == "comboBox" }?.key
    expect(comboHandle != nil, "Font panel did not realize a size combo box.")
    if let comboHandle {
        backend.textChangeActions[comboHandle]?("24")
        expect(manager.selectedFont?.pointSize == 24, "Size change did not update the selected font size.")
        expect(recorder.receivedFonts.count == 2, "Size change did not send changeFont again.")
    }

    // NSTextView applies panel fonts to its whole plain-text contents.
    let textView = NSTextView(frame: NSMakeRect(0, 0, 200, 100))
    textView.changeFont(manager)
    expect(textView.font == manager.selectedFont, "NSTextView.changeFont did not adopt the panel selection.")

    // A title-bar close hides the shared-style panel instead of destroying it.
    let closed = backend.requestWindowClose(handle)
    expect(!closed, "Title-bar close destroyed the font panel instead of hiding it.")
    expect(backend.records[handle]?.isHidden == true, "Close request did not hide the font panel.")
}

@MainActor
func testFontPanelFamilySelection(
    panel: NSFontPanel,
    manager: NSFontManager,
    recorder: FontChangeRecordingView,
    backend: InMemoryNativeControlBackend
) {
    let families = backend.fontFamilyNames()
    guard let tableHandle = backend.records.first(where: { $0.value.kind == "tableView" })?.key else {
        expect(false, "Font panel did not realize a family table.")
        return
    }
    expect(backend.records[tableHandle]?.tableRows.count == families.count, "Family table does not list the installed families.")
    guard let consolasRow = families.firstIndex(of: "Consolas") else {
        expect(false, "Deterministic family list is missing Consolas.")
        return
    }
    backend.setTableSelectedRow(consolasRow, for: tableHandle)
    backend.actions[tableHandle]?()
    expect(manager.selectedFont?.fontName == "Consolas", "Family selection did not update the manager's selected font.")
    expect(panel.winSelectedFont?.fontName == "Consolas", "Family selection did not update the panel selection.")
    expect(recorder.receivedFonts.count == 1, "changeFont did not reach the document window's first responder.")
    expect(recorder.receivedFonts.first?.fontName == "Consolas", "convert(_:) did not return the live panel selection.")
}

final class RealizationRecordingView: NSView {
    var didRealize = false

    override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        didRealize = true
        return super.realizeNativePeer(in: backend, parent: parent)
    }
}

