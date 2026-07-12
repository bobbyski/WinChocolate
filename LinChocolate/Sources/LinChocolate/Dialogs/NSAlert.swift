import Foundation

/// AppKit's modal response for the first alert button; subsequent buttons
/// count up from here (1000, 1001, 1002…).
public let NSAlertFirstButtonReturn = 1000
public let NSAlertSecondButtonReturn = 1001
public let NSAlertThirdButtonReturn = 1002

/// AppKit-shaped modal alert. Configure `messageText`/`informativeText`, add
/// buttons (first = default, shown rightmost), then `runModal()` blocks until
/// the user responds.
///
/// Composed natively: GTK4 removed blocking dialogs, so the backend builds a
/// modal window and nests a main loop for AppKit's synchronous semantics.
public final class NSAlert {

    /// The alert's headline.
    public var messageText = ""

    /// Smaller explanatory text under the headline.
    public var informativeText = ""

    /// Button titles in the order added.
    public private(set) var buttonTitles: [String] = []

    public init() {}

    /// Adds a response button. The first added is the default (rightmost).
    public func addButton(withTitle title: String) {
        buttonTitles.append(title)
    }

    /// Shows the alert modally and blocks until a button is pressed. Returns
    /// `NSAlertFirstButtonReturn + index` of the pressed button. With no
    /// buttons added, shows a single "OK" (AppKit behavior).
    @discardableResult
    public func runModal() -> Int {
        let buttons = buttonTitles.isEmpty ? ["OK"] : buttonTitles
        let parent = NSApplication.shared.windows.first?.handle
        let index = NSApplication.shared.nativeBackend.runAlert(
            message: messageText,
            informative: informativeText,
            buttons: buttons,
            for: parent
        )
        return NSAlertFirstButtonReturn + index
    }
}
