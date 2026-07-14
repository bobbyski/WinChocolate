#if os(Windows)
extension Win32NativeControlBackend {
    /// Creates a native toolbar child.
    /// Creates a host view for toolbar content.
    ///
    /// The classic backend renders toolbars through the composed
    /// `NSToolbarView` pipeline; the native `ToolbarWindow32` renderer was
    /// retired because its separator-placeholder model for custom views
    /// fought AppKit semantics (see `Docs/ToolbarArchitecture.md`).
    public func createToolbar(items: [NativeToolbarItem], frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        createView(frame: frame, parent: parent)
    }

    /// Retired: composed toolbars manage their own item views.
    public func setToolbarItems(_ items: [NativeToolbarItem], for handle: NativeHandle) {
    }

    /// Retired: composed toolbars compute item frames in the framework layer.
    public func toolbarItemFrame(at index: Int, for handle: NativeHandle) -> NSRect? {
        nil
    }

    /// Stores the toolbar activation action for backend compatibility.
    public func registerToolbarAction(for handle: NativeHandle, action: @escaping (String) -> Void) {
        toolbarActions[handle.rawValue] = action
    }

    private func toolbarImageIndex(for imageName: String?) -> Int32 {
        guard let imageName else {
            return iImageNone
        }

        switch imageName.lowercased() {
        case "new", "document", "doc", "filenew", "square.and.pencil":
            return stdFileNew
        case "open", "folder", "folder.open", "fileopen":
            return stdFileOpen
        case "save", "filesave", "square.and.arrow.down", "tray.and.arrow.down":
            return stdFileSave
        case "print", "printer":
            return stdPrint
        case "properties", "info", "info.circle", "gear", "gearshape":
            return stdProperties
        case "help", "questionmark", "questionmark.circle":
            return stdHelp
        default:
            return iImageNone
        }
    }

    /// Paints a custom view through an off-screen bitmap and blits it in one
    /// step, so continuously-animating views (spinners) never flicker between
    /// the background erase and the content redraw.
    func drawCustomView(hwnd: HWND?, handle: NativeHandle) {
        var paint = PAINTSTRUCT()
        guard let windowContext = winBeginPaint(hwnd, &paint) else {
            return
        }
        defer {
            withUnsafePointer(to: paint) { paintPointer in
                _ = winEndPaint(hwnd, paintPointer)
            }
        }

        var rectangle = RECT()
        _ = winGetClientRect(hwnd, &rectangle)
        let width = rectangle.right - rectangle.left
        let height = rectangle.bottom - rectangle.top

        // Double-buffer when possible; fall back to painting the window DC
        // directly if the off-screen surface can't be created.
        guard width > 0, height > 0,
              let memoryContext = winCreateCompatibleDC(windowContext),
              let memoryBitmap = winCreateCompatibleBitmap(windowContext, width, height) else {
            renderCustomViewContent(into: windowContext, hwnd: hwnd, handle: handle, rectangle: rectangle)
            return
        }
        let previousBitmap = winSelectObject(memoryContext, memoryBitmap)
        defer {
            _ = winSelectObject(memoryContext, previousBitmap ?? nil)
            _ = winDeleteObject(memoryBitmap)
            _ = winDeleteDC(memoryContext)
        }

        renderCustomViewContent(into: memoryContext, hwnd: hwnd, handle: handle, rectangle: rectangle)
        _ = winBitBlt(windowContext, 0, 0, width, height, memoryContext, 0, 0, srcCopyRasterOperation)
    }

    /// Renders a custom view's background and content into a device context.
    ///
    /// The background is always filled so the off-screen bitmap is fully
    /// covered (an unpainted bitmap holds garbage); a view with no explicit
    /// background inherits its nearest ancestor's color.
    private func renderCustomViewContent(into deviceContext: HDC, hwnd: HWND?, handle: NativeHandle, rectangle: RECT) {
        if let brush = backgroundBrushes[handle.rawValue] {
            withUnsafePointer(to: rectangle) { rectanglePointer in
                _ = winFillRect(deviceContext, rectanglePointer, brush)
            }
        } else {
            // Fill with the nearest ancestor's background so views without their
            // own background blend in (and the buffer is fully painted).
            fillRect(rectangle, color: inheritedBackgroundColor(behind: hwnd), deviceContext: deviceContext)
        }

        // Custom content drawn through `NSView.draw(_:)` paints above the
        // background and below any composed toolbar glyphs.
        if let drawAction = drawActions[handle.rawValue] {
            // Views draw in logical (point) coordinates through a GDI world
            // transform, which scales paths, text, and blits alike. The factor
            // is the display's device scale (10.7, DPI) times any per-view
            // magnification (3.3), so custom drawing renders crisp at HiDPI.
            let scale = winDeviceScale * (contentScales[handle.rawValue] ?? 1)
            let dirtyRect = NSMakeRect(
                0,
                0,
                CGFloat(max(0, rectangle.right - rectangle.left)) / scale,
                CGFloat(max(0, rectangle.bottom - rectangle.top)) / scale
            )
            if scale != 1 {
                _ = winSetGraphicsMode(deviceContext, gmAdvanced)
                var transform = XFORM(eM11: Float(scale), eM22: Float(scale))
                _ = winSetWorldTransform(deviceContext, &transform)
            }
            drawAction(Win32DrawingContext(deviceContext: deviceContext), dirtyRect)
            if scale != 1 {
                _ = winModifyWorldTransform(deviceContext, nil, mwtIdentity)
                _ = winSetGraphicsMode(deviceContext, gmCompatible)
            }
        }

        let preview = toolbarPreview(from: text(from: hwnd))
        guard preview.showItem || preview.showLabel else {
            return
        }

        // Plain container views have no text at all; drawing the fallback
        // glyph for them scatters phantom icons across spaces and panels.
        guard !preview.label.isEmpty || !preview.imageName.isEmpty else {
            return
        }

        if let textColor = textColors[handle.rawValue] {
            _ = winSetTextColor(deviceContext, textColor)
        }
        let backgroundColor = backgroundColors[handle.rawValue] ?? colorRef(red: 0.94, green: 0.94, blue: 0.94)
        _ = winSetBkColor(deviceContext, backgroundColor)
        _ = winSetBkMode(deviceContext, transparentBkMode)

        let parts = toolbarPreviewRects(for: preview, in: rectangle)
        if preview.showItem {
            drawToolbarItemGlyph(preview: preview, in: parts.image, deviceContext: deviceContext, parentWindow: hwnd)
        }

        let toolbarFont = toolbarPreviewFont()
        let oldFont = toolbarFont.map { winSelectObject(deviceContext, $0) }
        defer {
            if let toolbarFont {
                _ = winSelectObject(deviceContext, oldFont ?? nil)
                _ = winDeleteObject(toolbarFont)
            }
        }

        if preview.showLabel, !preview.label.isEmpty {
            var textRectangle = parts.label
            withWideString(preview.label) { textPointer in
                withUnsafeMutablePointer(to: &textRectangle) { rectanglePointer in
                    _ = winDrawTextW(deviceContext, textPointer, -1, rectanglePointer, dtCenter | dtVCenter | dtSingleLine | dtEndEllipsis)
                }
            }
        }
    }

    private struct ToolbarPreview {
        var label: String
        var imageName: String
        var showItem: Bool
        var showLabel: Bool
        var labelPosition: String
    }

    private func toolbarPreview(from text: String) -> ToolbarPreview {
        let fields = text.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        if fields.first == "__WinChocolateToolbarItem" {
            let label = fields.count > 1 ? fields[1] : ""
            let imageName = fields.count > 2 ? fields[2] : label
            let showItem = fields.count > 3 ? fields[3] == "1" : true
            let showLabel = fields.count > 4 ? fields[4] == "1" : true
            let labelPosition = fields.count > 5 ? fields[5] : "below"
            return ToolbarPreview(
                label: label,
                imageName: imageName,
                showItem: showItem,
                showLabel: showLabel,
                labelPosition: labelPosition
            )
        }

        let parts = text.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        let label = parts.first.map(String.init) ?? text
        let imageName = parts.count > 1 ? String(parts[1]) : label
        return ToolbarPreview(label: label, imageName: imageName, showItem: true, showLabel: true, labelPosition: "below")
    }

    private func toolbarPreviewRects(for preview: ToolbarPreview, in rectangle: RECT) -> (image: RECT, label: RECT) {
        let width = rectangle.right - rectangle.left
        let height = rectangle.bottom - rectangle.top
        let glyphSize = max(Int32(12), min(Int32(18), height - 16))
        let labelHeight: Int32 = preview.showLabel ? 14 : 0
        let gap: Int32 = preview.showItem && preview.showLabel ? 2 : 0

        switch preview.labelPosition {
        case "above":
            let totalHeight = glyphSize + labelHeight + gap
            let top = rectangle.top + max((height - totalHeight) / 2, 0)
            let labelRect = RECT(left: rectangle.left + 1, top: top, right: rectangle.right - 1, bottom: top + labelHeight)
            let imageTop = top + labelHeight + gap
            let imageLeft = rectangle.left + max((width - glyphSize) / 2, 2)
            let imageRect = RECT(left: imageLeft, top: imageTop, right: imageLeft + glyphSize, bottom: imageTop + glyphSize)
            return (imageRect, labelRect)
        case "left":
            let imageLeft = rectangle.right - glyphSize - 4
            let imageTop = rectangle.top + max((height - glyphSize) / 2, 0)
            let imageRect = RECT(left: imageLeft, top: imageTop, right: imageLeft + glyphSize, bottom: imageTop + glyphSize)
            let labelRect = RECT(left: rectangle.left + 1, top: rectangle.top + 1, right: max(rectangle.left + 1, imageLeft - gap), bottom: rectangle.bottom - 1)
            return (imageRect, labelRect)
        case "right":
            let imageLeft = rectangle.left + 4
            let imageTop = rectangle.top + max((height - glyphSize) / 2, 0)
            let imageRect = RECT(left: imageLeft, top: imageTop, right: imageLeft + glyphSize, bottom: imageTop + glyphSize)
            let labelRect = RECT(left: imageLeft + glyphSize + gap, top: rectangle.top + 1, right: rectangle.right - 1, bottom: rectangle.bottom - 1)
            return (imageRect, labelRect)
        default:
            let totalHeight = glyphSize + labelHeight + gap
            let top = rectangle.top + max((height - totalHeight) / 2, 0)
            let imageLeft = rectangle.left + max((width - glyphSize) / 2, 2)
            let imageRect = RECT(left: imageLeft, top: top, right: imageLeft + glyphSize, bottom: top + glyphSize)
            let labelTop = top + glyphSize + gap
            let labelRect = RECT(left: rectangle.left + 1, top: labelTop, right: rectangle.right - 1, bottom: labelTop + labelHeight)
            return (imageRect, labelRect)
        }
    }

    private func toolbarPreviewFont() -> HFONT? {
        withWideString("Segoe UI") { faceName in
            winCreateFontW(
                -11,
                0,
                0,
                0,
                600,
                0,
                0,
                0,
                defaultCharset,
                defaultPrecision,
                defaultPrecision,
                defaultQuality,
                defaultPitchAndFamily,
                faceName
            )
        }
    }

    private func drawToolbarItemGlyph(preview: ToolbarPreview, in rectangle: RECT, deviceContext: HDC?, parentWindow: HWND?) {
        let width = rectangle.right - rectangle.left
        let height = rectangle.bottom - rectangle.top
        let glyphSize = max(12, min(18, height))
        let glyphLeft = rectangle.left + max((width - glyphSize) / 2, 2)
        let glyphTop = rectangle.top + max((height - glyphSize) / 2, 0)
        let kind = preview.imageName.lowercased()

        if kind.contains("separator") {
            drawSeparatorGlyph(left: glyphLeft, top: glyphTop, size: glyphSize, deviceContext: deviceContext)
            return
        }
        if kind.contains("flexiblespace") {
            drawFlexibleSpaceGlyph(left: glyphLeft, top: glyphTop, size: glyphSize, deviceContext: deviceContext)
            return
        }
        if kind == "space" || kind.contains("fixedspace") {
            drawSpaceGlyph(left: glyphLeft, top: glyphTop, size: glyphSize, deviceContext: deviceContext)
            return
        }

        let imageIndex = toolbarImageIndex(for: preview.imageName)
        if imageIndex != iImageNone, let imageList = standardToolbarImages(parentWindow: parentWindow) {
            let imageLeft = rectangle.left + max((width - 16) / 2, 2)
            _ = winImageListDraw(imageList, imageIndex, deviceContext, imageLeft, glyphTop, ildNormal)
            return
        }

        drawDocumentGlyph(left: glyphLeft, top: glyphTop, size: glyphSize, accent: toolbarGlyphColor(for: preview.imageName), deviceContext: deviceContext)
    }

    private func standardToolbarImages(parentWindow: HWND?) -> HIMAGELIST? {
        if let standardToolbarImageList, winIsWindow(standardToolbarImageOwner) != 0 {
            return standardToolbarImageList
        }
        standardToolbarImageOwner = nil
        standardToolbarImageList = nil

        let toolbarHwnd = withWideString(toolbarClassName) { className in
            withWideString("") { title in
                winCreateWindowExW(
                    0,
                    className,
                    title,
                    wsChild,
                    -32_000,
                    -32_000,
                    1,
                    1,
                    parentWindow,
                    nil,
                    winGetModuleHandleW(nil),
                    nil
                )
            }
        }
        guard let toolbarHwnd else {
            return nil
        }

        _ = winSendMessageW(toolbarHwnd, tbButtonStructSize, WPARAM(MemoryLayout<TBBUTTON>.size), 0)
        _ = winSendMessageW(toolbarHwnd, tbLoadImages, idbStdSmallColor, hinstCommctrl)
        let imageList = HIMAGELIST(bitPattern: winSendMessageW(toolbarHwnd, tbGetImageList, 0, 0))
        standardToolbarImageOwner = toolbarHwnd
        standardToolbarImageList = imageList
        return imageList
    }

    private func drawDocumentGlyph(left glyphLeft: Int32, top glyphTop: Int32, size glyphSize: Int32, accent: DWORD, deviceContext: HDC?) {
        let shadow = colorRef(red: 0.50, green: 0.52, blue: 0.55)
        let paper = colorRef(red: 0.98, green: 0.98, blue: 0.96)
        let shine = colorRef(red: 1.0, green: 1.0, blue: 1.0)

        fillRect(
            RECT(left: glyphLeft + 1, top: glyphTop + 1, right: glyphLeft + glyphSize + 1, bottom: glyphTop + glyphSize + 1),
            color: shadow,
            deviceContext: deviceContext
        )
        fillRect(
            RECT(left: glyphLeft, top: glyphTop, right: glyphLeft + glyphSize, bottom: glyphTop + glyphSize),
            color: paper,
            deviceContext: deviceContext
        )
        fillRect(
            RECT(left: glyphLeft + 3, top: glyphTop + 4, right: glyphLeft + glyphSize - 3, bottom: glyphTop + glyphSize - 2),
            color: accent,
            deviceContext: deviceContext
        )
        fillRect(
            RECT(left: glyphLeft + 4, top: glyphTop + 5, right: glyphLeft + glyphSize - 4, bottom: glyphTop + 7),
            color: shine,
            deviceContext: deviceContext
        )
        fillRect(
            RECT(left: glyphLeft + glyphSize - 5, top: glyphTop, right: glyphLeft + glyphSize, bottom: glyphTop + 5),
            color: colorRef(red: 0.88, green: 0.90, blue: 0.92),
            deviceContext: deviceContext
        )
    }

    private func drawFolderGlyph(left glyphLeft: Int32, top glyphTop: Int32, size glyphSize: Int32, deviceContext: HDC?) {
        let edge = colorRef(red: 0.61, green: 0.43, blue: 0.16)
        let tab = colorRef(red: 0.94, green: 0.68, blue: 0.22)
        let body = colorRef(red: 0.98, green: 0.78, blue: 0.30)
        let shine = colorRef(red: 1.0, green: 0.90, blue: 0.48)
        fillRect(RECT(left: glyphLeft + 1, top: glyphTop + 5, right: glyphLeft + glyphSize, bottom: glyphTop + glyphSize - 1), color: edge, deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 2, top: glyphTop + 3, right: glyphLeft + glyphSize / 2 + 2, bottom: glyphTop + 7), color: tab, deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 2, top: glyphTop + 7, right: glyphLeft + glyphSize - 1, bottom: glyphTop + glyphSize - 2), color: body, deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 4, top: glyphTop + 8, right: glyphLeft + glyphSize - 3, bottom: glyphTop + 10), color: shine, deviceContext: deviceContext)
    }

    private func drawSaveGlyph(left glyphLeft: Int32, top glyphTop: Int32, size glyphSize: Int32, deviceContext: HDC?) {
        let body = colorRef(red: 0.11, green: 0.28, blue: 0.58)
        let edge = colorRef(red: 0.05, green: 0.12, blue: 0.30)
        let label = colorRef(red: 0.94, green: 0.94, blue: 0.90)
        let metal = colorRef(red: 0.78, green: 0.81, blue: 0.84)
        fillRect(RECT(left: glyphLeft + 1, top: glyphTop + 1, right: glyphLeft + glyphSize, bottom: glyphTop + glyphSize), color: edge, deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 2, top: glyphTop + 2, right: glyphLeft + glyphSize - 1, bottom: glyphTop + glyphSize - 1), color: body, deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 4, top: glyphTop + 3, right: glyphLeft + glyphSize - 4, bottom: glyphTop + 7), color: metal, deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + glyphSize - 6, top: glyphTop + 4, right: glyphLeft + glyphSize - 4, bottom: glyphTop + 6), color: edge, deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 4, top: glyphTop + glyphSize - 7, right: glyphLeft + glyphSize - 4, bottom: glyphTop + glyphSize - 2), color: label, deviceContext: deviceContext)
    }

    private func drawPrintGlyph(left glyphLeft: Int32, top glyphTop: Int32, size glyphSize: Int32, deviceContext: HDC?) {
        fillRect(RECT(left: glyphLeft + 4, top: glyphTop + 1, right: glyphLeft + glyphSize - 4, bottom: glyphTop + 6), color: colorRef(red: 0.95, green: 0.95, blue: 0.92), deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 2, top: glyphTop + 6, right: glyphLeft + glyphSize - 2, bottom: glyphTop + glyphSize - 4), color: colorRef(red: 0.30, green: 0.32, blue: 0.35), deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 4, top: glyphTop + glyphSize - 8, right: glyphLeft + glyphSize - 4, bottom: glyphTop + glyphSize - 1), color: colorRef(red: 0.97, green: 0.97, blue: 0.94), deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + glyphSize - 5, top: glyphTop + 8, right: glyphLeft + glyphSize - 3, bottom: glyphTop + 10), color: colorRef(red: 0.30, green: 0.62, blue: 0.86), deviceContext: deviceContext)
    }

    private func drawPropertiesGlyph(left glyphLeft: Int32, top glyphTop: Int32, size glyphSize: Int32, deviceContext: HDC?) {
        let edge = colorRef(red: 0.35, green: 0.40, blue: 0.48)
        let sheet = colorRef(red: 0.91, green: 0.94, blue: 0.97)
        let header = colorRef(red: 0.36, green: 0.55, blue: 0.75)
        let line = colorRef(red: 0.50, green: 0.56, blue: 0.62)
        fillRect(RECT(left: glyphLeft + 3, top: glyphTop + 1, right: glyphLeft + glyphSize - 3, bottom: glyphTop + glyphSize), color: edge, deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 4, top: glyphTop + 2, right: glyphLeft + glyphSize - 4, bottom: glyphTop + glyphSize - 1), color: sheet, deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 5, top: glyphTop + 4, right: glyphLeft + glyphSize - 5, bottom: glyphTop + 7), color: header, deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 6, top: glyphTop + 9, right: glyphLeft + glyphSize - 6, bottom: glyphTop + 10), color: line, deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 6, top: glyphTop + 12, right: glyphLeft + glyphSize - 8, bottom: glyphTop + 13), color: line, deviceContext: deviceContext)
    }

    private func drawTrashGlyph(left glyphLeft: Int32, top glyphTop: Int32, size glyphSize: Int32, deviceContext: HDC?) {
        fillRect(RECT(left: glyphLeft + 5, top: glyphTop + 2, right: glyphLeft + glyphSize - 5, bottom: glyphTop + 4), color: colorRef(red: 0.35, green: 0.37, blue: 0.40), deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 3, top: glyphTop + 5, right: glyphLeft + glyphSize - 3, bottom: glyphTop + 7), color: colorRef(red: 0.45, green: 0.47, blue: 0.50), deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 4, top: glyphTop + 7, right: glyphLeft + glyphSize - 4, bottom: glyphTop + glyphSize - 1), color: colorRef(red: 0.76, green: 0.78, blue: 0.80), deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 7, top: glyphTop + 8, right: glyphLeft + 8, bottom: glyphTop + glyphSize - 2), color: colorRef(red: 0.50, green: 0.52, blue: 0.55), deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + glyphSize - 8, top: glyphTop + 8, right: glyphLeft + glyphSize - 7, bottom: glyphTop + glyphSize - 2), color: colorRef(red: 0.50, green: 0.52, blue: 0.55), deviceContext: deviceContext)
    }

    private func drawSearchGlyph(left glyphLeft: Int32, top glyphTop: Int32, size glyphSize: Int32, deviceContext: HDC?) {
        let glass = colorRef(red: 0.45, green: 0.68, blue: 0.88)
        let rim = colorRef(red: 0.18, green: 0.32, blue: 0.48)
        fillRect(RECT(left: glyphLeft + 3, top: glyphTop + 3, right: glyphLeft + glyphSize - 6, bottom: glyphTop + glyphSize - 6), color: rim, deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 5, top: glyphTop + 5, right: glyphLeft + glyphSize - 8, bottom: glyphTop + glyphSize - 8), color: glass, deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + glyphSize - 7, top: glyphTop + glyphSize - 7, right: glyphLeft + glyphSize - 2, bottom: glyphTop + glyphSize - 4), color: rim, deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + glyphSize - 5, top: glyphTop + glyphSize - 5, right: glyphLeft + glyphSize - 2, bottom: glyphTop + glyphSize - 2), color: rim, deviceContext: deviceContext)
    }

    private func drawPlusGlyph(left glyphLeft: Int32, top glyphTop: Int32, size glyphSize: Int32, deviceContext: HDC?) {
        drawDocumentGlyph(left: glyphLeft, top: glyphTop, size: glyphSize, accent: colorRef(red: 0.31, green: 0.62, blue: 0.36), deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + glyphSize - 7, top: glyphTop + glyphSize - 10, right: glyphLeft + glyphSize - 4, bottom: glyphTop + glyphSize - 3), color: colorRef(red: 0.16, green: 0.56, blue: 0.20), deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + glyphSize - 9, top: glyphTop + glyphSize - 8, right: glyphLeft + glyphSize - 2, bottom: glyphTop + glyphSize - 5), color: colorRef(red: 0.16, green: 0.56, blue: 0.20), deviceContext: deviceContext)
    }

    private func drawSeparatorGlyph(left glyphLeft: Int32, top glyphTop: Int32, size glyphSize: Int32, deviceContext: HDC?) {
        let center = glyphLeft + glyphSize / 2
        fillRect(RECT(left: center - 1, top: glyphTop + 1, right: center, bottom: glyphTop + glyphSize - 1), color: colorRef(red: 0.52, green: 0.55, blue: 0.58), deviceContext: deviceContext)
        fillRect(RECT(left: center, top: glyphTop + 1, right: center + 1, bottom: glyphTop + glyphSize - 1), color: colorRef(red: 1.0, green: 1.0, blue: 1.0), deviceContext: deviceContext)
    }

    private func drawSpaceGlyph(left glyphLeft: Int32, top glyphTop: Int32, size glyphSize: Int32, deviceContext: HDC?) {
        let y = glyphTop + glyphSize / 2
        fillRect(RECT(left: glyphLeft + 3, top: y, right: glyphLeft + glyphSize - 3, bottom: y + 1), color: colorRef(red: 0.62, green: 0.65, blue: 0.68), deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 3, top: y - 3, right: glyphLeft + 4, bottom: y + 4), color: colorRef(red: 0.62, green: 0.65, blue: 0.68), deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + glyphSize - 4, top: y - 3, right: glyphLeft + glyphSize - 3, bottom: y + 4), color: colorRef(red: 0.62, green: 0.65, blue: 0.68), deviceContext: deviceContext)
    }

    private func drawFlexibleSpaceGlyph(left glyphLeft: Int32, top glyphTop: Int32, size glyphSize: Int32, deviceContext: HDC?) {
        let y = glyphTop + glyphSize / 2
        fillRect(RECT(left: glyphLeft + 2, top: y, right: glyphLeft + glyphSize - 2, bottom: y + 1), color: colorRef(red: 0.35, green: 0.45, blue: 0.58), deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 2, top: y - 2, right: glyphLeft + 5, bottom: y + 3), color: colorRef(red: 0.35, green: 0.45, blue: 0.58), deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + glyphSize - 5, top: y - 2, right: glyphLeft + glyphSize - 2, bottom: y + 3), color: colorRef(red: 0.35, green: 0.45, blue: 0.58), deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 6, top: y - 1, right: glyphLeft + 8, bottom: y + 2), color: colorRef(red: 0.82, green: 0.87, blue: 0.94), deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + glyphSize - 8, top: y - 1, right: glyphLeft + glyphSize - 6, bottom: y + 2), color: colorRef(red: 0.82, green: 0.87, blue: 0.94), deviceContext: deviceContext)
    }

    func fillRect(_ rectangle: RECT, color: DWORD, deviceContext: HDC?) {
        guard let brush = winCreateSolidBrush(color) else {
            return
        }
        defer {
            _ = winDeleteObject(brush)
        }

        withUnsafePointer(to: rectangle) { rectanglePointer in
            _ = winFillRect(deviceContext, rectanglePointer, brush)
        }
    }

    private func toolbarGlyphColor(for label: String) -> DWORD {
        let palette: [DWORD] = [
            colorRef(red: 0.24, green: 0.48, blue: 0.82),
            colorRef(red: 0.25, green: 0.58, blue: 0.43),
            colorRef(red: 0.68, green: 0.39, blue: 0.22),
            colorRef(red: 0.54, green: 0.42, blue: 0.72),
            colorRef(red: 0.63, green: 0.47, blue: 0.20),
            colorRef(red: 0.30, green: 0.55, blue: 0.64)
        ]
        let value = label.unicodeScalars.reduce(0) { partial, scalar in
            partial &+ Int(scalar.value)
        }
        return palette[value % palette.count]
    }
}
#endif
