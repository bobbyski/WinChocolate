/// Provides AppKit-compatible toolbar item customization hooks.
public protocol NSToolbarDelegate: AnyObject {
    /// Returns the identifiers allowed in the toolbar customization palette.
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier]

    /// Returns the default toolbar identifiers.
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier]

    /// Returns an item for an identifier that may be inserted into the toolbar.
    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem?
}

public extension NSToolbarDelegate {
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbar.items.map(\.itemIdentifier)
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbar.items.map(\.itemIdentifier)
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        toolbar.item(withIdentifier: itemIdentifier)
    }
}

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

    /// Object that supplies AppKit-style customization identifiers and items.
    open weak var delegate: NSToolbarDelegate?

    /// Whether toolbar customization changes are autosaved.
    open var autosavesConfiguration: Bool = false

    /// Whether the toolbar is visible.
    open var isVisible: Bool = true {
        didSet {
            visibilityDidChange?(isVisible)
        }
    }

    /// Preferred toolbar display mode.
    open var displayMode: DisplayMode = .default {
        didSet {
            itemsDidChange?()
        }
    }

    /// Preferred toolbar size mode.
    open var sizeMode: SizeMode = .default {
        didSet {
            itemsDidChange?()
        }
    }

    /// WinChocolate-specific separator rendering override.
    ///
    /// Apple has varied separator appearance across macOS releases, so prefer
    /// `.automatic`, which follows the active presentation: the classic Win32
    /// look renders a vertical bar and the future modern look will render a
    /// blank gap. Overriding this in application code is discouraged.
    open var winSeparatorStyle: WinToolbarSeparatorStyle = .automatic {
        didSet {
            itemsDidChange?()
        }
    }

    /// The window this toolbar is attached to.
    public private(set) weak var window: NSWindow?

    /// Called when `isVisible` changes.
    public var visibilityDidChange: ((Bool) -> Void)?

    /// Called when the toolbar item list changes.
    public var itemsDidChange: (() -> Void)?

    private var itemStore: [NSToolbarItem.Identifier: NSToolbarItem] = [:]
    private var customizationPanel: NSPanel?

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
        itemStore[item.itemIdentifier] = item
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
        items.first { $0.itemIdentifier == identifier } ?? itemStore[identifier]
    }

    /// Asks visible toolbar renderers to refresh their item state.
    open func validateVisibleItems() {
        itemsDidChange?()
    }

    /// Replaces visible toolbar items with the supplied identifiers.
    open func setVisibleItemIdentifiers(_ identifiers: [NSToolbarItem.Identifier]) {
        let replacementItems = identifiers.compactMap { identifier -> NSToolbarItem? in
            itemForVisibleIdentifier(identifier, willBeInsertedIntoToolbar: true)
        }

        for item in items {
            item.toolbar = nil
        }

        items = replacementItems
        for item in items {
            item.toolbar = self
        }
        itemsDidChange?()
    }

    /// Inserts an item by identifier, matching AppKit's customization pathway.
    open func insertItem(withItemIdentifier itemIdentifier: NSToolbarItem.Identifier, at index: Int) {
        guard let item = itemForVisibleIdentifier(itemIdentifier, willBeInsertedIntoToolbar: true) else {
            return
        }

        insertItem(item, at: index)
    }

    /// Restores the delegate-provided default visible toolbar items.
    open func resetVisibleItemsToDefault() {
        let identifiers = delegate?.toolbarDefaultItemIdentifiers(self) ?? itemStore.keys.map { $0 }
        setVisibleItemIdentifiers(identifiers)
    }

    /// Opens the Apple-style toolbar customization palette.
    open func runCustomizationPalette(_ sender: Any?) {
        guard allowsUserCustomization else {
            return
        }

        let panel = NSToolbarCustomizationPanel(toolbar: self)
        customizationPanel = panel
        panel.makeKeyAndOrderFront(sender)
    }

    /// Allowed customization identifiers from the delegate or the item store.
    internal var customizationAllowedIdentifiers: [NSToolbarItem.Identifier] {
        delegate?.toolbarAllowedItemIdentifiers(self) ?? itemStore.keys.map { $0 }
    }

    /// Default customization identifiers from the delegate or the item store.
    internal var customizationDefaultIdentifiers: [NSToolbarItem.Identifier] {
        delegate?.toolbarDefaultItemIdentifiers(self) ?? itemStore.keys.map { $0 }
    }

    internal func itemForCustomizationIdentifier(
        _ identifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        if let existing = itemStore[identifier] {
            return existing
        }

        guard let item = delegate?.toolbar(self, itemForItemIdentifier: identifier, willBeInsertedIntoToolbar: flag) else {
            return nil
        }

        itemStore[identifier] = item
        return item
    }

    private func itemForVisibleIdentifier(
        _ identifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard identifier.allowsMultipleToolbarInstances else {
            return itemForCustomizationIdentifier(identifier, willBeInsertedIntoToolbar: flag)
        }

        if let item = delegate?.toolbar(self, itemForItemIdentifier: identifier, willBeInsertedIntoToolbar: flag),
           item.itemIdentifier == identifier,
           item.toolbar == nil,
           !items.contains(where: { $0 === item }) {
            return item
        }

        return NSToolbarItem(itemIdentifier: identifier)
    }

    internal func attach(to window: NSWindow?) {
        self.window = window
    }
}

internal extension NSToolbarItem.Identifier {
    /// Whether the identifier may appear multiple times in one toolbar.
    var allowsMultipleToolbarInstances: Bool {
        switch self {
        case .separator, .space, .flexibleSpace:
            return true
        default:
            return false
        }
    }
}

/// A composed AppKit-style toolbar renderer.
///
/// AppKit's `NSToolbar` is normally window chrome, not a regular content view.
/// This view renders `NSToolbarItem` values as ordinary WinChocolate child
/// views so custom items, separators, and standard controls share one layout
/// model instead of overlaying native toolbar placeholders.
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

    private var renderedItemViews: [NSView] = []
    private var lastPreferredHeight: CGFloat?

    /// Creates a toolbar view.
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // Blend with the window chrome the way AppKit toolbars extend the
        // title bar; a bottom hairline separates the strip from content.
        backgroundColor = .windowBackgroundColor
    }

    /// The separator style after resolving `.automatic` for this presentation.
    private var resolvedSeparatorStyle: WinToolbarSeparatorStyle {
        switch toolbar?.winSeparatorStyle ?? .automatic {
        case .bar:
            return .bar
        case .space:
            return .space
        case .automatic:
            // Classic Win32 presentation; the modern look will resolve to `.space`.
            return .bar
        }
    }

    /// Toolbar strips do not take focus; their items do.
    open override var acceptsFirstResponder: Bool {
        false
    }

    /// Rebuilds composed toolbar child views from the toolbar model.
    open func reloadItems() {
        guard let toolbar else {
            return
        }

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

    private func rebuildItemViews(for toolbar: NSToolbar) {
        for renderedView in renderedItemViews {
            renderedView.removeFromSuperview()
        }
        renderedItemViews.removeAll()

        let layout = itemLayout(for: toolbar)
        for entry in layout {
            switch entry.kind {
            case .standard(let item):
                let compositeView = item.winCompositeView(
                    showItem: toolbar.displayMode != .labelOnly,
                    showLabel: toolbar.displayMode != .iconOnly,
                    toolbarHeight: frame.size.height
                )
                compositeView.frame = entry.frame
                addRenderedSubview(compositeView)
            case .custom(let item, let view):
                applyToolbarControlAppearance(to: view)
                view.frame = entry.frame
                view.toolTip = item.toolTip ?? view.toolTip
                if let control = view as? NSControl {
                    control.isEnabled = item.isEnabled
                }
                addRenderedSubview(view)
                applyRealizedToolbarControlAppearance(to: view)
            case .separator:
                let separatorItem = NSToolbarItem(itemIdentifier: .separator)
                let separatorView = separatorItem.winCompositeView(
                    showItem: true,
                    showLabel: false,
                    toolbarHeight: frame.size.height
                )
                separatorView.frame = entry.frame
                addRenderedSubview(separatorView)
            case .space:
                let spaceView = NSView(frame: entry.frame)
                addRenderedSubview(spaceView)
            }
        }

        // Chrome hairline separating the toolbar strip from window content.
        // Added after the item views so item indices stay stable for callers.
        let bottomEdge = NSView(frame: NSMakeRect(0, max(frame.size.height - 1, 0), frame.size.width, 1))
        bottomEdge.backgroundColor = NSColor(calibratedRed: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)
        bottomEdge.autoresizingMask = [.width]
        addSubview(bottomEdge)
        renderedItemViews.append(bottomEdge)
    }

    private func addRenderedSubview(_ view: NSView) {
        addSubview(view)
        // Separator bars and editable fields draw their own backgrounds.
        let keepsOwnBackground = view is NSToolbarSeparatorView || ((view as? NSTextField)?.isEditable ?? false)
        if !keepsOwnBackground {
            applyRealizedTransparentBackground(to: view)
        }
        renderedItemViews.append(view)
    }

    private func applyToolbarControlAppearance(to view: NSView) {
        view.backgroundColor = nil

        // Label-style text fields blend into the toolbar strip; editable
        // fields (search fields, text entries) keep their border and
        // background the way AppKit toolbar search fields do.
        if let textField = view as? NSTextField, !textField.isEditable {
            textField.isBordered = false
            textField.drawsBackground = false
        }
    }

    private func applyRealizedToolbarControlAppearance(to view: NSView) {
        guard let nativeHandle = view.nativeHandle, let backend = view.realizedBackend else {
            return
        }

        if let textField = view as? NSTextField, textField.isEditable {
            return
        }

        if view is NSTextField || view is NSPopUpButton {
            backend.setBackgroundColor(nil, for: nativeHandle)
            backend.setDrawsBackground(false, for: nativeHandle)
        }
    }

    private func applyRealizedTransparentBackground(to view: NSView) {
        guard let nativeHandle = view.nativeHandle, let backend = view.realizedBackend else {
            return
        }

        backend.setBackgroundColor(nil, for: nativeHandle)
        backend.setDrawsBackground(false, for: nativeHandle)
    }

    private enum RenderedItemKind {
        case standard(NSToolbarItem)
        case custom(NSToolbarItem, NSView)
        case separator
        case space
    }

    private struct RenderedItemLayout {
        var kind: RenderedItemKind
        var frame: NSRect
    }

    private func itemLayout(for toolbar: NSToolbar) -> [RenderedItemLayout] {
        let flexibleCount = toolbar.items.filter { $0.itemIdentifier == .flexibleSpace }.count
        let fixedWidth = toolbar.items.reduce(CGFloat(0)) { width, item in
            if item.itemIdentifier == .flexibleSpace {
                return width
            }
            return width + displayWidth(for: item, in: toolbar)
        }
        let fixedSpacing = max(CGFloat(toolbar.items.count - 1), 0) * itemSpacing
        let availableFlexibleWidth = max(24, frame.size.width - (leadingPadding * 2) - fixedWidth - fixedSpacing)
        let flexibleWidth = flexibleCount > 0 ? max(24, availableFlexibleWidth / CGFloat(flexibleCount)) : 24
        var x = leadingPadding
        var layout: [RenderedItemLayout] = []

        for item in toolbar.items {
            let width = item.itemIdentifier == .flexibleSpace ? flexibleWidth : displayWidth(for: item, in: toolbar)
            let height = displayHeight(for: item)
            let y = max((frame.size.height - height) / 2, 0)
            let itemFrame = NSMakeRect(x, y, width, height)

            if let view = item.view {
                layout.append(RenderedItemLayout(kind: .custom(item, view), frame: itemFrame))
            } else if item.itemIdentifier == .separator {
                if resolvedSeparatorStyle == .space {
                    layout.append(RenderedItemLayout(kind: .space, frame: itemFrame))
                } else {
                    layout.append(RenderedItemLayout(kind: .separator, frame: NSMakeRect(x + ((width - 2) / 2), 6, 2, max(frame.size.height - 12, 8))))
                }
            } else if item.itemIdentifier == .space || item.itemIdentifier == .flexibleSpace {
                layout.append(RenderedItemLayout(kind: .space, frame: itemFrame))
            } else {
                layout.append(RenderedItemLayout(kind: .standard(item), frame: itemFrame))
            }

            x += width + itemSpacing
        }

        return layout
    }

    private func notifyPreferredHeightIfNeeded() {
        let height = preferredHeight
        guard lastPreferredHeight != height else {
            return
        }

        lastPreferredHeight = height
        preferredHeightChanged?(height)
    }

    private func displayWidth(for item: NSToolbarItem, in toolbar: NSToolbar) -> CGFloat {
        if item.itemIdentifier == .flexibleSpace {
            return 24
        }
        if item.itemIdentifier == .separator {
            // A bar keeps a little whitespace on either side; a space is a
            // wider blank gap, matching Apple's varied separator treatments.
            return resolvedSeparatorStyle == .space ? 24 : 16
        }
        if item.itemIdentifier == .space {
            return 8
        }
        if item.view != nil {
            return max(item.minSize.width, min(item.maxSize.width, item.maxSize.width))
        }

        let mode: NSToolbar.DisplayMode
        switch toolbar.displayMode {
        case .default:
            mode = .iconAndLabel
        case .iconAndLabel, .iconOnly, .labelOnly:
            mode = toolbar.displayMode
        }
        let showsLabel = mode != .iconOnly
        let showsImage = mode != .labelOnly
        let iconWidth: CGFloat = showsImage && item.image != nil ? 24 : 0
        let labelWidth = showsLabel ? CGFloat(max(28, item.label.count * 6)) : 0
        let naturalWidth = max(iconWidth, labelWidth) + 16
        return max(item.minSize.width, min(item.maxSize.width, naturalWidth))
    }

    private func displayHeight(for item: NSToolbarItem) -> CGFloat {
        if item.itemIdentifier == .separator {
            return max(frame.size.height - 16, 8)
        }
        if item.itemIdentifier == .space || item.itemIdentifier == .flexibleSpace {
            return max(frame.size.height - 8, 8)
        }
        if item.view == nil {
            return max(frame.size.height - 6, 8)
        }
        return min(max(frame.size.height - 6, 20), max(20, item.maxSize.height))
    }

}

/// Separator line used by composed toolbar rendering.
open class NSToolbarSeparatorView: NSView {
    /// Creates a separator view.
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // The view itself is the thin vertical bar; layout centers it inside
        // a wider separator slot so whitespace frames it on either side.
        backgroundColor = NSColor(calibratedRed: 0.66, green: 0.66, blue: 0.66, alpha: 1.0)
    }

    /// Separators are display-only.
    open override var acceptsFirstResponder: Bool {
        false
    }

    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = backend.createView(frame: frame, parent: parent)
        backend.setText(" \nseparator", for: handle)
        backend.setDrawsBackground(false, for: handle)
        return handle
    }
}

/// WinChocolate-specific rendering style for toolbar separator items.
public enum WinToolbarSeparatorStyle: Sendable {
    /// Follow the active presentation: classic Win32 renders a bar, the
    /// future modern look renders a blank gap.
    case automatic

    /// A vertical bar with a little whitespace on either side.
    case bar

    /// A blank gap.
    case space
}

/// Position of a toolbar item's label relative to its item image or view.
public enum WinToolbarLabelPosition: Sendable {
    /// Place the label below the item image or view.
    case below

    /// Place the label above the item image or view.
    case above

    /// Place the label to the left of the item image or view.
    case left

    /// Place the label to the right of the item image or view.
    case right
}

/// WinChocolate-specific representation used while dragging a toolbar item.
public enum WinToolbarDragRepresentation {
    /// Use an image as the drag representation.
    case image(NSImage)

    /// Use a view as the drag representation.
    case view(NSView)
}

private final class NSToolbarCompositeItemView: NSView {
    weak var item: NSToolbarItem?
    var title: String {
        didSet {
            updateNativeText()
        }
    }
    var imageName: String {
        didSet {
            updateNativeText()
        }
    }
    var showItem: Bool {
        didSet {
            updateNativeText()
        }
    }
    var showLabel: Bool {
        didSet {
            updateNativeText()
        }
    }
    var labelLocation: WinToolbarLabelPosition {
        didSet {
            updateNativeText()
        }
    }
    var isEnabled: Bool {
        didSet {
            updateNativeTextColor()
        }
    }

    init(
        item: NSToolbarItem,
        title: String,
        imageName: String,
        showItem: Bool,
        showLabel: Bool,
        labelLocation: WinToolbarLabelPosition,
        frame frameRect: NSRect
    ) {
        self.item = item
        self.title = title
        self.imageName = imageName
        self.showItem = showItem
        self.showLabel = showLabel
        self.labelLocation = labelLocation
        self.isEnabled = item.isEnabled
        super.init(frame: frameRect)
        toolTip = item.toolTip
        backgroundColor = nil
    }

    override var acceptsFirstResponder: Bool {
        false
    }

    override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = backend.createView(frame: frame, parent: parent)
        backend.setText(nativeText, for: handle)
        backend.setDrawsBackground(false, for: handle)
        updateNativeTextColor(for: handle, backend: backend)
        return handle
    }

    override func mouseUp(with event: NSEvent) {
        item?.performAction()
    }

    private var nativeText: String {
        [
            "__WinChocolateToolbarItem",
            title,
            imageName,
            showItem ? "1" : "0",
            showLabel ? "1" : "0",
            labelLocation.nativeName
        ].joined(separator: "\t")
    }

    private func updateNativeText() {
        guard let nativeHandle else {
            return
        }

        realizedBackend?.setText(nativeText, for: nativeHandle)
    }

    private func updateNativeTextColor() {
        guard let nativeHandle, let realizedBackend else {
            return
        }

        updateNativeTextColor(for: nativeHandle, backend: realizedBackend)
    }

    private func updateNativeTextColor(for handle: NativeHandle, backend: NativeControlBackend) {
        let color = isEnabled
            ? NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.12, alpha: 1.0)
            : NSColor(calibratedRed: 0.42, green: 0.44, blue: 0.46, alpha: 1.0)
        backend.setTextColor(color, for: handle)
    }
}

private extension WinToolbarLabelPosition {
    var nativeName: String {
        switch self {
        case .below:
            return "below"
        case .above:
            return "above"
        case .left:
            return "left"
        case .right:
            return "right"
        }
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

    /// WinChocolate-specific image shown for this item in the customization palette.
    open var winImageForPallate: NSImage?

    /// WinChocolate-specific image or view used as this item's drag representation.
    open var winRenderForDrag: WinToolbarDragRepresentation?

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

    /// Creates a transparent composite view for this item in a toolbar.
    open func winCompositeView(
        showItem: Bool,
        showLabel: Bool,
        winLabelLocation: WinToolbarLabelPosition = .below,
        toolbarHeight: CGFloat
    ) -> NSView {
        if itemIdentifier == .separator {
            let separatorView = NSToolbarSeparatorView(frame: NSMakeRect(0, 0, 8, max(toolbarHeight - 12, 8)))
            separatorView.toolTip = toolTip
            return separatorView
        }

        let imageSize = NSMakeSize(24, 20)
        let labelSize = showLabel ? NSMakeSize(max(28, CGFloat(label.count * 6)), 13) : NSMakeSize(0, 0)
        let gap: CGFloat = showItem && showLabel ? 2 : 0
        let itemSize = showItem ? imageSize : NSMakeSize(0, 0)
        let horizontal = winLabelLocation == .left || winLabelLocation == .right
        let width = horizontal
            ? itemSize.width + labelSize.width + gap + 8
            : max(itemSize.width, labelSize.width) + 8
        let contentHeight = horizontal
            ? max(itemSize.height, labelSize.height)
            : itemSize.height + labelSize.height + gap
        let height = min(max(contentHeight + 4, 20), max(toolbarHeight, 20))
        return NSToolbarCompositeItemView(
            item: self,
            title: label,
            imageName: winToolbarImageName,
            showItem: showItem,
            showLabel: showLabel,
            labelLocation: winLabelLocation,
            frame: NSMakeRect(0, 0, width, height)
        )
    }

    private var winToolbarImageName: String {
        if let name = (image ?? winImageForPallate)?.name, !name.isEmpty {
            return name
        }

        return itemIdentifier.rawValue
    }
}

/// AppKit-compatible toolbar item identifier alias.
public typealias NSToolbarItemIdentifier = NSToolbarItem.Identifier
