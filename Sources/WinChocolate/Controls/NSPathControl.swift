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

    /// Creates a path control with a frame.
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isEditable = false
        isSelectable = true
    }

    /// Creates a path control with a URL.
    public init(url: URL?, frame frameRect: NSRect) {
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

    private func rebuildPathComponentCells() {
        guard let url else {
            pathComponentCells = []
            return
        }

        let components = url.pathComponents.filter { component in
            component != "/" && !component.isEmpty
        }
        pathComponentCells = components.map { component in
            let cell = NSPathComponentCell()
            cell.title = component
            return cell
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
