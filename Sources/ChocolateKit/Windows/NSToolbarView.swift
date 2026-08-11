open class NSToolbarView: NSView {
    /// Toolbar model rendered by this view.
    open var toolbar: NSToolbar? {
        didSet {
            oldValue?.visibilityDidChange = nil
            oldValue?.itemsDidChange = nil
            toolbar?.visibilityDidChange = { [weak self] isVisible in
                self?.isHidden = !isVisible
                self?.visibilityChanged?(isVisible)
            }
            toolbar?.itemsDidChange = { [weak self] in
                self?.reloadItems()
            }
            isHidden = !(toolbar?.isVisible ?? true)
            reloadItems()
        }
    }

    /// Item height inside the strip.
    open var itemHeight: CGFloat = 34

    /// Preferred strip height for the current toolbar display settings.
    open var preferredHeight: CGFloat {
        Self.preferredHeight(for: toolbar)
    }

    /// Horizontal padding before the first item.
    open var leadingPadding: CGFloat = 8

    /// Spacing between normal items.
    open var itemSpacing: CGFloat = 4

    /// Called after the hosted toolbar visibility changes.
    public var visibilityChanged: ((Bool) -> Void)?

    /// Called when display settings imply a different natural toolbar height.
    public var preferredHeightChanged: ((CGFloat) -> Void)?

    internal var renderedItemViews: [NSView] = []
    internal var lastPreferredHeight: CGFloat?
    /// Rendered strip items with their frames, for right-click hit-testing
    /// (the Mac's per-item "Remove Item" context entry).
    internal var renderedItemHits: [(item: NSToolbarItem, frame: NSRect)] = []
    /// Elastic factor (0...1) applied to custom-view items between their min
    /// and max sizes: a narrow strip shrinks them toward `minSize` before any
    /// item overflows, matching the Mac's shrink-then-overflow behavior.
    internal var winCustomViewShrink: CGFloat = 1

    /// Token for the live appearance-change observer, removed on deinit.
    // The opaque token `NotificationCenter.addObserver(forName:…)` hands back. Typed
    // `Any?` rather than AppKit's `NSObjectProtocol?` because the core shadows
    // that protocol (see Runtime/FoundationBridge.swift) while the token comes
    // from whichever Foundation is underneath. `removeObserver(_:)` takes `Any`
    // on both, and the property is private, so no API surface changes.
    internal var winAppearanceObserver: Any?

    /// Creates a toolbar view.
    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // Blend with the window chrome the way AppKit toolbars extend the
        // title bar; a bottom hairline separates the strip from content.
        winBackgroundColor = .windowBackgroundColor
        // The strip fill is resolved for the current appearance and cached as a
        // brush; re-resolve it on a live system theme switch so the toolbar
        // follows the window chrome instead of staying its old shade.
        winAppearanceObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.winEffectiveAppearanceDidChangeNotification,
            object: nil, queue: nil
        ) { [weak self] _ in
            self?.winBackgroundColor = .windowBackgroundColor
            self?.needsDisplay = true
        }
    }

    deinit {
        if let winAppearanceObserver {
            NotificationCenter.default.removeObserver(winAppearanceObserver)
        }
    }

    /// The separator style after resolving `.automatic` for this presentation.
    internal var resolvedSeparatorStyle: WinToolbarSeparatorStyle {
        switch toolbar?.winSeparatorStyle ?? .automatic {
        case .bar:
            return .bar
        case .space:
            return .space
        case .automatic:
            // Classic Win32 renders a vertical bar; the modern presentation
            // renders a blank gap, matching current Apple toolbars.
            return WinPresentation.selected == .modern ? .space : .bar
        }
    }

    /// Toolbar strips do not take focus; their items do.
    open override var acceptsFirstResponder: Bool {
        false
    }

    /// The brushed-silver chrome gradient shared by the strip and the item
    /// tiles' slice rendering.
    internal static func winMetallicChromeGradient() -> NSGradient? {
        NSGradient(colorsAndLocations:
            (NSColor(calibratedRed: 0.91, green: 0.91, blue: 0.92, alpha: 1.0), 0.0),
            (NSColor(calibratedRed: 0.78, green: 0.78, blue: 0.80, alpha: 1.0), 0.55),
            (NSColor(calibratedRed: 0.70, green: 0.70, blue: 0.72, alpha: 1.0), 1.0)
        )
    }

    /// The gradient's midtone: the erase color behind transparent children in
    /// metallic, so item windows never flash white over the chrome.
    internal static let winMetallicMidtone = NSColor(calibratedRed: 0.80, green: 0.80, blue: 0.82, alpha: 1.0)

    /// Paints the strip chrome for the selected Apple look: `.metallic` draws
    /// the classic brushed silver gradient; `.unified` keeps the flat
    /// background fill.
    open override func draw(_ dirtyRect: NSRect) {
        guard toolbar?.winResolvedAppleLook == .metallic else {
            return
        }
        Self.winMetallicChromeGradient()?.draw(in: bounds, angle: -90)
    }

    /// Right-clicking the toolbar (empty space, or an item — item views don't
    /// consume right-clicks, so they bubble here) pops the Mac toolbar context
    /// menu: the display-mode switches with the current mode checked, and
    /// "Customize Toolbar…" when customization is allowed.
    open override func rightMouseDown(with event: NSEvent) {
        guard let toolbar else {
            super.rightMouseDown(with: event)
            return
        }

        let point = convert(event.locationInWindow, from: nil)
        let hitItem = renderedItemHits.first { NSPointInRect(point, $0.frame) }?.item
        let menu = winToolbarContextMenu(for: toolbar, clickedItem: hitItem)
        _ = menu.popUp(positioning: nil, at: point, in: self)
    }

    /// Builds the Mac toolbar context menu for the current toolbar state; a
    /// right-click that lands on an item prepends "Remove Item" when
    /// customization is allowed, matching the Mac.
    internal func winToolbarContextMenu(for toolbar: NSToolbar, clickedItem: NSToolbarItem? = nil) -> NSMenu {
        let menu = NSMenu(title: "")

        if let clickedItem, toolbar.allowsUserCustomization {
            let remove = NSMenuItem(title: "Remove Item", action: nil, keyEquivalent: "")
            remove.winInternalAction = { [weak toolbar, weak clickedItem] _ in
                guard let toolbar, let clickedItem,
                      let index = toolbar.items.firstIndex(where: { $0 === clickedItem }) else {
                    return
                }
                _ = toolbar.removeItem(at: index)
            }
            menu.addItem(remove)
            menu.addItem(NSMenuItem.separator())
        }
        let currentMode: NSToolbar.DisplayMode = toolbar.displayMode == .default ? .iconAndLabel : toolbar.displayMode

        func addModeItem(_ title: String, _ mode: NSToolbar.DisplayMode) {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.state = currentMode == mode ? .on : .off
            item.winInternalAction = { [weak toolbar] _ in
                toolbar?.displayMode = mode
            }
            menu.addItem(item)
        }
        addModeItem("Icon and Text", .iconAndLabel)
        addModeItem("Icon Only", .iconOnly)
        addModeItem("Text Only", .labelOnly)

        if toolbar.allowsUserCustomization {
            menu.addItem(NSMenuItem.separator())
            let customize = NSMenuItem(title: "Customize Toolbar…", action: nil, keyEquivalent: "")
            customize.winInternalAction = { [weak toolbar] _ in
                toolbar?.runCustomizationPalette(nil)
            }
            menu.addItem(customize)
        }
        return menu
    }

    /// Rebuilds composed toolbar child views from the toolbar model.
    open func reloadItems() {
        guard let toolbar else {
            return
        }

        // The strip's own background is what transparent child windows erase
        // with: in metallic it must be the chrome midtone, never white.
        winBackgroundColor = toolbar.winResolvedAppleLook == .metallic
            ? Self.winMetallicMidtone
            : .windowBackgroundColor
        notifyPreferredHeightIfNeeded()
        rebuildItemViews(for: toolbar)
    }

    /// Returns the natural toolbar strip height for AppKit-style display settings.
    public static func preferredHeight(for toolbar: NSToolbar?) -> CGFloat {
        guard let toolbar else {
            return 40
        }

        let displayMode: NSToolbar.DisplayMode
        switch toolbar.displayMode {
        case .default:
            displayMode = .iconAndLabel
        case .iconAndLabel, .iconOnly, .labelOnly:
            displayMode = toolbar.displayMode
        }
        let hasCustomView = toolbar.items.contains { $0.view != nil }
        let customHeight = toolbar.items.reduce(CGFloat(0)) { height, item in
            guard item.view != nil else {
                return height
            }

            return max(height, min(max(item.minSize.height, item.maxSize.height), item.maxSize.height))
        }

        let baseHeight: CGFloat
        switch displayMode {
        case .default, .iconAndLabel:
            switch toolbar.sizeMode {
            case .small:
                baseHeight = 34
            case .default, .regular:
                baseHeight = 40
            }
        case .iconOnly:
            switch toolbar.sizeMode {
            case .small:
                baseHeight = 26
            case .default, .regular:
                baseHeight = 30
            }
        case .labelOnly:
            switch toolbar.sizeMode {
            case .small:
                baseHeight = 24
            case .default, .regular:
                baseHeight = 26
            }
        }

        guard hasCustomView else {
            return baseHeight
        }

        return max(baseHeight, customHeight + 8)
    }

    /// Creates the native host peer for the composed toolbar.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createView(frame: frame, parent: parent)
    }

    /// Ensures the toolbar host has a native peer and realizes composed children.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        if let toolbar {
            rebuildItemViews(for: toolbar)
        }
        return handle
    }

}
