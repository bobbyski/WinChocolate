/// The methods an alert delegate can implement.
public protocol NSAlertDelegate: AnyObject {
    /// Called when the user clicks the alert's help button; return `true` if
    /// the help request was handled.
    func alertShowHelp(_ alert: NSAlert) -> Bool
}

extension NSAlertDelegate {
    /// Default: help was not handled.
    public func alertShowHelp(_ alert: NSAlert) -> Bool {
        false
    }
}

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

    /// The alert's buttons in the order they were added, matching AppKit's
    /// `buttons`. The first button is the default (rightmost) button. Callers may
    /// customize a returned/stored button's `keyEquivalent`, `tag`, or `title`
    /// before running the alert.
    public private(set) var buttons: [NSButton] = []

    /// Whether the alert shows a suppression checkbox.
    open var showsSuppressionButton: Bool = false

    /// Whether the alert shows a help button.
    open var showsHelp: Bool = false

    /// The help anchor consulted when the help button is clicked.
    open var helpAnchor: String?

    /// The alert delegate, consulted for help-button clicks.
    open weak var delegate: NSAlertDelegate?

    /// A fallback help handler used when no delegate handles the help button.
    open var winHelpButtonAction: (() -> Void)?

    /// A custom icon shown instead of the style badge.
    open var icon: NSImage?

    /// A custom view displayed between the informative text and the buttons.
    ///
    /// The view keeps its own frame size; the composed panel indents it to the
    /// text column. Setting an accessory view makes `runModal()` use the
    /// composed panel, since the native message box cannot host custom views.
    open var accessoryView: NSView?

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

    /// Creates an alert that describes an error, matching `NSAlert(error:)`.
    ///
    /// The error's description becomes the message text and its failure reason,
    /// when present, the informative text; a single "OK" button dismisses it.
    public convenience init(error: Error) {
        self.init()
        alertStyle = .warning
        if let nsError = error as? NSError {
            messageText = nsError.localizedDescription
            informativeText = nsError.localizedFailureReason ?? ""
        } else if let localized = error as? LocalizedError {
            messageText = localized.errorDescription ?? "\(error)"
            informativeText = localized.failureReason ?? ""
        } else {
            messageText = "\(error)"
        }
        if messageText.isEmpty {
            messageText = "An error occurred."
        }
        addButton(withTitle: "OK")
    }

    /// Adds a button to the alert and returns it.
    ///
    /// The button carries AppKit's response `tag` (`alertFirstButtonReturn` for
    /// the first button, incrementing thereafter) and default key equivalents:
    /// the first button responds to Return, and a "Cancel" button to Escape.
    @discardableResult
    open func addButton(withTitle title: String) -> NSButton {
        let index = buttons.count
        let button = NSButton(title: title, frame: NSMakeRect(0, 0, 0, 0))
        button.tag = NSApplication.ModalResponse.alertFirstButtonReturn.rawValue + index
        if index == 0 {
            button.keyEquivalent = "\r"
        } else if title == "Cancel" {
            button.keyEquivalent = "\u{1b}"
        }
        buttons.append(button)
        buttonTitles.append(title)
        return button
    }

    /// Runs the alert modally.
    ///
    /// Alerts without custom buttons use the native message box; alerts with
    /// custom button titles or a suppression checkbox run as a composed modal
    /// panel so AppKit button semantics are preserved exactly.
    /// Whether the alert can use the OS `MessageBox`: only a plain alert
    /// (default buttons, no suppression/accessory/help/custom icon) qualifies,
    /// and **only in light mode** — the native message box does not honor dark
    /// mode, so a dark app composes the alert from its own dark-aware views
    /// instead (matching the 8.5 owner-draw-what-doesn't-theme rule).
    private var winCanUseNativeMessageBox: Bool {
        buttonTitles.isEmpty
            && !showsSuppressionButton
            && accessoryView == nil
            && !showsHelp
            && icon == nil
            && !NSApplication.shared.effectiveAppearance.winIsDark
    }

    open func runModal() -> NSApplication.ModalResponse {
        let application = NSApplication.shared
        let keyWindow = application.keyWindow
        let mainWindow = application.mainWindow
        let firstResponder = keyWindow?.firstResponder

        let response: NSApplication.ModalResponse
        if winCanUseNativeMessageBox {
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

    /// Presents the alert as a sheet for a window and reports the response.
    ///
    /// The classic backend runs sheets as application-modal sessions
    /// positioned under the window's title area; window-modal sheets with
    /// slide animation arrive with the modern appearance.
    open func beginSheetModal(for window: NSWindow, completionHandler handler: ((NSApplication.ModalResponse) -> Void)? = nil) {
        let application = NSApplication.shared
        let response: NSApplication.ModalResponse
        if winCanUseNativeMessageBox {
            response = application.nativeBackend.runAlert(self)
        } else {
            response = runComposedPanel(in: application, attachedTo: window)
        }
        handler?(response)
    }

    /// Builds and runs the composed alert panel for custom button layouts.
    private func runComposedPanel(in application: NSApplication, attachedTo parent: NSWindow? = nil) -> NSApplication.ModalResponse {
        let margin: CGFloat = 24
        let textLeft: CGFloat = 80
        // Size the panel to the measured message so long prompts never clip.
        let messageFont = NSFont.boldSystemFont(ofSize: 13)
        let messageSize = messageText.size(withAttributes: [.font: messageFont])
        let width: CGFloat = min(640, max(420, textLeft + messageSize.width + margin + 8))
        let textWidth = width - textLeft - margin
        var y: CGFloat = 20

        // Height of `text` word-wrapped at `textWidth`, counting explicit
        // newlines *and* wrapping — so multi-line message/informative text
        // (which the plain wrapped measure alone can under-count on embedded
        // "\n") gets a label tall enough to show every line.
        func wrappedHeight(_ text: String, font: NSFont) -> CGFloat {
            let lineHeight = font.pointSize + 7
            var total: CGFloat = 0
            for segment in text.split(separator: "\n", omittingEmptySubsequences: false) {
                let line = segment.isEmpty ? " " : String(segment)
                let measured = line.size(withAttributes: [.font: font], maxWidth: textWidth).height
                total += max(measured, lineHeight)
            }
            return total
        }

        let content = NSView(frame: NSMakeRect(0, 0, width, 200))
        content.backgroundColor = .windowBackgroundColor

        let iconView = AlertIconView(style: alertStyle, icon: icon, frame: NSMakeRect(24, 20, 40, 40))
        content.addSubview(iconView)

        let messageHeight = max(24, wrappedHeight(messageText, font: messageFont))
        let messageLabel = NSTextField(string: messageText, frame: NSMakeRect(textLeft, y, textWidth, messageHeight))
        messageLabel.isBordered = false
        messageLabel.drawsBackground = false
        messageLabel.font = messageFont
        messageLabel.usesSingleLineMode = false
        messageLabel.maximumNumberOfLines = 0
        content.addSubview(messageLabel)
        y += messageHeight + 10

        if !informativeText.isEmpty {
            let informativeFont = NSFont.systemFont(ofSize: 12)
            let informativeHeight = wrappedHeight(informativeText, font: informativeFont)
            let informativeLabel = NSTextField(string: informativeText, frame: NSMakeRect(textLeft, y, textWidth, informativeHeight))
            informativeLabel.isBordered = false
            informativeLabel.drawsBackground = false
            informativeLabel.font = informativeFont
            informativeLabel.usesSingleLineMode = false
            informativeLabel.maximumNumberOfLines = 0
            content.addSubview(informativeLabel)
            y += informativeHeight + 12
        }

        if showsSuppressionButton, let suppressionButton {
            suppressionButton.frame = NSMakeRect(textLeft, y, width - textLeft - margin, 20)
            content.addSubview(suppressionButton)
            y += 32
        }

        if let accessoryView {
            var accessoryFrame = accessoryView.frame
            accessoryFrame.origin = NSMakePoint(textLeft, y)
            accessoryView.frame = accessoryFrame
            content.addSubview(accessoryView)
            y += accessoryFrame.size.height + 12
        }

        // An alert always needs a way to dismiss it; synthesize the default
        // "OK" button when the caller added none, matching AppKit.
        if buttons.isEmpty {
            addButton(withTitle: "OK")
        }

        // Buttons flow right to left; the first button is the rightmost
        // default, matching AppKit. Each button carries its response as its tag.
        var buttonRight = width - margin
        for button in buttons {
            let buttonWidth = max(76, CGFloat(button.title.count * 7 + 28))
            button.frame = NSMakeRect(buttonRight - buttonWidth, y + 8, buttonWidth, 28)
            let code = NSApplication.ModalResponse(rawValue: button.tag)
            button.onAction = { _ in
                application.stopModal(withCode: code)
            }
            content.addSubview(button)
            buttonRight -= buttonWidth + 8
        }

        // The help button sits at the bottom-left and does not dismiss the
        // alert, matching AppKit's round "?" help affordance.
        if showsHelp {
            let helpButton = NSButton(title: "?", frame: NSMakeRect(margin, y + 8, 28, 28))
            helpButton.onAction = { [weak self] _ in
                guard let self else {
                    return
                }
                if self.delegate?.alertShowHelp(self) != true {
                    self.winHelpButtonAction?()
                }
            }
            content.addSubview(helpButton)
        }

        let contentHeight = y + 52
        content.frame = NSMakeRect(0, 0, width, contentHeight)
        var panelOrigin = NSMakePoint(360, 280)
        if let parent {
            // Sheet placement: centered under the parent's title area.
            panelOrigin = NSMakePoint(
                parent.frame.origin.x + max((parent.frame.size.width - width) / 2, 0),
                parent.frame.origin.y + 56
            )
        }
        // Sheets attach chromeless under the parent's title area like AppKit;
        // standalone alerts keep a captioned dialog frame.
        let panel = NSPanel(
            contentRect: NSRect(origin: panelOrigin, size: NSMakeSize(width, contentHeight)),
            styleMask: parent == nil ? [.titled] : .borderless,
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

/// Draws the alert-style badge shown at the left of composed alert panels.
private final class AlertIconView: NSView {
    private let style: NSAlert.Style
    private let icon: NSImage?

    init(style: NSAlert.Style, icon: NSImage?, frame frameRect: NSRect) {
        self.style = style
        self.icon = icon
        super.init(frame: frameRect)
    }

    override func draw(_ dirtyRect: NSRect) {
        let width = frame.size.width
        let height = frame.size.height

        // A custom icon replaces the style badge entirely.
        if let icon {
            icon.draw(in: NSMakeRect(0, 0, width, height))
            return
        }

        let glyph: String
        switch style {
        case .informational:
            NSColor(calibratedRed: 0.18, green: 0.47, blue: 0.84, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSMakeRect(2, 2, width - 4, height - 4)).fill()
            glyph = "i"
        case .warning:
            NSColor(calibratedRed: 0.95, green: 0.67, blue: 0.12, alpha: 1).setFill()
            let triangle = NSBezierPath()
            triangle.move(to: NSMakePoint(width / 2, 1))
            triangle.line(to: NSMakePoint(width - 1, height - 3))
            triangle.line(to: NSMakePoint(1, height - 3))
            triangle.close()
            triangle.fill()
            glyph = "!"
        case .critical:
            NSColor(calibratedRed: 0.80, green: 0.17, blue: 0.15, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSMakeRect(2, 2, width - 4, height - 4)).fill()
            glyph = "!"
        }

        // The warning triangle's visual center sits lower than the circles'.
        let glyphTop = style == .warning ? height / 2 - 7 : height / 2 - 11
        glyph.draw(
            at: NSMakePoint(width / 2 - 3, glyphTop),
            withAttributes: [
                .font: NSFont.boldSystemFont(ofSize: 18),
                .foregroundColor: NSColor.white
            ]
        )
    }
}

/// AppKit-compatible modal response alias.
public typealias NSModalResponse = NSApplication.ModalResponse
