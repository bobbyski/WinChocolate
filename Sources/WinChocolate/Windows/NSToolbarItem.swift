// NSToolbarItem.swift
// The toolbar item model (NSToolbarItem / NSToolbarItemGroup), the Apple-look
// and layout enums, and the composite item view used to render multi-part
// items. Split out of NSToolbar.swift (plan 10.4, large-file review); the
// NSToolbar model and NSToolbarView renderer remain in NSToolbar.swift.

/// The Apple toolbar looks selectable per the phase design note ("support
/// several Apple looks — for example the older metallic style and the modern
/// unified style").
public enum WinToolbarAppleLook: Sendable {
    /// Follow the app-wide presentation (Phase 8): the classic Win32
    /// presentation pairs with the classic **metallic** Mac chrome, the modern
    /// presentation with the flat **unified** look. The default, so a toolbar
    /// tracks the same `--classic`/modern switch as the rest of the app.
    case automatic

    /// The modern flat look: the strip blends with the window chrome.
    case unified

    /// The classic brushed-metal look: a silver vertical gradient chrome.
    case metallic
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

final class NSToolbarCompositeItemView: NSView {
    weak var item: NSToolbarItem?

    /// When the toolbar renders the metallic look, the tile paints its exact
    /// slice of the strip's chrome gradient (strip height + this tile's y
    /// offset) so the chrome reads continuous through the child windows.
    /// Set after creation, so re-resolve the label color (metallic = light
    /// silver strip → dark text; unified dark → light text).
    var metallicSlice: (stripHeight: CGFloat, y: CGFloat)? {
        didSet {
            updateNativeTextColor()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let metallicSlice, winBackgroundColor == nil else {
            return
        }
        // Paint the full strip gradient shifted up by this tile's offset; the
        // child surface clips it to the tile's own slice.
        NSToolbarView.winMetallicChromeGradient()?.draw(
            in: NSMakeRect(0, -metallicSlice.y, frame.size.width, metallicSlice.stripHeight),
            angle: -90
        )
    }

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
        winBackgroundColor = nil
        // The label color contrasts with the strip (light text on a dark strip,
        // dark text on light); re-resolve it on a live system theme switch.
        winAppearanceObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.winEffectiveAppearanceDidChangeNotification,
            object: nil, queue: nil
        ) { [weak self] _ in
            self?.updateNativeTextColor()
            self?.needsDisplay = true
        }
    }

    private var winAppearanceObserver: NSObjectProtocol?

    deinit {
        if let winAppearanceObserver {
            NotificationCenter.default.removeObserver(winAppearanceObserver)
        }
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
        // The label contrasts with the tile's background: the metallic look
        // paints a light silver slice (dark text regardless of appearance),
        // otherwise the tile is transparent over the strip, so a dark
        // appearance needs light text.
        let onDarkStrip = metallicSlice == nil && NSApplication.shared.effectiveAppearance.winIsDark
        let color: NSColor
        if onDarkStrip {
            color = isEnabled ? NSColor(calibratedWhite: 0.92, alpha: 1) : NSColor(calibratedWhite: 0.55, alpha: 1)
        } else {
            color = isEnabled
                ? NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.12, alpha: 1.0)
                : NSColor(calibratedRed: 0.42, green: 0.44, blue: 0.46, alpha: 1.0)
        }
        backend.setTextColor(color, for: handle)
    }
}

extension WinToolbarLabelPosition {
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

/// Lets an action target control a toolbar item's enabled state, matching
/// AppKit's `NSToolbarItemValidation` informal contract: `validate()` asks the
/// item's target and applies the answer to `isEnabled`.
public protocol NSToolbarItemValidation: AnyObject {
    /// Returns whether the item should be enabled right now.
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool
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

        /// Creates an identifier from a string, matching AppKit's
        /// unlabeled convenience spelling.
        public init(_ rawValue: String) {
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

        /// Standard print item; prints the key window's content by default.
        public static let print = Identifier(rawValue: "NSToolbarPrintItem")

        /// Standard show-colors item; opens the shared color panel.
        public static let showColors = Identifier(rawValue: "NSToolbarShowColorsItem")

        /// Standard show-fonts item; opens the shared font panel.
        public static let showFonts = Identifier(rawValue: "NSToolbarShowFontsItem")

        /// Classic customize-toolbar item; runs the customization palette.
        public static let customizeToolbar = Identifier(rawValue: "NSToolbarCustomizeToolbarItem")

        /// Modern toggle-sidebar item (macOS 11 shape). The classic backend
        /// stores the identifier; apps wire the action (AppKit's responder-chain
        /// `toggleSidebar:` is the documented boundary).
        public static let toggleSidebar = Identifier(rawValue: "NSToolbarToggleSidebarItem")

        /// Modern sidebar tracking separator (macOS 11 shape); renders as a gap.
        public static let sidebarTrackingSeparator = Identifier(rawValue: "NSToolbarSidebarTrackingSeparatorItem")

        /// Modern inspector tracking separator (macOS 14 shape); renders as a gap.
        public static let inspectorTrackingSeparator = Identifier(rawValue: "NSToolbarInspectorTrackingSeparatorItem")

        /// Modern toggle-inspector item (macOS 14 shape); like `toggleSidebar`,
        /// the app wires the action to its own inspector pane.
        public static let toggleInspector = Identifier(rawValue: "NSToolbarToggleInspectorItem")

        /// Cloud-sharing item (macOS 10.12 shape). Windows has no macOS
        /// sharing service, so the synthesized item is a labeled placeholder
        /// the app wires to its own sharing UI.
        public static let cloudSharing = Identifier(rawValue: "NSToolbarCloudSharingItem")
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

    /// Title shown by bordered (button-style) items, matching AppKit.
    open var title: String = ""

    /// Whether the item renders as a bordered control (macOS 10.15+ shape).
    /// The classic presentation stores the flag; the modern look will render it.
    open var isBordered: Bool = false

    /// Application-defined integer tag, matching AppKit.
    open var tag: Int = -1

    /// Compact menu representation used when the item moves into the overflow
    /// menu (or text-only menus), matching AppKit's `menuFormRepresentation`.
    open var menuFormRepresentation: NSMenuItem?

    /// Whether `validateVisibleItems()` includes this item, matching AppKit's
    /// `autovalidates` (default `true`).
    open var autovalidates: Bool = true

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
            guard oldValue != isEnabled else {
                return
            }
            (view as? NSControl)?.isEnabled = isEnabled
            toolbar?.validateVisibleItems()
        }
    }

    /// Visibility priority used when a toolbar overflows.
    open var visibilityPriority: VisibilityPriority = .standard

    /// Framework-internal action hook for toolbar chrome the framework builds
    /// itself (standard items, overflow/context menus). Not API: application
    /// toolbar items use real target/action.
    var winInternalAction: ((NSToolbarItem) -> Void)?

    /// The containing toolbar.
    public internal(set) weak var toolbar: NSToolbar?

    /// The group this item belongs to as a subitem, if any — activation then
    /// routes through the group (selection + group action), matching AppKit.
    internal weak var winGroup: NSToolbarItemGroup?

    /// This item's index within its group's `subitems`.
    internal var winGroupIndex: Int = -1

    /// Creates a toolbar item.
    public init(itemIdentifier: Identifier) {
        self.itemIdentifier = itemIdentifier
        self.label = itemIdentifier.rawValue
        self.paletteLabel = itemIdentifier.rawValue
        self.image = nil
        super.init()
    }

    /// Refreshes `isEnabled` from the item's target, matching AppKit's
    /// `validate()`: a target adopting `NSToolbarItemValidation` decides the
    /// enabled state; view-based items and targetless items are left alone.
    open func validate() {
        guard view == nil else {
            return
        }
        guard let validator = target as? NSToolbarItemValidation else {
            return
        }
        let valid = validator.validateToolbarItem(self)
        if valid != isEnabled {
            isEnabled = valid
        }
    }

    /// Programmatically activates the item.
    open func performAction() {
        guard isEnabled else {
            return
        }

        // A group subitem routes through its group: selection state updates
        // per the group's mode, then the group's action fires (AppKit shape).
        if let group = winGroup, winGroupIndex >= 0 {
            group.winSubitemActivated(at: winGroupIndex)
            return
        }

        if let control = view as? NSControl {
            control.sendAction()
            return
        }

        // Real AppKit dispatch: the item's action selector goes to its
        // target (or the responder chain when the target is nil).
        if let action {
            _ = NSApplication.shared.sendAction(action, to: target, from: self)
        }

        winInternalAction?(self)
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

/// A toolbar item composed of adjacent subitems, matching AppKit's
/// `NSToolbarItemGroup`: subitems render side by side, and activation updates
/// the group's selection per its `selectionMode` before firing the group's
/// action.
open class NSToolbarItemGroup: NSToolbarItem {
    /// How subitem activation affects the group's selection, matching AppKit.
    public enum SelectionMode: Sendable {
        /// Exactly one subitem is selected at a time (radio behavior).
        case selectOne

        /// Any combination of subitems may be selected (toggle behavior).
        case selectAny

        /// Activation fires the action without persisting a selection.
        case momentary
    }

    /// The grouped subitems, rendered side by side.
    open var subitems: [NSToolbarItem] = [] {
        didSet {
            adoptSubitems()
        }
    }

    /// Wires the subitems' group back-references and prunes stale selection.
    /// Called from `didSet` and explicitly from initializers (Swift property
    /// observers do not fire during initialization).
    private func adoptSubitems() {
        for (index, subitem) in subitems.enumerated() {
            subitem.winGroup = self
            subitem.winGroupIndex = index
        }
        selectedIndexes = selectedIndexes.filter { subitems.indices.contains($0) }
        toolbar?.validateVisibleItems()
    }

    /// How activation affects selection.
    open var selectionMode: SelectionMode = .momentary

    private var selectedIndexes: Set<Int> = []

    /// The selected subitem index for `selectOne` groups (the lowest selected
    /// index otherwise), or `-1` when nothing is selected. Matches AppKit.
    open var selectedIndex: Int {
        get {
            selectedIndexes.min() ?? -1
        }
        set {
            selectedIndexes = subitems.indices.contains(newValue) ? [newValue] : []
            toolbar?.validateVisibleItems()
        }
    }

    /// Sets a subitem's selected state, matching AppKit's `setSelected(_:at:)`.
    open func setSelected(_ selected: Bool, at index: Int) {
        guard subitems.indices.contains(index) else {
            return
        }
        if selected {
            if selectionMode == .selectOne {
                selectedIndexes = [index]
            } else {
                selectedIndexes.insert(index)
            }
        } else {
            selectedIndexes.remove(index)
        }
        toolbar?.validateVisibleItems()
    }

    /// Whether a subitem is selected, matching AppKit's `isSelected(at:)`.
    open func isSelected(at index: Int) -> Bool {
        selectedIndexes.contains(index)
    }

    /// Creates a group whose subitems are built from titles, matching AppKit's
    /// convenience shape (labels default to the titles).
    public convenience init(
        itemIdentifier: NSToolbarItem.Identifier,
        titles: [String],
        selectionMode: SelectionMode,
        labels: [String]? = nil,
        target: AnyObject? = nil,
        action: Selector? = nil
    ) {
        self.init(itemIdentifier: itemIdentifier)
        self.selectionMode = selectionMode
        self.target = target
        self.action = action
        self.subitems = titles.enumerated().map { index, title in
            let subitem = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier(rawValue: "\(itemIdentifier.rawValue)#\(index)"))
            subitem.label = labels?.indices.contains(index) == true ? labels![index] : title
            subitem.title = title
            return subitem
        }
        // Property observers do not fire inside initializers; wire explicitly.
        adoptSubitems()
    }

    /// A subitem was activated: update the selection per the mode, then fire
    /// the group's action.
    internal func winSubitemActivated(at index: Int) {
        guard isEnabled, subitems.indices.contains(index) else {
            return
        }
        switch selectionMode {
        case .selectOne:
            selectedIndexes = [index]
        case .selectAny:
            if selectedIndexes.contains(index) {
                selectedIndexes.remove(index)
            } else {
                selectedIndexes.insert(index)
            }
        case .momentary:
            break
        }
        toolbar?.validateVisibleItems()
        if let action {
            _ = NSApplication.shared.sendAction(action, to: target, from: self)
        }
        winInternalAction?(self)
    }
}

/// AppKit-compatible toolbar item identifier alias.
public typealias NSToolbarItemIdentifier = NSToolbarItem.Identifier
