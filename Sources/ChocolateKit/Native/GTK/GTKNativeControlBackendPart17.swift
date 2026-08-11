#if canImport(CGTK)
import CGTK
import CGTKCompat
import Foundation

// MARK: - The core seam
//
// Unified Chocolate Phase 3: everything above `Native/` calls the shared
// `NativeControlBackend`, and this is where the GTK widget code answers it.
//
// The two halves grew up apart. The core registers callbacks and passes AppKit
// values (`registerMouseDownAction(for:action: (NSEvent) -> Void)`,
// `setButtonState(_: NSControl.StateValue, …)`); GTK's own layer sets one
// closure per widget and passes plain numbers (`setMouseHandler`,
// `setButtonState(_: Bool, …)`). Neither shape is wrong, so rather than rewrite
// 4,700 lines of working GTK code, this extension is the translation: the
// core's 156 requirements on the left, the GTK methods above on the right.
//
// Where GTK4 genuinely has no equivalent, the method says so in its doc comment
// instead of quietly doing nothing — an accepted-and-ignored stub is the bug
// class this project keeps finding, so an honest gap is documented as a gap.

/// State the core seam needs that the GTK layer above has no reason to keep.
///
/// One object, held by a single stored property on the backend, because Swift
/// cannot add stored properties in an extension and the class body should not
/// grow another thirty dictionaries.
final class CoreSeamState {
    /// Per-widget core mouse callbacks, multiplexed onto GTK's single handler.
    struct MouseActions {
        var down: ((NSEvent) -> Void)?
        var up: ((NSEvent) -> Void)?
        var moved: ((NSEvent) -> Void)?
        var dragged: ((NSEvent) -> Void)?
        var left: (() -> Void)?
        var rightDown: ((NSEvent) -> Void)?
        var rightUp: ((NSEvent) -> Void)?
        var otherDown: ((NSEvent) -> Void)?
        var otherUp: ((NSEvent) -> Void)?
        var scroll: ((NSEvent) -> Void)?
    }
    var mouse: [UInt: MouseActions] = [:]
    /// Widgets whose GTK mouse handler has already been installed.
    var mouseInstalled: Set<UInt> = []

    /// Live GLib timer sources, keyed by the token handed back to the core.
    var timers: [UInt: guint] = [:]
    var nextTimerID: UInt = 1

    /// Last known table selection, mirrored from GTK's selection signal so the
    /// core's synchronous `tableSelectedRow(for:)` has an answer.
    var tableSelection: [UInt: [Int]] = [:]
    var tableClickedRow: [UInt: Int] = [:]
    var tableClickedColumn: [UInt: Int] = [:]

    /// Toolbar items staged by `createToolbar`/`setToolbarItems` until a window
    /// is known to install them on.
    var toolbarItems: [UInt: [NativeToolbarItem]] = [:]
    var toolbarActions: [UInt: (String) -> Void] = [:]
    var toolbarWindow: [UInt: NativeHandle] = [:]

    /// The code passed to `stopModal(withCode:)`, read back by `runModal(for:)`.
    var modalCode: Int = 0
    /// Windows currently minimized (GTK4 has no "is minimized" query).
    var minimizedWindows: Set<UInt> = []
    /// Bumped on every clipboard write, for `clipboardChangeCount()`.
    var clipboardChangeCount: Int = 0
    /// A parentless label kept only to build Pango layouts for text measurement.
    var measuringLabel: OpaquePointer?
    /// Single-content parents (frames, scrolled windows) that already have one.
    var contentAssigned: Set<UInt> = []
    /// Views whose draw handler came from the shared core, which authors in
    /// top-left device coordinates and so must not get Cairo's axis flip.
    var topLeftDrawing: Set<UInt> = []
    /// Each window's direct children, in the order the core realized them.
    var windowChildren: [UInt: [UInt]] = [:]
    /// The menu bar the core handed over before any window existed.
    var pendingMainMenu: [NativeMenuSpec]?
    /// Labels added to plain views that the core asked to display text.
    var viewTextLabels: [UInt: OpaquePointer] = [:]
    /// Each date picker's field pattern, supplied by the core.
    var datePickerFormats: [UInt: String] = [:]
}

#endif
