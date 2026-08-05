/// A path-display control.
///
/// Derives from `NSControl`, as AppKit's does. It previously derived from
/// `NSTextField`, which made `view as? NSTextField` match a path control here
/// but not on macOS — and the framework itself relies on exactly that test to
/// decide toolbar and panel behavior (`NSPanel`, `NSToolbar`), so a path
/// control was being treated as a text field. The peer was never a text field
/// anyway: `createNativePeer` makes a plain view and the breadcrumb is built
/// from child buttons. (DEMO_CHANGES.md MUST FIX, 18.x faithfulness.)
///
/// `backgroundColor` and `isEditable` are declared here because AppKit declares
/// them on `NSPathControl` itself — they came from `NSTextField` before, which
/// is why the wrong superclass went unnoticed. `stringValue` is declared here
/// too, pending the NSControl value-accessor work.
open class NSPathControl: NSControl {
    /// Path control display style.
    public enum Style: Sendable {
        /// Standard path style.
        case standard

        /// Navigation bar style.
        case navigationBar

        /// Pop-up path style.
        case popUp
    }

    /// The selected path URL.
    open var url: URL? {
        didSet {
            stringValue = url?.path ?? ""
            rebuildPathComponentCells()
        }
    }

    /// Current path style.
    open var pathStyle: Style = .standard

    /// Component cells derived from `url`.
    open private(set) var pathComponentCells: [NSPathComponentCell] = []

    /// The component cell the user last clicked, when click routing is wired.
    ///
    /// Populated by `selectComponentCell(at:)`; live breadcrumb hit-testing over
    /// the text peer is tracked with the path-control chrome work.
    package private(set) var winClickedPathComponentCell: NSPathComponentCell?

    /// The cell of the last-clicked path component. A **method** on Apple
    /// (`- clickedPathComponentCell`), so WinChocolate matches that shape.
    open func clickedPathComponentCell() -> NSPathComponentCell? {
        winClickedPathComponentCell
    }

    /// The URL of the last clicked component, if any.
    open var clickedPathComponentURL: URL? {
        winClickedPathComponentCell?.url
    }

    /// The displayed path text. On AppKit this comes from `NSControl`, reading
    /// through the cell; here `NSControl` has no value accessors yet (see
    /// `Docs/AppKitFaithfulnessIssues.md`, "NSControl value accessors"), so the
    /// control owns it — which is also the honest place for it while the peer is
    /// a plain view hosting breadcrumb buttons rather than a text peer.
    open var stringValue: String = ""

    /// The control's background fill. Real AppKit API on `NSPathControl`.
    open var backgroundColor: NSColor? {
        get { winBackgroundColor }
        set { winBackgroundColor = newValue }
    }

    /// Whether the path can be edited by the user. Real AppKit API on
    /// `NSPathControl`; the drag-and-drop editing path is not wired yet, so
    /// this is currently stored state that the breadcrumb honours by staying
    /// read-only.
    open var isEditable: Bool = false

    private var componentButtons: [NSButton] = []

    /// Path controls compose their breadcrumb segments in a container view so
    /// each component is individually clickable.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createView(frame: frame, parent: parent)
    }

    /// Creates a path control with a frame.
    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    /// Creates a path control with a zero frame, matching AppKit's shape.
    public convenience init() {
        self.init(frame: .zero)
    }

    /// Creates a path control with a URL.
    init(url: URL?, frame frameRect: NSRect) {
        self.url = url
        super.init(frame: frameRect)
        stringValue = url?.path ?? ""
        rebuildPathComponentCells()
    }

    /// Sets a path URL and refreshes the visible path.
    open func setURL(_ url: URL?) {
        self.url = url
    }

    /// Selects a component cell by index and points `url` at it, mirroring the
    /// AppKit click that navigates to a breadcrumb component.
    @discardableResult
    open func selectComponentCell(at index: Int) -> Bool {
        guard pathComponentCells.indices.contains(index) else {
            return false
        }

        winClickedPathComponentCell = pathComponentCells[index]
        sendAction()
        return true
    }

    private func rebuildPathComponentCells() {
        winClickedPathComponentCell = nil
        guard let url else {
            pathComponentCells = []
            return
        }

        let components = url.pathComponents.filter { component in
            component != "/" && !component.isEmpty
        }
        // Each component cell carries the cumulative file URL up to and
        // including that component, matching AppKit so a clicked breadcrumb
        // resolves to a real location.
        var cumulativePath = ""
        pathComponentCells = components.map { component in
            cumulativePath += "/" + component
            let cell = NSPathComponentCell()
            cell.title = component
            cell.url = URL(fileURLWithPath: cumulativePath)
            return cell
        }
        rebuildBreadcrumbButtons()
    }

    /// Rebuilds one clickable breadcrumb button per path component, chevron-
    /// separated. Clicking a segment selects that component and fires the action.
    private func rebuildBreadcrumbButtons() {
        for button in componentButtons {
            button.removeFromSuperview()
        }
        componentButtons = []

        let height = frame.size.height > 0 ? frame.size.height : 24
        var x: CGFloat = 0
        for (index, cell) in pathComponentCells.enumerated() {
            let label = index == 0 ? cell.title : "\u{203A} \(cell.title)"
            let width = max(24, CGFloat(label.count) * 8 + 16)
            let button = NSButton(title: label, frame: NSMakeRect(x, 0, width, height))
            // Breadcrumb segments read as flat text, not chunky push buttons.
            button.isBordered = false
            button.winInternalAction = { [weak self] _ in
                self?.selectComponentCell(at: index)
            }
            addSubview(button)
            componentButtons.append(button)
            x += width

            // Realize immediately when the control is already on screen (a URL
            // set after display); otherwise the parent realizes them.
            if let nativeHandle, let realizedBackend {
                button.realizeNativePeer(in: realizedBackend, parent: nativeHandle)
            }
        }
    }
}

/// A path segment cell used by `NSPathControl`.
open class NSPathComponentCell: NSObject {
    /// The segment title.
    open var title: String = ""

    /// The segment URL, if known.
    open var url: URL?

    /// Optional segment image.
    open var image: NSImage?

    /// Creates an empty path component cell.
    public override init() {
        super.init()
    }
}
