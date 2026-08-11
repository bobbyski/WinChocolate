// Part of the shared demo's convenience layer, split out of
// DemoConveniences.swift to keep each file under 500 lines.
// Declarations only — see the note in main.swift's companions.

#if os(Linux)
import LinChocolate
#elseif os(Windows)
import WinChocolate
#elseif canImport(AppKit)
import AppKit
#endif

/// A real `NSTextFieldDelegate` that forwards `controlTextDidChange(_:)` to a
/// closure (the mechanism AppKit apps use, minus the boilerplate).
final class DemoTextChangeDelegate: NSObject, NSTextFieldDelegate {
    nonisolated(unsafe) static var retained: [ObjectIdentifier: DemoTextChangeDelegate] = [:]

    let handler: @MainActor (NSTextField) -> Void

    init(handler: @escaping @MainActor (NSTextField) -> Void) {
        self.handler = handler
    }

    func controlTextDidChange(_ obj: Notification) {
        // Delegate callbacks arrive on the UI thread on both platforms.
        if let field = obj.object as? NSTextField {
            nonisolated(unsafe) let sender = field
            let handler = self.handler
            MainActor.assumeIsolated {
                handler(sender)
            }
        }
    }
}

extension NSTextField {
    /// Demo sugar: an edit-change closure installed as the field's REAL
    /// `delegate` (`controlTextDidChange(_:)`). Fields using this must not
    /// need another delegate — plain AppKit rules.
    @MainActor var onTextChanged: (@MainActor (NSTextField) -> Void)? {
        get { nil }
        set {
            guard let newValue else {
                DemoTextChangeDelegate.retained.removeValue(forKey: ObjectIdentifier(self))
                delegate = nil
                return
            }

            let trampoline = DemoTextChangeDelegate(handler: newValue)
            DemoTextChangeDelegate.retained[ObjectIdentifier(self)] = trampoline
            delegate = trampoline
        }
    }
}

extension NSComboBox {
    /// Demo sugar: combo text changes ride the same real text-field delegate.
    @MainActor var onComboBoxTextChanged: (@MainActor (NSComboBox) -> Void)? {
        get { nil }
        set {
            guard let newValue else {
                onTextChanged = nil
                return
            }

            onTextChanged = { field in
                if let combo = field as? NSComboBox {
                    newValue(combo)
                }
            }
        }
    }
}

/// A real `NSTextViewDelegate` forwarding `textDidChange(_:)` to a closure.
final class DemoTextViewChangeDelegate: NSObject, NSTextViewDelegate {
    nonisolated(unsafe) static var retained: [ObjectIdentifier: DemoTextViewChangeDelegate] = [:]

    let handler: @MainActor (NSTextView) -> Void

    init(handler: @escaping @MainActor (NSTextView) -> Void) {
        self.handler = handler
    }

    func textDidChange(_ notification: Notification) {
        if let view = notification.object as? NSTextView {
            nonisolated(unsafe) let sender = view
            let handler = self.handler
            MainActor.assumeIsolated {
                handler(sender)
            }
        }
    }
}

extension NSTextView {
    /// Demo sugar: an edit-change closure installed as the view's REAL
    /// `delegate` (`textDidChange(_:)`).
    @MainActor var onTextChanged: (@MainActor (NSTextView) -> Void)? {
        get { nil }
        set {
            guard let newValue else {
                DemoTextViewChangeDelegate.retained.removeValue(forKey: ObjectIdentifier(self))
                delegate = nil
                return
            }

            let trampoline = DemoTextViewChangeDelegate(handler: newValue)
            DemoTextViewChangeDelegate.retained[ObjectIdentifier(self)] = trampoline
            delegate = trampoline
        }
    }
}

// MARK: - Table selection/double-click closures over real delegates

/// A real `NSTableViewDelegate` forwarding selection changes to a closure.
/// Only for tables with no other delegate needs (drawn/classic tables).
final class DemoTableSelectionDelegate: NSObject, NSTableViewDelegate {
    nonisolated(unsafe) static var retained: [ObjectIdentifier: DemoTableSelectionDelegate] = [:]

    let handler: @MainActor (NSTableView) -> Void

    init(handler: @escaping @MainActor (NSTableView) -> Void) {
        self.handler = handler
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        if let table = notification.object as? NSTableView {
            nonisolated(unsafe) let sender = table
            let handler = self.handler
            MainActor.assumeIsolated {
                handler(sender)
            }
        }
    }
}

/// A real `NSOutlineViewDelegate` forwarding selection changes to a closure.
final class DemoOutlineSelectionDelegate: NSObject, NSOutlineViewDelegate {
    nonisolated(unsafe) static var retained: [ObjectIdentifier: DemoOutlineSelectionDelegate] = [:]

    let handler: @MainActor (NSOutlineView) -> Void

    init(handler: @escaping @MainActor (NSOutlineView) -> Void) {
        self.handler = handler
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        if let outline = notification.object as? NSOutlineView {
            nonisolated(unsafe) let sender = outline
            let handler = self.handler
            MainActor.assumeIsolated {
                handler(sender)
            }
        }
    }
}

extension NSTableView {
    /// Demo sugar: a selection closure installed as the table's REAL
    /// `delegate` (`tableViewSelectionDidChange(_:)`). Tables using this must
    /// not need another delegate — plain AppKit rules.
    @MainActor var onSelectionChanged: (@MainActor (NSTableView) -> Void)? {
        get { nil }
        set {
            guard let newValue else {
                DemoTableSelectionDelegate.retained.removeValue(forKey: ObjectIdentifier(self))
                delegate = nil
                return
            }

            let trampoline = DemoTableSelectionDelegate(handler: newValue)
            DemoTableSelectionDelegate.retained[ObjectIdentifier(self)] = trampoline
            delegate = trampoline
        }
    }

    /// Demo sugar: a double-click closure wired through the table's REAL
    /// `doubleAction` selector + `target`, exactly as AppKit dispatches it.
    /// Shares the sender's single trampoline with `onAction`, distinguished
    /// by selector — the same constraint any AppKit target has.
    @MainActor var onDoubleAction: (@MainActor (NSTableView) -> Void)? {
        get { nil }
        set {
            guard let newValue else {
                doubleAction = nil
                return
            }

            let trampoline = DemoActionTarget.trampoline(for: self)
            trampoline.handlers["moveDown:"] = { [weak self] sender in
                if let table = (sender as? NSTableView) ?? self {
                    newValue(table)
                }
            }
            target = trampoline
            doubleAction = DemoActionTarget.doubleFireSelector
        }
    }
}

/// A real `NSCollectionViewDelegate` forwarding selection to a closure
/// (`collectionView(_:didSelectItemsAt:)` — AppKit's mechanism; Apple's
/// `NSCollectionView` has no target/action).
final class DemoCollectionSelectionDelegate: NSObject, NSCollectionViewDelegate {
    nonisolated(unsafe) static var retained: [ObjectIdentifier: DemoCollectionSelectionDelegate] = [:]

    let handler: @MainActor (NSCollectionView) -> Void

    init(handler: @escaping @MainActor (NSCollectionView) -> Void) {
        self.handler = handler
    }

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        nonisolated(unsafe) let sender = collectionView
        let handler = self.handler
        MainActor.assumeIsolated {
            handler(sender)
        }
    }
}

extension NSCollectionView {
    /// Demo sugar: a selection closure installed as the collection's REAL
    /// `delegate`. Collections using this must not need another delegate —
    /// plain AppKit rules.
    @MainActor var onSelectionChanged: (@MainActor (NSCollectionView) -> Void)? {
        get { nil }
        set {
            guard let newValue else {
                DemoCollectionSelectionDelegate.retained.removeValue(forKey: ObjectIdentifier(self))
                delegate = nil
                return
            }

            let trampoline = DemoCollectionSelectionDelegate(handler: newValue)
            DemoCollectionSelectionDelegate.retained[ObjectIdentifier(self)] = trampoline
            delegate = trampoline
        }
    }
}

extension NSOutlineView {
    /// Demo sugar: outline selection closure installed as the outline's REAL
    /// `delegate` (AppKit's property — WinChocolate routes it identically).
    @MainActor var onOutlineSelectionChanged: (@MainActor (NSOutlineView) -> Void)? {
        get { nil }
        set {
            guard let newValue else {
                DemoOutlineSelectionDelegate.retained.removeValue(forKey: ObjectIdentifier(self))
                delegate = nil
                return
            }

            let trampoline = DemoOutlineSelectionDelegate(handler: newValue)
            DemoOutlineSelectionDelegate.retained[ObjectIdentifier(self)] = trampoline
            delegate = trampoline
        }
    }
}
