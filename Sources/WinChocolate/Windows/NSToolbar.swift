/// A toolbar attached to an `NSWindow`.
///
/// This first slice models AppKit's toolbar/item relationship and lets demos or
/// compatibility code render toolbar items through a native Windows toolbar.
/// Future passes will add overflow, images, and a customization sheet matching
/// the classic AppKit toolbar experience.
open class NSToolbar: NSObject {
    /// Display style for toolbar item labels and images.
    public enum DisplayMode: Sendable {
        case `default`
        case iconAndLabel
        case iconOnly
        case labelOnly
    }

    /// Toolbar item sizing mode.
    public enum SizeMode: Sendable {
        case `default`
        case regular
        case small
    }

    /// Unique toolbar identifier.
    public let identifier: String

    /// The toolbar's visible items.
    public private(set) var items: [NSToolbarItem] = []

    /// Whether users can customize this toolbar.
    open var allowsUserCustomization: Bool = false

    /// Whether toolbar customization changes are autosaved.
    open var autosavesConfiguration: Bool = false

    /// Whether the toolbar is visible.
    open var isVisible: Bool = true {
        didSet {
            visibilityDidChange?(isVisible)
        }
    }

    /// Preferred toolbar display mode.
    open var displayMode: DisplayMode = .default

    /// Preferred toolbar size mode.
    open var sizeMode: SizeMode = .default

    /// The window this toolbar is attached to.
    public private(set) weak var window: NSWindow?

    /// Called when `isVisible` changes.
    public var visibilityDidChange: ((Bool) -> Void)?

    /// Called when the toolbar item list changes.
    public var itemsDidChange: (() -> Void)?

    /// Creates a toolbar with an AppKit-style identifier.
    public init(identifier: String) {
        self.identifier = identifier
        super.init()
    }

    /// Adds an item at the end of the toolbar.
    open func addItem(_ item: NSToolbarItem) {
        insertItem(item, at: items.count)
    }

    /// Inserts an item at the requested index.
    open func insertItem(_ item: NSToolbarItem, at index: Int) {
        item.toolbar = nil
        let insertionIndex = min(max(index, 0), items.count)
        items.insert(item, at: insertionIndex)
        item.toolbar = self
        itemsDidChange?()
    }

    /// Removes and returns the item at the given index.
    @discardableResult
    open func removeItem(at index: Int) -> NSToolbarItem? {
        guard items.indices.contains(index) else {
            return nil
        }

        let item = items.remove(at: index)
        item.toolbar = nil
        itemsDidChange?()
        return item
    }

    /// Returns the first item with the given identifier.
    open func item(withIdentifier identifier: NSToolbarItem.Identifier) -> NSToolbarItem? {
        items.first { $0.itemIdentifier == identifier }
    }

    /// Asks visible toolbar renderers to refresh their item state.
    open func validateVisibleItems() {
        itemsDidChange?()
    }

    internal func attach(to window: NSWindow?) {
        self.window = window
    }
}

/// A classic native toolbar renderer.
///
/// AppKit's `NSToolbar` is normally window chrome, not a regular content view.
/// This view hosts the current classic `ToolbarWindow32` peer from the same
/// `NSToolbarItem` model and is owned by `NSWindow` when `window.toolbar` is set.
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
    open var itemHeight: CGFloat = 30

    /// Horizontal padding before the first item.
    open var leadingPadding: CGFloat = 8

    /// Spacing between normal items.
    open var itemSpacing: CGFloat = 4

    /// Called after the hosted toolbar visibility changes.
    public var visibilityChanged: ((Bool) -> Void)?

    /// Creates a toolbar view.
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        backgroundColor = NSColor(calibratedRed: 0.84, green: 0.84, blue: 0.80, alpha: 1.0)
    }

    /// Toolbar strips do not take focus; their items do.
    open override var acceptsFirstResponder: Bool {
        false
    }

    /// Rebuilds the native toolbar items from the toolbar model.
    open func reloadItems() {
        guard let toolbar, let nativeHandle, let realizedBackend else {
            return
        }

        realizedBackend.setToolbarItems(nativeItems(from: toolbar), for: nativeHandle)
    }

    /// Creates the native toolbar peer.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createToolbar(items: toolbar.map(nativeItems(from:)) ?? [], frame: frame, parent: parent)
    }

    /// Ensures the toolbar has a native peer and registers item dispatch.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        backend.registerToolbarAction(for: handle) { [weak self] identifier in
            guard let item = self?.toolbar?.item(withIdentifier: NSToolbarItem.Identifier(rawValue: identifier)) else {
                return
            }

            item.performAction()
        }
        backend.setToolbarItems(toolbar.map(nativeItems(from:)) ?? [], for: handle)
        return handle
    }

    private func nativeItems(from toolbar: NSToolbar) -> [NativeToolbarItem] {
        toolbar.items.map { item in
            switch item.itemIdentifier {
            case .flexibleSpace:
                return NativeToolbarItem(
                    identifier: item.itemIdentifier.rawValue,
                    label: "",
                    isSeparator: true,
                    isFlexibleSpace: true,
                    isEnabled: false
                )
            case .separator, .space:
                return NativeToolbarItem(identifier: item.itemIdentifier.rawValue, label: "", isSeparator: true, isEnabled: false)
            default:
                return NativeToolbarItem(
                    identifier: item.itemIdentifier.rawValue,
                    label: item.label,
                    imageName: item.image?.name,
                    isSeparator: false,
                    isEnabled: item.isEnabled
                )
            }
        }
    }
}

/// Separator line used by composed toolbar rendering.
open class NSToolbarSeparatorView: NSView {
    /// Creates a separator view.
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        backgroundColor = NSColor(calibratedRed: 0.52, green: 0.52, blue: 0.48, alpha: 1.0)
    }

    /// Separators are display-only.
    open override var acceptsFirstResponder: Bool {
        false
    }
}

/// A toolbar item model matching AppKit naming.
open class NSToolbarItem: NSObject {
    /// Toolbar item identifier.
    public struct Identifier: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral {
        /// Raw identifier string.
        public let rawValue: String

        /// Creates an identifier from a raw string.
        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// Creates an identifier from a string literal.
        public init(stringLiteral value: String) {
            self.rawValue = value
        }

        /// Space item identifier.
        public static let space = Identifier(rawValue: "NSToolbarSpaceItem")

        /// Flexible space item identifier.
        public static let flexibleSpace = Identifier(rawValue: "NSToolbarFlexibleSpaceItem")

        /// Separator item identifier.
        public static let separator = Identifier(rawValue: "NSToolbarSeparatorItem")
    }

    /// Toolbar item visibility priority.
    public enum VisibilityPriority: Int, Sendable {
        case standard = 0
        case low = -1000
        case high = 1000
        case user = 2000
    }

    /// The item identifier.
    public let itemIdentifier: Identifier

    /// Primary visible label.
    open var label: String {
        didSet {
            toolbar?.validateVisibleItems()
        }
    }

    /// Label used in customization UI.
    open var paletteLabel: String

    /// Tooltip text.
    open var toolTip: String?

    /// Target object for `action`.
    open weak var target: AnyObject?

    /// Selector sent when the item is activated.
    open var action: Selector?

    /// Custom view for this item.
    open var view: NSView?

    /// Image shown by icon-capable toolbar renderers.
    open var image: NSImage? {
        didSet {
            toolbar?.validateVisibleItems()
        }
    }

    /// Minimum item size.
    open var minSize: NSSize = NSMakeSize(32, 28)

    /// Maximum item size.
    open var maxSize: NSSize = NSMakeSize(160, 28)

    /// Whether this item is enabled.
    open var isEnabled: Bool = true {
        didSet {
            (view as? NSControl)?.isEnabled = isEnabled
            toolbar?.validateVisibleItems()
        }
    }

    /// Visibility priority used when a toolbar overflows.
    open var visibilityPriority: VisibilityPriority = .standard

    /// Swift-native action invoked by `performAction()`.
    open var onAction: ((NSToolbarItem) -> Void)?

    /// The containing toolbar.
    public internal(set) weak var toolbar: NSToolbar?

    /// Creates a toolbar item.
    public init(itemIdentifier: Identifier) {
        self.itemIdentifier = itemIdentifier
        self.label = itemIdentifier.rawValue
        self.paletteLabel = itemIdentifier.rawValue
        self.image = nil
        super.init()
    }

    /// Sends the configured action if possible.
    open func validate() -> Bool {
        isEnabled
    }

    /// Programmatically activates the item.
    open func performAction() {
        guard isEnabled else {
            return
        }

        if let control = view as? NSControl {
            control.sendAction()
            return
        }

        onAction?(self)
    }
}

/// AppKit-compatible toolbar item identifier alias.
public typealias NSToolbarItemIdentifier = NSToolbarItem.Identifier
