// The system-integration types an AppKit-shaped app names but no Chocolate
// backend can fully deliver (R25).
//
// Four families live here, and they share a shape: each is a *real* AppKit type
// with its real API, wired to whatever the backend can honestly do, and honest
// about the rest. A menu-bar extra needs a menu bar owned by an OS; a share
// sheet needs a system share service; a titlebar accessory needs a titlebar
// that can host views. Win32, GTK and the browser each have some of that and
// none have all of it.
//
// The alternative — leaving them out — is worse than a stub that says so: an
// app that mentions `NSStatusItem` once fails to compile in its entirety, and
// the developer learns nothing about which of its features will actually work.

/// A share destination, as AppKit's `NSSharingService`.
///
/// **Sharing is an operating-system service, not a control.** macOS enumerates
/// the installed destinations — Mail, Messages, AirDrop, every app that
/// registered a share extension. Windows has its own (`IDataTransferManager`),
/// GTK has portals, and a browser has `navigator.share` where the page is
/// served over https. None of them is reachable through the current backend
/// seam, so this is the API with no destinations behind it yet.
open class NSSharingService: NSObject {
    /// A named system service, matching AppKit's identifiers.
    public struct Name: Hashable, Sendable {
        /// The service's string value.
        public let rawValue: String

        /// Creates a name from its string value.
        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }

        /// Compose an email.
        public static let composeEmail = Name("com.apple.share.Mail.compose")
        /// Compose a message.
        public static let composeMessage = Name("com.apple.share.Messages.compose")
        /// Send by AirDrop.
        public static let sendViaAirDrop = Name("com.apple.share.AirDrop.send")
    }

    /// The service's display title.
    open var title: String

    /// Creates a service with a title.
    public init(title: String) {
        self.title = title
        super.init()
    }

    /// The named system service, or nil where the platform has none.
    ///
    /// Always nil here, and deliberately: returning an object that silently
    /// shared nothing would be worse than the nil AppKit itself returns for a
    /// service the machine does not have.
    open class func sharingService(named name: Name) -> NSSharingService? { nil }

    /// Whether the service can share these items.
    open func canPerform(withItems items: [Any]?) -> Bool { false }

    /// Shares the items.
    open func perform(withItems items: [Any]) {
        chocolateBackendWarn("NSSharingService.perform: no system share service on this backend.")
    }
}

/// What a share picker asks its delegate.
@MainActor
public protocol NSSharingServicePickerDelegate: AnyObject {
    /// Filters or reorders the services offered.
    func sharingServicePicker(_ picker: NSSharingServicePicker,
                              sharingServicesForItems items: [Any],
                              proposedSharingServices proposed: [NSSharingService]) -> [NSSharingService]
}

public extension NSSharingServicePickerDelegate {
    func sharingServicePicker(_ picker: NSSharingServicePicker,
                              sharingServicesForItems items: [Any],
                              proposedSharingServices proposed: [NSSharingService]) -> [NSSharingService] {
        proposed
    }
}

/// The share sheet, as AppKit's `NSSharingServicePicker`.
open class NSSharingServicePicker: NSObject {
    /// The items to be shared.
    open var items: [Any]

    /// The delegate consulted for the service list.
    open weak var delegate: NSSharingServicePickerDelegate?

    /// Creates a picker for some items.
    public init(items: [Any]) {
        self.items = items
        super.init()
    }

    /// Shows the picker relative to a rectangle in a view.
    ///
    /// Reports rather than presenting an empty sheet: a share button that
    /// opened a picker with nothing in it looks broken, where a logged
    /// explanation is a missing feature.
    open func show(relativeTo rect: NSRect, of view: NSView, preferredEdge: NSRectEdge) {
        chocolateBackendWarn("NSSharingServicePicker.show: no system share sheet on this backend.")
    }
}

/// A menu-bar extra, as AppKit's `NSStatusItem`.
///
/// The menu bar an item like this lives in belongs to the OS shell — the macOS
/// menu bar, the Windows notification area, a freedesktop tray. The backend
/// seam has no call for any of them, so the item holds its configuration and
/// the menu it would show, and shows nothing.
open class NSStatusItem: NSObject {
    /// The button drawn in the menu bar.
    open var button: NSButton? = NSButton(title: "", target: nil, action: nil)

    /// The menu shown when the item is clicked.
    open var menu: NSMenu?

    /// The item's width, or one of AppKit's automatic lengths.
    open var length: CGFloat = NSStatusItem.variableLength

    /// A width that follows the item's content.
    public static let variableLength: CGFloat = -1

    /// A width matching the menu bar's height.
    public static let squareLength: CGFloat = -2

    /// Whether the item is shown at all.
    open var isVisible: Bool = true
}

/// The system menu bar, as AppKit's `NSStatusBar`.
open class NSStatusBar: NSObject {
    /// The system-wide bar.
    public static let system = NSStatusBar()

    /// Creates a bar. Applications use `system`.
    public override init() {
        super.init()
    }

    /// Creates an item of a given width.
    ///
    /// Returns a real item so an app's configuration code runs and its menu is
    /// built; what is missing is a shell to put it in, which the item says
    /// once if anything tries to show it.
    open func statusItem(withLength length: CGFloat) -> NSStatusItem {
        chocolateBackendWarn("NSStatusBar.statusItem: no system menu bar extra area on this backend.")
        let item = NSStatusItem()
        item.length = length
        return item
    }

    /// Removes an item.
    open func removeStatusItem(_ item: NSStatusItem) {
        item.isVisible = false
    }
}

/// A view controller attached above or below a window's titlebar.
///
/// No Chocolate backend draws content in its window chrome — a synthesized
/// title bar in the browser, a real one on Win32 and GTK — so an accessory is
/// held and not shown. `NSWindow.addTitlebarAccessoryViewController` says so
/// once rather than per-window.
open class NSTitlebarAccessoryViewController: NSViewController {
    /// Which edge of the titlebar the accessory attaches to.
    open var layoutAttribute: NSLayoutConstraint.Attribute = .bottom

    /// Whether the accessory is hidden.
    open var isHidden: Bool = false

    /// How far the accessory can extend beyond the titlebar.
    open var fullScreenMinHeight: CGFloat = 0
}

/// A toolbar item that shows a menu, as AppKit's `NSMenuToolbarItem`.
open class NSMenuToolbarItem: NSToolbarItem {
    /// The menu shown when the item is clicked.
    open var menu: NSMenu?

    /// Whether the item shows an indicator that it has a menu.
    open var showsIndicator: Bool = true
}

/// A toolbar item hosting a search field, as AppKit's `NSSearchToolbarItem`.
open class NSSearchToolbarItem: NSToolbarItem {
    /// The field the item hosts.
    open var searchField: NSSearchField = NSSearchField(frame: NSMakeRect(0, 0, 180, 22))

    /// The width the field prefers when the toolbar has room.
    open var preferredWidthForSearchField: CGFloat = 180

    /// Whether the field is currently expanded from its collapsed button form.
    open private(set) var isSearchFieldExpanded: Bool = true

    /// Expands the field, as the collapsed button does when clicked.
    open func beginSearchInteraction() { isSearchFieldExpanded = true }

    /// Collapses the field back to a button.
    open func endSearchInteraction() { isSearchFieldExpanded = false }
}

/// The on/off switch, as AppKit's `NSSwitch`.
///
/// A real control: the backends all have a checkbox-shaped thing to realize it
/// as, and the drawn path can paint the pill. What differs from Apple is only
/// the look, which is what a platform's own switch is *for*.
open class NSSwitch: NSControl {
    /// Whether the switch is on.
    open var state: NSControl.StateValue = .off {
        didSet {
            guard state != oldValue else { return }
            needsDisplay = true
            sendAction()
        }
    }

    /// Creates a switch.
    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
}

/// The system's application services, as AppKit's `NSWorkspace`.
///
/// Opening a URL is the one thing every platform can do — `ShellExecute`,
/// `xdg-open`, `window.open` — and the one thing this is almost always used
/// for. The rest of `NSWorkspace` (running applications, icons for file types,
/// volume mounting) has no backend seam and is not pretended at.
open class NSWorkspace: NSObject {
    /// The shared workspace.
    public static let shared = NSWorkspace()

    /// Creates a workspace. Applications use `shared`.
    public override init() {
        super.init()
    }

    /// The icon a file's type is shown with.
    ///
    /// Nil everywhere: there is no system icon registry off Apple, and a
    /// generic placeholder returned from here would be worse than nil — a
    /// caller that checks gets to draw its own glyph, which is what the
    /// framework's own file browser does.
    open func icon(forFileType type: String) -> NSImage? { nil }

    /// The icon for a file at a path.
    open func icon(forFile path: String) -> NSImage? { nil }

    /// Opens a URL in whatever the system considers its handler.
    ///
    /// **Every platform can do this and none of them can do it through the
    /// current seam** — `ShellExecute`, `xdg-open` and `window.open` are three
    /// one-line calls behind a `NativeControlBackend` method that does not
    /// exist yet. Until it does, this reports and returns false, which is the
    /// same answer AppKit gives for a URL nothing can handle, so a caller that
    /// checks the result already behaves correctly here.
    @discardableResult
    open func open(_ url: URL) -> Bool {
        chocolateBackendWarn("NSWorkspace.open(\(url)): no URL-opening call on this backend yet.")
        return false
    }
}
