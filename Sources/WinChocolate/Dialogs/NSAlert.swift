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

    /// Whether the alert shows a suppression checkbox.
    open var showsSuppressionButton: Bool = false

    private var storedSuppressionButton: NSButton?

    /// The suppression checkbox, created lazily like AppKit's.
    ///
    /// Read `suppressionButton?.state` after `runModal()` to honor a
    /// "do not show this again" choice.
    open var suppressionButton: NSButton? {
        if storedSuppressionButton == nil {
            let button = NSButton(title: "Do not show this message again", frame: NSMakeRect(0, 0, 280, 20))
            button.setButtonType(.switchButton)
            storedSuppressionButton = button
        }
        return storedSuppressionButton
    }

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
    ///
    /// Alerts without custom buttons use the native message box; alerts with
    /// custom button titles or a suppression checkbox run as a composed modal
    /// panel so AppKit button semantics are preserved exactly.
    open func runModal() -> NSApplication.ModalResponse {
        let application = NSApplication.shared
        let keyWindow = application.keyWindow
        let mainWindow = application.mainWindow
        let firstResponder = keyWindow?.firstResponder

        let response: NSApplication.ModalResponse
        if buttonTitles.isEmpty && !showsSuppressionButton {
            response = application.nativeBackend.runAlert(self)
        } else {
            response = runComposedPanel(in: application)
        }

        if let mainWindow {
            mainWindow.makeMain()
        }
        if let keyWindow {
            keyWindow.makeKey()
            _ = keyWindow.makeFirstResponder(firstResponder)
        }

        return response
    }

    /// Builds and runs the composed alert panel for custom button layouts.
    private func runComposedPanel(in application: NSApplication) -> NSApplication.ModalResponse {
        let width: CGFloat = 420
        let margin: CGFloat = 24
        var y: CGFloat = 20

        let content = NSView(frame: NSMakeRect(0, 0, width, 200))
        content.backgroundColor = .windowBackgroundColor

        let messageLabel = NSTextField(string: messageText, frame: NSMakeRect(margin, y, width - margin * 2, 24))
        messageLabel.isBordered = false
        messageLabel.drawsBackground = false
        messageLabel.font = NSFont.boldSystemFont(ofSize: 13)
        content.addSubview(messageLabel)
        y += 34

        if !informativeText.isEmpty {
            let informativeLabel = NSTextField(string: informativeText, frame: NSMakeRect(margin, y, width - margin * 2, 40))
            informativeLabel.isBordered = false
            informativeLabel.drawsBackground = false
            content.addSubview(informativeLabel)
            y += 48
        }

        if showsSuppressionButton, let suppressionButton {
            suppressionButton.frame = NSMakeRect(margin, y, width - margin * 2, 20)
            content.addSubview(suppressionButton)
            y += 32
        }

        // Buttons flow right to left; the first button is the rightmost
        // default, matching AppKit.
        var buttonRight = width - margin
        for (index, title) in buttonTitles.enumerated() {
            let buttonWidth = max(76, CGFloat(title.count * 7 + 28))
            let button = NSButton(title: title, frame: NSMakeRect(buttonRight - buttonWidth, y + 8, buttonWidth, 28))
            button.onAction = { _ in
                application.stopModal(withCode: NSApplication.ModalResponse(rawValue: NSApplication.ModalResponse.alertFirstButtonReturn.rawValue + index))
            }
            content.addSubview(button)
            buttonRight -= buttonWidth + 8
        }

        let contentHeight = y + 52
        content.frame = NSMakeRect(0, 0, width, contentHeight)
        let panel = NSPanel(
            contentRect: NSMakeRect(360, 280, width, contentHeight),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        panel.title = ""
        panel.contentView = content

        let response = application.runModal(for: panel)
        panel.close()
        return response
    }
}

/// AppKit-compatible modal response alias.
public typealias NSModalResponse = NSApplication.ModalResponse
