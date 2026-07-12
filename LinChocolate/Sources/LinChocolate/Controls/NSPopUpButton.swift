import Foundation

/// AppKit-shaped pop-up (dropdown) button (GtkDropDown). Holds a fixed list of
/// item titles and reports selection changes through `onSelectionChange`.
public final class NSPopUpButton: NSView {

    /// The menu item titles, in order.
    public let itemTitles: [String]

    private var backingIndex: Int

    /// The index of the selected item (−1 if the list is empty).
    public var indexOfSelectedItem: Int {
        get { backingIndex }
        set {
            backingIndex = newValue
            backend.setSelectedIndex(newValue, for: handle)
        }
    }

    /// The title of the selected item, if any.
    public var titleOfSelectedItem: String? {
        (backingIndex >= 0 && backingIndex < itemTitles.count) ? itemTitles[backingIndex] : nil
    }

    /// Called when the user picks a different item.
    public var onSelectionChange: ((NSPopUpButton) -> Void)?

    /// Whether the button is a pull-down menu (accepted for API parity).
    public var pullsDown: Bool = false
    private var itemTags: [Int: Int] = [:]
    public func setTag(_ tag: Int, forItemAt index: Int) { itemTags[index] = tag }
    public func tag(atIndex index: Int) -> Int { itemTags[index] ?? 0 }
    /// The tag of the selected item (AppKit's `selectedTag()` method form).
    public func selectedTag() -> Int { itemTags[indexOfSelectedItem] ?? 0 }

    /// Creates an empty pop-up button (AppKit's `init(frame:pullsDown:)`).
    public convenience init(frame: NSRect, pullsDown: Bool) {
        self.init(items: [], frame: frame)
        self.pullsDown = pullsDown
    }

    /// Creates a pop-up button showing `items` (first item selected).
    public init(items: [String], frame: NSRect) {
        self.itemTitles = items
        self.backingIndex = items.isEmpty ? -1 : 0
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createPopUpButton(items: items, selectedIndex: backingIndex, frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
        backend.setSelectionChangeAction(for: handle) { [weak self] index in
            guard let self else { return }
            self.backingIndex = index          // sync silently
            self.onSelectionChange?(self)
        }
    }
}
