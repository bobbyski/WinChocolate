// Part of the shared demo, split out of main.swift by topic.
//
// Only DECLARATIONS live here. main.swift is Swift's top-level-code file:
// its statements run in written order, and moving one here would turn it
// into a lazily-initialized global that never runs. Declarations have no
// such ordering, so they move freely.

#if canImport(WASMChocolate)
import WASMChocolate
#elseif canImport(LinChocolate)
import LinChocolate
#elseif canImport(WinChocolate)
import WinChocolate
#else
import AppKit
#endif

/// Adapts `NSTextFieldDelegate` begin/end editing to closures for the demo.
final class DemoFieldDelegate: NSObject, NSTextFieldDelegate {
    var onBegin: (@MainActor () -> Void)?
    var onEnd: (@MainActor () -> Void)?
    var onChange: (@MainActor (NSTextField) -> Void)?

    func controlTextDidBeginEditing(_ obj: Notification) {
        let handler = onBegin
        MainActor.assumeIsolated {
            handler?()
        }
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        let handler = onEnd
        MainActor.assumeIsolated {
            handler?()
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        if let field = obj.object as? NSTextField {
            let handler = onChange
            nonisolated(unsafe) let sent = field
            MainActor.assumeIsolated {
                handler?(sent)
            }
        }
    }
}

/// Receives the alert help-button click through the real `NSAlertDelegate`.
final class DemoAlertHelpDelegate: NSObject, NSAlertDelegate {
    var onHelp: (@MainActor () -> Void)?

    func alertShowHelp(_ alert: NSAlert) -> Bool {
        let handler = onHelp
        MainActor.assumeIsolated {
            handler?()
        }
        return true
    }
}

/// Applies live font-panel picks through the real `changeFont(_:)` chain
/// action — `NSFontChanging`, AppKit's shape since 10.14 (`NSFontManager`'s
/// target receives it).
final class DemoFontChangeResponder: NSResponder, NSFontChanging {
    var handler: (@MainActor (NSFont) -> Void)?

    func changeFont(_ sender: NSFontManager?) {
        let stored = handler
        nonisolated(unsafe) let font = (sender ?? NSFontManager.shared).convert(NSFont.systemFont(ofSize: 13))
        MainActor.assumeIsolated {
            stored?(font)
        }
    }
}

final class DemoToolbarDelegate: NSObject, NSToolbarDelegate {
    let allowedIdentifiers: [NSToolbarItem.Identifier]
    let defaultIdentifiers: [NSToolbarItem.Identifier]
    let itemProvider: (NSToolbarItem.Identifier) -> NSToolbarItem?

    init(
        allowedIdentifiers: [NSToolbarItem.Identifier],
        defaultIdentifiers: [NSToolbarItem.Identifier],
        itemProvider: @escaping (NSToolbarItem.Identifier) -> NSToolbarItem?
    ) {
        self.allowedIdentifiers = allowedIdentifiers
        self.defaultIdentifiers = defaultIdentifiers
        self.itemProvider = itemProvider
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        allowedIdentifiers
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        defaultIdentifiers
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        itemProvider(itemIdentifier)
    }
}

// Live Auto Layout resize: when the Auto Layout page is showing, stretch the
// page + the resize-demo container to the window's content width and re-run the
// solver, so dragging the window reflows the constraint-driven boxes in real
// time. Other pages stay frame-based, so nothing else needs a resize pass.
final class DemoWindowDelegate: NSObject, NSWindowDelegate {
    /// Apple declares this as `windowDidResize(_ notification: Notification)` — the Swift
    /// value type, not `NSNotification`. `NSWindowDelegate` is an `@objc` protocol with
    /// *optional* methods, so a near-miss signature is not a witness, never gets
    /// `@objc`-exposed, and is simply never called: `responds(to: "windowDidResize:")` is
    /// **false**. Declared `NSNotification` (the chocolate frameworks' spelling) this
    /// method compiled, read correctly, and never once ran — which is why the Auto Layout
    /// page never reflowed and every box on it sat static.
    ///
    /// Swift *does* warn: "instance method 'windowDidResize' nearly matches optional
    /// requirement". That warning is the only signal this class of bug gives.
    func windowDidResize(_ notification: Notification) {
        MainActor.assumeIsolated {
            guard !layoutPage.isHidden else {
                return
            }
            let width = contentView.frame.size.width
            layoutPage.frame = NSRect(origin: layoutPage.frame.origin,
                                      size: NSSize(width: width, height: layoutPage.frame.size.height))
            // Reflow the whole page to the new width.
            reflowAutoLayoutPage(width: width)
        }
    }
}
