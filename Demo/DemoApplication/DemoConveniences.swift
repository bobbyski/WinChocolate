// DemoConveniences.swift — demo-local closure sugar over REAL AppKit
// mechanisms (Phase 18.1/18.2).
//
// The frameworks' surface has no closure actions: controls dispatch their real
// `target`/`action` selector, tables notify their delegate, text fields call
// `controlTextDidChange(_:)` — exactly AppKit. This file is APP code (never
// framework surface) that re-creates the closure ergonomics the demo likes,
// built ONLY on those real mechanisms.
//
// RULE: this file is SHARED (compiled into all three targets), so it may
// contain no platform conditionals beyond the import selection below, and
// everything in it must be valid against real AppKit as well as the Chocolate
// frameworks. Delegate-based sugar qualifies: conforming an NSObject subclass
// to an ObjC delegate protocol auto-exposes the methods on Darwin, and the
// Chocolate frameworks declare the same protocols as plain Swift.
//
// The target/action closure sugar (`onAction`, `onDoubleAction`) qualifies by
// the same auto-exposure rule: an AppKit action target needs ObjC-visible
// selectors on Darwin, and while `@objc` cannot compile off Apple, an OVERRIDE
// of an inherited ObjC method is implicitly `@objc` — no attribute in source.
// So the trampoline subclasses NSResponder and overrides two of Apple's
// standard key-binding action methods (`moveUp(_:)`/`moveDown(_:)` — declared
// `(Any?) -> Void` no-ops on NSResponder for exactly this kind of selector
// dispatch), and the controls' `action` is set to those REAL selectors. On
// Darwin the ObjC runtime dispatches them; on the Chocolate frameworks
// `NSResponder.perform(_:with:)` does — one source, no platform seam.

#if os(Linux)
import LinChocolate
#elseif os(Windows)
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
///
/// An `NSResponder` subclass, because the action selectors are two of
/// NSResponder's standard key-binding action methods: overriding an inherited
/// ObjC method is implicitly `@objc` on Darwin (the only attribute-free way to
/// be selector-reachable there), and a plain Swift override the Chocolate
/// frameworks dispatch through `NSResponder.perform(_:with:)`. The trampoline
/// never joins a responder chain, so nothing else ever sends it these
/// selectors.
final class DemoActionTarget: NSResponder {
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

    // Actions always arrive on the main thread, so hopping onto the main
    // actor here is a statement of fact, not a workaround.
    override func moveUp(_ sender: Any?) {
        nonisolated(unsafe) let sent = sender
        let handler = handlers["moveUp:"]
        MainActor.assumeIsolated {
            handler?(sent)
        }
    }

    override func moveDown(_ sender: Any?) {
        nonisolated(unsafe) let sent = sender
        let handler = handlers["moveDown:"]
        MainActor.assumeIsolated {
            handler?(sent)
        }
    }

    static let fireSelector = Selector(("moveUp:"))
    static let doubleFireSelector = Selector(("moveDown:"))
}

// MARK: - Closure actions over real target/action

extension NSControl {
    /// Demo sugar: a closure action wired through the control's REAL
    /// `target`/`action`. Setting it targets a trampoline; the platform
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
            trampoline.handlers["moveUp:"] = { [weak self] sender in
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
            trampoline.handlers["moveUp:"] = { [weak self] sender in
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
            trampoline.handlers["moveUp:"] = { [weak self] sender in
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
