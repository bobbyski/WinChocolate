/// The shared font panel.
///
/// The panel is a floating utility window composed of framework controls: an
/// installed-family list, a typeface popup, a size combo, and a live
/// preview. Every selection change applies immediately through
/// `NSFontManager.shared` — the manager updates its `selectedFont`, sends
/// `changeFont(_:)` along the responder chain, and fires the change
/// closures — matching AppKit's live font panel instead of the earlier modal
/// chooser. Closing the panel hides it; the shared instance stays alive for
/// the next presentation.
open class NSFontPanel: NSPanel {
    nonisolated(unsafe) private static var sharedPanel: NSFontPanel?

    /// The shared font panel instance.
    open class var shared: NSFontPanel {
        if let sharedPanel {
            return sharedPanel
        }

        let panel = NSFontPanel()
        sharedPanel = panel
        return panel
    }

    /// Whether the shared font panel has been created.
    open class var sharedFontPanelExists: Bool {
        sharedPanel != nil
    }

    /// The font most recently seeded or chosen in the panel, when any.
    open private(set) var winSelectedFont: NSFont?

    /// Whether the panel represents a multiple-font selection.
    open private(set) var winIsMultiple = false

    /// Called after every font change, alongside the responder-chain action.
    open var winFontDidChange: ((NSFont) -> Void)?

    private let familyNames: [String]
    private var familyTable: NSTableView?
    private var typefacePopUp: NSPopUpButton?
    private var sizeComboBox: NSComboBox?
    private var previewField: NSTextField?
    private var isSyncingSelection = false

    private static let contentSize = NSSize(width: 320, height: 308)
    private static let presetSizes: [Int] = [9, 10, 11, 12, 13, 14, 18, 24, 36, 48, 64]

    /// Creates a font panel against an explicit backend.
    public init(nativeBackend: NativeControlBackend) {
        self.familyNames = nativeBackend.fontFamilyNames()
        super.init(
            contentRect: NSMakeRect(780, 160, Self.contentSize.width, Self.contentSize.height),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false,
            nativeBackend: nativeBackend
        )
        configurePanel()
    }

    /// Creates a font panel on the application's backend.
    public convenience init() {
        self.init(nativeBackend: NSApplication.shared.nativeBackend)
    }

    /// Seeds the panel with the font it should display without notifying.
    open func setPanelFont(_ fontObj: NSFont, isMultiple flag: Bool) {
        winSelectedFont = fontObj
        winIsMultiple = flag
        syncControls(to: fontObj)
    }

    private func configurePanel() {
        title = "Fonts"
        isFloatingPanel = true
        hidesOnDeactivate = true
        delegate = self
        buildContent()
    }

    private func buildContent() {
        let content = NSView(frame: NSRect(origin: NSPoint(x: 0, y: 0), size: Self.contentSize))

        let familyLabel = NSTextField(string: "Family", frame: NSMakeRect(16, 12, 100, 18))
        familyLabel.isBordered = false
        content.addSubview(familyLabel)

        let table = NSTableView(frame: NSMakeRect(16, 32, 180, 216))
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("family"))
        column.title = "Family"
        column.width = 156
        table.addTableColumn(column)
        table.dataSource = self
        table.onSelectionChanged = { [weak self] _ in
            self?.selectionControlsDidChange()
        }
        content.addSubview(table)
        familyTable = table

        let typefaceLabel = NSTextField(string: "Typeface", frame: NSMakeRect(208, 12, 96, 18))
        typefaceLabel.isBordered = false
        content.addSubview(typefaceLabel)

        let typeface = NSPopUpButton(frame: NSMakeRect(208, 32, 96, 24), pullsDown: false)
        typeface.addItems(withTitles: ["Regular", "Bold", "Italic", "Bold Italic"])
        typeface.onAction = { [weak self] _ in
            self?.selectionControlsDidChange()
        }
        content.addSubview(typeface)
        typefacePopUp = typeface

        let sizeLabel = NSTextField(string: "Size", frame: NSMakeRect(208, 72, 96, 18))
        sizeLabel.isBordered = false
        content.addSubview(sizeLabel)

        let sizes = NSComboBox(frame: NSMakeRect(208, 92, 96, 24))
        sizes.addItems(withObjectValues: Self.presetSizes.map(String.init))
        sizes.stringValue = "13"
        sizes.onComboBoxTextChanged = { [weak self] _ in
            self?.selectionControlsDidChange()
        }
        content.addSubview(sizes)
        sizeComboBox = sizes

        let preview = NSTextField(string: "AaBbCcDdEe 1234567890", frame: NSMakeRect(16, 256, 288, 36))
        preview.isEditable = false
        content.addSubview(preview)
        previewField = preview

        contentView = content

        if let font = winSelectedFont {
            syncControls(to: font)
        }
    }

    /// Rebuilds the selected font after any control change and applies it live.
    private func selectionControlsDidChange() {
        guard !isSyncingSelection else {
            return
        }

        let font = fontFromControls()
        winSelectedFont = font
        previewField?.font = font
        winFontDidChange?(font)
        NSFontManager.shared.panelFontDidChange(font)
    }

    private func fontFromControls() -> NSFont {
        let fallback = winSelectedFont ?? NSFont.systemFont(ofSize: 13)

        var familyName = fallback.fontName
        if let table = familyTable, familyNames.indices.contains(table.selectedRow) {
            familyName = familyNames[table.selectedRow]
        }

        var pointSize = fallback.pointSize
        if let sizeText = sizeComboBox?.stringValue, let parsed = Double(sizeText), parsed > 0 {
            pointSize = CGFloat(parsed)
        }

        // Typeface popup order: Regular, Bold, Italic, Bold Italic.
        let typefaceIndex = typefacePopUp?.indexOfSelectedItem ?? 0
        let weight: NSFont.Weight = (typefaceIndex == 1 || typefaceIndex == 3) ? .bold : .regular
        let italic = typefaceIndex >= 2
        return NSFont(name: familyName, size: pointSize, weight: weight, italic: italic)
    }

    /// Moves the panel controls to reflect a font without emitting changes.
    private func syncControls(to font: NSFont) {
        isSyncingSelection = true
        defer {
            isSyncingSelection = false
        }

        if let row = familyNames.firstIndex(of: font.fontName) {
            familyTable?.selectRowIndexes([row], byExtendingSelection: false)
            familyTable?.scrollRowToVisible(row)
        }
        typefacePopUp?.indexOfSelectedItem = (font.weight.isBold ? 1 : 0) + (font.italic ? 2 : 0)
        sizeComboBox?.stringValue = "\(Int(font.pointSize))"
        previewField?.font = font
    }
}

extension NSFontPanel: NSWindowDelegate {
    /// The shared panel hides on a title-bar close instead of destroying its peer.
    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        orderOut(nil)
        return false
    }
}

extension NSFontPanel: NSTableViewDataSource {
    /// One row per installed font family.
    public func numberOfRows(in tableView: NSTableView) -> Int {
        familyNames.count
    }

    /// The family name for a row.
    public func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        familyNames.indices.contains(row) ? familyNames[row] : nil
    }

    /// The family list is read-only.
    public func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {}
}
