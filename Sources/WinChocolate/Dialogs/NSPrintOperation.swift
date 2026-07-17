/// Print-job parameters, matching AppKit's `NSPrintInfo` shape.
///
/// This first slice carries the values document apps set — paper size,
/// orientation, and margins — while the platform print dialog owns the
/// printer-specific settings.
open class NSPrintInfo: NSObject {
    /// Paper orientation.
    public enum PaperOrientation: Sendable {
        /// Portrait orientation.
        case portrait

        /// Landscape orientation.
        case landscape
    }

    nonisolated(unsafe) private static var sharedInfo: NSPrintInfo?

    /// The shared print info used when an operation does not supply one.
    open class var shared: NSPrintInfo {
        if let sharedInfo {
            return sharedInfo
        }
        let info = NSPrintInfo()
        sharedInfo = info
        return info
    }

    /// The paper size in points (US Letter by default).
    open var paperSize = NSSize(width: 612, height: 792)

    /// The paper orientation.
    open var orientation: PaperOrientation = .portrait

    /// The left margin in points.
    open var leftMargin: CGFloat = 72

    /// The right margin in points.
    open var rightMargin: CGFloat = 72

    /// The top margin in points.
    open var topMargin: CGFloat = 90

    /// The bottom margin in points.
    open var bottomMargin: CGFloat = 90

    /// How content paginates along an axis, matching AppKit's names.
    public enum PaginationMode: Sendable {
        /// Pages break automatically at page boundaries.
        case automatic

        /// Content scales to fit the page along the axis.
        case fit

        /// Content clips at the page edge.
        case clip
    }

    /// Horizontal pagination. Stored for AppKit shape; the classic print
    /// path already fits the view to the printable page rect.
    open var horizontalPagination: PaginationMode = .clip

    /// Vertical pagination. Stored for AppKit shape; see
    /// `horizontalPagination`.
    open var verticalPagination: PaginationMode = .automatic

    /// The printable area: the paper inset by the margins.
    open var imageablePageBounds: NSRect {
        NSRect(
            x: leftMargin,
            y: topMargin,
            width: max(0, paperSize.width - leftMargin - rightMargin),
            height: max(0, paperSize.height - topMargin - bottomMargin)
        )
    }

    /// Creates print parameters with default Letter paper and margins.
    public override init() {
        super.init()
    }
}

/// The panel that runs the print dialog, matching AppKit's `NSPrintPanel`.
///
/// The classic backend shows the native Windows print dialog, so this type
/// stores the AppKit option surface for source compatibility.
open class NSPrintPanel: NSObject {
    /// Print-panel option flags.
    public struct Options: OptionSet, Sendable {
        /// The raw option bits.
        public let rawValue: Int

        /// Creates options from raw bits.
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// Show the number-of-copies control.
        public static let showsCopies = Options(rawValue: 1 << 0)

        /// Show the page-range controls.
        public static let showsPageRange = Options(rawValue: 1 << 1)

        /// Show the paper-size control.
        public static let showsPaperSize = Options(rawValue: 1 << 2)

        /// Show the orientation control.
        public static let showsOrientation = Options(rawValue: 1 << 3)
    }

    /// The panel's option flags (the native dialog owns the actual UI).
    open var options: Options = [.showsCopies, .showsPageRange]

    /// Creates a print panel.
    public class func printPanel() -> NSPrintPanel {
        NSPrintPanel()
    }
}

/// One print job for a view, matching AppKit's `NSPrintOperation` workflow:
/// create with a view, optionally adjust `printInfo`, then `run()`.
open class NSPrintOperation: NSObject {
    /// The view whose drawing is printed.
    public let view: NSView

    /// The job's print parameters.
    open var printInfo: NSPrintInfo

    /// Whether `run()` shows the print dialog (the classic backend's native
    /// dialog also carries the printer choice, so this is always honored).
    open var showsPrintPanel = true

    /// The print panel (options surface; the native dialog renders the UI).
    open var printPanel = NSPrintPanel()

    /// The document name shown in the print queue.
    open var jobTitle: String


    /// Creates a print operation for a view. Not API (18.7): Apple spells
    /// this `NSPrintOperation(view:printInfo:)` in Swift — package for the
    /// framework and suite.
    package class func printOperation(with view: NSView, printInfo: NSPrintInfo = .shared) -> NSPrintOperation {
        NSPrintOperation(view: view, printInfo: printInfo)
    }

    /// Creates a print operation for a view, matching AppKit's shape.
    public init(view: NSView, printInfo: NSPrintInfo = .shared) {
        self.view = view
        self.printInfo = printInfo
        self.jobTitle = view.window?.title.isEmpty == false ? view.window!.title : "WinChocolate Document"
        super.init()
    }

    /// Runs the print job: shows the native print dialog and renders the
    /// view's drawing into the chosen printer. Returns whether a job printed.
    @discardableResult
    open func run() -> Bool {
        let backend = view.realizedBackend ?? NSApplication.shared.nativeBackend
        let handle = view.realizeNativePeer(in: backend, parent: view.superview?.nativeHandle)
        return backend.runPrintOperation(for: handle, jobName: jobTitle, contentSize: view.bounds.size)
    }
}
