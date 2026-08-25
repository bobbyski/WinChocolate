// The controller-shaped face of a split view (R25).
//
// AppKit has two ways to build the same thing. `NSSplitView` takes views and
// divider positions; `NSSplitViewController` takes *view controllers* wrapped
// in `NSSplitViewItem`s, and each item carries the behaviour that used to be
// delegate work — a sidebar that collapses, thickness limits, whether the
// titlebar draws a separator over it.
//
// The controller form is what modern AppKit code writes, so a framework that
// only offered the view form would push every port back through a rewrite it
// should not need. This is the controller form over the split view that already
// exists: the items own the policy, the split view owns the geometry.

/// One pane of a split view controller, and the policy attached to it.
open class NSSplitViewItem: NSObject {
    /// How the titlebar separator is drawn above this item.
    public enum TitlebarSeparatorStyle: Sendable {
        /// Let the system decide, which is what a sidebar item wants.
        case automatic
        /// No separator.
        case none
        /// A hairline separator.
        case line
        /// A shadow under the titlebar.
        case shadow
    }

    /// The controller whose view fills this pane.
    open var viewController: NSViewController

    /// Whether this pane is the window's sidebar.
    ///
    /// A sidebar collapses, and on AppKit it also takes the source-list
    /// appearance and the full-height layout. Here it carries the collapse
    /// behaviour and the layout intent; the appearance is the stylesheet's job
    /// (`ACTIVE_UI_CSS.md`), which is a better place for it anyway.
    open var isSidebar: Bool = false

    /// Whether the pane is currently collapsed to nothing.
    open var isCollapsed: Bool = false {
        didSet {
            guard isCollapsed != oldValue else { return }
            splitViewController?.applyItemGeometry()
        }
    }

    /// Whether a user can collapse this pane by dragging its divider.
    open var canCollapse: Bool = true

    /// The smallest thickness the pane may be given, or 0 for no limit.
    open var minimumThickness: CGFloat = 0 {
        didSet { splitViewController?.applyItemGeometry() }
    }

    /// The largest thickness the pane may be given, or 0 for no limit.
    open var maximumThickness: CGFloat = 0 {
        didSet { splitViewController?.applyItemGeometry() }
    }

    /// Whether the pane extends under the titlebar.
    ///
    /// Stored: no Chocolate backend draws content under its window chrome, so
    /// the pane starts below the titlebar either way. The value survives so a
    /// backend that grows the capability can read the intent rather than having
    /// to be told again.
    open var allowsFullHeightLayout: Bool = false

    /// How the titlebar separator is drawn above this pane.
    open var titlebarSeparatorStyle: TitlebarSeparatorStyle = .automatic

    /// The controller this item belongs to, set when it is added.
    internal weak var splitViewController: NSSplitViewController?

    /// Creates an item hosting a controller.
    public init(viewController: NSViewController) {
        self.viewController = viewController
        super.init()
    }

    /// Creates a sidebar item hosting a controller.
    public convenience init(sidebarWithViewController viewController: NSViewController) {
        self.init(viewController: viewController)
        isSidebar = true
    }

    /// Creates a content-list item hosting a controller.
    ///
    /// AppKit distinguishes this from a plain item only in its default
    /// behaviour, which is what is reproduced here.
    public convenience init(contentListWithViewController viewController: NSViewController) {
        self.init(viewController: viewController)
    }

    /// Creates a trailing inspector item hosting a controller.
    public convenience init(inspectorWithViewController viewController: NSViewController) {
        self.init(viewController: viewController)
        isInspector = true
    }

    /// Whether this pane is the window's trailing inspector.
    open var isInspector: Bool = false

    /// The animating proxy for this item's properties.
    ///
    /// AppKit's `animator()` returns a proxy that animates whatever you set on
    /// it; `item.animator().isCollapsed.toggle()` is the idiomatic way to
    /// collapse a pane with the system animation. No Chocolate backend animates
    /// a split collapse, so the proxy is the item itself: the property changes,
    /// the pane collapses, and it simply does so at once. Every caller written
    /// against AppKit keeps working, which is the point of returning something
    /// rather than nothing.
    open func animator() -> NSSplitViewItem { self }
}

/// A view controller that arranges child controllers in a split view.
open class NSSplitViewController: NSViewController {
    /// The panes, in leading-to-trailing order.
    open private(set) var splitViewItems: [NSSplitViewItem] = []

    /// The split view the items are arranged in.
    open var splitView: NSSplitView {
        winSplitView
    }

    private let winSplitView: NSSplitView

    /// Creates an empty split view controller.
    ///
    /// The split view *is* the controller's root view, as in AppKit — which is
    /// why `super.init(view:)` is used rather than assigning afterwards: the
    /// responder chain is wired once, at the point the view is adopted.
    public init() {
        let splitView = NSSplitView(frame: NSMakeRect(0, 0, 640, 400))
        self.winSplitView = splitView
        super.init(view: splitView)
    }

    /// Adds a pane at the end.
    open func addSplitViewItem(_ splitViewItem: NSSplitViewItem) {
        insertSplitViewItem(splitViewItem, at: splitViewItems.count)
    }

    /// Inserts a pane at an index.
    open func insertSplitViewItem(_ splitViewItem: NSSplitViewItem, at index: Int) {
        let position = max(0, min(index, splitViewItems.count))
        splitViewItem.splitViewController = self
        splitViewItems.insert(splitViewItem, at: position)
        winSplitView.addArrangedSubview(splitViewItem.viewController.view)
        applyItemGeometry()
    }

    /// Removes a pane.
    open func removeSplitViewItem(_ splitViewItem: NSSplitViewItem) {
        guard let index = splitViewItems.firstIndex(where: { $0 === splitViewItem }) else { return }
        splitViewItems.remove(at: index)
        splitViewItem.splitViewController = nil
        splitViewItem.viewController.view.removeFromSuperview()
        applyItemGeometry()
    }

    /// Collapses or expands the sidebar item.
    ///
    /// AppKit's action, sent by the system toolbar item and by View ▸ Hide
    /// Sidebar. Toggling the item directly does the same thing; this exists so
    /// menu and toolbar wiring written against the action keeps working.
    open func toggleSidebar(_ sender: Any?) {
        guard let sidebar = splitViewItems.first(where: { $0.isSidebar }) else { return }
        sidebar.isCollapsed.toggle()
    }

    /// Collapses or expands the inspector item.
    open func toggleInspector(_ sender: Any?) {
        guard let inspector = splitViewItems.first(where: { $0.isInspector }) else { return }
        inspector.isCollapsed.toggle()
    }

    /// The item hosting a controller, if it is one of this controller's.
    open func splitViewItem(for viewController: NSViewController) -> NSSplitViewItem? {
        splitViewItems.first { $0.viewController === viewController }
    }

    /// Pushes each item's thickness limits and collapsed state onto the split
    /// view, which owns the geometry.
    ///
    /// Internal rather than private: the items call it from their own `didSet`,
    /// which is what makes `item.minimumThickness = 180` take effect rather
    /// than merely be recorded.
    internal func applyItemGeometry() {
        for (index, item) in splitViewItems.enumerated() {
            let pane = item.viewController.view
            pane.isHidden = item.isCollapsed
            guard index < splitViewItems.count - 1, !item.isCollapsed else { continue }
            if item.minimumThickness > 0 {
                winSplitView.setPosition(item.minimumThickness, ofDividerAt: index)
            }
        }
        winSplitView.needsLayout = true
    }
}
