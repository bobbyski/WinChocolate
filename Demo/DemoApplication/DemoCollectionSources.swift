// Part of the shared demo, split out of main.swift by topic.
//
// Only DECLARATIONS live here. main.swift is Swift's top-level-code file:
// its statements run in written order, and moving one here would turn it
// into a lazily-initialized global that never runs. Declarations have no
// such ordering, so they move freely.

#if canImport(LinChocolate)
import LinChocolate
#elseif canImport(WinChocolate)
import WinChocolate
#else
import AppKit
#endif

final class DemoCollectionDataSource: NSObject, NSCollectionViewDataSource {
    let values = ["NSButton", "NSTextField", "NSTableView", "NSImageView", "NSBrowser", "NSOutlineView"]

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        values.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = NSCollectionViewItem()
        let title = values[indexPath.item]
        item.representedObject = title
        item.view = NSButton(title: title, frame: NSMakeRect(0, 0, 112, 28))
        return item
    }
}

/// A multi-section collection source (with section headers) so the flow
/// layout's wrapping, re-tiling, and section headers are all demonstrable.
final class DemoFlowCollectionDataSource: NSObject, NSCollectionViewDataSource {
    /// Reuse identifiers for the section band views. AppKit requires every
    /// supplementary view to be registered under an identifier and then vended
    /// by `makeSupplementaryView` — returning a freshly built view raises
    /// "was not retrieved by calling -makeSupplementaryViewOfKind:…".
    static let headerID = NSUserInterfaceItemIdentifier("DemoSectionHeader")
    static let footerID = NSUserInterfaceItemIdentifier("DemoSectionFooter")

    let sections: [(title: String, items: [String])] = [
        ("Views", ["NSView", "NSImageView", "NSTextField", "NSButton", "NSSlider", "NSStepper"]),
        ("Controls", ["NSComboBox", "NSPopUpButton", "NSDatePicker", "NSColorWell", "NSSegmentedControl", "NSLevelIndicator", "NSPathControl", "NSTokenField"]),
        ("Containers", ["NSTableView", "NSOutlineView", "NSBrowser", "NSScrollView", "NSSplitView", "NSTabView", "NSBox"]),
    ]

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        sections.count
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        sections[section].items.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = NSCollectionViewItem()
        let title = sections[indexPath.section].items[indexPath.item]
        item.representedObject = title
        let button = NSButton(title: title, frame: NSMakeRect(0, 0, 120, 28))
        item.view = button
        return item
    }

    func collectionView(_ collectionView: NSCollectionView, viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind, at indexPath: IndexPath) -> NSView {
        let section = sections[indexPath.section]
        // Resolve the appearance live (not the cached launch value) so bands
        // recreated during a redraw after a system switch pick up the new look.
        let dark = NSApplication.shared.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        if kind == NSCollectionView.elementKindSectionHeader {
            guard let header = collectionView.makeSupplementaryView(
                ofKind: kind, withIdentifier: Self.headerID, for: indexPath) as? NSTextField else {
                return NSView()
            }
            header.stringValue = "  \(section.title)"
            header.isBordered = false
            header.isEditable = false
            header.font = NSFont.boldSystemFont(ofSize: 12)
            // Appearance-aware band so the dynamic label color stays legible.
            header.drawsBackground = true
            header.backgroundColor = dark
                ? NSColor(red: 0.16, green: 0.22, blue: 0.34, alpha: 1)
                : NSColor(red: 0.90, green: 0.93, blue: 0.98, alpha: 1)
            return header
        }
        if kind == NSCollectionView.elementKindSectionFooter {
            guard let footer = collectionView.makeSupplementaryView(
                ofKind: kind, withIdentifier: Self.footerID, for: indexPath) as? NSTextField else {
                return NSView()
            }
            footer.stringValue = "  — \(section.items.count) classes —"
            footer.isBordered = false
            footer.isEditable = false
            footer.font = NSFont.boldSystemFont(ofSize: 10)
            footer.textColor = dark ? NSColor(white: 0.75, alpha: 1) : NSColor(white: 0.35, alpha: 1)
            footer.drawsBackground = true
            footer.backgroundColor = dark
                ? NSColor(red: 0.30, green: 0.27, blue: 0.20, alpha: 1)
                : NSColor(red: 0.95, green: 0.93, blue: 0.88, alpha: 1)
            return footer
        }
        // Unhandled kinds return an empty view (the protocol's return is
        // non-optional, as on Apple).
        return NSView()
    }
}

/// Sizes each collection item to fit its label, demonstrating per-item flow
/// sizing (`NSCollectionViewDelegateFlowLayout`).
final class DemoFlowSizeDelegate: NSObject, NSCollectionViewDelegateFlowLayout {
    let source: DemoFlowCollectionDataSource
    init(_ source: DemoFlowCollectionDataSource) { self.source = source }
    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
        NSMakeSize(28 + CGFloat(source.sections[indexPath.section].items[indexPath.item].count) * 8, 28)
    }
}

/// Reports split-view divider drags in the status label.
final class DemoSplitDelegate: NSObject, NSSplitViewDelegate {
    var onResize: (@MainActor () -> Void)?

    func splitViewDidResizeSubviews(_ notification: Notification) {
        let handler = onResize
        MainActor.assumeIsolated {
            handler?()
        }
    }
}

/// Enables Edit-menu items from the notes text view's undo stacks.
final class EditMenuController: NSObject, NSMenuItemValidation {
    var textView: NSTextView?

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let manager = textView?.undoManager else {
            return false
        }

        // Titles refresh live ("Undo Typing") because the native menu
        // rebuilds from the NSMenu on WM_INITMENUPOPUP.
        if menuItem.keyEquivalentModifierMask.contains(.shift) {
            menuItem.title = manager.redoMenuItemTitle
            return manager.canRedo
        }
        menuItem.title = manager.undoMenuItemTitle
        return manager.canUndo
    }
}

/// A plain-text document demonstrating the NSDocument window-controller flow.
/// The document is its editor's real `NSTextViewDelegate` — the plain AppKit
/// idiom for tracking dirty state.
final class DemoNoteDocument: NSDocument, NSTextViewDelegate {
    // The delegate conformance infers @MainActor on the class; NSDocument's
    // read/write overrides stay nonisolated, so the backing text opts out
    // (the demo is single-threaded).
    nonisolated(unsafe) var text = ""

    override func data(ofType typeName: String) throws -> Data {
        Data(Array(text.utf8))
    }

    override func read(from data: Data, ofType typeName: String) throws {
        text = String(decoding: data, as: UTF8.self)
    }

    func textDidChange(_ notification: Notification) {
        guard let editor = notification.object as? NSTextView else {
            return
        }

        text = editor.string
        updateChangeCount(.changeDone)
    }

    override func makeWindowControllers() {
        let noteWindow = NSWindow(
            contentRect: NSMakeRect(220, 180, 460, 320),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        let editor = NSTextView(frame: NSMakeRect(12, 12, 436, 296))
        editor.string = text
        editor.allowsUndo = true
        editor.delegate = self
        let noteContent = DemoPageView(frame: NSMakeRect(0, 0, 460, 320))
        noteContent.addSubview(editor)
        noteWindow.contentView = noteContent
        addWindowController(NSWindowController(window: noteWindow))
    }
}

// Document-architecture demo: a New Note window driven by NSDocument,
// NSWindowController, and the shared NSDocumentController. The window title
// gains the classic asterisk while the note has unsaved edits.
// The plain-AppKit pattern: subclass NSDocumentController overriding
// documentClass(forType:), and instantiate it early — the first controller
// created becomes `shared`.
final class DemoDocumentController: NSDocumentController {
    override func documentClass(forType typeName: String) -> AnyClass? {
        DemoNoteDocument.self
    }
}
