// DemoConveniences.swift — demo-local closure sugar over REAL AppKit
// mechanisms (Phase 18.1/18.2).
//
// WinChocolate's framework surface has no closure actions: controls dispatch
// their real `target`/`action` selector, tables notify their delegate, text
// fields call `controlTextDidChange(_:)` — exactly AppKit. This file is APP
// code (never framework surface) that re-creates the closure ergonomics the
// demo likes, built ONLY on those real mechanisms:
//
//   * `onAction` holds the closure in a trampoline object and sets the
//     control's ACTUAL `target`/`action` to it — the framework dispatches the
//     selector for real; the trampoline just forwards to the closure.
//   * `onTextChanged`/`onComboBoxTextChanged` install a real
//     `NSTextFieldDelegate`/`NSTextViewDelegate` trampoline.
//
// Per the set-in-stone rule: the Apple-native way works WITHOUT this file
// (it is sugar, never required), and each platform side uses that platform's
// real dispatch — `NSObject.perform(_:with:)` overrides on Windows, `@objc`
// + `#selector` on macOS (`@objc` does not exist off-Darwin, which is the
// one reason this file has a platform seam inside it).

#if canImport(LinChocolate)
import LinChocolate
#elseif canImport(WinChocolate)
import WinChocolate
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Colored container view

/// A view that fills itself with a color — the plain-AppKit answer to
/// "give this container a background" (AppKit's `NSView` has no
/// `backgroundColor`; a subclass draws its own fill in `draw(_:)`).
final class DemoFilledView: NSView {
    /// This demo lays every page out in top-left coordinates. AppKit's NSView
    /// defaults to a bottom-left origin, so without this the whole page renders
    /// inverted; WinChocolate/LinChocolate already report `true`, so overriding
    /// here is a no-op there and the one authored layout works on all three.
    override var isFlipped: Bool {
        true
    }

    var backgroundColor: NSColor? {
        didSet {
            needsDisplay = true
        }
    }

    convenience init(frame frameRect: NSRect, backgroundColor: NSColor?) {
        self.init(frame: frameRect)
        self.backgroundColor = backgroundColor
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let backgroundColor else {
            return
        }

        backgroundColor.setFill()
        NSBezierPath(rect: bounds).fill()
    }
}

// MARK: - Frame-carrying init sugar
//
// AppKit's content inits size to fit (`NSButton(title:target:action:)`,
// `NSTextField(string:)`, …) and `init(frame:)` takes only a frame; there is
// no combined form. The demo likes the combined spelling, so these demo-local
// conveniences compose the two REAL steps: Apple's `init(frame:)` (or content
// convenience) followed by the real content property.

extension NSButton {
    convenience init(title: String, frame: NSRect) {
        self.init(frame: frame)
        self.title = title
    }

    convenience init(checkboxWithTitle title: String, frame: NSRect) {
        self.init(checkboxWithTitle: title, target: nil, action: nil)
        self.frame = frame
    }

    convenience init(radioButtonWithTitle title: String, frame: NSRect) {
        self.init(radioButtonWithTitle: title, target: nil, action: nil)
        self.frame = frame
    }
}

extension NSTextField {
    convenience init(string: String, frame: NSRect) {
        self.init(frame: frame)
        self.stringValue = string
    }

    convenience init(labelWithString string: String, frame: NSRect) {
        self.init(labelWithString: string)
        self.frame = frame
    }
}

extension NSSegmentedControl {
    convenience init(labels: [String], frame: NSRect) {
        self.init(labels: labels, trackingMode: .selectOne, target: nil, action: nil)
        self.frame = frame
    }
}

extension NSDatePicker {
    convenience init(date: Date, frame: NSRect) {
        self.init(frame: frame)
        self.dateValue = date
    }
}

extension NSTokenField {
    convenience init(tokens: [String], frame: NSRect) {
        self.init(frame: frame)
        self.objectValue = tokens
    }
}

extension NSPathControl {
    convenience init(url: URL?, frame: NSRect) {
        self.init(frame: frame)
        // Assign through a method: property observers are suppressed for
        // direct assignments inside an initializer, and `url`'s observer
        // builds the breadcrumb.
        applyDemoURL(url)
    }

    private func applyDemoURL(_ url: URL?) {
        self.url = url
    }
}

extension NSBox {
    convenience init(title: String, frame: NSRect) {
        self.init(frame: frame)
        self.title = title
    }
}

// (No NSSecureTextField variant: a subclass cannot re-declare a superclass
// extension convenience init — its one demo call site sets the frame and
// string in two plain steps instead.)

// MARK: - Action trampoline

/// Receives a sender's real action selectors and forwards each to a stored
/// closure. One trampoline per sender (AppKit controls have a single
/// `target`, so `action` and `doubleAction` both land here, distinguished by
/// selector — exactly the shape a hand-written AppKit target has).
final class DemoActionTarget: NSObject {
    /// Keeps each sender's trampoline alive (targets are held weakly,
    /// as AppKit does).
    nonisolated(unsafe) static var retained: [ObjectIdentifier: DemoActionTarget] = [:]

    /// Selector name → closure.
    var handlers: [String: @MainActor (Any?) -> Void] = [:]

    /// The sender's trampoline, created on first use.
    static func trampoline(for sender: NSObject) -> DemoActionTarget {
        if let existing = retained[ObjectIdentifier(sender)] {
            return existing
        }

        let created = DemoActionTarget()
        retained[ObjectIdentifier(sender)] = created
        return created
    }

    #if canImport(AppKit) && !canImport(WinChocolate) && !canImport(LinChocolate)
    // Real AppKit: Objective-C action methods the runtime dispatches. Actions
    // always arrive on the main thread, so hopping onto the main actor here
    // is a statement of fact, not a workaround.
    @objc func demoFire(_ sender: Any?) {
        nonisolated(unsafe) let sent = sender
        nonisolated(unsafe) let handler = handlers["demoFire:"]
        MainActor.assumeIsolated {
            handler?(sent)
        }
    }

    @objc func demoFireDouble(_ sender: Any?) {
        nonisolated(unsafe) let sent = sender
        nonisolated(unsafe) let handler = handlers["demoFireDouble:"]
        MainActor.assumeIsolated {
            handler?(sent)
        }
    }

    static let fireSelector = #selector(DemoActionTarget.demoFire(_:))
    static let doubleFireSelector = #selector(DemoActionTarget.demoFireDouble(_:))
    #else
    // WinChocolate/LinChocolate: the same dispatch surface without an ObjC
    // runtime — the framework sends the selector through
    // `NSObject.perform(_:with:)`, which app classes override (see the
    // framework's selector-dispatch note).
    override func responds(to aSelector: Selector?) -> Bool {
        guard let aSelector else {
            return false
        }

        return handlers[aSelector.name] != nil || super.responds(to: aSelector)
    }

    @discardableResult
    override func perform(_ aSelector: Selector, with object: Any?) -> Any? {
        guard let handler = handlers[aSelector.name] else {
            return super.perform(aSelector, with: object)
        }

        // Actions are dispatched from the UI thread — same fact as on macOS.
        nonisolated(unsafe) let sender = object
        MainActor.assumeIsolated {
            handler(sender)
        }
        return nil
    }

    static let fireSelector = Selector("demoFire:")
    static let doubleFireSelector = Selector("demoFireDouble:")
    #endif
}

// MARK: - Closure actions over real target/action

extension NSControl {
    /// Demo sugar: a closure action wired through the control's REAL
    /// `target`/`action`. Setting it targets a trampoline; the framework
    /// dispatches the selector exactly as for any target.
    @MainActor var onAction: (@MainActor (NSControl) -> Void)? {
        get { nil }
        set {
            guard let newValue else {
                DemoActionTarget.retained.removeValue(forKey: ObjectIdentifier(self))
                target = nil
                action = nil
                return
            }

            let trampoline = DemoActionTarget.trampoline(for: self)
            trampoline.handlers["demoFire:"] = { [weak self] sender in
                if let control = (sender as? NSControl) ?? self {
                    newValue(control)
                }
            }
            target = trampoline
            action = DemoActionTarget.fireSelector
        }
    }
}

extension NSMenuItem {
    /// Demo sugar: a closure action wired through the item's REAL
    /// `target`/`action`.
    @MainActor var onAction: (@MainActor (NSMenuItem) -> Void)? {
        get { nil }
        set {
            guard let newValue else {
                DemoActionTarget.retained.removeValue(forKey: ObjectIdentifier(self))
                target = nil
                action = nil
                return
            }

            let trampoline = DemoActionTarget.trampoline(for: self)
            trampoline.handlers["demoFire:"] = { [weak self] sender in
                if let item = (sender as? NSMenuItem) ?? self {
                    newValue(item)
                }
            }
            target = trampoline
            action = DemoActionTarget.fireSelector
        }
    }
}

extension NSToolbarItem {
    /// Demo sugar: a closure action wired through the item's REAL
    /// `target`/`action`.
    @MainActor var onAction: (@MainActor (NSToolbarItem) -> Void)? {
        get { nil }
        set {
            guard let newValue else {
                DemoActionTarget.retained.removeValue(forKey: ObjectIdentifier(self))
                target = nil
                action = nil
                return
            }

            let trampoline = DemoActionTarget.trampoline(for: self)
            trampoline.handlers["demoFire:"] = { [weak self] sender in
                if let item = (sender as? NSToolbarItem) ?? self {
                    newValue(item)
                }
            }
            target = trampoline
            action = DemoActionTarget.fireSelector
        }
    }
}

// MARK: - Text-change closures over real delegates

/// A real `NSTextFieldDelegate` that forwards `controlTextDidChange(_:)` to a
/// closure (the mechanism AppKit apps use, minus the boilerplate).
final class DemoTextChangeDelegate: NSObject, NSTextFieldDelegate {
    nonisolated(unsafe) static var retained: [ObjectIdentifier: DemoTextChangeDelegate] = [:]

    let handler: @MainActor (NSTextField) -> Void

    init(handler: @escaping @MainActor (NSTextField) -> Void) {
        self.handler = handler
    }

    func controlTextDidChange(_ obj: NSNotification) {
        // Delegate callbacks arrive on the UI thread on both platforms.
        if let field = obj.object as? NSTextField {
            nonisolated(unsafe) let sender = field
            nonisolated(unsafe) let handler = self.handler
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

    #if canImport(AppKit) && !canImport(WinChocolate) && !canImport(LinChocolate)
    func textDidChange(_ notification: Notification) {
        if let view = notification.object as? NSTextView {
            nonisolated(unsafe) let sender = view
            nonisolated(unsafe) let handler = self.handler
            MainActor.assumeIsolated {
                handler(sender)
            }
        }
    }
    #else
    func textDidChange(_ notification: NSNotification) {
        if let view = notification.object as? NSTextView {
            nonisolated(unsafe) let sender = view
            nonisolated(unsafe) let handler = self.handler
            MainActor.assumeIsolated {
                handler(sender)
            }
        }
    }
    #endif
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

    func tableViewSelectionDidChange(_ notification: NSNotification) {
        if let table = notification.object as? NSTableView {
            nonisolated(unsafe) let sender = table
            nonisolated(unsafe) let handler = self.handler
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

    func outlineViewSelectionDidChange(_ notification: NSNotification) {
        if let outline = notification.object as? NSOutlineView {
            nonisolated(unsafe) let sender = outline
            nonisolated(unsafe) let handler = self.handler
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
            trampoline.handlers["demoFireDouble:"] = { [weak self] sender in
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
        nonisolated(unsafe) let handler = self.handler
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
