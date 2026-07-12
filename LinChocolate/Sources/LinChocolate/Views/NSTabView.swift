import Foundation

/// One page of an `NSTabView`: a label and the view shown when its tab is
/// selected. Mirrors AppKit's `NSTabViewItem` surface minimally.
public final class NSTabViewItem {

    /// Identifier for lookup, as in AppKit (unused by the backend).
    public let identifier: Any?

    /// The tab's title.
    public var label: String = ""

    /// The view displayed when this tab is selected.
    public var view: NSView?

    public init(identifier: Any? = nil) {
        self.identifier = identifier
    }
}

/// AppKit-shaped tabbed container (GtkNotebook). Add fully-built pages with
/// `addTabViewItem(_:)`; switch programmatically with `selectTabViewItem(at:)`.
///
/// Splitting a busy window into tabs also matters for the XQuartz dev loop:
/// software rendering repaints the whole window over the wire, so smaller
/// windows are visibly smoother.
public final class NSTabView: NSView {

    /// The tabs, in the order added.
    public private(set) var tabViewItems: [NSTabViewItem] = []

    /// Index of the selected tab (0-based).
    public private(set) var indexOfSelectedTab: Int = 0

    /// The selected tab's item, if any tabs exist.
    public var selectedTabViewItem: NSTabViewItem? {
        (indexOfSelectedTab >= 0 && indexOfSelectedTab < tabViewItems.count)
            ? tabViewItems[indexOfSelectedTab] : nil
    }

    /// Called when the user switches tabs.
    public var onSelectionChange: ((NSTabView) -> Void)?

    /// Creates an empty tab view.
    public override init(frame: NSRect) {
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createTabView(frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
        backend.setSelectionChangeAction(for: handle) { [weak self] index in
            guard let self else { return }
            self.indexOfSelectedTab = index    // sync silently
            self.onSelectionChange?(self)
        }
    }

    /// Appends `item` as the last tab. The item's `view` should be fully built.
    public func addTabViewItem(_ item: NSTabViewItem) {
        tabViewItems.append(item)
        guard let view = item.view else { return }
        backend.addTabPage(view.handle, label: item.label, to: handle)
    }

    /// Selects the tab at `index`.
    public func selectTabViewItem(at index: Int) {
        indexOfSelectedTab = index
        backend.setSelectedIndex(index, for: handle)
    }
}
