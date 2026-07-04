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
