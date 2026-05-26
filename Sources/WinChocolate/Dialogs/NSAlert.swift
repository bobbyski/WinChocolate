/// A modal alert dialog.
///
/// `NSAlert` mirrors AppKit's common alert workflow: configure message text,
/// optional informative text, add buttons, then call `runModal()`. The current
/// Windows backend uses native `MessageBoxW`, so button count is honored while
/// fully custom button captions are planned for a later custom dialog backend.
open class NSAlert: NSObject {
    /// Alert visual style.
    public enum Style: Sendable {
        /// Informational alert style.
        case informational

        /// Warning alert style.
        case warning

        /// Critical alert style.
        case critical
    }

    /// Main alert message.
    open var messageText: String = ""

    /// Secondary explanatory alert text.
    open var informativeText: String = ""

    /// Alert style.
    open var alertStyle: Style = .warning

    /// Button titles in display order.
    public private(set) var buttonTitles: [String] = []

    /// Creates an alert.
    public override init() {
        super.init()
    }

    /// Adds a button to the alert.
    @discardableResult
    open func addButton(withTitle title: String) -> NSButton {
        buttonTitles.append(title)
        return NSButton(title: title, frame: NSMakeRect(0, 0, 0, 0))
    }

    /// Runs the alert modally.
    open func runModal() -> NSApplication.ModalResponse {
        NSApplication.shared.nativeBackend.runAlert(self)
    }
}

/// AppKit-compatible modal response alias.
public typealias NSModalResponse = NSApplication.ModalResponse
