/// A modal panel that chooses a destination file for saving.
///
/// `NSSavePanel` mirrors AppKit's save-panel workflow: configure the panel,
/// call `runModal()`, then read `url`. The Windows backend presents the native
/// comdlg32 save dialog. AppKit's `NSSavePanel` is technically an `NSPanel`
/// window subclass; this first slice models the dialog contract without the
/// window surface, which is what ported application code almost always uses.
open class NSSavePanel: NSObject {
    /// Panel title text.
    open var title: String = ""

    /// Accept-button label, when the platform dialog supports one.
    open var prompt: String = ""

    /// Explanatory message text shown by the panel when supported.
    open var message: String = ""

    /// Label shown next to the file-name field when supported.
    open var nameFieldLabel: String = ""

    /// Initial value for the file-name field.
    open var nameFieldStringValue: String = ""

    /// Allowed file-name extensions without dots, such as `["png", "jpg"]`.
    open var allowedFileTypes: [String]?

    /// Whether the user may save with an extension outside `allowedFileTypes`.
    open var allowsOtherFileTypes: Bool = false

    /// Directory shown when the panel opens.
    open var directoryURL: URL?

    /// Whether the panel offers directory creation.
    open var canCreateDirectories: Bool = true

    /// Whether hidden files are shown.
    open var showsHiddenFiles: Bool = false

    /// Whether the chosen file name hides its extension.
    open var isExtensionHidden: Bool = false

    /// Whether file packages are treated as directories.
    open var treatsFilePackagesAsDirectories: Bool = false

    /// The chosen destination after a successful run.
    public internal(set) var url: URL?

    /// Parent window frame while presenting as a sheet.
    internal var sheetAnchorFrame: NSRect?

    /// Creates a save panel.
    public override init() {
        super.init()
    }

    /// Returns a new save panel.
    /// Legacy factory. Not API (18.7): Apple deprecated `savePanel()` in favor
    /// of `init()` — package for the framework and suite.
    package class func savePanel() -> NSSavePanel {
        NSSavePanel()
    }

    /// Runs the panel modally, returning `.OK` or `.cancel`.
    open func runModal() -> NSApplication.ModalResponse {
        let application = NSApplication.shared
        let keyWindow = application.keyWindow
        let mainWindow = application.mainWindow
        let firstResponder = keyWindow?.firstResponder

        let paths = application.nativeBackend.runFileDialog(dialogOptions())

        if let mainWindow {
            mainWindow.makeMain()
        }
        if let keyWindow {
            keyWindow.makeKey()
            _ = keyWindow.makeFirstResponder(firstResponder)
        }

        return finishRun(with: paths)
    }

    /// Presents the panel and calls the handler with the modal response.
    ///
    /// The current backend runs the dialog synchronously before invoking the
    /// handler, matching AppKit call sites without a separate modal session.
    open func begin(completionHandler handler: (NSApplication.ModalResponse) -> Void) {
        handler(runModal())
    }

    /// Presents the panel for a window and calls the handler with the response.
    ///
    /// The classic backend positions the native dialog under the window's
    /// title area, standing in for AppKit's window-attached sheet.
    open func beginSheetModal(
        for window: NSWindow,
        completionHandler handler: (NSApplication.ModalResponse) -> Void
    ) {
        sheetAnchorFrame = window.frame
        defer {
            sheetAnchorFrame = nil
        }
        handler(runModal())
    }

    /// Builds the backend dialog descriptor for this panel.
    internal func dialogOptions() -> NativeFileDialogOptions {
        NativeFileDialogOptions(
            kind: .save,
            title: title,
            prompt: prompt,
            directoryPath: directoryURL?.path,
            fileName: nameFieldStringValue,
            fileTypes: allowedFileTypes ?? [],
            allowsOtherFileTypes: allowsOtherFileTypes,
            canChooseFiles: true,
            canChooseDirectories: false,
            allowsMultipleSelection: false,
            canCreateDirectories: canCreateDirectories,
            showsHiddenFiles: showsHiddenFiles,
            anchorFrame: sheetAnchorFrame
        )
    }

    /// Applies backend dialog results to panel state.
    internal func finishRun(with paths: [String]?) -> NSApplication.ModalResponse {
        guard let first = paths?.first else {
            url = nil
            return .cancel
        }

        url = URL(fileURLWithPath: first)
        return .OK
    }
}

/// A modal panel that chooses existing files or directories to open.
open class NSOpenPanel: NSSavePanel {
    /// Whether existing files can be chosen.
    open var canChooseFiles: Bool = true

    /// Whether directories can be chosen.
    open var canChooseDirectories: Bool = false

    /// Whether multiple entries can be chosen.
    open var allowsMultipleSelection: Bool = false

    /// Whether aliases resolve to their targets.
    open var resolvesAliases: Bool = true

    /// All chosen entries after a successful run.
    public internal(set) var urls: [URL] = []

    /// Returns a new open panel.
    /// Legacy factory. Not API (18.7): Apple deprecated `openPanel()` in favor
    /// of `init()` — package for the framework and suite.
    package class func openPanel() -> NSOpenPanel {
        NSOpenPanel()
    }

    /// Builds the backend dialog descriptor for this panel.
    internal override func dialogOptions() -> NativeFileDialogOptions {
        NativeFileDialogOptions(
            kind: .open,
            title: title,
            prompt: prompt,
            directoryPath: directoryURL?.path,
            fileName: nameFieldStringValue,
            fileTypes: allowedFileTypes ?? [],
            allowsOtherFileTypes: allowsOtherFileTypes,
            canChooseFiles: canChooseFiles,
            canChooseDirectories: canChooseDirectories,
            allowsMultipleSelection: allowsMultipleSelection,
            canCreateDirectories: canCreateDirectories,
            showsHiddenFiles: showsHiddenFiles,
            anchorFrame: sheetAnchorFrame
        )
    }

    /// Applies backend dialog results to panel state.
    internal override func finishRun(with paths: [String]?) -> NSApplication.ModalResponse {
        guard let paths, !paths.isEmpty else {
            url = nil
            urls = []
            return .cancel
        }

        urls = paths.map { URL(fileURLWithPath: $0) }
        url = urls.first
        return .OK
    }
}
