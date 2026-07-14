/// A path-display control.
///
/// `NSPathControl` is AppKit-shaped API over a simple text-field peer for now.
/// Rich breadcrumb segments and menus can be layered on this model later.
open class NSPathControl: NSTextField {
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
    open private(set) var clickedPathComponentCell: NSPathComponentCell?

    /// The URL of the last clicked component, if any.
    open var clickedPathComponentURL: URL? {
        clickedPathComponentCell?.url
    }

    private var componentButtons: [NSButton] = []

    /// Path controls compose their breadcrumb segments in a container view so
    /// each component is individually clickable.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createView(frame: frame, parent: parent)
    }

    /// Creates a path control with a frame.
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isEditable = false
        isSelectable = true
    }

    /// Creates a path control with a zero frame, matching AppKit's shape.
    public convenience init() {
        self.init(frame: .zero)
    }

    /// Creates a path control with a URL.
    init(url: URL?, frame frameRect: NSRect) {
        self.url = url
        super.init(string: url?.path ?? "", frame: frameRect)
        isEditable = false
        isSelectable = true
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

        clickedPathComponentCell = pathComponentCells[index]
        sendAction()
        return true
    }

    private func rebuildPathComponentCells() {
        clickedPathComponentCell = nil
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
