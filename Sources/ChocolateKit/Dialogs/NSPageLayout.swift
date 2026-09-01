/// The page-setup panel, matching AppKit's `NSPageLayout`.
///
/// This is what a Page Setup… menu item reaches: `NSDocument.runPageLayout(_:)`
/// builds one, lets the document configure it through
/// `preparePageLayout(_:)`, and runs it over the document's `NSPrintInfo`.
///
/// The panel collects paper size, orientation, and scale into the `NSPrintInfo`
/// it was given, so a caller reads its results from that object rather than
/// from here — the same shape as `NSPrintPanel`, which sits beside this in
/// `NSPrintOperation.swift`.
///
/// **Boundary.** The classic backends present the platform's own page-setup
/// dialog, which owns its user interface; accessory controllers are therefore
/// stored and reported but not displayed. `NSPrintInfo` still receives whatever
/// the platform dialog collected, which is what callers actually consume.
open class NSPageLayout: NSObject {
    /// View controllers contributing extra panel content.
    ///
    /// Stored so `addAccessoryController(_:)` round-trips; see the boundary
    /// note above for why they are not rendered.
    open private(set) var accessoryControllers: [NSViewController] = []

    /// The print parameters the panel last ran against.
    open private(set) var printInfo: NSPrintInfo?

    /// Creates a page-layout panel.
    public override init() {
        super.init()
    }

    /// Returns a new page-layout panel, matching AppKit's factory.
    public class func pageLayout() -> NSPageLayout {
        NSPageLayout()
    }

    /// Adds a view controller supplying extra panel content.
    open func addAccessoryController(_ accessoryController: NSViewController) {
        accessoryControllers.append(accessoryController)
    }

    /// Removes a previously added accessory controller.
    open func removeAccessoryController(_ accessoryController: NSViewController) {
        accessoryControllers.removeAll { $0 === accessoryController }
    }

    /// Runs the panel over the shared print parameters.
    @discardableResult
    open func runModal() -> NSApplication.ModalResponse {
        runModal(with: NSPrintInfo.shared)
    }

    /// Runs the panel over specific print parameters.
    ///
    /// - Returns: `.OK` when the user accepted the settings, `.cancel` otherwise.
    @discardableResult
    open func runModal(with printInfo: NSPrintInfo) -> NSApplication.ModalResponse {
        self.printInfo = printInfo
        let backend = NSApplication.shared.nativeBackend
        return backend.runPageLayout(for: printInfo) ? .OK : .cancel
    }

    /// Runs the panel as a sheet on a window, reporting to a delegate.
    open func beginSheet(with printInfo: NSPrintInfo,
                         modalFor docWindow: NSWindow,
                         delegate: Any?,
                         didEnd didEndSelector: Selector?,
                         contextInfo: UnsafeMutableRawPointer?) {
        let response = runModal(with: printInfo)
        guard let didEndSelector, let object = delegate as? NSObject,
              object.responds(to: didEndSelector) else {
            return
        }
        object.perform(didEndSelector, with: response == .OK)
    }
}
