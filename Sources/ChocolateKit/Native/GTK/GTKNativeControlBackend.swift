#if canImport(CGTK)
import CGTK
import CGTKCompat
import Foundation

/// Linux backend: maps the AppKit-shaped seam onto native GTK4 widgets.
///
/// ```text
///   NSWindow             ->  GtkWindow (its child is the content view's GtkFixed)
///   NSView               ->  GtkFixed  (absolute child placement, like AppKit)
///   NSButton             ->  GtkButton
///   NSTextField (label)  ->  GtkLabel
/// ```
///
/// GTK is C/GObject. The `as*` helpers stand in for GTK's upcast macros
/// (`GTK_WINDOW()`, `GTK_BUTTON()`, …), which don't survive the C→Swift import;
/// every GObject begins with a `GTypeInstance`, so the reinterpret is safe.
///
/// The event loop uses a plain `GMainLoop` (not `GtkApplication`) so the
/// create-window-then-run ordering matches AppKit's, instead of GTK's
/// activate-callback model.
public final class GTKNativeControlBackend: NativeControlBackend {

    private var nextRaw: UInt = 1
    /// State the core-protocol seam needs (see "The core seam" at the end of
    /// this file). One property, because Swift cannot add stored properties in
    /// an extension and the class body has enough dictionaries already.
    let coreSeam = CoreSeamState()
    private var widgets: [UInt: OpaquePointer] = [:]   // handle -> GtkWidget*
    private var kinds: [UInt: InMemoryNativeControlBackend.Kind] = [:]
    private var frames: [UInt: NSRect] = [:]
    private var parents: [UInt: UInt] = [:]   // child -> parent, for repositioning
    private var childrenByParent: [UInt: [UInt]] = [:]   // parent -> children, in add order
    private var ranges: [UInt: (min: Double, max: Double)] = [:]   // slider/progress
    private var indeterminateProgress: Set<UInt> = []
    private var progressSpinners: Set<UInt> = []
    private var progressPulseSources: [UInt: guint] = [:]
    private var spinnerPhase: [UInt: Int] = [:]         // spinner -> rotation step
    private var spinnerSources: [UInt: guint] = [:]     // spinner -> animation timeout
    private var spinnerAnimating: Set<UInt> = []
    private var stepperValues: [UInt: Double] = [:]     // stepper -> current value
    private var stepperSteps: [UInt: Double] = [:]      // stepper -> increment
    private var valueChangeActions: [UInt: (Double) -> Void] = [:]
    private var comboEntries: [UInt: OpaquePointer] = [:]   // combo -> its GtkEntry child
    private var splitPaneCounts: [UInt: Int] = [:]           // paned -> panes added
    private var viewFixeds: [UInt: OpaquePointer] = [:]      // view -> child-hosting GtkFixed
    private var datePickerEntries: [UInt: OpaquePointer] = [:]   // compact picker -> its GtkEntry
    private var dateValues: [UInt: Date] = [:]                   // picker -> current date
    private var dateRanges: [UInt: (min: Date?, max: Date?)] = [:]
    private var dateStepActions: [UInt: (Int) -> Void] = [:]
    private var dateCursorActions: [UInt: (Int) -> Void] = [:]
    private var dateMoveActions: [UInt: (Int) -> Void] = [:]
    private var dateTypeActions: [UInt: (String) -> Void] = [:]
    private var levelValues: [UInt: Double] = [:]
    private var levelStyles: [UInt: Int] = [:]
    private var levelEditable: Set<UInt> = []
    private var levelThresholds: [UInt: (warning: Double, critical: Double)] = [:]
    private var levelChangeActions: [UInt: (Double) -> Void] = [:]
    private var levelClickGestures: Set<UInt> = []   // indicators already wired for clicks
    private var graphicalCalendars: [UInt: OpaquePointer] = [:]   // clockAndCalendar -> its GtkCalendar
    private var suppressCalendarReport: Set<UInt> = []
    private var scrollerAdjustments: [UInt: UnsafeMutablePointer<GtkAdjustment>] = [:]
    private var scrollerActions: [UInt: (Double) -> Void] = [:]
    private var suppressScrollerReport: Set<UInt> = []
    private var suppressCursorReport: Set<UInt> = []
    private var dateChangeActions: [UInt: (Date) -> Void] = [:]
    private var viewDrawAreas: [UInt: OpaquePointer] = [:]   // view -> GtkDrawingArea
    private var drawHandlers: [UInt: (NativeGraphicsContext, Double, Double) -> Void] = [:]
    private var windowBoxes: [UInt: OpaquePointer] = [:]     // window -> vertical GtkBox child
    private var windowContents: [UInt: OpaquePointer] = [:]  // window -> current content widget
    private var windowMenuBars: [UInt: OpaquePointer] = [:]  // window -> GtkPopoverMenuBar
    private var windowToolbars: [UInt: OpaquePointer] = [:]  // window -> toolbar GtkBox
    private var windowToolbarViews: [UInt: [OpaquePointer]] = [:] // window -> embedded view widgets (survive rebuild)
    private var flippedViews: Set<UInt> = []  // parents that position children top-left
    private var viewMagnifications: [UInt: Double] = [:]   // view -> NSScrollView magnification factor
    private var graphicalDatePickers: Set<UInt> = []  // date pickers shown as a GtkCalendar
    private var radiosByParent: [UInt: [UInt]] = [:]   // radio buttons grouped per superview
    // GTK 4.10 deprecated per-widget CSS providers (gtk_widget_get_style_context /
    // gtk_style_context_add_provider). The replacement is display-wide providers
    // plus a per-widget class: every styled widget carries a unique `lc-w<handle>`
    // class, and all rules at one priority live in a single provider that is
    // rebuilt whenever any of them changes.
    private var scopedProviders: [Int32: UnsafeMutablePointer<GtkCssProvider>] = [:]  // priority -> provider
    private var scopedRules: [Int32: [String: String]] = [:]       // priority -> ruleID -> css
    private var segmentButtons: [UInt: [OpaquePointer]] = [:] // segmented -> its toggle buttons
    private var tokenEntries: [UInt: OpaquePointer] = [:]     // token field -> its entry
    private var tokenChips: [UInt: [OpaquePointer]] = [:]     // token field -> chip buttons
    private var tokenValues: [UInt: [String]] = [:]           // token field -> tokens
    private var tokenActions: [UInt: ([String]) -> Void] = [:]
    private var tableColumnViews: [UInt: OpaquePointer] = [:] // table -> GtkColumnView
    private var tableSelections: [UInt: OpaquePointer] = [:]  // table -> GtkSingleSelection
    private var tableLists: [UInt: OpaquePointer] = [:]       // table -> GtkStringList model
    private var tableRowCounts: [UInt: Int] = [:]
    private var tableColumnCounts: [UInt: Int] = [:]
    private var tableColumnObjects: [UInt: [OpaquePointer]] = [:] // table -> GtkColumnViewColumn list
    private var tableProviders: [UInt: (Int, Int) -> String] = [:]
    private var tableSortActions: [UInt: (Int, Bool) -> Void] = [:]     // (columnIndex, ascending)
    private var tableActivateActions: [UInt: (Int) -> Void] = [:]       // double-click / Enter (row)
    private var collectionLists: [UInt: OpaquePointer] = [:]  // collection -> GtkStringList
    private var collectionItemCounts: [UInt: Int] = [:]
    private var collectionProviders: [UInt: (Int) -> String] = [:]
    private var collectionViewProviders: [UInt: (Int) -> NativeHandle?] = [:]
    private var collectionFlows: [UInt: OpaquePointer] = [:]          // legacy single-flow lookup
    private var collectionStacks: [UInt: OpaquePointer] = [:]         // collection -> vertical GtkBox
    private var collectionSectionSpecs: [UInt: [NativeCollectionSection]] = [:]
    private var collectionSectionFlows: [UInt: [(flow: OpaquePointer, base: Int)]] = [:]
    private var collectionFlowGeometry: [UInt: (interitem: Double, line: Double, horizontal: Bool)] = [:]
    private var windowResizeActions: [UInt: (Double, Double) -> Void] = [:]
    private var contentViewOwners: [UInt: UInt] = [:]     // content view -> its window
    private var lastContentSizes: [UInt: NSSize] = [:]
    /// Windows that have already been through first-show setup.
    private var presentedWindows: Set<UInt> = []
    // ── Paint tracing (LINCHOCOLATE_PAINT_TRACE=1) ────────────────────────────
    // Answers "where do the repaints come from" with evidence instead of
    // theory: every window lifecycle step and every frame-clock cycle is logged
    // with a timestamp, the window's size and its content's allocation, so a
    // repaint storm shows up as either repeated frames at a STABLE size (damage
    // /expose) or frames whose size KEEPS CHANGING (re-layout).
    private lazy var paintTrace: Bool =
        !(ProcessInfo.processInfo.environment["LINCHOCOLATE_PAINT_TRACE"] ?? "").isEmpty
    private let paintTraceStart = g_get_monotonic_time()
    private var paintTraceFrames: [UInt: Int] = [:]
    private var paintTraceLastSize: [UInt: (Int32, Int32)] = [:]
    private var paintTraceMapped: [UInt: gint64] = [:]
    private var paintTraceReported: Set<UInt> = []   // collection -> GtkFlowBox
    private var collectionSelectionActions: [UInt: (Int) -> Void] = [:]
    private var suppressCollectionSelection: Set<UInt> = []
    private var clickActionBoxes: [UInt: Bool] = [:]
    private var outlineColumnViews: [UInt: OpaquePointer] = [:]
    private var outlineRootLists: [UInt: OpaquePointer] = [:]
    private var outlineRootCounts: [UInt: Int] = [:]
    private var outlineColumnCounts: [UInt: Int] = [:]
    private var outlineChildCountProviders: [UInt: (String) -> Int] = [:]
    private var outlineCellTextProviders: [UInt: (String, Int) -> String] = [:]
    private var widgetFonts: [UInt: NativeFontSpec] = [:]     // style state per widget
    private var widgetTextColors: [UInt: NSColor] = [:]
    private var menuActionCounter = 0                         // unique GAction names
    private var nonComposited = false                         // display lacks alpha compositing
    private var mainLoop: OpaquePointer?   // GMainLoop* (opaque in the GTK import)

    /// Connects to the display and initializes GTK. Only construct this when a
    /// display is available (the demo/app), never in headless tests.
    public init() {
        gtk_init()
        applyNonCompositedFixups()
        installCompactControlStyle()
        installToolbarStyle()
    }

    /// GTK's Adwaita theme gives controls a generous `min-height` (~34px), which
    /// floors them above the demo's smaller frame heights, so a field sized 24px
    /// still renders ~34px — noticeably chunkier than the Win32/macOS controls
    /// the same layout targets. Drop the theme minimums and trim padding so each
    /// control honors its requested frame and reads at a comparable density.
    private func installCompactControlStyle() {
        guard let display = gdk_display_get_default() else { return }
        let css = """
            button, entry, spinbutton, dropdown, dropdown button, combobox,
            checkbutton, scale, levelbar, progressbar, calendar {
                min-height: 0;
            }
            button { padding: 2px 10px; }
            entry, spinbutton, dropdown button { padding: 1px 6px; min-height: 0; }
            spinbutton button { padding: 0 4px; }
            checkbutton { padding: 0; }
            checkbutton check { min-height: 16px; min-width: 16px; }
            /* NSColorWell: GtkButton's default padding is asymmetric (5px 10px),
               which squeezes the colour swatch into a narrow vertical strip.
               Symmetric padding gives the colour a consistent margin on all
               sides, inset in a softly rounded, bordered well like AppKit's. */
            colorbutton, colorbutton > button {
                min-width: 0; min-height: 0;
                border-radius: 7px;
            }
            colorbutton > button {
                padding: 3px;
                border: 1px solid alpha(currentColor, 0.28);
                box-shadow: none;
            }
            colorbutton > button > colorswatch,
            colorbutton > button > colorswatch > overlay {
                border-radius: 4px;
                min-width: 0; min-height: 0;
            }
            /* NSDatePicker's .clockAndCalendar: GtkCalendar's intrinsic minimum
               (291x198) exceeds the frame AppKit fits a month grid into
               (276x168 in the demo, deliberately). The frame is law, so the
               widget must be made to fit rather than allowed to draw past its
               allocation over the controls below it. */
            calendar { font-size: 90%; }
            calendar > grid > label { padding: 1px 2px; min-width: 0; min-height: 0; }
            calendar > header { padding: 0; min-height: 0; }
            calendar > header button { padding: 0 2px; min-width: 0; min-height: 0; }
            calendar > header label { padding: 0; }
            /* NSLevelIndicator's warningValue/criticalValue tints. */
            progressbar.linchocolate-level-warning > trough > progress { background-color: #e5a50a; }
            progressbar.linchocolate-level-critical > trough > progress { background-color: #e01b24; }
            /* AppKit's stepper: two stacked arrows (NSStepper is 20x28 there,
               so the theme's button minimums have to go). */
            .linchocolate-stepper button {
                min-width: 0; min-height: 0; padding: 0;
            }
            .linchocolate-stepper button image { -gtk-icon-size: 10px; }
            /* NSSegmentedControl: GTK's :checked toggle is a barely-darker grey
               that reads as unselected next to AppKit's tinted segment. Give the
               selected segment the accent fill and matching text, as AppKit does. */
            .linchocolate-segmented > button:checked,
            .linchocolate-segmented > button:checked:hover {
                background-image: none;
                background-color: @theme_selected_bg_color;
                color: @theme_selected_fg_color;
            }
            .linchocolate-segmented > button:checked label { color: inherit; }
            /* NSSlider: AppKit draws the same track in both orientations. GTK's
               vertical trough came out thinner and square-ended than the
               horizontal one, so pin both to a rounded 4px groove with a real
               round knob. */
            scale > trough { min-height: 4px; min-width: 4px; border-radius: 999px; }
            scale > trough > highlight { border-radius: 999px; }
            scale > trough > slider { min-height: 16px; min-width: 16px; }
            scale marks { color: alpha(currentColor, 0.55); }
            /* NSTokenField chips: AppKit draws each token as a rounded, tinted
               pill with its text sitting directly on the tint. The label must stay
               transparent — anything opaque behind the text hides the pill. */
            button.linchocolate-token-chip {
                border-radius: 999px;
                padding: 1px 9px;
                min-height: 0;
                background-image: none;
                background-color: alpha(@theme_selected_bg_color, 0.22);
                border: 1px solid alpha(@theme_selected_bg_color, 0.45);
            }
            button.linchocolate-token-chip:hover {
                background-color: alpha(@theme_selected_bg_color, 0.34);
            }
            button.linchocolate-token-chip label {
                background: none;
                background-color: transparent;
            }
            /* Non-editable NSTextFields render as plain labels (no field chrome). */
            entry.linchocolate-label {
                background: none; background-color: transparent;
                border: none; box-shadow: none; outline: none;
                padding: 1px 2px;
            }
            """
        let provider = gtk_css_provider_new()!
        lc_css_provider_load(provider, css)
        // 590 < the toolbar/app provider (600) so per-widget rules still win.
        gtk_style_context_add_provider_for_display(display, OpaquePointer(provider), 590)

        // The GtkColorChooserDialog the well opens packs its palette, editor and
        // action buttons flush against the window border. Inset them so the
        // controls have breathing room, like AppKit's colour panel. This must
        // sit ABOVE the theme (600) — the Adwaita rules that zero these margins
        // would otherwise win — so it rides at USER priority (800).
        let colorCSS = """
            colorchooser { padding: 16px 16px 8px 16px; }
            box.dialog-action-area { margin: 0 16px 14px 0; }
            """
        let colorProvider = gtk_css_provider_new()!
        lc_css_provider_load(colorProvider, colorCSS)
        gtk_style_context_add_provider_for_display(display, OpaquePointer(colorProvider), 800)
    }

    /// Display-wide CSS for the Apple-look toolbar (the deliberate Apple
    /// look-and-feel exception, Goal 2): a light gradient strip with a hairline
    /// bottom border and flat, hover-highlighted text buttons.
    private func installToolbarStyle() {
        guard let display = gdk_display_get_default() else { return }
        // Colors are expressed against GTK's theme-named colors (not literals)
        // so the strip tracks the app appearance: a subtle light gradient in
        // Aqua, a subtle dark one in Dark Aqua — matching macOS, whose toolbar
        // also follows the system appearance. Hover/active and the hairline use
        // the foreground color at low alpha, which reads correctly in both.
        let css = """
            .linchocolate-toolbar {
                padding: 5px 8px;
                background: linear-gradient(to bottom, shade(@theme_bg_color, 1.06), shade(@theme_bg_color, 0.98));
                border-bottom: 1px solid alpha(@theme_fg_color, 0.18);
            }
            .linchocolate-toolbar button {
                background: none; border: none; box-shadow: none;
                padding: 3px 12px; border-radius: 6px;
            }
            .linchocolate-toolbar button:hover { background: alpha(@theme_fg_color, 0.10); }
            .linchocolate-toolbar button:active { background: alpha(@theme_fg_color, 0.18); }
            .linchocolate-palette-tile {
                background: alpha(@theme_fg_color, 0.04);
                border: 1px solid alpha(@theme_fg_color, 0.12);
                border-radius: 8px; box-shadow: none; padding: 4px;
            }
            .linchocolate-palette-tile:hover { background: alpha(@theme_fg_color, 0.09); }
            .linchocolate-palette-tile:checked {
                background: alpha(@theme_selected_bg_color, 0.22);
                border-color: alpha(@theme_selected_bg_color, 0.65);
            }
            """
        let provider = gtk_css_provider_new()!
        lc_css_provider_load(provider, css)
        gtk_style_context_add_provider_for_display(display, OpaquePointer(provider), 600)
    }

    /// Popovers (menus, dropdowns) draw a drop shadow and rounded corners that
    /// need an alpha channel. On a non-composited display (XQuartz over TCP,
    /// Xvfb) that transparent region renders solid black, so flatten popovers
    /// there: no shadow, square corners, a hairline border instead. Composited
    /// displays (real Linux desktops, WSLg) keep the native look.
    private func applyNonCompositedFixups() {
        guard let display = gdk_display_get_default() else { return }
        guard gdk_display_is_composited(display) == 0 else { return }
        nonComposited = true
        let css = """
            popover { margin: 0; padding: 0; border-radius: 0; background: #fafafa; }
            popover > contents { margin: 0; box-shadow: none; border-radius: 0; border: 1px solid rgba(0,0,0,0.25); }
            """
        let provider = gtk_css_provider_new()!
        lc_css_provider_load(provider, css)
        // 600 = GTK_STYLE_PROVIDER_PRIORITY_APPLICATION (macro doesn't import).
        gtk_style_context_add_provider_for_display(display, OpaquePointer(provider), 600)
    }

    // MARK: Handle bookkeeping
    private func allocate(_ widget: UnsafeMutablePointer<GtkWidget>, _ kind: InMemoryNativeControlBackend.Kind, frame: NSRect) -> NativeHandle {
        defer { nextRaw += 1 }
        widgets[nextRaw] = OpaquePointer(widget)
        kinds[nextRaw] = kind
        frames[nextRaw] = frame
        return NativeHandle(rawValue: nextRaw)
    }
    private func widget(_ h: NativeHandle) -> OpaquePointer? { widgets[h.rawValue] }

    // MARK: Pointer upcasts (stand-ins for GTK_*() macros)
    private func asWidget(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkWidget> { .init(p) }
    private func asWindow(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkWindow> { .init(p) }
    private func asFixed(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkFixed> { .init(p) }
    private func asButton(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkButton> { .init(p) }
    private func asCheckButton(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkCheckButton> { .init(p) }
    private func asToggleButton(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkToggleButton> { .init(p) }
    private func asGrid(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkGrid> { .init(p) }
    private func asRange(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkRange> { .init(p) }
    private func asTextView(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkTextView> { .init(p) }
    private func asTextBuffer(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkTextBuffer> { .init(p) }
    private func asFrame(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkFrame> { .init(p) }
    private func asBox(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkBox> { .init(p) }
    private func asToggle(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkToggleButton> { .init(p) }
    private func asPopover(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkPopover> { .init(p) }
    private func asMenuModel(_ p: OpaquePointer) -> UnsafeMutablePointer<GMenuModel> { .init(p) }
    // GtkProgressBar, GtkDropDown, GtkLevelBar and GtkSpinButton are opaque in the
    // import — their functions take OpaquePointer directly. GtkTextBuffer is nominal.
    // NOTE: GtkLabel, GtkEditable, and GMainLoop are opaque in the GTK4 Swift
    // import (no nominal type), so their functions take/return OpaquePointer.
    // GtkWindow/GtkButton/GtkCheckButton/GtkFixed do import as nominal types.

    // MARK: Application lifecycle
    /// Installs the main-actor executor and runs a `GMainLoop` until `terminateApplication` quits it.
    public func runApplication() {
        // Route Task { @MainActor } onto GTK's loop, or those jobs never run
        // (nothing else pumps Swift's main-actor executor under g_main_loop_run).
        installGLibMainActorExecutor()
        let loop = g_main_loop_new(nil, gboolean(0))   // OpaquePointer!
        mainLoop = loop
        g_main_loop_run(loop)
    }
    /// Quits every running `GMainLoop` — the app's, plus any nested loop a
    /// modal is spinning. Quitting only the outer loop leaves a modal's loop
    /// running and the app never exits, which is what made Quit look dead after
    /// an alert was dismissed by closing its window.
    public func terminateApplication() {
        for loop in nestedLoops.reversed() { g_main_loop_quit(loop) }
        nestedLoops.removeAll()
        guard let loop = mainLoop else { return }
        g_main_loop_quit(loop)
    }

    /// Nested modal loops, innermost last.
    private var nestedLoops: [OpaquePointer] = []
    /// Records a modal's loop so `terminateApplication` can end it.
    func pushNestedLoop(_ loop: OpaquePointer?) {
        if let loop { nestedLoops.append(loop) }
    }
    /// Drops the innermost modal loop once it has finished.
    func popNestedLoop() {
        if !nestedLoops.isEmpty { nestedLoops.removeLast() }
    }

    /// Schedules `block` on GTK's main loop via `g_timeout_add`.
    public func scheduleTimer(interval: Double, repeats: Bool, _ block: @escaping () -> Void) {
        var block = block
        if paintTrace {
            let original = block
            let every = interval
            let start = paintTraceStart
            block = {
                let ms = Double(g_get_monotonic_time() - start) / 1000.0
                FileHandle.standardError.write(
                    String(format: "LCPAINT %8.1fms [timer] every=%.2fs\n", ms, every)
                        .data(using: .utf8)!)
                original()
            }
        }
        // Foundation's Timer lands on RunLoop.main, which is (a) never pumped
        // under g_main_loop_run and (b) broken for repeating timers on
        // swift-corelibs-foundation 6.0.3 anyway (RunLoop.run fires a repeating
        // timer exactly once, then blocks). So drive it off GTK's own loop.
        let box = TimerBox(block: block, repeats: repeats)
        g_timeout_add(guint(max(1, interval * 1000)), { userData in
            guard let userData else { return gboolean(0) }
            let box = Unmanaged<TimerBox>.fromOpaque(userData).takeUnretainedValue()
            box.block()
            if box.repeats { return gboolean(1) }        // G_SOURCE_CONTINUE
            Unmanaged<TimerBox>.fromOpaque(userData).release()
            return gboolean(0)                           // G_SOURCE_REMOVE
        }, Unmanaged.passRetained(box).toOpaque())
    }

    // MARK: Appearance
    /// The last appearance set; template toolbar icons tint against it.
    private var prefersDarkAppearance = false

    /// Toggles GTK's display-wide dark-theme preference. GtkSettings has no
    /// typed setter for this property, and `g_object_set` is C-variadic
    /// (uncallable from Swift), so set it through a GValue.
    public func setAppearanceDark(_ dark: Bool) {
        prefersDarkAppearance = dark
        guard let settings = gtk_settings_get_default() else { return }
        var value = GValue()
        _ = g_value_init(&value, GType(5 << 2))   // G_TYPE_BOOLEAN = 5 << G_TYPE_FUNDAMENTAL_SHIFT
        g_value_set_boolean(&value, gboolean(dark ? 1 : 0))
        g_object_set_property(UnsafeMutablePointer<GObject>(settings),
                              "gtk-application-prefer-dark-theme", &value)
        g_value_unset(&value)
    }

    // MARK: Pasteboard & drag-and-drop
    private var clipboardMirror: String?

    /// Copies `string` to the GDK default clipboard (and caches it locally).
    public func setClipboardString(_ string: String) {
        clipboardMirror = string
        guard let display = gdk_display_get_default() else { return }
        let clipboard = gdk_display_get_clipboard(display)
        var value = GValue()
        _ = g_value_init(&value, GType(16 << 2))   // G_TYPE_STRING
        g_value_set_string(&value, string)
        gdk_clipboard_set_value(clipboard, &value)
        g_value_unset(&value)
    }

    // System-clipboard reads are async in GTK4; return the last value we set.
    // Inbound cross-app paste is a later parity item.
    /// Returns the last string written to the clipboard by this process.
    public func clipboardString() -> String? { clipboardMirror }

    /// Attaches a `GtkDropTarget` accepting strings; delivers drops via `onDrop`.
    public func registerDropTarget(for handle: NativeHandle, types: [String], onDrop: @escaping (String, Double, Double) -> Bool) {
        guard let w = widget(handle) else { return }
        // String drops only in this slice (G_TYPE_STRING); copy is enough.
        let target = gtk_drop_target_new(GType(16 << 2), GDK_ACTION_COPY)
        let box = DropBox(onDrop)
        g_signal_connect_data(
            UnsafeMutableRawPointer(target), "drop",
            unsafeBitCast(gtkDropTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        gtk_widget_add_controller(asWidget(w), target)
    }

    /// Attaches a `GtkDragSource` whose payload is the string produced by `provider`.
    public func registerDragSource(for handle: NativeHandle, provider: @escaping () -> String?) {
        guard let w = widget(handle) else { return }
        let source = gtk_drag_source_new()
        let box = DragProviderBox(provider)
        g_signal_connect_data(
            UnsafeMutableRawPointer(source), "prepare",
            unsafeBitCast(gtkDragPrepareTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        gtk_widget_add_controller(asWidget(w), source)
    }

    // MARK: Windows
    /// Creates a `GtkWindow` sized to `frame`, hosting a vertical `GtkBox` for the menu bar + content view.
    public func createWindow(title: String, frame: NSRect, styleMask: NSWindow.StyleMask) -> NativeHandle {
        let win = gtk_window_new()!
        let h = allocate(win, .window, frame: frame)
        let p = widget(h)!
        gtk_window_set_title(asWindow(p), title)
        // Honour the style mask instead of accepting and ignoring it: a window
        // with no title bar must not be decorated, and one that cannot be closed
        // must not offer a close button. Telling the WM this up front avoids it
        // decorating the window and then being corrected.
        gtk_window_set_decorated(asWindow(p), gboolean(styleMask.contains(.titled) ? 1 : 0))
        gtk_window_set_deletable(asWindow(p), gboolean(styleMask.contains(.closable) ? 1 : 0))
        // Deliberately NO `gtk_window_set_default_size` here. `frame` is AppKit's
        // CONTENT rect, while the GTK window also holds the menu bar and toolbar,
        // so a default size of the content alone is too short: the window maps at
        // that size and then has to grow to its natural size, and under a real
        // window manager that second sizing is a visible map-then-repaint. The
        // content view carries its own size request, so GTK's natural size is
        // already content + chrome — exactly the window AppKit's contentRect
        // describes — and it gets there in one step.
        // The window's real child is a vertical box: [menu bar?][content view].
        // This keeps a slot for `installMenuBar` above the AppKit content view.
        let box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        gtk_window_set_child(asWindow(p), box)
        windowBoxes[h.rawValue] = OpaquePointer(box)
        installPopoverDismissFallback(on: asWidget(p))
        return h
    }

    /// Popovers normally dismiss on outside click via a pointer grab, but that
    /// grab does not take effect on non-composited X11 (XQuartz), leaving open
    /// popovers stuck. Fallback: a capture-phase click handler on the window
    /// that pops down any *other* open popover before the click lands. Clicks
    /// inside a popover are on its own surface and never reach this handler, so
    /// item activation is unaffected.
    ///
    /// We deliberately do NOT dismiss on `notify::is-active`: opening an
    /// autohide popover briefly deactivates the toplevel window (the popover
    /// grabs its own surface), and reacting to that would pop the popover down
    /// the instant it opens — which broke the combo-box dropdown and `NSPopover`.
    private func installPopoverDismissFallback(on windowWidget: UnsafeMutablePointer<GtkWidget>) {
        guard nonComposited else { return }
        let gesture = gtk_gesture_click_new()!
        // GtkEventController is opaque; the gesture pointer doubles as one.
        gtk_event_controller_set_propagation_phase(gesture, GTK_PHASE_CAPTURE)
        let box = WidgetBox(widget: windowWidget)
        g_signal_connect_data(
            UnsafeMutableRawPointer(gesture), "pressed",
            unsafeBitCast(gtkDismissPopoversTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        gtk_widget_add_controller(windowWidget, gesture)
    }
    /// Installs `view` as the window's (or box/scroll-view's) content, routed by kind.
    public func setContentView(_ view: NativeHandle, for window: NativeHandle) {
        guard let w = widget(window), let v = widget(view) else { return }
        switch kinds[window.rawValue] {
        case .box:        gtk_frame_set_child(asFrame(w), asWidget(v))
        case .scrollView: gtk_scrolled_window_set_child(w, asWidget(v))   // GtkScrolledWindow is opaque
        default:
            guard let box = windowBoxes[window.rawValue] else { return }
            if let old = windowContents[window.rawValue] {
                gtk_box_remove(asBox(box), asWidget(old))
            }
            gtk_box_append(asBox(box), asWidget(v))
            windowContents[window.rawValue] = v
            contentViewOwners[view.rawValue] = window.rawValue
        }
    }
    /// Emits one paint-trace line for `raw`: elapsed ms, the window's own size,
    /// its content view's allocation, and the GTK frame counter.
    fileprivate func tracePaint(_ raw: UInt, _ event: String) {
        guard paintTrace, let w = widgets[raw] else { return }
        let ms = Double(g_get_monotonic_time() - paintTraceStart) / 1000.0
        let widget = asWidget(w)
        let ww = gtk_widget_get_width(widget), wh = gtk_widget_get_height(widget)
        var content = "content=none"
        if let c = windowContents[raw] {
            content = "content=\(gtk_widget_get_width(asWidget(c)))x\(gtk_widget_get_height(asWidget(c)))"
        }
        var frame = ""
        if let clock = gtk_widget_get_frame_clock(widget) {
            frame = " frame=\(gdk_frame_clock_get_frame_counter(clock))"
        }
        // The GdkSurface is what the X server actually shows. GTK's allocation
        // (win=) is only computed on the frame clock, so it reads 0 before the
        // first cycle even when the real window is already the right size — the
        // two together separate "bookkeeping not filled in yet" from "the window
        // on screen is genuinely the wrong size".
        var surface = " surface=none"
        if let native = gtk_widget_get_native(widget), let s = gtk_native_get_surface(native) {
            surface = " surface=\(gdk_surface_get_width(s))x\(gdk_surface_get_height(s))"
        }
        // Flag the two signatures that matter: a size change (re-layout) versus a
        // repeat at the same size (damage/expose).
        var note = ""
        if let last = paintTraceLastSize[raw], last != (ww, wh) {
            note = "  ← SIZE CHANGED \(last.0)x\(last.1) → \(ww)x\(wh)"
        }
        paintTraceLastSize[raw] = (ww, wh)
        let title = gtk_window_get_title(asWindow(w)).map { String(cString: $0) } ?? "?"
        // The number this whole investigation turns on: how long the window sat
        // on screen before anything was painted into it. Reported once, in
        // plain sight, so nobody has to subtract timestamps by hand.
        if event == "map" { paintTraceMapped[raw] = g_get_monotonic_time() }
        if event.hasPrefix("draw#1"), !paintTraceReported.contains(raw),
           let mapped = paintTraceMapped[raw] {
            paintTraceReported.insert(raw)
            let delay = Double(g_get_monotonic_time() - mapped) / 1000.0
            FileHandle.standardError.write(
                String(format: "LCPAINT ======== [%@] FIRST FRAME %.1f ms after map ========\n",
                       title as NSString, delay).data(using: .utf8)!)
        }
        FileHandle.standardError.write(
            String(format: "LCPAINT %8.1fms [%@] %-12@ win=%dx%d %@%@%@\n",
                   ms, title as NSString, event as NSString, Int(ww), Int(wh),
                   (content + surface) as NSString, frame as NSString, note as NSString).data(using: .utf8)!)
    }

    /// Hooks the window's lifecycle and its frame clock so every paint cycle is
    /// visible. Installed once, at first present, when tracing is on.
    private func installPaintTrace(_ handle: NativeHandle) {
        guard paintTrace, let w = widget(handle) else { return }
        let widget = asWidget(w)
        for signal in ["map", "unmap", "realize", "unrealize"] {
            let box = PaintTraceBox(backend: self, raw: handle.rawValue, event: signal)
            g_signal_connect_data(
                UnsafeMutableRawPointer(widget), signal,
                unsafeBitCast(gtkPaintTraceTrampoline, to: GCallback.self),
                Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
            )
        }
        // The frame clock is the authority on repaints: one cycle per frame GTK
        // actually renders.
        guard let clock = gtk_widget_get_frame_clock(widget) else { return }
        for signal in ["layout", "after-paint"] {
            let box = PaintTraceBox(backend: self, raw: handle.rawValue, event: "clock:" + signal)
            g_signal_connect_data(
                UnsafeMutableRawPointer(clock), signal,
                unsafeBitCast(gtkPaintTraceTrampoline, to: GCallback.self),
                Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
            )
        }
    }

    /// Presents the window (`gtk_window_present`).
    public func showWindow(_ handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        installPendingMainMenu(on: handle)
        // Realize before mapping so the surface exists and GTK can measure the
        // window, then map it.
        // Re-presenting an ALREADY-SHOWN window (the demo's inspector panel is
        // cached and re-ordered front on every press) must only raise it. Doing
        // the first-show work again re-sized a mapped window — a resize request
        // costs a window-manager round trip, which is why a second open measured
        // SLOWER than the first (2.1s then 3.5s on the reporter's display) — and
        // re-installed the trace handlers, so every later event logged twice.
        guard !presentedWindows.contains(handle.rawValue) else {
            tracePaint(handle.rawValue, "re-present")
            gtk_window_present(asWindow(w))
            return
        }
        presentedWindows.insert(handle.rawValue)

        // Size the window BEFORE realizing it. `gtk_widget_realize` creates the
        // GdkSurface, and with no size set that surface is created 1x1: the trace
        // showed `map surface=1x1` followed by a jump to the real size on the
        // first frame-clock cycle, i.e. the window is mapped tiny and then
        // resized — a visible flash, and the origin of the "blank repaints".
        //
        // Measure rather than reusing AppKit's contentRect: the window also
        // carries the menu bar and toolbar, and an earlier attempt that set the
        // content size mapped the window too short and then had to grow it.
        // Measuring gets content + chrome right in one step, for a panel (no
        // chrome) as much as for the main window.
        var minW: gint = 0, natW: gint = 0, minH: gint = 0, natH: gint = 0
        gtk_widget_measure(asWidget(w), GTK_ORIENTATION_HORIZONTAL, -1, &minW, &natW, nil, nil)
        gtk_widget_measure(asWidget(w), GTK_ORIENTATION_VERTICAL, natW, &minH, &natH, nil, nil)
        if natW > 0, natH > 0 {
            gtk_window_set_default_size(asWindow(w), natW, natH)
        }
        tracePaint(handle.rawValue, "pre-realize")
        gtk_widget_realize(asWidget(w))
        // Paint the X background to match the app BEFORE the window is mapped.
        // Between map and the first frame the X server fills the window with
        // this pixel, and that gap is seconds on a window manager that never
        // finishes GTK's frame-sync handshake. Left at the default it flashes
        // white against a dark app — the reported "blank screens". Matched to the
        // window background, the same wait is invisible. (Verified as the visible
        // symptom by Tools/window-timing-spike.c, whose light theme made the very
        // same flash near-invisible: white on white.)
        let background = NSColor.windowBackgroundColor
        lc_set_window_background_rgb(asWidget(w),
                                     Double(background.redComponent),
                                     Double(background.greenComponent),
                                     Double(background.blueComponent))
        // Drop GTK's frame-sync handshake where there is no compositor to sync
        // WITH. GTK holds a newly mapped window's first frame until the window
        // manager acknowledges it through a sync counter; quartz-wm advertises
        // the protocol and never answers, so GTK waited out its timeout — a
        // measured ~2 s for every window after the first, identical to the
        // millisecond across two different code paths. On a composited desktop
        // the handshake earns its keep (it is what keeps resizing tear-free), so
        // this is deliberately scoped to displays with no compositor, where the
        // wait buys nothing. `LINCHOCOLATE_KEEP_WM_SYNC=1` restores it.
        let keepSync = !(ProcessInfo.processInfo.environment["LINCHOCOLATE_KEEP_WM_SYNC"] ?? "").isEmpty
        if nonComposited, !keepSync {
            lc_strip_wm_sync_request(asWidget(w))
        }
        installPaintTrace(handle)
        tracePaint(handle.rawValue, "pre-present")
        gtk_window_present(asWindow(w))
        tracePaint(handle.rawValue, "post-present")
        // NOTE: there is deliberately NO "wait until laid out" loop here.
        //
        // An earlier version pumped the main context after `present` so the
        // content would have a size before returning. It was wrong, and it was
        // the cause of the reported flashing rather than a fix for it: GTK lays
        // a window out on the frame clock, so every pumped iteration while the
        // window is mapped-but-unlaid-out lets GTK render and push a BLANK frame
        // to the display — "several repainting blank screens before the real
        // one". A pure-GTK4 control program (Tools/window-timing-spike.c) waits
        // just as long for its first frame on the same display (1131 ms for a
        // second window) and shows no flashing at all, precisely because it
        // never pumps: it returns to the main loop and paints once, when ready.
        //
        // The multi-second wait for a second window's first frame is GTK's/the
        // window manager's (quartz-wm does not complete the frame-sync
        // handshake). We cannot shorten it — but we must not make it visible.
        if !(ProcessInfo.processInfo.environment["LINCHOCOLATE_GEOMETRY_AUDIT"] ?? "").isEmpty {
            let box = ActionBox { [weak self] in self?.auditGeometry() }
            g_timeout_add_seconds(2, { userData in
                guard let userData else { return gboolean(0) }
                Unmanaged<ActionBox>.fromOpaque(userData).takeUnretainedValue().action()
                return gboolean(0)   // one shot
            }, Unmanaged.passRetained(box).toOpaque())
        }
    }

    // MARK: Geometry audit

    /// Compares every placed widget's AppKit frame against what GTK actually
    /// allocated it. Enabled with `LINCHOCOLATE_GEOMETRY_AUDIT=1`.
    ///
    /// The frame is authoritative in AppKit: a view IS its frame. GTK's
    /// `gtk_widget_set_size_request` only sets a *minimum* and documents that it
    /// "will not cause a widget to be smaller than its natural size" — so any
    /// widget whose intrinsic minimum exceeds its AppKit frame silently
    /// overflows and collides with its neighbours. This audit surfaces exactly
    /// which controls do that, and by how much.
    func auditGeometry() {
        print("── LinChocolate geometry audit ─────────────────────────────────────────────")
        print(String(format: "%-14@ %-18@ %-13@ %-13@ %-14@ %@", "kind" as NSString, "frame x,y,w,h" as NSString,
                     "min w,h" as NSString, "alloc w,h" as NSString, "self/parent" as NSString, "verdict" as NSString))
        var violations = 0
        var pending = 0
        for (raw, w) in widgets.sorted(by: { $0.key < $1.key }) {
            guard let frame = frames[raw], let parentRaw = parents[raw] else { continue }
            guard gtk_widget_get_mapped(asWidget(w)) != 0 else { continue }
            let kind = kinds[raw].map { String(describing: $0) } ?? "view"
            let flip = (flippedViews.contains(raw) ? "flip" : "unflip")
                + "/" + (flippedViews.contains(parentRaw) ? "flip" : "unflip")

            var minW: gint = 0, natW: gint = 0, minH: gint = 0, natH: gint = 0
            gtk_widget_measure(asWidget(w), GTK_ORIENTATION_HORIZONTAL, -1, &minW, &natW, nil, nil)
            gtk_widget_measure(asWidget(w), GTK_ORIENTATION_VERTICAL, -1, &minH, &natH, nil, nil)
            // Measure the *allocated* (border) box, not gtk_widget_get_width():
            // that returns the CSS content box — allocation minus margin, border
            // and padding — so a correctly placed control still reads short by
            // exactly its padding. compute_bounds gives the real rect.
            var allocW = -1, allocH = -1
            var actualX = Double.nan, actualY = Double.nan
            if let container = containerFixed(of: parentRaw) {
                var bounds = graphene_rect_t()
                if gtk_widget_compute_bounds(asWidget(w), asWidget(container), &bounds) != 0 {
                    actualX = Double(bounds.origin.x)
                    actualY = Double(bounds.origin.y)
                    allocW = Int(bounds.size.width.rounded())
                    allocH = Int(bounds.size.height.rounded())
                }
            }
            let wantX = Double(frame.origin.x)
            let wantY = Double(placementY(for: frame, in: parentRaw))

            // A 0x0 bounds means GTK has not allocated the widget yet, not that
            // it was allocated wrongly — an animating page (Auto Layout) can be
            // caught mid-relayout. Report it, but don't call it a frame fault.
            if allocW == 0 && allocH == 0 {
                pending += 1
                print("\(kind) \(Int(frame.origin.x)),\(Int(frame.origin.y)) — not allocated yet (mid-relayout?)")
                continue
            }
            var faults: [String] = []
            if allocW >= 0 && Int(frame.width) != allocW { faults.append("W \(Int(frame.width))→\(allocW)") }
            if allocH >= 0 && Int(frame.height) != allocH { faults.append("H \(Int(frame.height))→\(allocH)") }
            if actualX.isFinite && abs(actualX - wantX) > 0.5 { faults.append("X \(Int(wantX))→\(Int(actualX))") }
            if actualY.isFinite && abs(actualY - wantY) > 0.5 { faults.append("Y \(Int(wantY))→\(Int(actualY))") }
            if faults.isEmpty { continue }
            violations += 1
            let frameDesc = "\(Int(frame.origin.x)),\(Int(frame.origin.y)),\(Int(frame.width)),\(Int(frame.height))"
            print(String(format: "%-14@ %-18@ %-13@ %-13@ %-14@ %@",
                         kind as NSString, frameDesc as NSString,
                         "\(minW),\(minH)" as NSString, "\(allocW),\(allocH)" as NSString,
                         flip as NSString, faults.joined(separator: "  ") as NSString))
        }
        print("── \(violations) control(s) not honouring their AppKit frame"
              + (pending > 0 ? "; \(pending) not yet allocated" : "") + " ─────────────────")
        fflush(nil)   // stdout is fully buffered when piped
    }

    /// Hides the window without destroying it (AppKit's `orderOut`).
    public func setWindowResizeAction(for handle: NativeHandle, _ handler: @escaping (Double, Double) -> Void) {
        // GTK4 has no public size-allocate signal, and a window's
        // default-width/height do NOT change for a resize driven by the WM — so
        // neither is usable here. The content view's DRAW pass is: it re-runs
        // with the new width/height on every resize (that is what repaints the
        // background at the new size). `noteContentDraw` compares sizes there and
        // fires this handler when it actually changed.
        windowResizeActions[handle.rawValue] = handler
    }
    /// Called from the content view's draw pass. Fires the window's resize
    /// handler when the size really changed, from an idle callback so layout
    /// never runs inside a draw.
    func noteContentDraw(view raw: UInt, width: Double, height: Double) {
        guard let window = contentViewOwners[raw], let handler = windowResizeActions[window] else { return }
        guard lastContentSizes[window] != NSMakeSize(width, height) else { return }
        let isFirstSize = lastContentSizes[window] == nil
        lastContentSizes[window] = NSMakeSize(width, height)
        // The first size is the window's initial layout, not a resize: AppKit
        // does not post `windowDidResize` for it. Recording it as the baseline
        // (and not notifying) also spares a layout pass during the first map.
        guard !isFirstSize else { return }
        let box = ActionBox { handler(width, height) }
        g_idle_add({ userData in
            guard let userData else { return gboolean(0) }
            Unmanaged<ActionBox>.fromOpaque(userData).takeUnretainedValue().action()
            return gboolean(0)   // one shot
        }, Unmanaged.passRetained(box).toOpaque())
    }
    public func setWindowParent(_ parent: NativeHandle, for handle: NativeHandle) {
        guard let w = widget(handle), let p = widget(parent) else { return }
        // A transient window is placed and decorated by the WM as a utility
        // window of its parent, in one pass. Without this a panel maps as an
        // unrelated new toplevel and goes through full placement/decoration
        // negotiation — extra visible mapping work on a remote/slow display.
        gtk_window_set_transient_for(asWindow(w), asWindow(p))
        // AppKit keeps the panel alive independently of the parent's lifetime.
        gtk_window_set_destroy_with_parent(asWindow(w), gboolean(0))
    }
    public func hideWindow(_ handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_widget_set_visible(asWidget(w), gboolean(0))
    }

    public func toggleZoomWindow(_ handle: NativeHandle) {
        // Track intent ourselves. AppKit's `zoom(_:)` is synchronous — `isZoomed`
        // reads true the instant it returns — but GTK's `is_maximized` reflects
        // the compositor's *acknowledged* surface state, which lands a frame or
        // two later (and never, with no window manager). Mirroring the request
        // keeps `isZoomed` truthful immediately, as the demo reads it.
        let nowZoomed = !zoomedWindows.contains(handle.rawValue)
        guard let content = windowContents[handle.rawValue], let w = widget(handle) else { return }
        let cw = asWidget(content)
        let win = asWindow(w)
        if nowZoomed {
            zoomedWindows.insert(handle.rawValue)
            // Zoom on Linux follows the desktop convention (fill the screen), NOT
            // AppKit's fit-to-content. We do NOT call `gtk_window_maximize`: the
            // diagnostic proved that under quartz-wm (XQuartz) it locks the window
            // size and the surface never grows — the content stayed 1120 in a
            // maximized frame (the black void). Instead we grow the CONTENT to the
            // monitor size, which makes GTK issue a normal client resize; a WM that
            // honors client resizes (mutter/kwin, and — un-maximized — quartz-wm)
            // grows the surface, and the content's expand/fill makes it cover the
            // window. Children stay frame-placed.
            let (mw, mh) = monitorWorkArea()
            // Remember the window's current size so un-zoom restores it.
            preZoomContentSize[handle.rawValue] = (Int32(gtk_widget_get_width(UnsafeMutablePointer<GtkWidget>(OpaquePointer(win)))),
                                                   Int32(gtk_widget_get_height(UnsafeMutablePointer<GtkWidget>(OpaquePointer(win)))))
            // The content must FILL whatever the window becomes; it must not be
            // floored by a size_request (a floor also blocks later shrinking, and
            // an over-large floor makes a WM refuse the resize outright).
            gtk_widget_set_hexpand(cw, gboolean(1)); gtk_widget_set_vexpand(cw, gboolean(1))
            gtk_widget_set_halign(cw, GTK_ALIGN_FILL); gtk_widget_set_valign(cw, GTK_ALIGN_FILL)
            // GTK4 has no `gtk_window_resize`; set_default_size resizes a mapped
            // window. Sizes are LOGICAL pixels — the monitor geometry comes back in
            // device pixels on a scaled/retina display (3200x1767 on the reporter's
            // Mac), and asking for a window larger than the screen is exactly what
            // quartz-wm refused.
            gtk_window_set_default_size(win, mw, mh)
            gtk_widget_queue_resize(cw)
            logZoom("request", handle: handle, content: cw, window: win, req: (mw, mh))
        } else {
            zoomedWindows.remove(handle.rawValue)
            if let (rw, rh) = preZoomContentSize[handle.rawValue], rw > 0, rh > 0 {
                gtk_window_set_default_size(win, rw, rh)
                preZoomContentSize[handle.rawValue] = nil
            }
        }
    }
    /// Env-gated (`LINCHOCOLATE_ZOOM_DEBUG`) diagnostics: logs the requested size
    /// now, and the content's *actual* allocation a moment later. Lets us see, on
    /// a setup we can't reproduce, whether the monitor query or the resize is the
    /// problem.
    private func logZoom(_ phase: String, handle: NativeHandle, content: UnsafeMutablePointer<GtkWidget>,
                         window: UnsafeMutablePointer<GtkWindow>, req: (Int32, Int32)) {
        guard !(ProcessInfo.processInfo.environment["LINCHOCOLATE_ZOOM_DEBUG"] ?? "").isEmpty else { return }
        FileHandle.standardError.write("ZOOM \(phase): monitor req=\(req.0)x\(req.1)\n".data(using: .utf8)!)
        let box = ActionBox {
            let cw = gtk_widget_get_width(content), ch = gtk_widget_get_height(content)
            let ww = gtk_widget_get_width(UnsafeMutablePointer<GtkWidget>(OpaquePointer(window)))
            let wh = gtk_widget_get_height(UnsafeMutablePointer<GtkWidget>(OpaquePointer(window)))
            FileHandle.standardError.write("ZOOM alloc: content=\(cw)x\(ch) window=\(ww)x\(wh)\n".data(using: .utf8)!)
        }
        g_timeout_add(guint(700), { ud in
            Unmanaged<ActionBox>.fromOpaque(ud!).takeUnretainedValue().action(); return gboolean(0)
        }, Unmanaged.passRetained(box).toOpaque())
    }
    /// The geometry of the primary monitor, for sizing a zoomed window. Falls
    /// back to a generous default when no monitor is enumerable (headless / some
    /// XQuartz setups) so zoom still grows the content.
    private func monitorWorkArea() -> (Int32, Int32) {
        let fallback: (Int32, Int32) = (1680, 1040)
        guard let display = gdk_display_get_default() else { return fallback }
        let monitors = gdk_display_get_monitors(display)
        guard let raw = g_list_model_get_item(monitors, 0) else { return fallback }
        var geo = GdkRectangle()
        gdk_monitor_get_geometry(OpaquePointer(raw), &geo)
        // GdkMonitor reports DEVICE pixels; windows are sized in logical pixels.
        // On a retina Mac that is a 2x difference — asking for the device size
        // makes the window bigger than the screen, which a WM may refuse outright.
        let scale = Swift.max(1, gdk_monitor_get_scale_factor(OpaquePointer(raw)))
        g_object_unref(raw)
        guard geo.width > 0, geo.height > 0 else { return fallback }
        return (geo.width / scale, geo.height / scale)
    }
    public func isWindowZoomed(_ handle: NativeHandle) -> Bool {
        zoomedWindows.contains(handle.rawValue)
    }
    public func miniaturizeWindow(_ handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_window_minimize(asWindow(w))
    }

    /// Updates the window's title-bar text.
    public func setWindowTitle(_ title: String, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_window_set_title(asWindow(w), title)
    }
    /// Builds a `GtkPopoverMenuBar` from `menus` and installs it above the content view.
    public func installMenuBar(_ menus: [NativeMenuSpec], on window: NativeHandle) {
        guard let w = widget(window), let box = windowBoxes[window.rawValue] else { return }

        // Build the GMenu model and a matching action group. Item actions are
        // GSimpleActions named "m<N>" in the window-scoped "win" group;
        // separators become GMenu section boundaries.
        let root = g_menu_new()!
        let group = g_simple_action_group_new()!
        // Key equivalents become GtkShortcuts on a window-scoped controller.
        let shortcuts = gtk_shortcut_controller_new()!
        gtk_shortcut_controller_set_scope(shortcuts, GTK_SHORTCUT_SCOPE_MANAGED)
        for menu in menus {
            let submenu = g_menu_new()!
            var section = g_menu_new()!
            for item in menu.items {
                if item.isSeparator {
                    g_menu_append_section(submenu, nil, asMenuModel(section))
                    section = g_menu_new()!
                    continue
                }
                menuActionCounter += 1
                let name = "m\(menuActionCounter)"
                if let accel = item.accelerator {
                    let menuItem = g_menu_item_new(item.title, "win.\(name)")!
                    g_menu_item_set_attribute_value(menuItem, "accel", g_variant_new_string(accel))
                    g_menu_append_item(section, menuItem)
                    g_object_unref(UnsafeMutableRawPointer(menuItem))
                    if let trigger = gtk_shortcut_trigger_parse_string(accel) {
                        let shortcut = gtk_shortcut_new(trigger, gtk_named_action_new("win.\(name)"))
                        gtk_shortcut_controller_add_shortcut(shortcuts, shortcut)
                    }
                } else {
                    g_menu_append(section, item.title, "win.\(name)")
                }
                let gaction = g_simple_action_new(name, nil)!
                if let action = item.action {
                    let box = ActionBox(action)
                    g_signal_connect_data(
                        UnsafeMutableRawPointer(gaction), "activate",
                        unsafeBitCast(gtkMenuActivateTrampoline, to: GCallback.self),
                        Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
                    )
                }
                g_action_map_add_action(OpaquePointer(group), gaction)
            }
            g_menu_append_section(submenu, nil, asMenuModel(section))
            g_menu_append_submenu(root, menu.title, asMenuModel(submenu))
        }
        gtk_widget_insert_action_group(asWidget(w), "win", OpaquePointer(group))
        gtk_widget_add_controller(asWidget(w), shortcuts)

        // Replace any existing bar, then put the new one at the top of the box.
        if let oldBar = windowMenuBars[window.rawValue] {
            gtk_box_remove(asBox(box), asWidget(oldBar))
        }
        let bar = gtk_popover_menu_bar_new_from_model(asMenuModel(root))!
        gtk_box_prepend(asBox(box), bar)
        windowMenuBars[window.rawValue] = OpaquePointer(bar)
    }
    /// Presents a composed modal alert (modal `GtkWindow` + nested `GMainLoop`) and returns the pressed button's index.
    public func runAlert(message: String, informative: String, buttons: [String], for window: NativeHandle?) -> Int {
        // Composed modal alert: GTK4 removed blocking dialogs (gtk_dialog_run),
        // and its dialog constructors are C-variadic (uncallable from Swift), so
        // AppKit's synchronous `runModal` is built from a modal GtkWindow plus a
        // nested GMainLoop that runs until a button responds.
        let alert = gtk_window_new()!
        // Modal only on composited displays: on XQuartz a modal window that
        // fails to map grabs all input and the app looks hung (seen with the
        // color chooser). Non-modal still blocks `runModal` via the nested
        // loop, but can never input-lock the app.
        if !nonComposited {
            gtk_window_set_modal(asWindow(OpaquePointer(alert)), gboolean(1))
        }
        gtk_window_set_resizable(asWindow(OpaquePointer(alert)), gboolean(0))
        if let window, let parent = widget(window) {
            gtk_window_set_transient_for(asWindow(OpaquePointer(alert)), asWindow(parent))
        }

        let vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 12)!
        gtk_widget_set_margin_top(vbox, 20); gtk_widget_set_margin_bottom(vbox, 16)
        gtk_widget_set_margin_start(vbox, 24); gtk_widget_set_margin_end(vbox, 24)

        let title = gtk_label_new(message)!
        gtk_widget_add_css_class(title, "title-4")   // GTK's built-in heading style
        gtk_box_append(asBox(OpaquePointer(vbox)), title)
        if !informative.isEmpty {
            let detail = gtk_label_new(informative)!
            gtk_box_append(asBox(OpaquePointer(vbox)), detail)
        }

        let loop = g_main_loop_new(nil, gboolean(0))
        let state = AlertState(loop: loop)

        let buttonRow = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8)!
        gtk_widget_set_halign(buttonRow, GTK_ALIGN_END)
        gtk_widget_set_margin_top(buttonRow, 8)
        // AppKit shows the first (default) button rightmost; append in reverse.
        for (index, buttonTitle) in buttons.enumerated().reversed() {
            let button = gtk_button_new_with_label(buttonTitle)!
            let box = AlertButtonBox(index: index, state: state)
            g_signal_connect_data(
                UnsafeMutableRawPointer(button), "clicked",
                unsafeBitCast(gtkAlertButtonTrampoline, to: GCallback.self),
                Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
            )
            gtk_box_append(asBox(OpaquePointer(buttonRow)), button)
        }
        gtk_box_append(asBox(OpaquePointer(vbox)), buttonRow)

        gtk_window_set_child(asWindow(OpaquePointer(alert)), vbox)
        // Closing the alert's window is a dismissal too. Without this the nested
        // loop below runs forever: the app keeps processing events and looks
        // fine, but `terminate` quits the OUTER loop and so Quit silently does
        // nothing. (Alerts are deliberately non-modal on non-composited displays,
        // which gives them a real close button — easy to hit.) Report the last
        // button, AppKit's cancel-ish answer for a dismissed alert.
        let closeBox = AlertButtonBox(index: Swift.max(0, buttons.count - 1), state: state)
        g_signal_connect_data(
            UnsafeMutableRawPointer(alert), "close-request",
            unsafeBitCast(gtkAlertCloseTrampoline, to: GCallback.self),
            Unmanaged.passRetained(closeBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        gtk_window_present(asWindow(OpaquePointer(alert)))
        pushNestedLoop(loop)
        g_main_loop_run(loop)   // blocks until a button (or the close box) quits it
        popNestedLoop()

        gtk_window_destroy(asWindow(OpaquePointer(alert)))
        return state.response
    }
    /// Rebuilds the window's toolbar as a horizontal `GtkBox` styled for the Apple look.
    public func installToolbar(_ items: [NativeToolbarItemSpec], displayMode: NativeToolbarDisplayMode = .iconAndLabel, on window: NativeHandle) {
        guard let box = windowBoxes[window.rawValue] else { return }
        // Detach any embedded custom views (page selector, search field, …) from
        // the old bar first so removing it doesn't destroy widgets we still own.
        // Unparenting drops the bar's reference — which is the ONLY one, so the
        // widget would be destroyed before the rebuilt bar could re-embed it
        // (the disappearing page-selector bug). Hold a reference across the move.
        var detachedViews: [OpaquePointer] = []
        for view in windowToolbarViews[window.rawValue] ?? [] {
            if gtk_widget_get_parent(asWidget(view)) != nil {
                g_object_ref(UnsafeMutableRawPointer(view))
                detachedViews.append(view)
                gtk_widget_unparent(asWidget(view))
            }
        }
        windowToolbarViews[window.rawValue] = []
        defer {
            // The rebuilt bar has re-parented (and re-referenced) every view it
            // embeds by the time installToolbar returns; release our hold.
            for view in detachedViews {
                g_object_unref(UnsafeMutableRawPointer(view))
            }
        }
        if let old = windowToolbars[window.rawValue] {
            gtk_box_remove(asBox(box), asWidget(old))
        }
        let bar = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 4)!
        gtk_widget_add_css_class(bar, "linchocolate-toolbar")
        for item in items {
            if item.isFlexibleSpace {
                let spacer = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0)!
                gtk_widget_set_hexpand(spacer, gboolean(1))
                gtk_box_append(asBox(OpaquePointer(bar)), spacer)
                continue
            }
            // Apple's standard separator/space items are visual elements, not buttons.
            if item.identifier == "NSToolbarSeparatorItem" {
                let divider = gtk_separator_new(GTK_ORIENTATION_VERTICAL)!
                gtk_widget_set_margin_top(divider, 6)
                gtk_widget_set_margin_bottom(divider, 6)
                gtk_box_append(asBox(OpaquePointer(bar)), divider)
                continue
            }
            if item.identifier == "NSToolbarSpaceItem" {
                let gap = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0)!
                gtk_widget_set_size_request(gap, 16, 1)
                gtk_box_append(asBox(OpaquePointer(bar)), gap)
                continue
            }
            // A view-based item (AppKit's NSToolbarItem.view): embed the control
            // widget itself (a pop-up, a search field, …) rather than a button.
            if let viewHandle = item.viewHandle, let viewWidget = widget(viewHandle) {
                if gtk_widget_get_parent(asWidget(viewWidget)) != nil {
                    gtk_widget_unparent(asWidget(viewWidget))
                }
                gtk_widget_set_valign(asWidget(viewWidget), GTK_ALIGN_CENTER)
                gtk_box_append(asBox(OpaquePointer(bar)), asWidget(viewWidget))
                windowToolbarViews[window.rawValue, default: []].append(viewWidget)
                continue
            }
            let button: UnsafeMutablePointer<GtkWidget>
            if let content = makeToolbarItemContent(item, displayMode: displayMode) {
                button = gtk_button_new()!
                gtk_button_set_child(asButton(OpaquePointer(button)), content)
            } else {
                button = gtk_button_new_with_label(item.label)!
            }
            if let action = item.action {
                let actionBox = ActionBox(action)
                g_signal_connect_data(
                    UnsafeMutableRawPointer(button), "clicked",
                    unsafeBitCast(gtkActionTrampoline, to: GCallback.self),
                    Unmanaged.passRetained(actionBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
                )
            }
            gtk_box_append(asBox(OpaquePointer(bar)), button)
        }
        // Below the menu bar if present, else at the very top.
        let anchor = windowMenuBars[window.rawValue]
        gtk_box_insert_child_after(asBox(box), bar, anchor.map(asWidget))
        windowToolbars[window.rawValue] = OpaquePointer(bar)
    }
    /// Builds a toolbar item's visual content for a display mode: icon over
    /// label (Apple's .iconAndLabel), icon only, or label only. Returns nil
    /// when there is nothing but a plain label to show.
    private func makeToolbarItemContent(_ item: NativeToolbarItemSpec,
                                        displayMode: NativeToolbarDisplayMode) -> UnsafeMutablePointer<GtkWidget>? {
        var icon: UnsafeMutablePointer<GtkWidget>?
        if displayMode != .labelOnly {
            if let path = item.imagePath {
                icon = makeToolbarImage(path: path, template: item.imageIsTemplate)
            } else if let iconName = item.iconName {
                let themed = gtk_image_new_from_icon_name(iconName)!
                gtk_image_set_pixel_size(OpaquePointer(themed), 22)
                icon = themed
            }
        }
        guard icon != nil || displayMode == .labelOnly else { return nil }
        let content = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2)!
        gtk_widget_set_halign(content, GTK_ALIGN_CENTER)
        if let icon { gtk_box_append(asBox(OpaquePointer(content)), icon) }
        if displayMode != .iconOnly && !item.label.isEmpty {
            gtk_box_append(asBox(OpaquePointer(content)), gtk_label_new(item.label))
        }
        if displayMode == .labelOnly && item.label.isEmpty { return nil }
        return content
    }

    /// Loads a file-backed toolbar icon. Template images are pure-alpha
    /// artwork (the demo's Tabler PNGs are black-on-transparent): recolor every
    /// pixel to the theme foreground, keeping alpha — AppKit's template
    /// semantics, so one shipped image serves both appearances.
    private func makeToolbarImage(path: String, template: Bool) -> UnsafeMutablePointer<GtkWidget>? {
        guard let pixbuf = gdk_pixbuf_new_from_file(path, nil) else { return nil }
        if template, gdk_pixbuf_get_has_alpha(pixbuf) != 0, gdk_pixbuf_get_n_channels(pixbuf) == 4 {
            let fg: (UInt8, UInt8, UInt8) = prefersDarkAppearance ? (238, 238, 236) : (46, 52, 54)
            let width = Int(gdk_pixbuf_get_width(pixbuf))
            let height = Int(gdk_pixbuf_get_height(pixbuf))
            let stride = Int(gdk_pixbuf_get_rowstride(pixbuf))
            if let pixels = gdk_pixbuf_get_pixels(pixbuf) {
                for y in 0..<height {
                    for x in 0..<width {
                        let p = pixels + y * stride + x * 4
                        p[0] = fg.0
                        p[1] = fg.1
                        p[2] = fg.2
                    }
                }
            }
        }
        guard let texture = gdk_texture_new_for_pixbuf(pixbuf) else { return nil }
        let image = gtk_image_new_from_paintable(texture)!
        gtk_image_set_pixel_size(OpaquePointer(image), 22)
        return image
    }

    /// The open customization panel's live widgets, for in-place refresh.
    private struct CustomizationPanelState {
        var panel: OpaquePointer
        var stripHolder: OpaquePointer
        var paletteHolder: OpaquePointer
        var handlers: NativeToolbarCustomizationHandlers
        var displayModeIndex: Int
    }
    private var customizationState: CustomizationPanelState?

    /// Presents the toolbar customization panel as a modal `GtkWindow` with duplicate strip, palette, and default set.
    public func runToolbarCustomization(_ session: NativeToolbarCustomizationSession,
                                        handlers: NativeToolbarCustomizationHandlers,
                                        for window: NativeHandle) {
        let panel = gtk_window_new()!
        gtk_window_set_title(asWindow(OpaquePointer(panel)), "Customize Toolbar")
        gtk_window_set_resizable(asWindow(OpaquePointer(panel)), gboolean(0))
        if let parent = widget(window) {
            gtk_window_set_transient_for(asWindow(OpaquePointer(panel)), asWindow(parent))
        }
        if !nonComposited { gtk_window_set_modal(asWindow(OpaquePointer(panel)), gboolean(1)) }

        let vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 12)!
        gtk_widget_set_margin_top(vbox, 16); gtk_widget_set_margin_bottom(vbox, 14)
        gtk_widget_set_margin_start(vbox, 20); gtk_widget_set_margin_end(vbox, 20)
        gtk_widget_add_css_class(vbox, "linchocolate-palette")

        // The duplicated bar — the drag-and-drop surface (the WinChocolate
        // concession: dragging into the real toolbar would cross windows).
        let stripHolder = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        gtk_box_append(asBox(OpaquePointer(vbox)), stripHolder)

        let heading = gtk_label_new("Drag your favorite items into the toolbar…")!
        gtk_widget_set_halign(heading, GTK_ALIGN_START)
        gtk_box_append(asBox(OpaquePointer(vbox)), heading)

        // Palette grid (drag sources; present items dimmed).
        let paletteHolder = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        gtk_box_append(asBox(OpaquePointer(vbox)), paletteHolder)

        let heading2 = gtk_label_new("… or drag the default set into the toolbar.")!
        gtk_widget_set_halign(heading2, GTK_ALIGN_START)
        gtk_box_append(asBox(OpaquePointer(vbox)), heading2)

        // The default set: one draggable unit that resets the strip.
        let defaultBar = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 4)!
        gtk_widget_add_css_class(defaultBar, "linchocolate-toolbar")
        for item in session.defaultSet {
            let tile = makeStripTileWidget(spec(for: item), displayMode: .iconAndLabel)
            gtk_widget_set_sensitive(tile, gboolean(0))
            gtk_box_append(asBox(OpaquePointer(defaultBar)), tile)
        }
        addDragSource(to: defaultBar, payload: "default")
        gtk_box_append(asBox(OpaquePointer(vbox)), defaultBar)

        // Bottom row: Show [mode] … Done.
        let bottom = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8)!
        gtk_box_append(asBox(OpaquePointer(bottom)), gtk_label_new("Show"))
        var modeStrings: [UnsafePointer<CChar>?] = []
        for mode in ["Icon and Text", "Icon Only", "Text Only"] { modeStrings.append(UnsafePointer(strdup(mode))) }
        modeStrings.append(nil)
        let dropdown = modeStrings.withUnsafeMutableBufferPointer { buffer in
            gtk_drop_down_new_from_strings(buffer.baseAddress)!
        }
        gtk_drop_down_set_selected(OpaquePointer(dropdown), guint(session.displayModeIndex))
        let modeBox = DropDownBox(dropdown: OpaquePointer(dropdown)) { [weak self] index in
            guard let self, self.customizationState != nil else { return }
            handlers.onDisplayMode(index)
        }
        g_signal_connect_data(
            UnsafeMutableRawPointer(dropdown), "notify::selected",
            unsafeBitCast(gtkDropDownSelectedTrampoline, to: GCallback.self),
            Unmanaged.passRetained(modeBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        gtk_box_append(asBox(OpaquePointer(bottom)), dropdown)
        let spacer = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0)!
        gtk_widget_set_hexpand(spacer, gboolean(1))
        gtk_box_append(asBox(OpaquePointer(bottom)), spacer)
        let done = gtk_button_new_with_label("Done")!
        gtk_widget_add_css_class(done, "suggested-action")
        let doneBox = ActionBox { [weak self] in
            self?.customizationState = nil
            handlers.onClose()
            gtk_window_destroy(UnsafeMutablePointer<GtkWindow>(OpaquePointer(panel)))
        }
        g_signal_connect_data(
            UnsafeMutableRawPointer(done), "clicked",
            unsafeBitCast(gtkActionTrampoline, to: GCallback.self),
            Unmanaged.passRetained(doneBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        gtk_box_append(asBox(OpaquePointer(bottom)), done)
        gtk_box_append(asBox(OpaquePointer(vbox)), bottom)

        // Dropping a strip item on the panel body (not the strip) removes it —
        // Apple's drag-off-the-toolbar gesture.
        addDropTarget(to: vbox) { [weak self] payload, _, _ in
            guard let self, self.customizationState != nil else { return false }
            if payload.hasPrefix("strip:"), let index = Int(payload.dropFirst(6)) {
                self.customizationState?.handlers.onRemove(index)
                return true
            }
            return false
        }

        // The window-close (X) also ends the session.
        let closeBox = ActionBox { [weak self] in
            self?.customizationState = nil
            handlers.onClose()
        }
        g_signal_connect_data(
            UnsafeMutableRawPointer(panel), "close-request",
            unsafeBitCast(gtkCloseRequestTrampoline, to: GCallback.self),
            Unmanaged.passRetained(closeBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )

        gtk_window_set_child(asWindow(OpaquePointer(panel)), vbox)
        customizationState = CustomizationPanelState(panel: OpaquePointer(panel),
                                                     stripHolder: OpaquePointer(stripHolder),
                                                     paletteHolder: OpaquePointer(paletteHolder),
                                                     handlers: handlers,
                                                     displayModeIndex: session.displayModeIndex)
        rebuildCustomizationContent(session)
        gtk_window_present(asWindow(OpaquePointer(panel)))
    }

    /// Refreshes the open customization panel's strip and palette in place.
    public func updateToolbarCustomization(_ session: NativeToolbarCustomizationSession) {
        guard customizationState != nil else { return }
        customizationState?.displayModeIndex = session.displayModeIndex
        rebuildCustomizationContent(session)
    }

    /// (Re)fills the strip duplicate and palette grid from the session.
    private func rebuildCustomizationContent(_ session: NativeToolbarCustomizationSession) {
        guard let state = customizationState else { return }

        while let child = gtk_widget_get_first_child(asWidget(state.stripHolder)) {
            gtk_box_remove(asBox(state.stripHolder), child)
        }
        let strip = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 4)!
        gtk_widget_add_css_class(strip, "linchocolate-toolbar")
        gtk_widget_set_size_request(strip, 660, 52)
        let displayMode: NativeToolbarDisplayMode = [.iconAndLabel, .iconOnly, .labelOnly][min(max(state.displayModeIndex, 0), 2)]
        for (index, item) in session.strip.enumerated() {
            let tile = makeStripTileWidget(item, displayMode: displayMode)
            addDragSource(to: tile, payload: "strip:\(index)")
            gtk_box_append(asBox(OpaquePointer(strip)), tile)
        }
        addDropTarget(to: strip) { [weak self] payload, x, _ in
            guard let self, let state = self.customizationState else { return false }
            let index = self.stripInsertionIndex(in: OpaquePointer(strip), x: x)
            if payload == "default" {
                state.handlers.onResetToDefault()
                return true
            }
            if payload.hasPrefix("new:") {
                state.handlers.onInsert(String(payload.dropFirst(4)), index)
                return true
            }
            if payload.hasPrefix("strip:"), let from = Int(payload.dropFirst(6)) {
                state.handlers.onMove(from, index)
                return true
            }
            return false
        }
        gtk_box_append(asBox(state.stripHolder), strip)

        while let child = gtk_widget_get_first_child(asWidget(state.paletteHolder)) {
            gtk_box_remove(asBox(state.paletteHolder), child)
        }
        let columns = 4
        let grid = gtk_grid_new()!
        gtk_grid_set_row_spacing(asGrid(OpaquePointer(grid)), 8)
        gtk_grid_set_column_spacing(asGrid(OpaquePointer(grid)), 8)
        let multiInstance: Set<String> = ["NSToolbarSeparatorItem", "NSToolbarSpaceItem", "NSToolbarFlexibleSpaceItem"]
        for (index, item) in session.palette.enumerated() {
            let tile = gtk_box_new(GTK_ORIENTATION_VERTICAL, 3)!
            gtk_widget_add_css_class(tile, "linchocolate-palette-tile")
            gtk_widget_set_size_request(tile, 120, 56)
            let content = makeStripTileWidget(spec(for: item), displayMode: .iconAndLabel)
            gtk_widget_set_valign(content, GTK_ALIGN_CENTER)
            gtk_widget_set_vexpand(content, gboolean(1))
            gtk_widget_set_halign(content, GTK_ALIGN_CENTER)
            gtk_box_append(asBox(OpaquePointer(tile)), content)
            if item.isInToolbar && !multiInstance.contains(item.identifier) {
                gtk_widget_set_sensitive(tile, gboolean(0))   // dimmed, as on Apple
            } else {
                addDragSource(to: tile, payload: "new:\(item.identifier)")
            }
            gtk_grid_attach(asGrid(OpaquePointer(grid)), tile,
                            gint(index % columns), gint(index / columns), 1, 1)
        }
        gtk_box_append(asBox(state.paletteHolder), grid)
    }

    /// A palette entry rendered as an item spec (for the shared tile builder).
    private func spec(for item: NativeToolbarPaletteItem) -> NativeToolbarItemSpec {
        NativeToolbarItemSpec(imagePath: item.imagePath, imageIsTemplate: item.imageIsTemplate,
                              identifier: item.identifier, label: item.label,
                              iconName: item.iconName)
    }

    /// A strip/palette tile: the item content in a flat button-look box.
    private func makeStripTileWidget(_ item: NativeToolbarItemSpec,
                                     displayMode: NativeToolbarDisplayMode) -> UnsafeMutablePointer<GtkWidget> {
        if item.identifier == "NSToolbarSeparatorItem" {
            let divider = gtk_separator_new(GTK_ORIENTATION_VERTICAL)!
            gtk_widget_set_margin_top(divider, 6); gtk_widget_set_margin_bottom(divider, 6)
            return divider
        }
        if item.identifier == "NSToolbarFlexibleSpaceItem" || item.identifier == "NSToolbarSpaceItem" {
            let label = gtk_label_new(item.identifier == "NSToolbarSpaceItem" ? "Space" : "Flexible Space")!
            gtk_widget_add_css_class(label, "dim-label")
            return label
        }
        if let content = makeToolbarItemContent(item, displayMode: displayMode) {
            return content
        }
        return gtk_label_new(item.label)!
    }

    /// The insertion index for a drop at `x` over the strip: before the first
    /// tile whose midpoint is right of the pointer.
    private func stripInsertionIndex(in strip: OpaquePointer, x: Double) -> Int {
        var index = 0
        var child = gtk_widget_get_first_child(asWidget(strip))
        var edge = 0.0
        while let current = child {
            let width = Double(gtk_widget_get_width(current))
            if x < edge + width / 2 { return index }
            edge += width + 4
            index += 1
            child = gtk_widget_get_next_sibling(current)
        }
        return index
    }

    /// Attaches a string drag source carrying `payload`.
    private func addDragSource(to widget: UnsafeMutablePointer<GtkWidget>, payload: String) {
        let source = gtk_drag_source_new()
        gtk_drag_source_set_actions(source, GDK_ACTION_COPY)
        let box = DragPayloadBox(payload)
        g_signal_connect_data(
            UnsafeMutableRawPointer(source), "prepare",
            unsafeBitCast(gtkPaletteDragPrepareTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        gtk_widget_add_controller(widget, source)
    }

    /// Attaches a string drop target; `handle` reports whether the drop landed.
    private func addDropTarget(to widget: UnsafeMutablePointer<GtkWidget>,
                               handle: @escaping (String, Double, Double) -> Bool) {
        let target = gtk_drop_target_new(GType(16 << 2), GDK_ACTION_COPY)
        let box = DropHandlerBox(handle)
        g_signal_connect_data(
            UnsafeMutableRawPointer(target), "drop",
            unsafeBitCast(gtkPaletteDropTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        gtk_widget_add_controller(widget, target)
    }

    /// Presents a modal `GtkFileDialog` in open mode and returns the chosen path (nil on cancel).
    public func runOpenPanel(directory: String?, for window: NativeHandle?) -> String? {
        runFileDialog(open: true, directory: directory, suggestedName: nil, for: window)
    }
    /// Presents a modal `GtkFileDialog` in save mode and returns the chosen path (nil on cancel).
    public func runSavePanel(directory: String?, suggestedName: String?, for window: NativeHandle?) -> String? {
        runFileDialog(open: false, directory: directory, suggestedName: suggestedName, for: window)
    }

    /// Runs the file chooser through the C compatibility layer so Ubuntu 22.04's
    /// GTK 4.6 can compile without newer `GtkFileDialog` symbols.
    private func runFileDialog(open: Bool, directory: String?, suggestedName: String?, for window: NativeHandle?) -> String? {
        let parent = window.flatMap { widget($0) }.map { asWindow($0) }
        guard let cPath = lc_run_file_chooser(parent, open ? 1 : 0, directory, suggestedName) else {
            return nil
        }
        defer { g_free(cPath) }
        return String(cString: cPath)
    }
    /// Wires `action` to the window's `close-request` signal.
    public func registerWindowCloseAction(for handle: NativeHandle, action: @escaping () -> Void) {
        guard let w = widget(handle) else { return }
        let box = ActionBox(action)
        g_signal_connect_data(
            UnsafeMutableRawPointer(w), "close-request",
            unsafeBitCast(gtkCloseRequestTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
    }

    // MARK: Popover
    private var popoverParented: Set<UInt> = []
    /// Creates a `GtkPopover` with autohide enabled.
    public func createPopover() -> NativeHandle {
        let pop = gtk_popover_new()!
        gtk_popover_set_autohide(asPopover(OpaquePointer(pop)), gboolean(1))
        if nonComposited { gtk_popover_set_has_arrow(asPopover(OpaquePointer(pop)), gboolean(0)) }
        return allocate(pop, .view, frame: .zero)
    }
    /// Installs `content` as the popover's child and sizes it.
    public func setPopoverContent(_ content: NativeHandle, size: NSSize, for popover: NativeHandle) {
        guard let pop = widget(popover), let c = widget(content) else { return }
        gtk_widget_set_size_request(asWidget(c), Int32(size.width), Int32(size.height))
        gtk_popover_set_child(asPopover(pop), asWidget(c))
    }
    /// Anchors the popover to `view` at `rect` on `edge` and pops it up.
    public func showPopover(_ popover: NativeHandle, relativeTo view: NativeHandle, rect: NSRect, edge: Int) {
        guard let pop = widget(popover), let v = widget(view) else { return }
        if !popoverParented.contains(popover.rawValue) {
            gtk_widget_set_parent(asWidget(pop), asWidget(v))
            popoverParented.insert(popover.rawValue)
        }
        // Flip the AppKit rect into the view's GTK (top-left) coordinates.
        let viewHeight = Double(gtk_widget_get_height(asWidget(v)))
        var pointing = GdkRectangle(x: Int32(rect.minX), y: Int32(viewHeight - Double(rect.maxY)),
                                    width: Int32(rect.width), height: Int32(rect.height))
        gtk_popover_set_pointing_to(asPopover(pop), &pointing)
        // NSRectEdge raw: minX=0, minY=1, maxX=2, maxY=3.
        let position: GtkPositionType = edge == 0 ? GTK_POS_LEFT : edge == 2 ? GTK_POS_RIGHT : GTK_POS_BOTTOM
        gtk_popover_set_position(asPopover(pop), position)
        gtk_popover_popup(asPopover(pop))
    }
    /// Pops the popover down.
    public func closePopover(_ popover: NativeHandle) {
        guard let pop = widget(popover) else { return }
        gtk_popover_popdown(asPopover(pop))
    }

    // MARK: Views & controls
    /// Creates a container view: a `GtkOverlay` with a `GtkDrawingArea` under a `GtkFixed`.
    public func createView(frame: NSRect) -> NativeHandle {
        // An NSView both draws (AppKit `draw(_:)`) and contains children, so it
        // is a GtkOverlay: a GtkDrawingArea underneath for custom drawing, and
        // a GtkFixed on top for absolute child placement.
        let overlay = gtk_overlay_new()!
        let area = gtk_drawing_area_new()!
        let fixed = gtk_fixed_new()!
        // Children are placed at exact AppKit frames, so the fixed's own layout
        // manager (which allocates each child its *minimum* size) is replaced.
        // GtkFixed's put/move API must not be used on it from here on.
        gtk_widget_set_layout_manager(
            fixed, unsafeBitCast(g_object_new_with_properties(linChocolateFixedLayoutType(), 0, nil, nil),
                                 to: UnsafeMutablePointer<GtkLayoutManager>.self)
        )
        gtk_overlay_set_child(OpaquePointer(overlay), area)
        gtk_overlay_add_overlay(OpaquePointer(overlay), fixed)
        // Explicit size + expand: without this the container can collapse to
        // 0×0 and clip its children (the "window shows but controls are blank"
        // symptom seen over XQuartz, where the initial configure can lag).
        gtk_widget_set_size_request(overlay, Int32(frame.width), Int32(frame.height))
        gtk_widget_set_hexpand(overlay, gboolean(1))
        gtk_widget_set_vexpand(overlay, gboolean(1))
        let h = allocate(overlay, .view, frame: frame)
        viewFixeds[h.rawValue] = OpaquePointer(fixed)
        viewDrawAreas[h.rawValue] = OpaquePointer(area)
        return h
    }

    /// The child-hosting GtkFixed of a container view.
    private func containerFixed(of raw: UInt) -> OpaquePointer? {
        viewFixeds[raw]
    }
    /// Creates a `GtkButton` labelled `title`.
    public func createButton(title: String, frame: NSRect) -> NativeHandle {
        let b = gtk_button_new_with_label(title)!
        gtk_widget_set_size_request(b, Int32(frame.width), Int32(frame.height))
        return allocate(b, .button, frame: frame)
    }
    /// Creates a static `GtkLabel`.
    public func createLabel(text: String, frame: NSRect) -> NativeHandle {
        let l = gtk_label_new(text)!
        gtk_widget_set_size_request(l, Int32(frame.width), Int32(frame.height))
        return allocate(l, .label, frame: frame)
    }
    /// Creates a `GtkEntry` (starts frameless and non-editable, per AppKit's default).
    public func createTextField(text: String, frame: NSRect) -> NativeHandle {
        let e = gtk_entry_new()!
        gtk_editable_set_text(OpaquePointer(e), text)   // GtkEditable is opaque
        // AppKit's `NSTextField(string:)` defaults to non-editable — rendered as a
        // borderless STATIC label on Windows. Match that: start frameless and
        // read-only; `isEditable = true` (setTextEditable) turns it into a field.
        gtk_editable_set_editable(OpaquePointer(e), gboolean(0))
        gtk_entry_set_has_frame(UnsafeMutablePointer<GtkEntry>(OpaquePointer(e)), gboolean(0))
        gtk_widget_add_css_class(e, "linchocolate-label")
        gtk_widget_set_size_request(e, Int32(frame.width), Int32(frame.height))
        return allocate(e, .textField, frame: frame)
    }
    /// Toggles a `GtkEntry` between editable framed and borderless static.
    public func setTextEditable(_ editable: Bool, for handle: NativeHandle) {
        guard let w = widget(handle), kinds[handle.rawValue] == .textField else { return }
        gtk_editable_set_editable(w, gboolean(editable ? 1 : 0))
        gtk_entry_set_has_frame(UnsafeMutablePointer<GtkEntry>(w), gboolean(editable ? 1 : 0))
        if editable {
            gtk_widget_remove_css_class(asWidget(w), "linchocolate-label")
        } else {
            gtk_widget_add_css_class(asWidget(w), "linchocolate-label")
        }
    }
    /// The unique style class that scopes display-wide CSS to one widget.
    private func scopeClass(_ raw: UInt) -> String { "lc-w\(raw)" }

    /// Installs (or clears, when `body` is nil) one widget-scoped rule at
    /// `priority`, then rebuilds that priority's display-wide provider.
    private func setScopedRule(_ body: String?, id: String, priority: Int32, for handle: NativeHandle) {
        let raw = handle.rawValue
        if let w = widget(handle) {
            gtk_widget_add_css_class(asWidget(w), scopeClass(raw))
        }
        var rules = scopedRules[priority] ?? [:]
        let key = "\(raw).\(id)"
        if let body, !body.isEmpty { rules[key] = body } else { rules.removeValue(forKey: key) }
        scopedRules[priority] = rules
        guard let display = gdk_display_get_default() else { return }
        let provider: UnsafeMutablePointer<GtkCssProvider>
        if let existing = scopedProviders[priority] {
            provider = existing
        } else {
            provider = gtk_css_provider_new()!
            gtk_style_context_add_provider_for_display(display, OpaquePointer(provider), guint(priority))
            scopedProviders[priority] = provider
        }
        let css = rules.keys.sorted().compactMap { rules[$0] }.joined(separator: "\n")
        lc_css_provider_load(provider, css)
    }

    /// Paints the widget's background via a display-wide scoped CSS rule (nil clears it).
    public func setBackgroundColor(_ color: NSColor?, for handle: NativeHandle) {
        guard widget(handle) != nil else { return }
        guard let color else {
            setScopedRule(nil, id: "bg", priority: 800, for: handle)
            return
        }
        // The widget ONLY — deliberately not `.cls *`. A background does not
        // inherit in CSS, and the per-widget provider this replaced styled just
        // the widget's own node. Painting every descendant put an opaque slab of
        // the field colour behind each child's text — visible as the token chips'
        // labels masking their pill. 800 > the app-wide providers, so this wins.
        let cls = scopeClass(handle.rawValue)
        // `text` subnodes are included because GtkEntry/GtkTextView paint their
        // editable surface there, so a field's background must reach it. `label`
        // is deliberately NOT included — that is what masked the token pills.
        let rule = String(
            format: ".%@, .%@ text { background-color: rgba(%d,%d,%d,%.3f); }", cls, cls,
            Int(color.redComponent * 255), Int(color.greenComponent * 255),
            Int(color.blueComponent * 255), Double(color.alphaComponent)
        )
        setScopedRule(rule, id: "bg", priority: 800, for: handle)
    }
    /// Creates a `GtkPasswordEntry`.
    public func createSecureTextField(text: String, frame: NSRect) -> NativeHandle {
        let e = gtk_password_entry_new()!
        gtk_editable_set_text(OpaquePointer(e), text)
        gtk_widget_set_size_request(e, Int32(frame.width), Int32(frame.height))
        return allocate(e, .secureField, frame: frame)
    }
    /// Creates a `GtkSearchEntry`.
    public func createSearchField(text: String, frame: NSRect) -> NativeHandle {
        let e = gtk_search_entry_new()!
        gtk_editable_set_text(OpaquePointer(e), text)
        gtk_widget_set_size_request(e, Int32(frame.width), Int32(frame.height))
        return allocate(e, .searchField, frame: frame)
    }
    /// Creates an editable `GtkComboBoxText` (with an embedded `GtkEntry`).
    public func createComboBox(items: [String], text: String, frame: NSRect) -> NativeHandle {
        // GtkComboBoxText(-with-entry) is deprecated in GTK4 but remains the
        // direct editable-combo analog; its child GtkEntry (GtkEditable) carries
        // the text get/set and the change signal.
        let combo = lc_combo_box_text_new_with_entry()!
        for item in items { lc_combo_box_text_append_text(combo, item) }
        let entry = lc_combo_box_get_child(combo)
        if let entry { gtk_editable_set_text(OpaquePointer(entry), text) }
        gtk_widget_set_size_request(combo, Int32(frame.width), Int32(frame.height))
        let h = allocate(combo, .comboBox, frame: frame)
        if let entry { comboEntries[h.rawValue] = OpaquePointer(entry) }
        return h
    }
    /// Creates a `GtkCheckButton` used as a checkbox.
    public func createCheckbox(title: String, frame: NSRect) -> NativeHandle {
        let c = gtk_check_button_new_with_label(title)!
        gtk_widget_set_size_request(c, Int32(frame.width), Int32(frame.height))
        return allocate(c, .checkbox, frame: frame)
    }
    /// Creates a `GtkCheckButton` used as a radio (group it via `groupRadioButtons`).
    public func createRadioButton(title: String, frame: NSRect) -> NativeHandle {
        // A radio button is a GtkCheckButton grouped via groupRadioButtons().
        let r = gtk_check_button_new_with_label(title)!
        gtk_widget_set_size_request(r, Int32(frame.width), Int32(frame.height))
        return allocate(r, .radio, frame: frame)
    }
    /// Groups the check-button widgets via `gtk_check_button_set_group` for mutual exclusion.
    public func groupRadioButtons(_ handles: [NativeHandle]) {
        guard let first = handles.first, let lead = widget(first) else { return }
        for handle in handles.dropFirst() {
            guard let w = widget(handle) else { continue }
            gtk_check_button_set_group(asCheckButton(w), asCheckButton(lead))
        }
    }
    /// Creates a horizontal `GtkScale` over `[minValue, maxValue]`.
    public func createSlider(value: Double, minValue: Double, maxValue: Double, frame: NSRect) -> NativeHandle {
        let step = (maxValue - minValue) / 100
        let s = gtk_scale_new_with_range(GTK_ORIENTATION_HORIZONTAL, minValue, maxValue, step == 0 ? 1 : step)!
        gtk_range_set_value(asRange(OpaquePointer(s)), value)
        gtk_widget_set_size_request(s, Int32(frame.width), Int32(frame.height))
        let h = allocate(s, .slider, frame: frame)
        ranges[h.rawValue] = (minValue, maxValue)
        return h
    }
    /// Creates a `GtkProgressBar` over `[minValue, maxValue]`.
    public func createProgressIndicator(value: Double, minValue: Double, maxValue: Double, frame: NSRect) -> NativeHandle {
        let p = gtk_progress_bar_new()!
        gtk_widget_set_size_request(p, Int32(frame.width), Int32(frame.height))
        let h = allocate(p, .progress, frame: frame)
        ranges[h.rawValue] = (minValue, maxValue)
        setDoubleValue(value, for: h)
        return h
    }

    /// Toggles a progress bar between determinate and indeterminate (pulsing) modes.
    public func setProgressIndeterminate(_ indeterminate: Bool, for handle: NativeHandle) {
        if indeterminate { indeterminateProgress.insert(handle.rawValue) }
        else { indeterminateProgress.remove(handle.rawValue); stopProgressPulse(handle.rawValue) }
    }

    /// Swaps between a `GtkProgressBar` (bar) and a custom Cairo spoke-rotator (spinner).
    public func setProgressSpinning(_ spinning: Bool, for handle: NativeHandle) {
        let raw = handle.rawValue
        guard spinning != progressSpinners.contains(raw), let old = widgets[raw] else { return }
        let frame = frames[raw] ?? .zero
        // Style is set before the indicator is added to a page, so the widget
        // has no parent yet; a straight swap is safe (like the date picker).
        if gtk_widget_get_parent(asWidget(old)) != nil { gtk_widget_unparent(asWidget(old)) }
        let new: UnsafeMutablePointer<GtkWidget>
        if spinning {
            // A custom Cairo drawing area, NOT GtkSpinner: GtkSpinner draws
            // NOTHING when stopped, but AppKit's spinning indicator is always
            // visible (the spokes just stop rotating). We draw the spokes
            // ourselves and rotate them via a timeout only while animating.
            let area = gtk_drawing_area_new()!
            spinnerPhase[raw] = 0
            let drawBox = SpinnerDrawBox(backend: self, raw: raw)
            gtk_drawing_area_set_draw_func(
                UnsafeMutablePointer<GtkDrawingArea>(OpaquePointer(area)),
                gtkSpinnerDrawFunc,
                Unmanaged.passRetained(drawBox).toOpaque(), boxDestroyNotify
            )
            new = area
            progressSpinners.insert(raw)
        } else {
            stopSpinnerAnimation(raw)
            new = gtk_progress_bar_new()!
            progressSpinners.remove(raw)
        }
        gtk_widget_set_size_request(new, Int32(frame.width), Int32(frame.height))
        widgets[raw] = OpaquePointer(new)
        g_object_ref_sink(UnsafeMutableRawPointer(old))
        g_object_unref(UnsafeMutableRawPointer(old))
    }

    /// Starts or stops the pulse / spoke-rotation animation of an indeterminate indicator.
    public func setProgressAnimating(_ animating: Bool, for handle: NativeHandle) {
        let raw = handle.rawValue
        if progressSpinners.contains(raw) {
            if animating {
                spinnerAnimating.insert(raw)
                guard spinnerSources[raw] == nil else { return }
                // ~12.5 fps advances the bright spoke → a full turn every ~1s.
                let box = SpinnerDrawBox(backend: self, raw: raw)
                let id = g_timeout_add(guint(80), { userData in
                    guard let userData else { return gboolean(0) }
                    let box = Unmanaged<SpinnerDrawBox>.fromOpaque(userData).takeUnretainedValue()
                    return gboolean(box.backend?.tickSpinner(box.raw) == true ? 1 : 0)
                }, Unmanaged.passRetained(box).toOpaque())
                spinnerSources[raw] = id
            } else {
                stopSpinnerAnimation(raw)
            }
            return
        }
        // Only an indeterminate bar animates — AppKit's `startAnimation` on a
        // determinate bar is a no-op.
        guard animating, indeterminateProgress.contains(raw) else { stopProgressPulse(raw); return }
        guard progressPulseSources[raw] == nil, let w = widgets[raw] else { return }
        gtk_progress_bar_set_pulse_step(w, 0.12)
        gtk_progress_bar_pulse(w)
        // GtkProgressBar's "pulse" moves a block back and forth — the GTK
        // analog of AppKit's barber-pole indeterminate bar. ~25×/s reads as a
        // brisk barber-pole (AppKit's is fast).
        let box = ActionBox { [weak self] in
            guard let self, let w = self.widgets[raw] else { return }
            gtk_progress_bar_pulse(w)
        }
        let id = g_timeout_add(guint(40), { userData in
            guard let userData else { return gboolean(0) }
            Unmanaged<ActionBox>.fromOpaque(userData).takeUnretainedValue().action()
            return gboolean(1)   // keep pulsing
        }, Unmanaged.passRetained(box).toOpaque())
        progressPulseSources[raw] = id
    }

    private func stopProgressPulse(_ raw: UInt) {
        if let id = progressPulseSources.removeValue(forKey: raw) {
            g_source_remove(id)
            if let w = widgets[raw] { gtk_progress_bar_set_fraction(w, 0) }
        }
    }
    /// Creates a `GtkDropDown` populated from `items`.
    public func createPopUpButton(items: [String], selectedIndex: Int, frame: NSRect) -> NativeHandle {
        // gtk_drop_down_new_from_strings takes a NULL-terminated C string array;
        // it copies the strings, so the temporaries are freed right after.
        var cStrings: [UnsafePointer<CChar>?] = items.map { UnsafePointer(strdup($0)) }
        cStrings.append(nil)
        let widget = cStrings.withUnsafeBufferPointer { gtk_drop_down_new_from_strings($0.baseAddress) }!
        for s in cStrings where s != nil { free(UnsafeMutableRawPointer(mutating: s)) }
        if selectedIndex >= 0 { gtk_drop_down_set_selected(OpaquePointer(widget), guint(selectedIndex)) }
        gtk_widget_set_size_request(widget, Int32(frame.width), Int32(frame.height))
        stripPopoverArrows(of: widget)
        return allocate(widget, .popUp, frame: frame)
    }

    /// On non-composited displays a popover's pointing arrow renders as a black
    /// bar (its tail geometry is compiled into GTK — CSS cannot remove it), so
    /// walk `widget`'s children and disable the arrow on any internal popover.
    private func stripPopoverArrows(of widget: UnsafeMutablePointer<GtkWidget>) {
        guard nonComposited else { return }
        var child = gtk_widget_get_first_child(widget)
        while let c = child {
            let typeName = String(cString: g_type_name_from_instance(
                UnsafeMutableRawPointer(c).assumingMemoryBound(to: GTypeInstance.self)))
            if typeName == "GtkPopover" {
                gtk_popover_set_has_arrow(UnsafeMutablePointer<GtkPopover>(OpaquePointer(c)), gboolean(0))
            }
            child = gtk_widget_get_next_sibling(c)
        }
    }
    /// AppKit's stepper: two arrow buttons **stacked, up above down** — the
    /// control Apple actually draws. Shared by `NSStepper` and
    /// `NSDatePicker`'s `.textFieldAndStepper` field, so there is one stepper.
    ///
    /// Built from buttons rather than a GtkSpinButton on purpose: a spin button
    /// bundles a text entry, which forces a ~120px minimum (it overran and
    /// covered its own value label), stacks its buttons side by side, and can't
    /// be talked out of either.
    private func makeStepperArrows(onStep: @escaping (Int) -> Void) -> UnsafeMutablePointer<GtkWidget> {
        let arrows = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        gtk_widget_add_css_class(arrows, "linked")
        gtk_widget_add_css_class(arrows, "linchocolate-stepper")
        for (icon, direction) in [("pan-up-symbolic", 1), ("pan-down-symbolic", -1)] {
            let button = gtk_button_new_from_icon_name(icon)!
            gtk_widget_set_vexpand(button, gboolean(1))
            let action = ActionBox { onStep(direction) }
            g_signal_connect_data(
                UnsafeMutableRawPointer(button), "clicked",
                unsafeBitCast(gtkActionTrampoline, to: GCallback.self),
                Unmanaged.passRetained(action).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
            )
            gtk_box_append(asBox(OpaquePointer(arrows)), button)
        }
        return arrows
    }

    /// Steps a stepper's value by one increment, clamped to its range, and
    /// reports it — AppKit's NSStepper increments and sends its action.
    private func stepStepper(_ raw: UInt, by direction: Int) {
        guard let current = stepperValues[raw] else { return }
        let step = stepperSteps[raw] ?? 1
        let (lo, hi) = ranges[raw] ?? (0, 100)
        let stepped = Swift.min(Swift.max(current + Double(direction) * step, lo), hi)
        guard stepped != current else { return }
        stepperValues[raw] = stepped
        valueChangeActions[raw]?(stepped)
    }

    /// Creates a stepper as a stacked pair of arrow `GtkButton`s over `[minValue, maxValue]`.
    public func createStepper(value: Double, minValue: Double, maxValue: Double, stepSize: Double, frame: NSRect) -> NativeHandle {
        // The arrows' handler needs the handle, which `allocate` only hands back
        // after the widget exists; the closure captures `raw` by reference and
        // cannot run before then (it takes a click).
        var raw: UInt = 0
        let arrows = makeStepperArrows { [weak self] direction in
            self?.stepStepper(raw, by: direction)
        }
        gtk_widget_set_size_request(arrows, Int32(frame.width), Int32(frame.height))
        let h = allocate(arrows, .stepper, frame: frame)
        raw = h.rawValue
        ranges[raw] = (minValue, maxValue)
        stepperSteps[raw] = stepSize == 0 ? 1 : stepSize
        stepperValues[raw] = value
        return h
    }
    /// A standalone GtkScrollbar. `NSScroller` used directly (not as an
    /// NSScrollView's bar) previously fell through to `NSView`'s initializer and
    /// became an empty container — it simply never appeared.
    public func createScroller(vertical: Bool, frame: NSRect) -> NativeHandle {
        // AppKit's value/knobProportion are both 0...1 fractions. A GtkAdjustment
        // instead runs its value over [lower, upper - page_size], so with
        // upper = 1 and page_size = knobProportion the knob length is the
        // proportion and the value spans [0, 1 - proportion]; see scrollerValue().
        let adjustment = gtk_adjustment_new(0, 0, 1, 0.05, 0.25, 0.25)
        let bar = gtk_scrollbar_new(vertical ? GTK_ORIENTATION_VERTICAL : GTK_ORIENTATION_HORIZONTAL,
                                    adjustment)!
        gtk_widget_set_size_request(bar, Int32(frame.width), Int32(frame.height))
        // AppKit's NSScroller starts disabled — verified by probing real AppKit
        // (isEnabled == false, usableParts == .noScrollerParts) — so nothing is
        // draggable until the app enables it.
        gtk_widget_set_sensitive(bar, gboolean(0))
        let h = allocate(bar, .scroller, frame: frame)
        scrollerAdjustments[h.rawValue] = adjustment
        return h
    }

    /// The AppKit 0...1 value for a scroller's current adjustment.
    private func scrollerValue(_ raw: UInt) -> Double {
        guard let adjustment = scrollerAdjustments[raw] else { return 0 }
        let span = gtk_adjustment_get_upper(adjustment) - gtk_adjustment_get_page_size(adjustment)
        return span > 0 ? gtk_adjustment_get_value(adjustment) / span : 0
    }

    /// Sets a standalone scroller's `GtkAdjustment` to represent `(value, knobProportion)` in AppKit's 0...1 space.
    public func setScrollerGeometry(value: Double, knobProportion: Double, for handle: NativeHandle) {
        guard let adjustment = scrollerAdjustments[handle.rawValue] else { return }
        let proportion = Swift.min(1, Swift.max(0, knobProportion))
        // Setting the adjustment emits value-changed; that is us, not the user.
        suppressScrollerReport.insert(handle.rawValue)
        gtk_adjustment_set_page_size(adjustment, proportion)
        gtk_adjustment_set_upper(adjustment, 1)
        gtk_adjustment_set_value(adjustment, Swift.min(1, Swift.max(0, value)) * (1 - proportion))
        suppressScrollerReport.remove(handle.rawValue)
    }

    /// Wires user drags of a standalone scroller to `action`, ignoring programmatic changes.
    public func setScrollerAction(for handle: NativeHandle, action: @escaping (Double) -> Void) {
        guard let adjustment = scrollerAdjustments[handle.rawValue] else { return }
        scrollerActions[handle.rawValue] = action
        let box = ScrollerBox(backend: self, raw: handle.rawValue)
        g_signal_connect_data(
            UnsafeMutableRawPointer(adjustment), "value-changed",
            unsafeBitCast(gtkScrollerChangedTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
    }

    /// Reports a *user* drag. Programmatic geometry changes are suppressed, the
    /// same trap the date field hit: GTK can't tell us who moved the value.
    fileprivate func reportScroller(_ raw: UInt) {
        guard !suppressScrollerReport.contains(raw) else { return }
        scrollerActions[raw]?(scrollerValue(raw))
    }

    /// Creates a level-indicator container whose content is rebuilt to match the current style.
    public func createLevelIndicator(value: Double, minValue: Double, maxValue: Double, frame: NSRect) -> NativeHandle {
        // A container, because the style decides the content: a capacity bar, or
        // a row of stars for .rating. AppKit's NSLevelIndicator is one control
        // that renders either.
        let box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0)!
        gtk_widget_set_size_request(box, Int32(frame.width), Int32(frame.height))
        let h = allocate(box, .level, frame: frame)
        ranges[h.rawValue] = (minValue, maxValue)
        levelValues[h.rawValue] = value
        buildLevelContent(h.rawValue)
        return h
    }

    /// Sets the level-indicator style raw value and rebuilds its content.
    public func setLevelIndicatorStyle(_ rawValue: Int, for handle: NativeHandle) {
        levelStyles[handle.rawValue] = rawValue
        buildLevelContent(handle.rawValue)
    }

    /// Toggles whether the user can set the level by clicking, and rebuilds gestures.
    public func setLevelIndicatorEditable(_ editable: Bool, for handle: NativeHandle) {
        let raw = handle.rawValue
        guard levelEditable.contains(raw) != editable else { return }
        if editable { levelEditable.insert(raw) } else { levelEditable.remove(raw) }
        buildLevelContent(raw)
    }

    /// Sets the indicator's numeric range and rebuilds (for `.rating`, the span is the star count).
    public func setLevelIndicatorRange(min: Double, max: Double, for handle: NativeHandle) {
        ranges[handle.rawValue] = (min, max)
        buildLevelContent(handle.rawValue)      // the span is the star count
    }

    /// Sets the warning and critical thresholds and rebuilds the coloured fill.
    public func setLevelThresholds(warning: Double, critical: Double, for handle: NativeHandle) {
        levelThresholds[handle.rawValue] = (warning, critical)
        buildLevelContent(handle.rawValue)
    }

    /// Registers the level-change action fired by user interaction with an editable indicator.
    public func setLevelChangeAction(for handle: NativeHandle, action: @escaping (Double) -> Void) {
        levelChangeActions[handle.rawValue] = action
    }

    /// Renders a level indicator for its current style: a row of stars for
    /// `.rating` (3), otherwise a capacity bar that turns warning/critical
    /// coloured past its thresholds, as AppKit's does.
    private func buildLevelContent(_ raw: UInt) {
        guard let box = widgets[raw] else { return }
        while let child = gtk_widget_get_first_child(asWidget(box)) { gtk_widget_unparent(child) }
        let (lo, hi) = ranges[raw] ?? (0, 1)
        let value = levelValues[raw] ?? 0

        if levelStyles[raw] == NativeLevelIndicatorStyle.rating {
            guard Int((hi - lo).rounded()) > 0 else { return }
            // Stars are drawn, not taken from the icon theme: "starred-symbolic"
            // is absent on plenty of systems (it is not in this container's
            // Adwaita at all, and rendered as broken-image placeholders), and a
            // rating control should not change shape with the user's theme —
            // AppKit draws its own.
            let area = gtk_drawing_area_new()!
            gtk_widget_set_hexpand(area, gboolean(1))
            gtk_widget_set_vexpand(area, gboolean(1))
            let drawBox = LevelClickBox(backend: self, raw: raw)
            gtk_drawing_area_set_draw_func(
                UnsafeMutablePointer<GtkDrawingArea>(OpaquePointer(area)),
                gtkStarDrawFunc,
                Unmanaged.passRetained(drawBox).toOpaque(), boxDestroyNotify
            )
            gtk_box_append(asBox(box), area)
            attachLevelClickGesture(raw, to: box)
            return
        }

        let bar = gtk_progress_bar_new()!
        gtk_widget_set_hexpand(bar, gboolean(1))
        gtk_widget_set_valign(bar, GTK_ALIGN_CENTER)
        let span = hi - lo
        gtk_progress_bar_set_fraction(OpaquePointer(bar), span > 0 ? Swift.min(1, Swift.max(0, (value - lo) / span)) : 0)
        // AppKit tints the fill once the level reaches warningValue, and again
        // at criticalValue.
        if let thresholds = levelThresholds[raw] {
            if thresholds.critical > 0 && value >= thresholds.critical {
                gtk_widget_add_css_class(bar, "linchocolate-level-critical")
            } else if thresholds.warning > 0 && value >= thresholds.warning {
                gtk_widget_add_css_class(bar, "linchocolate-level-warning")
            }
        }
        gtk_box_append(asBox(box), bar)
        attachLevelClickGesture(raw, to: box)
    }

    /// An editable indicator takes clicks in **any** style: AppKit lets you set
    /// a capacity bar's level by clicking it, not just a rating's stars.
    private func attachLevelClickGesture(_ raw: UInt, to box: OpaquePointer) {
        guard levelEditable.contains(raw), !levelClickGestures.contains(raw) else { return }
        let click = gtk_gesture_click_new()
        let clickBox = LevelClickBox(backend: self, raw: raw)
        g_signal_connect_data(
            UnsafeMutableRawPointer(click), "pressed",
            unsafeBitCast(gtkLevelClickTrampoline, to: GCallback.self),
            Unmanaged.passRetained(clickBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        gtk_widget_add_controller(asWidget(box), click)
        levelClickGestures.insert(raw)
    }

    /// Draws the rating's stars: filled up to the value, outlined beyond it.
    /// Advances the spinner's bright spoke and redraws. Returns whether the
    /// timeout should keep firing (`G_SOURCE_CONTINUE`).
    fileprivate func tickSpinner(_ raw: UInt) -> Bool {
        guard spinnerAnimating.contains(raw), let w = widgets[raw] else { return false }
        spinnerPhase[raw] = (spinnerPhase[raw] ?? 0) + 1
        gtk_widget_queue_draw(asWidget(w))
        return true
    }

    /// Stops the rotation timeout; the spokes stay drawn at their current phase
    /// (AppKit's spinner stays visible when stopped — it just holds still).
    private func stopSpinnerAnimation(_ raw: UInt) {
        spinnerAnimating.remove(raw)
        if let id = spinnerSources.removeValue(forKey: raw) { g_source_remove(id) }
    }

    /// Draws an AppKit-style spinning indicator: spokes radiating from the
    /// centre, the one at the current phase brightest and the rest fading
    /// behind it. Always drawn (visible whether or not it is animating).
    fileprivate func drawSpinner(_ raw: UInt, cr: OpaquePointer, width: Double, height: Double) {
        guard width > 0, height > 0 else { return }
        let spokes = 12
        let cx = width / 2, cy = height / 2
        let radius = Swift.min(width, height) / 2
        let inner = radius * 0.42
        let outer = radius * 0.92
        let phase = ((spinnerPhase[raw] ?? 0) % spokes + spokes) % spokes
        cairo_set_line_cap(cr, CAIRO_LINE_CAP_ROUND)
        cairo_set_line_width(cr, Swift.max(1.5, radius * 0.22))
        for i in 0..<spokes {
            // Distance behind the bright head, 0 (brightest) … spokes-1 (faintest).
            let behind = Double((phase - i + spokes) % spokes)
            let alpha = 0.15 + 0.85 * (1 - behind / Double(spokes))
            let angle = -Double.pi / 2 + Double(i) / Double(spokes) * 2 * Double.pi
            cairo_set_source_rgba(cr, 0.45, 0.45, 0.45, alpha)
            cairo_move_to(cr, cx + inner * cos(angle), cy + inner * sin(angle))
            cairo_line_to(cr, cx + outer * cos(angle), cy + outer * sin(angle))
            cairo_stroke(cr)
        }
    }

    fileprivate func drawStars(_ raw: UInt, cr: OpaquePointer, width: Double, height: Double) {
        let (lo, hi) = ranges[raw] ?? (0, 5)
        let stars = Int((hi - lo).rounded())
        guard stars > 0, width > 0, height > 0 else { return }
        let value = levelValues[raw] ?? 0
        let slot = width / Double(stars)
        let radius = Swift.min(slot, height) * 0.42
        // AppKit's rating star is a fixed mid-gray in BOTH appearances (probed:
        // ~0.5, not appearance-inverted). The old 0.85 made dark-mode stars
        // near-white — nothing like the Mac's grey stars.
        let tone = 0.5
        for index in 0..<stars {
            appendStarPath(cr: cr, centreX: slot * (Double(index) + 0.5), centreY: height / 2, radius: radius)
            cairo_set_source_rgb(cr, tone, tone, tone)
            if Double(index) < (value - lo) {
                cairo_fill(cr)
            } else {
                cairo_set_line_width(cr, 1.2)
                cairo_stroke(cr)
            }
        }
    }

    /// A five-pointed star, outer points alternating with inner ones.
    private func appendStarPath(cr: OpaquePointer, centreX: Double, centreY: Double, radius: Double) {
        for point in 0..<10 {
            let r = point % 2 == 0 ? radius : radius * 0.42
            let angle = -Double.pi / 2 + Double(point) * Double.pi / 5
            let x = centreX + r * cos(angle)
            let y = centreY + r * sin(angle)
            if point == 0 { cairo_move_to(cr, x, y) } else { cairo_line_to(cr, x, y) }
        }
        cairo_close_path(cr)
    }

    /// Reports the star a click landed on, as a level (AppKit sets the rating to
    /// the clicked star).
    fileprivate func reportLevelClick(_ raw: UInt, x: Double) {
        guard levelEditable.contains(raw), let frame = frames[raw], frame.width > 0 else { return }
        let (lo, hi) = ranges[raw] ?? (0, 1)
        let value: Double
        if levelStyles[raw] == NativeLevelIndicatorStyle.rating {
            // A rating snaps to the star clicked.
            let stars = Int((hi - lo).rounded())
            guard stars > 0 else { return }
            let index = Swift.min(stars - 1, Swift.max(0, Int(x / (frame.width / Double(stars)))))
            value = lo + Double(index) + 1
        } else {
            // A capacity bar takes the level at the point clicked.
            value = lo + Swift.min(1, Swift.max(0, x / frame.width)) * (hi - lo)
        }
        levelValues[raw] = value
        buildLevelContent(raw)
        levelChangeActions[raw]?(value)
    }
    /// Creates a multi-line `GtkTextView` initialised with `text`.
    public func createTextView(text: String, frame: NSRect) -> NativeHandle {
        let tv = gtk_text_view_new()!
        let buffer = gtk_text_view_get_buffer(asTextView(OpaquePointer(tv)))
        gtk_text_buffer_set_text(buffer, text, -1)   // GtkTextBuffer is opaque
        gtk_widget_set_size_request(tv, Int32(frame.width), Int32(frame.height))
        return allocate(tv, .textView, frame: frame)
    }
    /// Creates the compact (.textFieldAndStepper) date picker: a `GtkEntry` and stacked stepper arrows in a `GtkBox`.
    public func createDatePicker(date: Date, frame: NSRect) -> NativeHandle {
        // AppKit's default style is .textFieldAndStepper — a compact field *with
        // a stepper*, not a full month grid. clockAndCalendar swaps in a
        // GtkCalendar via setDatePickerGraphical.
        let h = allocate(gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0)!, .datePicker, frame: frame)
        buildCompactDatePicker(raw: h.rawValue, frame: frame)
        setDateValue(date, for: h)
        return h
    }

    /// Fills a compact (.textFieldAndStepper) picker's box: the field, plus the
    /// stepper the style is named after. GTK has no date-field widget, so the
    /// stepper is a pair of arrows driving the value directly.
    private func buildCompactDatePicker(raw: UInt, frame: NSRect) {
        guard let box = widgets[raw] else { return }
        while let child = gtk_widget_get_first_child(asWidget(box)) { gtk_widget_unparent(child) }
        gtk_widget_add_css_class(asWidget(box), "linked")
        gtk_box_append(asBox(box), makeDateEntryRow(raw: raw))
        gtk_widget_set_size_request(asWidget(box), Int32(frame.width), Int32(frame.height))
    }

    /// A date/time entry field plus the stacked stepper — the editable part of
    /// both `.textFieldAndStepper` (the whole control) and `.clockAndCalendar`
    /// (the time row beneath the calendar). The entry is stored in
    /// `datePickerEntries[raw]`, so the framework drives its text and selection
    /// through the same seam either way.
    private func makeDateEntryRow(raw: UInt) -> UnsafeMutablePointer<GtkWidget> {
        let row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0)!
        gtk_widget_add_css_class(row, "linked")

        let entry = gtk_entry_new()!
        gtk_widget_set_hexpand(entry, gboolean(1))
        // Not editable — the framework owns the text — but focusable, so typed
        // digits reach the selected element.
        gtk_editable_set_editable(OpaquePointer(entry), gboolean(0))
        gtk_widget_set_focusable(entry, gboolean(1))
        gtk_widget_set_can_focus(entry, gboolean(1))
        gtk_box_append(asBox(OpaquePointer(row)), entry)
        datePickerEntries[raw] = OpaquePointer(entry)

        // A click moves the cursor; that is how AppKit picks the element to edit.
        let cursorBox = DateCursorBox(backend: self, raw: raw)
        g_signal_connect_data(
            UnsafeMutableRawPointer(entry), "notify::cursor-position",
            unsafeBitCast(gtkDateCursorTrampoline, to: GCallback.self),
            Unmanaged.passRetained(cursorBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        let keys = gtk_event_controller_key_new()
        gtk_event_controller_set_propagation_phase(keys, GTK_PHASE_CAPTURE)
        let keyBox = DateCursorBox(backend: self, raw: raw)
        g_signal_connect_data(
            UnsafeMutableRawPointer(keys), "key-pressed",
            unsafeBitCast(gtkDateKeyTrampoline, to: GCallback.self),
            Unmanaged.passRetained(keyBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        gtk_widget_add_controller(entry, keys)

        // The same stacked arrows NSStepper uses; it reports only a direction —
        // which element moves is the framework's call (it tracks the selection).
        let arrows = makeStepperArrows { [weak self] direction in
            self?.dateStepActions[raw]?(direction)
        }
        gtk_box_append(asBox(OpaquePointer(row)), arrows)
        return row
    }

    /// Records the selectable date range (clamping is the framework's job).
    public func setDateRange(min: Date?, max: Date?, for handle: NativeHandle) {
        // Recorded for parity; the framework does the authoritative clamping
        // (minDate/maxDate are AppKit semantics, not GTK's).
        dateRanges[handle.rawValue] = (min, max)
    }

    /// Sets the compact field's rendered text, suppressing the resulting cursor callback.
    public func setDatePickerText(_ text: String, for handle: NativeHandle) {
        guard let entry = datePickerEntries[handle.rawValue] else { return }
        guard String(cString: gtk_editable_get_text(entry)) != text else { return }
        suppressCursorReport.insert(handle.rawValue)
        gtk_editable_set_text(entry, text)
        suppressCursorReport.remove(handle.rawValue)
    }

    /// Highlights the selected element in the compact field.
    public func setDatePickerSelection(location: Int, length: Int, for handle: NativeHandle) {
        guard let entry = datePickerEntries[handle.rawValue] else { return }
        // Selecting moves the cursor, which would re-enter the cursor handler
        // and fight the framework for the selection.
        suppressCursorReport.insert(handle.rawValue)
        gtk_editable_select_region(entry, gint(location), gint(location + length))
        suppressCursorReport.remove(handle.rawValue)
    }

    /// Registers the stepper-direction action for a date picker.
    public func setDateStepAction(for handle: NativeHandle, action: @escaping (Int) -> Void) {
        dateStepActions[handle.rawValue] = action
    }

    /// Registers the click-position action for a compact date picker.
    public func setDatePickerCursorAction(for handle: NativeHandle, action: @escaping (Int) -> Void) {
        dateCursorActions[handle.rawValue] = action
    }

    /// Registers the left/right-arrow action for a compact date picker.
    public func setDatePickerMoveAction(for handle: NativeHandle, action: @escaping (Int) -> Void) {
        dateMoveActions[handle.rawValue] = action
    }

    /// Registers the character-typed action for a compact date picker.
    public func setDatePickerTypeAction(for handle: NativeHandle, action: @escaping (String) -> Void) {
        dateTypeActions[handle.rawValue] = action
    }

    /// Reports a click's character offset so the framework can select that
    /// element. Ignored while we are the ones moving the cursor.
    fileprivate func reportDateCursor(_ raw: UInt) {
        if ProcessInfo.processInfo.environment["LINCHOCOLATE_DATE_DEBUG"] != nil {
            let pos = datePickerEntries[raw].map { Int(gtk_editable_get_position($0)) } ?? -1
            let suppressed = suppressCursorReport.contains(raw)
            FileHandle.standardError.write(Data("cursor-notify pos=\(pos) suppressed=\(suppressed)\n".utf8))
        }
        guard !suppressCursorReport.contains(raw), let entry = datePickerEntries[raw] else { return }
        dateCursorActions[raw]?(Int(gtk_editable_get_position(entry)))
    }

    /// AppKit's keyboard for a date field: left/right move the selected
    /// element, up/down step it, and digits (or "a"/"p") *type* into it.
    ///
    /// Returning true stops the key here. That matters: this controller runs in
    /// the capture phase, so left/right would otherwise reach the entry's
    /// GtkText and move its cursor, fighting the framework for the selection.
    fileprivate func reportDateKey(_ raw: UInt, keyval: guint) -> Bool {
        switch keyval {
        case guint(GDK_KEY_Left):  dateMoveActions[raw]?(-1); return true
        case guint(GDK_KEY_Right): dateMoveActions[raw]?(1);  return true
        case guint(GDK_KEY_Up):    dateStepActions[raw]?(1);  return true
        case guint(GDK_KEY_Down):  dateStepActions[raw]?(-1); return true
        default: break
        }
        let unicode = gdk_keyval_to_unicode(keyval)
        guard unicode != 0, let scalar = Unicode.Scalar(unicode) else { return false }
        let character = Character(scalar)
        guard character.isNumber || character.lowercased() == "a" || character.lowercased() == "p" else {
            return false
        }
        dateTypeActions[raw]?(String(character))
        return true
    }

    /// Swaps the widget for a new button/check button matching `kind`, preserving frame.
    public func setButtonKind(_ kind: NativeButtonKind, title: String, for handle: NativeHandle) {
        let raw = handle.rawValue
        guard let old = widgets[raw] else { return }
        let frame = frames[raw] ?? .zero
        if gtk_widget_get_parent(asWidget(old)) != nil { gtk_widget_unparent(asWidget(old)) }
        let new: UnsafeMutablePointer<GtkWidget>
        switch kind {
        case .push:     new = gtk_button_new_with_label(title)!;       kinds[raw] = .button
        case .checkbox: new = gtk_check_button_new_with_label(title)!; kinds[raw] = .checkbox
        case .radio:    new = gtk_check_button_new_with_label(title)!; kinds[raw] = .radio
        }
        gtk_widget_set_size_request(new, Int32(frame.width), Int32(frame.height))
        widgets[raw] = OpaquePointer(new)
        g_object_ref_sink(UnsafeMutableRawPointer(old))
        g_object_unref(UnsafeMutableRawPointer(old))
    }
    /// Swaps between the compact stepper picker and a graphical `GtkCalendar` (with time row).
    public func setDatePickerGraphical(_ graphical: Bool, for handle: NativeHandle) {
        let raw = handle.rawValue
        guard graphical != graphicalDatePickers.contains(raw), let old = widgets[raw] else { return }
        let frame = frames[raw] ?? .zero
        if gtk_widget_get_parent(asWidget(old)) != nil { gtk_widget_unparent(asWidget(old)) }
        let new: UnsafeMutablePointer<GtkWidget>
        if graphical {
            // AppKit's .clockAndCalendar shows a month grid AND a time editor
            // (an analog clock on macOS). Here: the calendar for the date, and a
            // compact time field with a stepper below it — the same type-to-edit
            // field the .textFieldAndStepper style uses, so the time can be
            // typed or stepped, which is the functionality that was missing.
            let column = gtk_box_new(GTK_ORIENTATION_VERTICAL, 4)!
            let calendar = gtk_calendar_new()!
            gtk_widget_set_vexpand(calendar, gboolean(1))
            gtk_box_append(asBox(OpaquePointer(column)), calendar)
            graphicalCalendars[raw] = OpaquePointer(calendar)

            let timeRow = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0)!
            gtk_widget_set_halign(timeRow, GTK_ALIGN_CENTER)
            gtk_box_append(asBox(OpaquePointer(timeRow)), makeDateEntryRow(raw: raw))
            gtk_box_append(asBox(OpaquePointer(column)), timeRow)

            new = column
            graphicalDatePickers.insert(raw)
            gtk_widget_set_size_request(new, Int32(frame.width), Int32(frame.height))
            widgets[raw] = OpaquePointer(new)
        } else {
            new = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0)!
            graphicalDatePickers.remove(raw)
            graphicalCalendars[raw] = nil
            widgets[raw] = OpaquePointer(new)
            buildCompactDatePicker(raw: raw, frame: frame)   // field *and* stepper
        }
        // Free the discarded (still-floating, unparented) widget.
        g_object_ref_sink(UnsafeMutableRawPointer(old))
        g_object_unref(UnsafeMutableRawPointer(old))
        // The swap replaced the widget, so re-apply the value and re-attach the
        // change action — both were bound to the widget we just discarded.
        if let date = dateValues[raw] { setDateValue(date, for: handle) }
        if let action = dateChangeActions[raw] { attachDateChangeAction(action, to: handle) }
    }
    /// Creates a `GtkColorButton` (via `GtkColorChooser`) initialised to `color`.
    public func createColorWell(color: NSColor, frame: NSRect) -> NativeHandle {
        // GtkColorButton (via the GtkColorChooser interface) is deprecated in
        // GTK 4.10 like GtkComboBoxText, but remains the direct color-well
        // analog; the non-deprecated GtkColorDialogButton is async-only.
        let cb = lc_color_button_new()!
        // Non-modal: a modal chooser grabs all input, and if the dialog fails to
        // map (seen over XQuartz) the whole app looks hung and cannot be closed.
        lc_color_button_set_modal(cb, gboolean(0))
        gtk_widget_set_size_request(cb, Int32(frame.width), Int32(frame.height))
        let h = allocate(cb, .colorWell, frame: frame)
        setColor(color, for: h)
        return h
    }
    /// Creates a `GtkNotebook` as the tab-view container.
    public func createTabView(frame: NSRect) -> NativeHandle {
        let nb = gtk_notebook_new()!
        gtk_widget_set_size_request(nb, Int32(frame.width), Int32(frame.height))
        gtk_widget_set_hexpand(nb, gboolean(1))
        gtk_widget_set_vexpand(nb, gboolean(1))
        return allocate(nb, .tabView, frame: frame)
    }
    /// Appends a page to a `GtkNotebook`, labelled `label`.
    public func addTabPage(_ page: NativeHandle, label: String, to tabView: NativeHandle) {
        guard let nb = widget(tabView), let p = widget(page) else { return }
        let tabLabel = gtk_label_new(label)
        gtk_notebook_append_page(nb, asWidget(p), tabLabel)   // GtkNotebook is opaque
    }
    /// Creates a segmented control as a linked row of `GtkToggleButton`s.
    public func createSegmentedControl(labels: [String], frame: NSRect) -> NativeHandle {
        // Composed control: linked GtkToggleButtons in a horizontal box — the
        // native GTK idiom for a segmented switcher ("linked" style class).
        let box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0)!
        gtk_widget_add_css_class(box, "linked")
        gtk_widget_add_css_class(box, "linchocolate-segmented")
        gtk_widget_set_size_request(box, Int32(frame.width), Int32(frame.height))
        let h = allocate(box, .segmented, frame: frame)

        var buttons: [OpaquePointer] = []
        for label in labels {
            let tb = gtk_toggle_button_new_with_label(label)!
            if let first = buttons.first {
                gtk_toggle_button_set_group(asToggle(OpaquePointer(tb)), asToggle(first))
            }
            gtk_box_append(asBox(OpaquePointer(box)), tb)
            buttons.append(OpaquePointer(tb))
        }
        segmentButtons[h.rawValue] = buttons
        return h
    }
    /// Creates a table as a `GtkColumnView` inside a `GtkScrolledWindow`.
    public func createTableView(frame: NSRect) -> NativeHandle {
        // GtkColumnView = selection model over a GListModel + per-column cell
        // factories. The model is a GtkStringList used purely for its item
        // count; cell text comes from the Swift-side provider at bind time.
        let list = gtk_string_list_new(nil)!   // GtkStringList is opaque
        let selection = gtk_single_selection_new(list)!   // GListModel is opaque
        let cv = gtk_column_view_new(selection)!   // GtkSingleSelection is opaque
        let scroller = gtk_scrolled_window_new()!
        gtk_scrolled_window_set_child(OpaquePointer(scroller), cv)
        gtk_widget_set_size_request(scroller, Int32(frame.width), Int32(frame.height))
        let h = allocate(scroller, .table, frame: frame)
        tableColumnViews[h.rawValue] = OpaquePointer(cv)
        tableSelections[h.rawValue] = selection
        tableLists[h.rawValue] = list
        return h
    }
    /// Appends a titled `GtkColumnViewColumn` with a signal-driven cell factory.
    public func addTableColumn(title: String, editable: Bool, to table: NativeHandle) {
        guard let cv = tableColumnViews[table.rawValue] else { return }
        let columnIndex = tableColumnCounts[table.rawValue, default: 0]
        if editable { editableTableColumns[table.rawValue, default: []].insert(columnIndex) }
        let factory = gtk_signal_list_item_factory_new()!
        let setupBox = TableColumnBox(backend: self, table: table.rawValue, column: columnIndex, editable: editable)
        g_signal_connect_data(
            UnsafeMutableRawPointer(factory), "setup",
            unsafeBitCast(gtkTableCellSetupTrampoline, to: GCallback.self),
            Unmanaged.passRetained(setupBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        let box = TableColumnBox(backend: self, table: table.rawValue, column: columnIndex, editable: editable)
        g_signal_connect_data(
            UnsafeMutableRawPointer(factory), "bind",
            unsafeBitCast(gtkTableCellBindTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        let column = gtk_column_view_column_new(title, factory)!   // factory is opaque
        gtk_column_view_column_set_expand(column, gboolean(1))
        gtk_column_view_append_column(cv, column)
        tableColumnObjects[table.rawValue, default: []].append(column)
        tableColumnCounts[table.rawValue] = columnIndex + 1
    }
    /// Renames an existing table column via `gtk_column_view_column_set_title`.
    public func setTableColumnTitle(_ title: String, columnIndex: Int, for table: NativeHandle) {
        guard let columns = tableColumnObjects[table.rawValue], columnIndex < columns.count else { return }
        gtk_column_view_column_set_title(columns[columnIndex], title)
    }
    /// Marks a column sortable via a placeholder `GtkCustomSorter` (real sort is Swift-side).
    public func setColumnSortable(_ columnIndex: Int, for table: NativeHandle) {
        guard let columns = tableColumnObjects[table.rawValue], columnIndex < columns.count else { return }
        // A no-op custom sorter makes the header clickable and drives the view's
        // GtkColumnViewSorter; the actual re-sort happens Swift-side (the model
        // is count-only), so we only need the header click + indicator + signal.
        let sorter = gtk_custom_sorter_new(nil, nil, nil)
        gtk_column_view_column_set_sorter(columns[columnIndex], UnsafeMutablePointer<GtkSorter>(sorter))
    }
    /// Wires the column-view's sorter `changed` signal to `action`, passing `(columnIndex, ascending)`.
    public func setSortChangeAction(for table: NativeHandle, action: @escaping (Int, Bool) -> Void) {
        tableSortActions[table.rawValue] = action
        guard let cv = tableColumnViews[table.rawValue],
              let sorter = gtk_column_view_get_sorter(cv) else { return }
        let box = TableSignalBox(backend: self, table: table.rawValue)
        g_signal_connect_data(
            UnsafeMutableRawPointer(sorter), "changed",
            unsafeBitCast(gtkSorterChangedTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
    }
    /// Brings `row` into view via `gtk_column_view_scroll_to` without changing focus/selection.
    public func scrollTableRowToVisible(_ row: Int, for table: NativeHandle) {
        guard row >= 0, let cv = tableColumnViews[table.rawValue],
              row < (tableRowCounts[table.rawValue] ?? 0) else { return }
        // GTK_LIST_SCROLL_NONE: bring the row into view but leave focus and
        // selection alone — AppKit's scrollRowToVisible does not select.
        _ = cv
    }
    /// Wires the column-view's `activate` signal (double-click / Enter) to `action`.
    public func setRowActivateAction(for table: NativeHandle, action: @escaping (Int) -> Void) {
        tableActivateActions[table.rawValue] = action
        guard let cv = tableColumnViews[table.rawValue] else { return }
        let box = TableSignalBox(backend: self, table: table.rawValue)
        g_signal_connect_data(
            UnsafeMutableRawPointer(cv), "activate",
            unsafeBitCast(gtkRowActivateTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
    }
    /// Called from the sorter-changed trampoline: maps the primary sort column
    /// back to its index and reports (index, ascending) to the Swift action.
    func handleSorterChanged(table: UInt, sorter: OpaquePointer) {
        _ = sorter
        guard let action = tableSortActions[table] else { return }
        action(0, true)
    }
    /// Called from the row-activate trampoline (double-click / Enter).
    func handleRowActivate(table: UInt, position: Int) {
        tableActivateActions[table]?(position)
    }
    /// Replaces all items in the underlying `GtkStringList`, forcing every visible cell to re-bind.
    public func setTableRowCount(_ count: Int, for table: NativeHandle) {
        guard let list = tableLists[table.rawValue] else { return }
        // Replace all items: forces every visible cell to re-bind (= reload).
        let old = tableRowCounts[table.rawValue] ?? 0
        var additions: [UnsafePointer<CChar>?] = (0..<count).map { _ in UnsafePointer(strdup("")) }
        additions.append(nil)
        additions.withUnsafeBufferPointer {
            gtk_string_list_splice(list, 0, guint(old), $0.baseAddress)
        }
        for s in additions where s != nil { free(UnsafeMutableRawPointer(mutating: s)) }
        tableRowCounts[table.rawValue] = count
    }
    /// Records the cell-text provider used by the column bind trampoline.
    public func setTableCellCommitAction(for handle: NativeHandle, _ handler: @escaping (Int, Int, String) -> Void) {
        tableCommitActions[handle.rawValue] = handler
    }
    /// Called from the editable-cell commit trampoline.
    func reportCellEdit(table: UInt, row: Int, column: Int, text: String) {
        tableCommitActions[table]?(row, column, text)
    }
    public func setTableCellProvider(for table: NativeHandle, provider: @escaping (Int, Int) -> String) {
        tableProviders[table.rawValue] = provider
    }
    /// Cell text for the bind trampoline.
    func tableCellText(table: UInt, row: Int, column: Int) -> String {
        tableProviders[table]?(row, column) ?? ""
    }
    /// Creates a collection view as a `GtkFlowBox` inside a `GtkScrolledWindow`.
    public func createCollectionView(frame: NSRect) -> NativeHandle {
        // A GtkFlowBox hosting each item's REAL widget — Apple's collection
        // hosts each NSCollectionViewItem's view (the demo's items are push
        // buttons), so a text-tile grid was never going to look like the Mac.
        // The flow box wraps children by width, like NSCollectionViewFlowLayout.
        // A vertical GtkBox of section blocks; each block is an optional header
        // band, a GtkFlowBox of that section's items, and an optional footer
        // band. One flow box per section is what gives AppKit's sectioned flow
        // layout its full-width bands — a single flow box cannot break a line
        // for a header.
        let stack = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        gtk_widget_add_css_class(stack, "linchocolate-collection")
        let scroller = gtk_scrolled_window_new()!
        gtk_scrolled_window_set_child(OpaquePointer(scroller), stack)
        gtk_widget_set_size_request(scroller, Int32(frame.width), Int32(frame.height))
        let h = allocate(scroller, .collection, frame: frame)
        collectionStacks[h.rawValue] = OpaquePointer(stack)
        return h
    }
    /// Sets the item count and rebuilds (= reload). A collection with no
    /// declared sections is one unsectioned run of items.
    public func setCollectionItemCount(_ count: Int, for collection: NativeHandle) {
        let raw = collection.rawValue
        collectionItemCounts[raw] = count
        collectionSectionSpecs[raw] = [NativeCollectionSection(itemCount: count)]
        rebuildCollectionChildren(raw)
    }
    public func setCollectionFlow(interitemSpacing: Double, lineSpacing: Double, horizontal: Bool,
                                  for collection: NativeHandle) {
        // Stored only — `setCollectionSections` does the rebuild, so a reload
        // rebuilds once rather than twice.
        collectionFlowGeometry[collection.rawValue] = (interitemSpacing, lineSpacing, horizontal)
    }
    public func setCollectionSections(_ sections: [NativeCollectionSection], for collection: NativeHandle) {
        let raw = collection.rawValue
        collectionSectionSpecs[raw] = sections
        collectionItemCounts[raw] = sections.reduce(0) { $0 + $1.itemCount }
        rebuildCollectionChildren(raw)
    }
    /// Records the text provider used when no item-view provider supplies a widget.
    public func setCollectionItemProvider(for collection: NativeHandle, provider: @escaping (Int) -> String) {
        collectionProviders[collection.rawValue] = provider
    }
    /// Records the item-view provider used to host each item's real widget.
    public func setCollectionItemViewProvider(for collection: NativeHandle, provider: @escaping (Int) -> NativeHandle?) {
        collectionViewProviders[collection.rawValue] = provider
    }

    /// (Re)fills the flow box: each item contributes its real widget when the
    /// view provider has one, else a text label from the text provider.
    private func rebuildCollectionChildren(_ raw: UInt) {
        guard let stack = collectionStacks[raw] else { return }
        suppressCollectionSelection.insert(raw)
        // Tear the previous blocks down WITHOUT destroying anything we merely
        // host. Item and band widgets belong to their Swift views; a GTK widget
        // whose last reference is its parent dies the moment it is unparented,
        // so removing a section's flow box took its buttons with it and the next
        // rebuild had nothing left to re-host (the items vanished on reload).
        // Hold a reference across the move and drop it once re-parented.
        var rescued: [UnsafeMutableRawPointer] = []
        let previousFlows = collectionSectionFlows[raw] ?? []
        while let child = gtk_widget_get_first_child(asWidget(stack)) {
            if let entry = previousFlows.first(where: { asWidget($0.flow) == child }) {
                // A section flow box: rescue each hosted item, then drop the box.
                while let flowChild = gtk_widget_get_first_child(asWidget(entry.flow)) {
                    if let hosted = gtk_widget_get_first_child(flowChild) {
                        g_object_ref(UnsafeMutableRawPointer(hosted))
                        rescued.append(UnsafeMutableRawPointer(hosted))
                        gtk_flow_box_remove(entry.flow, hosted)
                    } else {
                        gtk_flow_box_remove(entry.flow, flowChild)
                    }
                }
            } else {
                // A header/footer band.
                g_object_ref(UnsafeMutableRawPointer(child))
                rescued.append(UnsafeMutableRawPointer(child))
            }
            gtk_box_remove(asBox(stack), child)
        }
        defer { for widget in rescued { g_object_unref(widget) } }
        collectionSectionFlows[raw] = []
        collectionFlows[raw] = nil
        // AppKit's `.horizontal` scroll direction lays the SECTIONS out left to
        // right, each one's items flowing top-to-bottom in columns. `.vertical`
        // stacks the sections. Match that by re-orienting the section stack.
        let horizontal = collectionFlowGeometry[raw]?.horizontal ?? false
        gtk_orientable_set_orientation(stack, horizontal ? GTK_ORIENTATION_HORIZONTAL
                                                         : GTK_ORIENTATION_VERTICAL)
        let sections = collectionSectionSpecs[raw] ?? [NativeCollectionSection(itemCount: collectionItemCounts[raw] ?? 0)]
        var base = 0
        for section in sections {
            if let header = section.header, let hw = widgets[header.rawValue] {
                hostBand(asWidget(hw), in: stack)
            }
            let flow = makeCollectionFlow(raw: raw, base: base)
            gtk_box_append(asBox(stack), asWidget(flow))
            collectionSectionFlows[raw, default: []].append((flow: flow, base: base))
            if collectionFlows[raw] == nil { collectionFlows[raw] = flow }
            fillCollectionFlow(flow, raw: raw, base: base, count: section.itemCount)
            base += section.itemCount
            if let footer = section.footer, let fw = widgets[footer.rawValue] {
                hostBand(asWidget(fw), in: stack)
            }
        }
        suppressCollectionSelection.remove(raw)
    }
    /// Appends a full-width header/footer band, re-parenting it safely.
    private func hostBand(_ band: UnsafeMutablePointer<GtkWidget>, in stack: OpaquePointer) {
        g_object_ref(UnsafeMutableRawPointer(band))
        if gtk_widget_get_parent(band) != nil { gtk_widget_unparent(band) }
        gtk_widget_set_hexpand(band, gboolean(1))
        gtk_widget_set_halign(band, GTK_ALIGN_FILL)
        gtk_box_append(asBox(stack), band)
        g_object_unref(UnsafeMutableRawPointer(band))
    }
    /// One section's GtkFlowBox, wired to report selection in FLAT indices.
    private func makeCollectionFlow(raw: UInt, base: Int) -> OpaquePointer {
        let flow = gtk_flow_box_new()!
        gtk_flow_box_set_selection_mode(OpaquePointer(flow), GTK_SELECTION_SINGLE)
        gtk_flow_box_set_homogeneous(OpaquePointer(flow), gboolean(0))
        let geometry = collectionFlowGeometry[raw] ?? (interitem: 8, line: 8, horizontal: false)
        gtk_flow_box_set_column_spacing(OpaquePointer(flow), guint(Swift.max(0, geometry.interitem)))
        gtk_flow_box_set_row_spacing(OpaquePointer(flow), guint(Swift.max(0, geometry.line)))
        gtk_flow_box_set_max_children_per_line(OpaquePointer(flow), 64)
        // AppKit's `.vertical` scroll direction means items flow in ROWS, which
        // is GtkFlowBox's horizontal orientation (and vice versa).
        gtk_orientable_set_orientation(OpaquePointer(flow),
                                       geometry.horizontal ? GTK_ORIENTATION_VERTICAL : GTK_ORIENTATION_HORIZONTAL)
        let box = CollectionBox(backend: self, collection: raw, base: base)
        g_signal_connect_data(
            UnsafeMutableRawPointer(flow), "selected-children-changed",
            unsafeBitCast(gtkFlowSelectionTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        return OpaquePointer(flow)
    }
    /// Fills one section's flow box with items `base ..< base+count`.
    private func fillCollectionFlow(_ flow: OpaquePointer, raw: UInt, base: Int, count: Int) {
        for offset in 0..<count {
            let index = base + offset
            let content: UnsafeMutablePointer<GtkWidget>
            if let handle = collectionViewProviders[raw]?(index), let widget = widgets[handle.rawValue] {
                // Hold a reference across the move (the toolbar lesson: an
                // unparented GTK4 widget with no other ref is destroyed).
                g_object_ref(UnsafeMutableRawPointer(widget))
                if gtk_widget_get_parent(asWidget(widget)) != nil { gtk_widget_unparent(asWidget(widget)) }
                content = asWidget(widget)
                gtk_flow_box_insert(flow, content, -1)
                g_object_unref(UnsafeMutableRawPointer(widget))
            } else {
                content = gtk_label_new(collectionProviders[raw]?(index) ?? "")!
                gtk_flow_box_insert(flow, content, -1)
            }
            // An item hosting a control (a button) would swallow the click and
            // the flow box would never select the child — so select it from a
            // capture-phase gesture that doesn't claim the event: one click
            // both selects the item and presses its control.
            if let child = gtk_widget_get_parent(content) {
                let click = gtk_gesture_click_new()
                gtk_event_controller_set_propagation_phase(click, GTK_PHASE_CAPTURE)
                let selectBox = FlowChildBox(flow: flow, child: OpaquePointer(child))
                g_signal_connect_data(
                    UnsafeMutableRawPointer(click), "pressed",
                    unsafeBitCast(gtkFlowChildSelectTrampoline, to: GCallback.self),
                    Unmanaged.passRetained(selectBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
                )
                gtk_widget_add_controller(asWidget(OpaquePointer(child)), click)
            }
        }
    }

    /// Reports a flow-box selection as an item index.
    fileprivate func reportCollectionSelection(_ raw: UInt, base: Int) {
        guard !suppressCollectionSelection.contains(raw) else { return }
        guard let entry = collectionSectionFlows[raw]?.first(where: { $0.base == base }) else { return }
        var index = -1
        if let selected = gtk_flow_box_get_selected_children(entry.flow) {
            if let first = selected.pointee.data {
                index = base + Int(gtk_flow_box_child_get_index(first.assumingMemoryBound(to: GtkFlowBoxChild.self)))
            }
            g_list_free(selected)
        }
        guard index >= 0 else { return }   // a deselect from another section's flow
        // Selection is single across the whole collection, as on AppKit: clear
        // every other section's flow box so two sections never look selected.
        suppressCollectionSelection.insert(raw)
        for other in collectionSectionFlows[raw] ?? [] where other.base != base {
            gtk_flow_box_unselect_all(other.flow)
        }
        suppressCollectionSelection.remove(raw)
        collectionSelectionActions[raw]?(index)
    }
    /// Creates a tree table (`GtkColumnView` over a `GtkTreeListModel`) in a scrolled window.
    public func createOutlineView(frame: NSRect) -> NativeHandle {
        // Tree table: GtkTreeListModel over a root GtkStringList of path keys
        // ("0", "1", …); expanding a row asks the create-func for a child list
        // ("0.0", "0.1", …). Cell text resolves paths through the Swift provider.
        let rootList = gtk_string_list_new(nil)!
        let box = OutlineBox(backend: self)
        let tree = gtk_tree_list_model_new(
            rootList, gboolean(0), gboolean(0),   // passthrough: no, autoexpand: no
            outlineCreateChildModelFunc,
            Unmanaged.passRetained(box).toOpaque(), boxDestroyNotify
        )!
        let selection = gtk_single_selection_new(tree)!   // GtkTreeListModel is opaque
        let cv = gtk_column_view_new(selection)!
        let scroller = gtk_scrolled_window_new()!
        gtk_scrolled_window_set_child(OpaquePointer(scroller), cv)
        gtk_widget_set_size_request(scroller, Int32(frame.width), Int32(frame.height))
        let h = allocate(scroller, .outline, frame: frame)
        box.outline = h.rawValue
        outlineColumnViews[h.rawValue] = OpaquePointer(cv)
        outlineRootLists[h.rawValue] = rootList
        tableSelections[h.rawValue] = selection   // shared selection routing
        return h
    }
    /// Appends a titled column to an outline view (column 0 carries the expand arrows).
    public func addOutlineColumn(title: String, to outline: NativeHandle) {
        guard let cv = outlineColumnViews[outline.rawValue] else { return }
        let columnIndex = outlineColumnCounts[outline.rawValue, default: 0]
        let factory = gtk_signal_list_item_factory_new()!
        let setupBox = OutlineColumnBox(backend: self, outline: outline.rawValue, column: columnIndex)
        g_signal_connect_data(
            UnsafeMutableRawPointer(factory), "setup",
            unsafeBitCast(gtkOutlineCellSetupTrampoline, to: GCallback.self),
            Unmanaged.passRetained(setupBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        let bindBox = OutlineColumnBox(backend: self, outline: outline.rawValue, column: columnIndex)
        g_signal_connect_data(
            UnsafeMutableRawPointer(factory), "bind",
            unsafeBitCast(gtkOutlineCellBindTrampoline, to: GCallback.self),
            Unmanaged.passRetained(bindBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        let column = gtk_column_view_column_new(title, factory)!
        gtk_column_view_column_set_expand(column, gboolean(1))
        gtk_column_view_append_column(cv, column)
        outlineColumnCounts[outline.rawValue] = columnIndex + 1
    }
    /// Replaces the outline's root list to have `count` items (= reload).
    public func setOutlineRootCount(_ count: Int, for outline: NativeHandle) {
        guard let list = outlineRootLists[outline.rawValue] else { return }
        let old = outlineRootCounts[outline.rawValue] ?? 0
        var additions: [UnsafePointer<CChar>?] = (0..<count).map { UnsafePointer(strdup("\($0)")) }
        additions.append(nil)
        additions.withUnsafeBufferPointer {
            gtk_string_list_splice(list, 0, guint(old), $0.baseAddress)
        }
        for s in additions where s != nil { free(UnsafeMutableRawPointer(mutating: s)) }
        outlineRootCounts[outline.rawValue] = count
    }
    /// The `GtkTreeListRow` at a visible outline position, or nil. The outline's
    /// selection model (a `GtkSingleSelection` over the tree list model) is a
    /// GListModel of the flattened, expanded rows.
    private func outlineTreeRow(atRow row: Int, for outline: NativeHandle) -> OpaquePointer? {
        guard row >= 0, let selection = tableSelections[outline.rawValue] else { return nil }
        guard row < Int(g_list_model_get_n_items(selection)) else { return nil }
        return g_list_model_get_item(selection, guint(row)).map { OpaquePointer($0) }  // caller unrefs
    }
    public func outlineVisibleRowCount(for outline: NativeHandle) -> Int {
        guard let selection = tableSelections[outline.rawValue] else { return 0 }
        return Int(g_list_model_get_n_items(selection))
    }
    public func outlineItemPath(atRow row: Int, for outline: NativeHandle) -> String? {
        guard let treeRow = outlineTreeRow(atRow: row, for: outline) else { return nil }
        defer { g_object_unref(UnsafeMutableRawPointer(treeRow)) }
        guard let item = gtk_tree_list_row_get_item(treeRow) else { return nil }
        defer { g_object_unref(item) }
        return String(cString: gtk_string_object_get_string(OpaquePointer(item)))
    }
    public func outlineRowDepth(atRow row: Int, for outline: NativeHandle) -> Int {
        guard let treeRow = outlineTreeRow(atRow: row, for: outline) else { return 0 }
        defer { g_object_unref(UnsafeMutableRawPointer(treeRow)) }
        return Int(gtk_tree_list_row_get_depth(treeRow))
    }
    public func outlineIsRowExpanded(atRow row: Int, for outline: NativeHandle) -> Bool {
        guard let treeRow = outlineTreeRow(atRow: row, for: outline) else { return false }
        defer { g_object_unref(UnsafeMutableRawPointer(treeRow)) }
        return gtk_tree_list_row_get_expanded(treeRow) != 0
    }
    public func setOutlineRowExpanded(_ expanded: Bool, atRow row: Int, for outline: NativeHandle) {
        guard let treeRow = outlineTreeRow(atRow: row, for: outline) else { return }
        defer { g_object_unref(UnsafeMutableRawPointer(treeRow)) }
        gtk_tree_list_row_set_expanded(treeRow, gboolean(expanded ? 1 : 0))
    }
    public func selectOutlineRow(_ row: Int, for outline: NativeHandle) {
        guard let selection = tableSelections[outline.rawValue] else { return }
        gtk_single_selection_set_selected(selection, row < 0 ? guint.max : guint(row))
    }
    /// Records the child-count and cell-text providers used by the tree model and bind trampolines.
    public func setOutlineProviders(
        for outline: NativeHandle,
        childCount: @escaping (String) -> Int,
        cellText: @escaping (String, Int) -> String
    ) {
        outlineChildCountProviders[outline.rawValue] = childCount
        outlineCellTextProviders[outline.rawValue] = cellText
    }
    /// Child count for the tree create-func.
    func outlineChildCount(outline: UInt, path: String) -> Int {
        outlineChildCountProviders[outline]?(path) ?? 0
    }
    /// Cell text for the outline bind trampoline.
    func outlineCellText(outline: UInt, path: String, column: Int) -> String {
        outlineCellTextProviders[outline]?(path, column) ?? ""
    }
    /// Creates a token field: a `GtkBox` hosting chip buttons and a trailing `GtkEntry`.
    public func createTokenField(tokens: [String], frame: NSRect) -> NativeHandle {
        // Composed control (no GTK peer): [chip][chip]…[entry] in a box.
        // Enter in the entry commits a token; clicking a chip removes it.
        let box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6)!
        gtk_widget_set_size_request(box, Int32(frame.width), Int32(frame.height))
        let entry = gtk_entry_new()!
        gtk_widget_set_hexpand(entry, gboolean(1))
        gtk_box_append(asBox(OpaquePointer(box)), entry)
        let h = allocate(box, .tokenField, frame: frame)
        tokenEntries[h.rawValue] = OpaquePointer(entry)
        tokenValues[h.rawValue] = tokens
        rebuildTokenChips(for: h)

        let commit = ActionBox { [weak self] in self?.commitTokenEntry(h) }
        g_signal_connect_data(
            UnsafeMutableRawPointer(entry), "activate",
            unsafeBitCast(gtkActionTrampoline, to: GCallback.self),
            Unmanaged.passRetained(commit).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        return h
    }
    /// Replaces a token field's tokens and rebuilds its chip buttons.
    public func setTokens(_ tokens: [String], for handle: NativeHandle) {
        tokenValues[handle.rawValue] = tokens
        rebuildTokenChips(for: handle)
    }
    /// Registers the tokens-change action for a token field.
    public func setTokensChangeAction(for handle: NativeHandle, action: @escaping ([String]) -> Void) {
        tokenActions[handle.rawValue] = action
    }

    /// Commits the entry's text as a new token (Enter pressed).
    private func commitTokenEntry(_ handle: NativeHandle) {
        guard let entry = tokenEntries[handle.rawValue] else { return }
        let text = String(cString: gtk_editable_get_text(entry)).trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        tokenValues[handle.rawValue, default: []].append(text)
        gtk_editable_set_text(entry, "")
        rebuildTokenChips(for: handle)
        tokenActions[handle.rawValue]?(tokenValues[handle.rawValue] ?? [])
    }

    /// Removes token `index` (its chip was clicked).
    private func removeToken(_ handle: NativeHandle, at index: Int) {
        guard var tokens = tokenValues[handle.rawValue], index < tokens.count else { return }
        tokens.remove(at: index)
        tokenValues[handle.rawValue] = tokens
        rebuildTokenChips(for: handle)
        tokenActions[handle.rawValue]?(tokens)
    }

    /// Recreates the chip buttons to match the current tokens (entry stays last).
    private func rebuildTokenChips(for handle: NativeHandle) {
        guard let boxWidget = widget(handle) else { return }
        for chip in tokenChips[handle.rawValue] ?? [] {
            gtk_box_remove(asBox(boxWidget), asWidget(chip))
        }
        var chips: [OpaquePointer] = []
        var previous: OpaquePointer? = nil
        for (index, token) in (tokenValues[handle.rawValue] ?? []).enumerated() {
            let chip = gtk_button_new_with_label("\(token) ✕")!
            gtk_widget_add_css_class(chip, "linchocolate-token-chip")
            let remove = ActionBox { [weak self] in self?.removeToken(handle, at: index) }
            g_signal_connect_data(
                UnsafeMutableRawPointer(chip), "clicked",
                unsafeBitCast(gtkActionTrampoline, to: GCallback.self),
                Unmanaged.passRetained(remove).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
            )
            gtk_box_insert_child_after(asBox(boxWidget), chip, previous.map(asWidget))
            previous = OpaquePointer(chip)
            chips.append(OpaquePointer(chip))
        }
        tokenChips[handle.rawValue] = chips
    }
    /// Creates a `GtkPicture` as the image view.
    public func createImageView(frame: NSRect) -> NativeHandle {
        let picture = gtk_picture_new()!
        gtk_widget_set_size_request(picture, Int32(frame.width), Int32(frame.height))
        return allocate(picture, .imageView, frame: frame)
    }
    private var editableTableColumns: [UInt: Set<Int>] = [:]   // table -> editable column indices
    private var tableCommitActions: [UInt: (Int, Int, String) -> Void] = [:]
    private var imageViewPaths: [UInt: String] = [:]
    private var imageViewTints: [UInt: (UInt8, UInt8, UInt8)] = [:]
    /// Windows the app has requested zoomed; mirrors AppKit's synchronous `isZoomed`.
    private var zoomedWindows: Set<UInt> = []
    /// A zoomed window's pre-zoom content size, to restore on unzoom.
    private var preZoomContentSize: [UInt: (Int32, Int32)] = [:]
    /// Loads (or clears with nil) the picture from a file path.
    public func setImagePath(_ path: String?, for handle: NativeHandle) {
        imageViewPaths[handle.rawValue] = path
        renderImageView(handle)
    }
    public func setImageTint(_ color: NSColor?, isTemplate: Bool, for handle: NativeHandle) {
        if let color, isTemplate {
            imageViewTints[handle.rawValue] = (UInt8(color.redComponent * 255),
                                               UInt8(color.greenComponent * 255),
                                               UInt8(color.blueComponent * 255))
        } else {
            imageViewTints[handle.rawValue] = nil
        }
        renderImageView(handle)
    }
    /// (Re)paints an image view from its stored path, recoloring the artwork to
    /// the tint when one is set (AppKit template semantics: keep alpha, replace RGB).
    private func renderImageView(_ handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        guard let path = imageViewPaths[handle.rawValue] else {
            gtk_picture_set_filename(w, nil)
            return
        }
        guard let tint = imageViewTints[handle.rawValue],
              let pixbuf = gdk_pixbuf_new_from_file(path, nil),
              gdk_pixbuf_get_has_alpha(pixbuf) != 0, gdk_pixbuf_get_n_channels(pixbuf) == 4 else {
            gtk_picture_set_filename(w, path)
            return
        }
        recolorPixbuf(pixbuf, to: tint)
        if let texture = gdk_texture_new_for_pixbuf(pixbuf) {
            gtk_picture_set_paintable(w, texture)
        }
    }
    /// Replaces every pixel's RGB with `rgb`, keeping alpha (template recolor).
    private func recolorPixbuf(_ pixbuf: OpaquePointer, to rgb: (UInt8, UInt8, UInt8)) {
        let width = Int(gdk_pixbuf_get_width(pixbuf))
        let height = Int(gdk_pixbuf_get_height(pixbuf))
        let stride = Int(gdk_pixbuf_get_rowstride(pixbuf))
        guard let pixels = gdk_pixbuf_get_pixels(pixbuf) else { return }
        for y in 0..<height {
            for x in 0..<width {
                let p = pixels + y * stride + x * 4
                p[0] = rgb.0; p[1] = rgb.1; p[2] = rgb.2
            }
        }
    }
    /// Creates a titled `GtkFrame` as the box container.
    public func createBox(title: String, frame: NSRect) -> NativeHandle {
        let f = gtk_frame_new(title)!
        gtk_widget_set_size_request(f, Int32(frame.width), Int32(frame.height))
        return allocate(f, .box, frame: frame)
    }
    /// Creates a `GtkScrolledWindow` with permanent scroller gutters.
    public func createScrollView(frame: NSRect) -> NativeHandle {
        let sw = gtk_scrolled_window_new()!
        gtk_widget_set_size_request(sw, Int32(frame.width), Int32(frame.height))
        // Reserve a permanent gutter for the scrollbar instead of floating it
        // over the content (AppKit's legacy scrollers take space). GTK's overlay
        // scrollbar otherwise draws atop the right edge — and on a non-composited
        // display (XQuartz) that overlay renders as an opaque strip clipping the
        // content rather than the viewport resizing to make room for it.
        gtk_scrolled_window_set_overlay_scrolling(OpaquePointer(sw), gboolean(0))
        return allocate(sw, .scrollView, frame: frame)
    }
    /// Sets per-axis scroller visibility policy via `gtk_scrolled_window_set_policy`.
    public func setScrollerPolicy(vertical: Bool, horizontal: Bool, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_scrolled_window_set_policy(w,   // GtkScrolledWindow is opaque
            horizontal ? GTK_POLICY_AUTOMATIC : GTK_POLICY_NEVER,
            vertical ? GTK_POLICY_AUTOMATIC : GTK_POLICY_NEVER)
    }
    /// Sets the scroll adjustments' values to `(x, y)`.
    public func setScrollOffset(x: Double, y: Double, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_adjustment_set_value(gtk_scrolled_window_get_hadjustment(w), x)
        gtk_adjustment_set_value(gtk_scrolled_window_get_vadjustment(w), y)
    }
    /// Returns the scroll adjustments' current values.
    public func scrollOffset(for handle: NativeHandle) -> (x: Double, y: Double) {
        guard let w = widget(handle) else { return (0, 0) }
        return (gtk_adjustment_get_value(gtk_scrolled_window_get_hadjustment(w)),
                gtk_adjustment_get_value(gtk_scrolled_window_get_vadjustment(w)))
    }
    /// Returns the total scrollable content size (each adjustment's upper).
    public func scrollDocumentSize(for handle: NativeHandle) -> (width: Double, height: Double) {
        guard let w = widget(handle) else { return (0, 0) }
        return (gtk_adjustment_get_upper(gtk_scrolled_window_get_hadjustment(w)),
                gtk_adjustment_get_upper(gtk_scrolled_window_get_vadjustment(w)))
    }
    /// Returns the visible viewport size (each adjustment's page size).
    public func scrollVisibleSize(for handle: NativeHandle) -> (width: Double, height: Double) {
        guard let w = widget(handle) else { return (0, 0) }
        return (gtk_adjustment_get_page_size(gtk_scrolled_window_get_hadjustment(w)),
                gtk_adjustment_get_page_size(gtk_scrolled_window_get_vadjustment(w)))
    }
    /// Wires both scroll adjustments' `value-changed` signals to report the new offset.
    public func setScrollChangeAction(for handle: NativeHandle, action: @escaping (Double, Double) -> Void) {
        guard let w = widget(handle),
              let hadj = gtk_scrolled_window_get_hadjustment(w),
              let vadj = gtk_scrolled_window_get_vadjustment(w) else { return }
        let box = ScrollBox(hadj: hadj, vadj: vadj, action: action)
        // Both adjustments drive the same box; retain once per connection.
        for adjustment in [hadj, vadj] {
            g_signal_connect_data(
                UnsafeMutableRawPointer(adjustment), "value-changed",
                unsafeBitCast(gtkScrollChangedTrampoline, to: GCallback.self),
                Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
            )
        }
    }
    /// Creates a `GtkPaned`; AppKit `vertical` = vertical divider = GTK horizontal orientation.
    public func createSplitView(vertical: Bool, frame: NSRect) -> NativeHandle {
        // AppKit "vertical" = vertical divider = panes side by side, which is
        // GTK's *horizontal* orientation.
        let orientation = vertical ? GTK_ORIENTATION_HORIZONTAL : GTK_ORIENTATION_VERTICAL
        let paned = gtk_paned_new(orientation)!
        gtk_widget_set_size_request(paned, Int32(frame.width), Int32(frame.height))
        return allocate(paned, .splitView, frame: frame)
    }
    /// Adds `pane` as the next `GtkPaned` child (first = leading/top, second = trailing/bottom).
    public func addSplitPane(_ pane: NativeHandle, to splitView: NativeHandle) {
        guard let paned = widget(splitView), let p = widget(pane) else { return }
        let count = splitPaneCounts[splitView.rawValue, default: 0]
        if count == 0 {
            gtk_paned_set_start_child(paned, asWidget(p))   // GtkPaned is opaque
            // Pin the leading pane to the divider position (don't let it grow to
            // its natural width and push the divider right).
            gtk_paned_set_resize_start_child(paned, gboolean(0))
            gtk_paned_set_shrink_start_child(paned, gboolean(0))
        } else {
            gtk_paned_set_end_child(paned, asWidget(p))
            // The trailing pane fills the remaining width but never shrinks below
            // its content — otherwise the pane's box is clipped on the right.
            gtk_paned_set_resize_end_child(paned, gboolean(1))
            gtk_paned_set_shrink_end_child(paned, gboolean(0))
        }
        splitPaneCounts[splitView.rawValue] = count + 1
    }
    /// Moves the paned's divider to `position` (pixels from the leading edge).
    public func setDividerPosition(_ position: Double, for splitView: NativeHandle) {
        guard let paned = widget(splitView) else { return }
        gtk_paned_set_position(paned, gint(position))
    }
    /// Toggles `gtk_widget_set_overflow` between `HIDDEN` and `VISIBLE`.
    public func setClipsToBounds(_ clips: Bool, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_widget_set_overflow(asWidget(w), clips ? GTK_OVERFLOW_HIDDEN : GTK_OVERFLOW_VISIBLE)
    }

    /// Records the view's flip state and re-places every child accordingly.
    public func setViewFlipped(_ flipped: Bool, for handle: NativeHandle) {
        let was = flippedViews.contains(handle.rawValue)
        if flipped { flippedViews.insert(handle.rawValue) } else { flippedViews.remove(handle.rawValue) }
        // isFlipped is per-view, not app-wide: this view may disagree with its
        // parent and its own children. Changing it re-reads every child's Y.
        if was != flipped { replaceChildren(of: handle.rawValue) }
    }

    /// Re-places every child of `parentRaw` from its (unchanged) AppKit frame.
    ///
    /// A child's GTK Y is derived from *this* parent's height and *this*
    /// parent's flip — so resizing the parent, or flipping it, invalidates
    /// every child's position even though no child's frame changed. Only
    /// unflipped parents actually move their children, but re-placing is
    /// idempotent, so it is not worth special-casing.
    private func replaceChildren(of parentRaw: UInt) {
        guard let container = containerFixed(of: parentRaw) else { return }
        var moved = false
        for childRaw in childrenByParent[parentRaw] ?? [] {
            guard let w = widgets[childRaw], let childFrame = frames[childRaw] else { continue }
            setExactRect(placement(for: childFrame, in: parentRaw), on: w)
            moved = true
        }
        if moved { gtk_widget_queue_allocate(asWidget(container)) }
    }

    /// Whether `view` draws in a top-left (flipped) coordinate space.
    func isViewFlipped(_ view: UInt) -> Bool {
        // Read only by the draw trampoline, to decide whether Cairo needs the
        // Y-axis flip that lets bottom-left AppKit drawing code work. The
        // shared core always authors in top-left device coordinates (it grew up
        // on GDI), so a view it draws needs no flip — with one, the pill shapes
        // survived because a rounded rect is vertically symmetric, but every
        // glyph came out mirrored. Layout's own notion of flipped-ness is
        // `flippedViews`, which this deliberately does not disturb.
        flippedViews.contains(view) || coreSeam.topLeftDrawing.contains(view)
    }

    /// The magnification applied to `view`'s custom drawing (1 = no zoom).
    func viewMagnification(_ view: UInt) -> Double { viewMagnifications[view] ?? 1 }

    /// Scales a document view's drawing and enlarges its requested size so a
    /// hosting `GtkScrolledWindow` reports the enlarged scrollable extent —
    /// the backing for `NSScrollView.magnification`.
    public func setViewMagnification(_ magnification: Double, for handle: NativeHandle) {
        // The natural (unscaled) size is what the view was created at.
        guard let overlay = widget(handle), let natural = frames[handle.rawValue] else { return }
        let scale = magnification > 0 ? magnification : 1
        viewMagnifications[handle.rawValue] = scale
        gtk_widget_set_size_request(asWidget(overlay),
                                    Int32((natural.width  * CGFloat(scale)).rounded()),
                                    Int32((natural.height * CGFloat(scale)).rounded()))
        if let area = viewDrawAreas[handle.rawValue] {
            gtk_widget_queue_draw(asWidget(area))
        }
    }

    /// The exact rect `childFrame` occupies inside `parentRaw`, in GTK's
    /// top-left space. The one place a child's geometry is decided — see
    /// `CoordinateSpace.place`.
    private func placement(for childFrame: NSRect, in parentRaw: UInt) -> NSRect {
        CoordinateSpace.place(childFrame,
                              inParentOfHeight: frames[parentRaw]?.height ?? 0,
                              parentIsFlipped: flippedViews.contains(parentRaw))
    }

    /// The GTK (top-left) Y for `childFrame` inside `parentRaw`.
    private func placementY(for childFrame: NSRect, in parentRaw: UInt) -> CGFloat {
        placement(for: childFrame, in: parentRaw).origin.y
    }

    /// Places `child` inside `parent`'s child-hosting `GtkFixed` at the child's frame origin.
    public func addSubview(_ child: NativeHandle, to parent: NativeHandle) {
        guard let c = widget(child) else { return }
        guard let p = containerFixed(of: parent.rawValue) else {
            // The parent hosts no children (it is not an NSView-backed
            // container). Silently dropping the child is how controls went
            // missing, so say so instead.
            let kind = kinds[parent.rawValue].map { String(describing: $0) } ?? "?"
            let message = "LinChocolate: cannot add a subview to a " + kind
                + " - it has no child area; the child will not appear.\n"
            FileHandle.standardError.write(Data(message.utf8))
            return
        }
        parents[child.rawValue] = parent.rawValue
        childrenByParent[parent.rawValue, default: []].append(child.rawValue)
        let childFrame = frames[child.rawValue] ?? .zero
        setExactRect(placement(for: childFrame, in: parent.rawValue), on: c)
        gtk_widget_set_parent(asWidget(c), asWidget(p))
        gtk_widget_queue_allocate(asWidget(p))
        // AppKit groups radio buttons that share a superview; mirror that so the
        // GtkCheckButtons render round and behave mutually exclusively.
        if kinds[child.rawValue] == .radio {
            if let lead = radiosByParent[parent.rawValue]?.first, let leadW = widgets[lead] {
                gtk_check_button_set_group(asCheckButton(c), asCheckButton(leadW))
            }
            radiosByParent[parent.rawValue, default: []].append(child.rawValue)
        }
    }

    // MARK: Mutators
    /// Updates a control's text/title, dispatched by kind to the appropriate GTK setter.
    public func setText(_ text: String, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        switch kinds[handle.rawValue] {
        case .button:    gtk_button_set_label(asButton(w), text)
        case .label:     gtk_label_set_text(w, text)          // GtkLabel is opaque
        case .textField, .secureField, .searchField: gtk_editable_set_text(w, text)
        case .comboBox:  if let e = comboEntries[handle.rawValue] { gtk_editable_set_text(e, text) }
        case .checkbox, .radio: gtk_check_button_set_label(asCheckButton(w), text)
        case .textView:  gtk_text_buffer_set_text(gtk_text_view_get_buffer(asTextView(w)), text, -1)
        case .box:       gtk_frame_set_label(asFrame(w), text)
        case .window:    gtk_window_set_title(asWindow(w), text)
        case .view:      setViewText(text, for: handle)
        default: break
        }
    }

    /// Displays `text` on a plain view.
    ///
    /// A Win32 view is a static control, so the shared core sets text straight
    /// on one and expects it to show — that is how a toolbar item's icon-and-
    /// label tile renders (`NSToolbarCompositeItemView.updateNativeText`).
    /// GTK's view is a GtkOverlay with a drawing area and a child area, and
    /// neither displays text, so the toolbar came up as a row of blank tiles.
    /// A centered label overlaid on the view is the missing piece.
    private func setViewText(_ text: String, for handle: NativeHandle) {
        let raw = handle.rawValue
        guard let overlay = widgets[raw] else { return }

        // Drop whatever this view showed before; the core re-sends the whole
        // description on every change.
        if let old = coreSeam.viewTextLabels[raw] {
            gtk_widget_unparent(UnsafeMutablePointer<GtkWidget>(old))
            coreSeam.viewTextLabels[raw] = nil
        }

        guard let content = viewTextContent(text) else { return }
        gtk_widget_set_halign(content, GTK_ALIGN_CENTER)
        gtk_widget_set_valign(content, GTK_ALIGN_CENTER)
        gtk_overlay_add_overlay(overlay, content)
        coreSeam.viewTextLabels[raw] = OpaquePointer(content)
    }

    /// Builds the widget a plain view's text asks for, or nil for nothing.
    ///
    /// A toolbar item tile does not send a label — it sends a tab-separated
    /// description (`NSToolbarCompositeItemView.nativeText`) that the Win32
    /// side decodes into an icon and a caption. Rendering it verbatim printed
    /// the image's file path across the toolbar, so it is decoded here too.
    private func viewTextContent(_ text: String) -> UnsafeMutablePointer<GtkWidget>? {
        let fields = text.components(separatedBy: "\t")
        guard fields.first == "__WinChocolateToolbarItem" else {
            let plain = text.trimmingCharacters(in: .whitespacesAndNewlines)
            // `NSToolbarSeparatorView` marks itself with a bare "separator";
            // it is a drawn bar, not a caption.
            guard !plain.isEmpty, plain != "separator" else { return nil }
            return gtk_label_new(plain)
        }

        let title = fields.count > 1 ? fields[1] : ""
        let imageName = fields.count > 2 ? fields[2] : ""
        let showItem = fields.count > 3 && fields[3] == "1"
        let showLabel = fields.count > 4 && fields[4] == "1"
        let labelBeside = fields.count > 5 && fields[5] == "beside"

        let image: UnsafeMutablePointer<GtkWidget>? = (showItem && !imageName.isEmpty)
            ? (FileManager.default.fileExists(atPath: imageName)
                ? gtk_image_new_from_file(imageName)
                : gtk_image_new_from_icon_name(imageName))
            : nil
        image.map { gtk_image_set_pixel_size(OpaquePointer($0), 18) }
        let label: UnsafeMutablePointer<GtkWidget>? = (showLabel && !title.isEmpty)
            ? gtk_label_new(title) : nil

        switch (image, label) {
        case let (image?, label?):
            let box = gtk_box_new(labelBeside ? GTK_ORIENTATION_HORIZONTAL : GTK_ORIENTATION_VERTICAL, 2)!
            gtk_box_append(asBox(OpaquePointer(box)), image)
            gtk_box_append(asBox(OpaquePointer(box)), label)
            return box
        case let (image?, nil):  return image
        case let (nil, label?):  return label
        default:                 return nil
        }
    }
    /// Updates a control's frame, re-placing it inside its parent and re-placing its children.
    public func setFrame(_ frame: NSRect, for handle: NativeHandle) {
        frames[handle.rawValue] = frame
        guard let w = widget(handle) else { return }

        if kinds[handle.rawValue] == .window {
            // GTK4 delegates live window sizing to the compositor; set the
            // default so an unmapped window opens at the requested size.
            gtk_window_set_default_size(asWindow(w), Int32(frame.width), Int32(frame.height))
            return
        }

        gtk_widget_set_size_request(asWidget(w), Int32(frame.width), Int32(frame.height))

        // Re-place at the new exact rect within our own parent...
        if let parentRaw = parents[handle.rawValue], let p = containerFixed(of: parentRaw) {
            setExactRect(placement(for: frame, in: parentRaw), on: w)
            gtk_widget_queue_allocate(asWidget(p))
        }
        // ...and re-place our children, whose Y is measured against our height
        // when we are unflipped.
        replaceChildren(of: handle.rawValue)
    }
    /// Attaches a `GtkGestureClick` reporting the press position in the view's coordinates.
    public func setClickAction(for handle: NativeHandle, action: @escaping (Double, Double) -> Void) {
        guard let w = widget(handle) else { return }
        let click = gtk_gesture_click_new()
        let box = ClickBox(action)
        g_signal_connect_data(
            UnsafeMutableRawPointer(click), "pressed",
            unsafeBitCast(gtkViewClickTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        gtk_widget_add_controller(asWidget(w), click)
    }

    /// Attaches motion and click controllers to deliver enter/leave/press events to `handler`.
    public func setMouseHandler(for handle: NativeHandle, _ handler: @escaping (NativeMouseEvent) -> Void) {
        guard let w = widget(handle) else { return }
        let widget = asWidget(w)

        // Enter/leave for hover tracking.
        let motion = gtk_event_controller_motion_new()
        let enterBox = MouseBox(handler)
        g_signal_connect_data(
            UnsafeMutableRawPointer(motion), "enter",
            unsafeBitCast(gtkMotionEnterTrampoline, to: GCallback.self),
            Unmanaged.passRetained(enterBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        let leaveBox = MouseBox(handler)
        g_signal_connect_data(
            UnsafeMutableRawPointer(motion), "leave",
            unsafeBitCast(gtkMotionLeaveTrampoline, to: GCallback.self),
            Unmanaged.passRetained(leaveBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        gtk_widget_add_controller(widget, motion)

        // Left + right press → mouseDown / rightMouseDown.
        for button in [guint(1), guint(3)] {
            let click = gtk_gesture_click_new()
            gtk_gesture_single_set_button(click, button)
            let clickBox = MouseClickBox(handler: handler, rightButton: button == 3)
            g_signal_connect_data(
                UnsafeMutableRawPointer(click), "pressed",
                unsafeBitCast(gtkMousePressTrampoline, to: GCallback.self),
                Unmanaged.passRetained(clickBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
            )
            gtk_widget_add_controller(widget, click)
        }

        // Scroll wheel / trackpad → scrollWheel(with:).
        let scroll = gtk_event_controller_scroll_new(GTK_EVENT_CONTROLLER_SCROLL_BOTH_AXES)
        let scrollBox = MouseBox(handler)
        g_signal_connect_data(
            UnsafeMutableRawPointer(scroll), "scroll",
            unsafeBitCast(gtkScrollTrampoline, to: GCallback.self),
            Unmanaged.passRetained(scrollBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        gtk_widget_add_controller(widget, scroll)
    }

    /// Installs a Cairo draw function on the view's `GtkDrawingArea` that adapts to `NativeGraphicsContext`.
    public func setDrawHandler(for handle: NativeHandle, handler: @escaping (NativeGraphicsContext, Double, Double) -> Void) {
        guard let area = viewDrawAreas[handle.rawValue] else { return }
        drawHandlers[handle.rawValue] = handler
        let box = DrawBox(backend: self, view: handle.rawValue)
        gtk_drawing_area_set_draw_func(
            UnsafeMutablePointer<GtkDrawingArea>(area),
            gtkDrawFunc,
            Unmanaged.passRetained(box).toOpaque(), boxDestroyNotify
        )
    }
    public func runPrintOperation(view: NativeHandle, jobTitle: String, parent: NativeHandle?) -> Bool {
        guard drawHandlers[view.rawValue] != nil else { return false }
        let op = gtk_print_operation_new()!
        gtk_print_operation_set_n_pages(op, 1)
        gtk_print_operation_set_job_name(op, jobTitle)
        let frame = frames[view.rawValue] ?? NSMakeRect(0, 0, 320, 180)
        let box = PrintBox(backend: self, view: view.rawValue,
                           width: Double(frame.width), height: Double(frame.height))
        g_signal_connect_data(
            UnsafeMutableRawPointer(op), "draw-page",
            unsafeBitCast(gtkPrintDrawPageTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        // A headless/automation escape hatch: export to PDF instead of showing
        // the (modal, display-bound) print dialog. Keeps CI and the geometry
        // audit from blocking on a dialog while still exercising the render path.
        let result: GtkPrintOperationResult
        if let exportPath = ProcessInfo.processInfo.environment["LINCHOCOLATE_PRINT_EXPORT"], !exportPath.isEmpty {
            gtk_print_operation_set_export_filename(op, exportPath)
            result = gtk_print_operation_run(op, GTK_PRINT_OPERATION_ACTION_EXPORT, nil, nil)
        } else {
            let parentWindow = parent.flatMap { widget($0) }.map { asWindow($0) }
            result = gtk_print_operation_run(op, GTK_PRINT_OPERATION_ACTION_PRINT_DIALOG, parentWindow, nil)
        }
        g_object_unref(UnsafeMutableRawPointer(op))
        return result == GTK_PRINT_OPERATION_RESULT_APPLY
    }
    /// Renders the print page: wraps the print context's Cairo in a graphics
    /// context and runs the view's draw handler at its natural size, top-left.
    func drawPrintPage(view: UInt, printContext: OpaquePointer, width: Double, height: Double) {
        guard let cr = gtk_print_context_get_cairo_context(printContext) else { return }
        // The demo's print view is flipped (top-left origin), matching Cairo's
        // native space, so no axis flip — same as the on-screen flipped path.
        let context = CairoGraphicsContext(cr: cr, flipped: true)
        dispatchDraw(view: view, context: context, width: width, height: height)
    }
    /// Queues a redraw of the view's `GtkDrawingArea`.
    public func setNeedsDisplay(_ handle: NativeHandle) {
        guard let area = viewDrawAreas[handle.rawValue] else { return }
        if paintTrace {
            let ms = Double(g_get_monotonic_time() - paintTraceStart) / 1000.0
            FileHandle.standardError.write(
                String(format: "LCPAINT %8.1fms [invalidate] view=%d\n", ms, Int(handle.rawValue))
                    .data(using: .utf8)!)
        }
        gtk_widget_queue_draw(asWidget(area))
    }
    /// Dispatches a draw pass to the Swift handler (called by the draw func).
    func dispatchDraw(view: UInt, context: NativeGraphicsContext, width: Double, height: Double) {
        if paintTrace, let window = contentViewOwners[view] {
            paintTraceFrames[window, default: 0] += 1
            tracePaint(window, "draw#\(paintTraceFrames[window] ?? 0)@\(Int(width))x\(Int(height))")
        }
        drawHandlers[view]?(context, width, height)
        noteContentDraw(view: view, width: width, height: height)
    }
    /// Sets the widget's sensitivity (`gtk_widget_set_sensitive`).
    public func setEnabled(_ isEnabled: Bool, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_widget_set_sensitive(asWidget(w), gboolean(isEnabled ? 1 : 0))
    }
    /// Sets the widget's visibility (`gtk_widget_set_visible`).
    public func setHidden(_ isHidden: Bool, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_widget_set_visible(asWidget(w), gboolean(isHidden ? 0 : 1))
    }
    /// Renders `runs` as Pango markup on a `GtkLabel`.
    public func setStyledText(_ runs: [NativeTextRun], for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        // Attributed text renders via Pango markup on the label.
        var markup = ""
        for run in runs {
            var attributes: [String] = []
            if let color = run.color {
                attributes.append(String(
                    format: "foreground=\"#%02X%02X%02X\"",
                    Int(color.redComponent * 255), Int(color.greenComponent * 255),
                    Int(color.blueComponent * 255)
                ))
            }
            if let font = run.font {
                var description = font.family ?? ""
                if font.bold { description += " Bold" }
                if font.italic { description += " Italic" }
                description += " \(Int(font.size))"
                attributes.append("font_desc=\"\(description.trimmingCharacters(in: .whitespaces))\"")
            }
            let escaped = run.text
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            markup += attributes.isEmpty ? escaped : "<span \(attributes.joined(separator: " "))>\(escaped)</span>"
        }
        gtk_label_set_markup(w, markup)   // GtkLabel is opaque
    }
    /// Applies a font to the widget via a display-wide scoped CSS rule.
    public func setFont(_ font: NativeFontSpec, for handle: NativeHandle) {
        widgetFonts[handle.rawValue] = font
        applyWidgetStyle(for: handle)
    }
    /// Applies a foreground text color via a display-wide scoped CSS rule.
    public func setTextColor(_ color: NSColor, for handle: NativeHandle) {
        widgetTextColors[handle.rawValue] = color
        applyWidgetStyle(for: handle)
    }

    /// Applies a theme-derived background to an `NSVisualEffectView`. The shade
    /// is expressed against GTK's theme-named colors (`@theme_bg_color`, …), so
    /// it flips automatically when the app switches to dark appearance — no real
    /// blur (XQuartz is non-composited), just a material-shaded surface.
    public func setMaterial(_ material: String, for handle: NativeHandle) {
        guard widget(handle) != nil else { return }
        let background: String
        switch material {
        case "sidebar", "underWindowBackground": background = "shade(@theme_bg_color, 0.93)"
        case "titlebar", "headerView":           background = "shade(@theme_bg_color, 1.05)"
        case "menu", "popover", "sheet":         background = "@theme_base_color"
        case "hudWindow":                        background = "alpha(@theme_fg_color, 0.55)"
        default:                                 background = "@theme_bg_color"
        }
        // 700 sits between the app (600) and per-widget font/color (800) layers.
        let cls = scopeClass(handle.rawValue)
        setScopedRule(".\(cls), .\(cls) * { background: \(background); }",
                      id: "material", priority: 700, for: handle)
    }

    /// Rebuilds and installs the widget-scoped CSS provider carrying the
    /// control's font and text color (GTK styles text via CSS, not API calls).
    private func applyWidgetStyle(for handle: NativeHandle) {
        guard widget(handle) != nil else { return }

        var declarations: [String] = []
        if let font = widgetFonts[handle.rawValue] {
            if let family = font.family { declarations.append("font-family: \"\(family)\";") }
            declarations.append("font-size: \(Int(font.size))px;")
            if font.bold { declarations.append("font-weight: bold;") }
            if font.italic { declarations.append("font-style: italic;") }
        }
        if let color = widgetTextColors[handle.rawValue] {
            declarations.append(String(
                format: "color: rgba(%d,%d,%d,%.2f);",
                Int(color.redComponent * 255), Int(color.greenComponent * 255),
                Int(color.blueComponent * 255), color.alphaComponent
            ))
        }
        let body = declarations.joined(separator: " ")
        // `text` reaches text-holding subnodes (GtkTextView, GtkEntry); the
        // `.cls *` arm reproduces the old widget-scoped `*` reach.
        // 800 = GTK_STYLE_PROVIDER_PRIORITY_USER (macro doesn't import).
        let cls = scopeClass(handle.rawValue)
        let rule = ".\(cls), .\(cls) * { \(body) } .\(cls) text, .\(cls) * text { \(body) }"
        setScopedRule(body.isEmpty ? nil : rule, id: "font", priority: 800, for: handle)
    }
    /// Sets a check button's on/off state.
    public func setButtonState(_ on: Bool, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_check_button_set_active(asCheckButton(w), gboolean(on ? 1 : 0))
    }
    /// Updates a slider/progress/stepper/level's numeric value, dispatched by kind.
    public func setDoubleValue(_ value: Double, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        switch kinds[handle.rawValue] {
        case .slider:
            gtk_range_set_value(asRange(w), value)
        case .progress:
            guard !indeterminateProgress.contains(handle.rawValue) else { break }
            let (lo, hi) = ranges[handle.rawValue] ?? (0, 1)
            let fraction = hi > lo ? (value - lo) / (hi - lo) : 0
            gtk_progress_bar_set_fraction(w, min(1, max(0, fraction)))   // GtkProgressBar is opaque
        case .stepper:
            // Arrows only — nothing to display; the value lives in the app's
            // own field, exactly as AppKit's NSStepper works.
            stepperValues[handle.rawValue] = value
        case .level:
            levelValues[handle.rawValue] = value
            buildLevelContent(handle.rawValue)
        default: break
        }
    }
    /// Sets the selected index for pop-ups, tabs, segments, tables, outlines, and collections.
    public func setSelectedIndex(_ index: Int, for handle: NativeHandle) {
        guard let w = widget(handle), index >= 0 else { return }
        switch kinds[handle.rawValue] {
        case .tabView: gtk_notebook_set_current_page(w, gint(index))   // GtkNotebook is opaque
        case .segmented:
            guard let buttons = segmentButtons[handle.rawValue], index < buttons.count else { return }
            gtk_toggle_button_set_active(asToggle(buttons[index]), gboolean(1))
        case .table, .outline, .collection:
            guard let selection = tableSelections[handle.rawValue] else { return }
            gtk_single_selection_set_selected(selection, guint(index))
        default:       gtk_drop_down_set_selected(w, guint(index))     // GtkDropDown is opaque
        }
    }
    /// Reorients a `GtkScale` slider (AppKit's vertical minimum is at the bottom, so the range is inverted).
    private var sliderSnapTicks: [UInt: Int] = [:]   // slider -> tick count it snaps to
    private var suppressSliderReport: Set<UInt> = []
    public func setSliderTickMarks(count: Int, snapsToTicks: Bool, for handle: NativeHandle) {
        guard let w = widget(handle), kinds[handle.rawValue] == .slider else { return }
        let scale = UnsafeMutablePointer<GtkScale>(w)
        gtk_scale_clear_marks(scale)
        sliderSnapTicks[handle.rawValue] = nil
        guard count >= 2, let (lo, hi) = ranges[handle.rawValue], hi > lo else { return }
        // GtkScale draws a mark per position, the direct analog of AppKit's
        // evenly spaced tick marks. Position BOTTOM is GTK's "trailing side",
        // which is the right of a vertical scale and below a horizontal one —
        // where AppKit puts them by default.
        for index in 0..<count {
            let value = lo + (hi - lo) * Double(index) / Double(count - 1)
            gtk_scale_add_mark(scale, value, GTK_POS_BOTTOM, nil)
        }
        if snapsToTicks { sliderSnapTicks[handle.rawValue] = count }
    }
    /// Rounds a slider's value to its nearest tick, for
    /// `allowsTickMarkValuesOnly`. Returns the snapped value.
    func snapSliderValue(_ raw: UInt, _ value: Double) -> Double {
        guard let count = sliderSnapTicks[raw], count >= 2,
              let (lo, hi) = ranges[raw], hi > lo else { return value }
        let step = (hi - lo) / Double(count - 1)
        return lo + (step * ((value - lo) / step).rounded())
    }
    public func setSliderVertical(_ vertical: Bool, for handle: NativeHandle) {
        guard let w = widget(handle), kinds[handle.rawValue] == .slider else { return }
        gtk_orientable_set_orientation(
            w, vertical ? GTK_ORIENTATION_VERTICAL : GTK_ORIENTATION_HORIZONTAL)
        // AppKit's vertical slider puts the minimum at the bottom; GtkScale's
        // vertical default puts it at the top, so invert to match.
        gtk_range_set_inverted(asRange(w), gboolean(vertical ? 1 : 0))
    }
    /// Replaces the drop-down's model with a fresh `GtkStringList` and selects `selectedIndex`.
    public func setPopUpItems(_ titles: [String], selectedIndex: Int, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        // Rebuild the drop-down's model from a fresh GtkStringList.
        let list = gtk_string_list_new(nil)!
        for title in titles { gtk_string_list_append(list, title) }
        gtk_drop_down_set_model(w, list)
        if selectedIndex >= 0, selectedIndex < titles.count {
            gtk_drop_down_set_selected(w, guint(selectedIndex))
        }
    }
    /// Updates the graphical picker's `GtkCalendar` (compact text is set separately via `setDatePickerText`).
    public func setDateValue(_ date: Date, for handle: NativeHandle) {
        let raw = handle.rawValue
        dateValues[raw] = date
        guard widget(handle) != nil else { return }
        // GtkCalendar navigates via a GDateTime; unix-local keeps Date exact.
        guard let gdt = g_date_time_new_from_unix_local(gint64(date.timeIntervalSince1970)) else { return }
        if graphicalDatePickers.contains(raw), let calendar = graphicalCalendars[raw] {
            // Selecting a day re-emits day-selected; that is us, not the user.
            suppressCalendarReport.insert(raw)
            gtk_calendar_select_day(calendar, gdt)
            suppressCalendarReport.remove(raw)
        }
        // The compact style's (and clockAndCalendar's time row's) text arrives
        // through setDatePickerText: formatting
        // needs the locale, calendar and element flags, which are AppKit's to
        // decide, not the backend's.
        g_date_time_unref(gdt)
    }
    /// Sets a `GtkColorButton`'s color via `GtkColorChooser`.
    public func setColor(_ color: NSColor, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        var rgba = GdkRGBA(
            red: Float(color.redComponent), green: Float(color.greenComponent),
            blue: Float(color.blueComponent), alpha: Float(color.alphaComponent)
        )
        lc_color_chooser_set_rgba(asWidget(w), &rgba)
    }
    /// Destroys the widget (windows only) and forgets its bookkeeping.
    public func destroyControl(_ handle: NativeHandle) {
        let r = handle.rawValue
        if kinds[r] == .window, let w = widgets[r] {
            gtk_window_destroy(asWindow(w))
        }
        widgets[r] = nil; kinds[r] = nil; frames[r] = nil; parents[r] = nil
    }

    // MARK: Events
    /// Wires the widget's `clicked` signal to `action`.
    public func registerAction(for handle: NativeHandle, action: @escaping () -> Void) {
        // AppKit puts target/action on `NSControl`, so the shared core registers
        // one for EVERY control — label, slider, progress bar and all. GTK has
        // no such universal signal: "clicked" belongs to GtkButton alone, and
        // connecting it to a GtkDropDown or GtkLabel logs
        // `signal 'clicked' is invalid for instance …` and then walks off the
        // end of the signal table. So each kind gets the signal it actually
        // has, and kinds with no activation signal get none.
        let signal: String
        switch kinds[handle.rawValue] {
        case .button:
            signal = "clicked"
        case .checkbox, .radio:
            // GTK4's GtkCheckButton is no longer a GtkButton, so it has no
            // "clicked" — its activation signal is "toggled".
            signal = "toggled"
        case .textField, .secureField, .searchField:
            signal = "activate"          // Enter, as on an AppKit text field
        case .slider:
            signal = "value-changed"     // GtkRange's, same callback shape
        case .comboBox:
            // The combo's activation comes from its internal entry.
            guard let entry = comboEntries[handle.rawValue] else { return }
            let box = ActionBox(action)
            g_signal_connect_data(
                UnsafeMutableRawPointer(entry), "activate",
                unsafeBitCast(gtkActionTrampoline, to: GCallback.self),
                Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
            )
            return
        default:
            return
        }
        guard let w = widget(handle) else { return }
        let box = ActionBox(action)
        g_signal_connect_data(
            UnsafeMutableRawPointer(w), signal,
            unsafeBitCast(gtkActionTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
    }
    /// Wires a `GtkEntry`'s `activate` signal (Enter pressed) to `action`.
    public func setSubmitAction(for handle: NativeHandle, action: @escaping () -> Void) {
        guard let w = widget(handle) else { return }
        // GtkEntry emits "activate" on Enter — AppKit's text-field action.
        let box = ActionBox(action)
        g_signal_connect_data(
            UnsafeMutableRawPointer(w), "activate",
            unsafeBitCast(gtkActionTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
    }

    /// Wires text-change signals (text buffer `changed` or editable `changed`, depending on kind) to `action`.
    public func setTextChangeAction(for handle: NativeHandle, action: @escaping (String) -> Void) {
        let box = StringActionBox(action)
        // A text view's changes come from its GtkTextBuffer, which reads back
        // differently from a GtkEditable, so it uses its own trampoline.
        if kinds[handle.rawValue] == .textView, let w = widget(handle) {
            let buffer = gtk_text_view_get_buffer(asTextView(w))
            g_signal_connect_data(
                UnsafeMutableRawPointer(buffer), "changed",
                unsafeBitCast(gtkTextBufferChangedTrampoline, to: GCallback.self),
                Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
            )
            return
        }
        // "changed" is GtkEditable's. A label has no editable text, and the
        // core asks every text-ish control for change notifications, so only
        // the kinds that really are editable get connected.
        switch kinds[handle.rawValue] {
        case .textField, .secureField, .searchField, .comboBox, .tokenField:
            break
        default:
            return
        }
        // A combo emits text changes on its internal entry, not the combo itself.
        let target = (kinds[handle.rawValue] == .comboBox) ? comboEntries[handle.rawValue] : widget(handle)
        guard let w = target else { return }
        g_signal_connect_data(
            UnsafeMutableRawPointer(w), "changed",
            unsafeBitCast(gtkTextChangedTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
    }
    /// Wires a check button's `toggled` signal to `action`, passing the new active state.
    public func setToggleAction(for handle: NativeHandle, action: @escaping (Bool) -> Void) {
        guard let w = widget(handle) else { return }
        let box = BoolActionBox(action)
        g_signal_connect_data(
            UnsafeMutableRawPointer(w), "toggled",
            unsafeBitCast(gtkToggledTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
    }
    /// Wires a slider/level's `value-changed` signal to `action`, or records it for the stepper.
    public func setValueChangeAction(for handle: NativeHandle, action: @escaping (Double) -> Void) {
        guard let w = widget(handle) else { return }
        let box = DoubleActionBox(action)
        // A stepper is our own arrow buttons, not a GtkRange, so it has no
        // "value-changed" to connect to: `stepStepper` reports directly.
        if kinds[handle.rawValue] == .stepper {
            valueChangeActions[handle.rawValue] = action
            return
        }
        if kinds[handle.rawValue] == .slider {
            // A slider may snap to its tick marks, which means rewriting the
            // value before reporting it — that needs the backend and handle, so
            // it gets its own box and trampoline.
            let sliderBox = SliderValueBox(backend: self, raw: handle.rawValue, action: action)
            g_signal_connect_data(
                UnsafeMutableRawPointer(w), "value-changed",
                unsafeBitCast(gtkSliderValueChangedTrampoline, to: GCallback.self),
                Unmanaged.passRetained(sliderBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
            )
            return
        }
        let trampoline = gtkValueChangedTrampoline
        g_signal_connect_data(
            UnsafeMutableRawPointer(w), "value-changed",
            unsafeBitCast(trampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
    }
    /// Reports a slider's new value, snapping it to the tick marks first when
    /// `allowsTickMarkValuesOnly` is set (AppKit snaps the knob itself, so the
    /// control is moved too — guarded against the re-entrant value-changed).
    fileprivate func reportSliderValue(_ raw: UInt, action: (Double) -> Void) {
        guard !suppressSliderReport.contains(raw), let w = widgets[raw] else { return }
        let value = gtk_range_get_value(asRange(w))
        let snapped = snapSliderValue(raw, value)
        if snapped != value {
            suppressSliderReport.insert(raw)
            gtk_range_set_value(asRange(w), snapped)
            suppressSliderReport.remove(raw)
        }
        action(snapped)
    }
    /// Wires selection-change signals for pop-ups, tabs, tables, outlines, segments, and collections.
    public func setSelectionChangeAction(for handle: NativeHandle, action: @escaping (Int) -> Void) {
        if collectionFlows[handle.rawValue] != nil {
            collectionSelectionActions[handle.rawValue] = action
            return
        }
        guard let w = widget(handle) else { return }
        let box = IntActionBox(action)
        if [.table, .outline, .collection].contains(kinds[handle.rawValue]) {
            guard let selection = tableSelections[handle.rawValue] else { return }
            g_signal_connect_data(
                UnsafeMutableRawPointer(selection), "notify::selected",
                unsafeBitCast(gtkTableSelectionChangedTrampoline, to: GCallback.self),
                Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
            )
            return
        }
        if kinds[handle.rawValue] == .segmented {
            // One "toggled" hookup per segment; each box carries its index and
            // only fires on activation (the deactivating peer stays quiet).
            for (index, button) in (segmentButtons[handle.rawValue] ?? []).enumerated() {
                let segmentBox = SegmentBox(index: index, action: action)
                g_signal_connect_data(
                    UnsafeMutableRawPointer(button), "toggled",
                    unsafeBitCast(gtkSegmentToggledTrampoline, to: GCallback.self),
                    Unmanaged.passRetained(segmentBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
                )
            }
            return
        }
        if kinds[handle.rawValue] == .tabView {
            // GtkNotebook reports tab changes via "switch-page" (page index arg).
            g_signal_connect_data(
                UnsafeMutableRawPointer(w), "switch-page",
                unsafeBitCast(gtkSwitchPageTrampoline, to: GCallback.self),
                Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
            )
            return
        }
        // GtkDropDown exposes its selection as the "selected" property.
        g_signal_connect_data(
            UnsafeMutableRawPointer(w), "notify::selected",
            unsafeBitCast(gtkSelectionChangedTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
    }
    /// Records and installs the date-change action; the actual signal binding depends on picker style.
    public func setDateChangeAction(for handle: NativeHandle, action: @escaping (Date) -> Void) {
        dateChangeActions[handle.rawValue] = action
        attachDateChangeAction(action, to: handle)
    }

    /// Binds `action` to the widget currently backing the picker. The graphical
    /// style emits `day-selected`; the compact style reports through its
    /// stepper (`stepDate`), which reads `dateChangeActions` directly.
    private func attachDateChangeAction(_ action: @escaping (Date) -> Void, to handle: NativeHandle) {
        let raw = handle.rawValue
        guard graphicalDatePickers.contains(raw), let calendar = graphicalCalendars[raw] else { return }
        // Wrap so our own select_day calls (setDateValue) don't report as user edits.
        let wrapped: (Date) -> Void = { [weak self] date in
            guard self?.suppressCalendarReport.contains(raw) != true else { return }
            action(date)
        }
        let box = DateActionBox(wrapped)
        g_signal_connect_data(
            UnsafeMutableRawPointer(calendar), "day-selected",
            unsafeBitCast(gtkDaySelectedTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
    }
    /// Wires a color button's `color-set` signal to `action`.
    public func setColorChangeAction(for handle: NativeHandle, action: @escaping (NSColor) -> Void) {
        guard let w = widget(handle) else { return }
        let box = ColorActionBox(action)
        g_signal_connect_data(
            UnsafeMutableRawPointer(w), "color-set",
            unsafeBitCast(gtkColorSetTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
    }
}

// MARK: - GObject signal glue
//
// GTK signal handlers must be bare C function pointers, so the Swift closure is
// boxed and passed as `user_data`; a destroy-notify releases the box when the
// signal is disconnected. These live at file scope because @convention(c)
// closures cannot capture context.

private final class ActionBox {
    let action: () -> Void
    init(_ action: @escaping () -> Void) { self.action = action }
}
private final class StringActionBox {
    let action: (String) -> Void
    init(_ action: @escaping (String) -> Void) { self.action = action }
}
private final class BoolActionBox {
    let action: (Bool) -> Void
    init(_ action: @escaping (Bool) -> Void) { self.action = action }
}
private final class DoubleActionBox {
    let action: (Double) -> Void
    init(_ action: @escaping (Double) -> Void) { self.action = action }
}
private final class IntActionBox {
    let action: (Int) -> Void
    init(_ action: @escaping (Int) -> Void) { self.action = action }
}
private final class DateActionBox {
    let action: (Date) -> Void
    init(_ action: @escaping (Date) -> Void) { self.action = action }
}
private final class SegmentBox {
    let index: Int
    let action: (Int) -> Void
    init(index: Int, action: @escaping (Int) -> Void) { self.index = index; self.action = action }
}
private final class WidgetBox {
    let widget: UnsafeMutablePointer<GtkWidget>
    init(widget: UnsafeMutablePointer<GtkWidget>) { self.widget = widget }
}
private final class DropBox {
    let onDrop: (String, Double, Double) -> Bool
    init(_ onDrop: @escaping (String, Double, Double) -> Bool) { self.onDrop = onDrop }
}
private final class DragProviderBox {
    let provider: () -> String?
    init(_ provider: @escaping () -> String?) { self.provider = provider }
}
private final class ScrollBox {
    let hadj: UnsafeMutablePointer<GtkAdjustment>
    let vadj: UnsafeMutablePointer<GtkAdjustment>
    let action: (Double, Double) -> Void
    init(hadj: UnsafeMutablePointer<GtkAdjustment>, vadj: UnsafeMutablePointer<GtkAdjustment>, action: @escaping (Double, Double) -> Void) {
        self.hadj = hadj; self.vadj = vadj; self.action = action
    }
}

private final class DrawBox {
    weak var backend: GTKNativeControlBackend?
    let view: UInt
    init(backend: GTKNativeControlBackend, view: UInt) {
        self.backend = backend
        self.view = view
    }
}

/// Cairo-backed graphics context: NSBezierPath ops map 1:1 onto the cairo_t.
final class CairoGraphicsContext: NativeGraphicsContext {
    private let cr: OpaquePointer
    /// Whether drawing happens in a top-left (y-down) space; affects arc winding.
    private let flipped: Bool
    private var fillColor = NSColor.black
    private var strokeColor = NSColor.black
    private var lineWidth = 1.0

    init(cr: OpaquePointer, flipped: Bool = false) { self.cr = cr; self.flipped = flipped }

    func setFillColor(_ color: NSColor) { fillColor = color }
    func setStrokeColor(_ color: NSColor) { strokeColor = color }
    func setLineWidth(_ width: Double) { lineWidth = width }
    func beginPath() { cairo_new_path(cr) }
    func move(toX x: Double, y: Double) { cairo_move_to(cr, x, y) }
    func line(toX x: Double, y: Double) { cairo_line_to(cr, x, y) }
    func curve(toX x: Double, y: Double, c1x: Double, c1y: Double, c2x: Double, c2y: Double) {
        cairo_curve_to(cr, c1x, c1y, c2x, c2y, x, y)
    }
    func addArc(centerX: Double, centerY: Double, radius: Double, startAngleRadians: Double, endAngleRadians: Double, clockwise: Bool) {
        // `cairo_arc` sweeps by increasing angle: counter-clockwise on screen in
        // a y-up (unflipped, axis-scaled) space, but clockwise in a y-down
        // (flipped/top-left) space. Pick the sweep so the visual winding matches
        // the requested `clockwise`, and prefer `cairo_arc` for a given winding
        // since a full 0…2π sweep stays a circle (cairo_arc_negative collapses it).
        let useForwardSweep = flipped ? clockwise : !clockwise
        if useForwardSweep {
            cairo_arc(cr, centerX, centerY, radius, startAngleRadians, endAngleRadians)
        } else {
            cairo_arc_negative(cr, centerX, centerY, radius, startAngleRadians, endAngleRadians)
        }
    }
    func closePath() { cairo_close_path(cr) }
    func fillPath() {
        cairo_set_source_rgba(cr, Double(fillColor.redComponent), Double(fillColor.greenComponent),
                              Double(fillColor.blueComponent), Double(fillColor.alphaComponent))
        cairo_fill(cr)
    }
    func strokePath() {
        cairo_set_source_rgba(cr, Double(strokeColor.redComponent), Double(strokeColor.greenComponent),
                              Double(strokeColor.blueComponent), Double(strokeColor.alphaComponent))
        cairo_set_line_width(cr, lineWidth)
        cairo_stroke(cr)
    }
    func saveState() { cairo_save(cr) }
    func restoreState() { cairo_restore(cr) }
    func clipToCurrentPath() { cairo_clip(cr) }

    func drawText(_ text: String, at point: NSPoint, font: NativeFontSpec?, color: NSColor) {
        cairo_save(cr)
        cairo_select_font_face(cr, font?.family == nil ? "Sans" : font!.family!,
                               (font?.italic ?? false) ? CAIRO_FONT_SLANT_ITALIC : CAIRO_FONT_SLANT_NORMAL,
                               (font?.bold ?? false) ? CAIRO_FONT_WEIGHT_BOLD : CAIRO_FONT_WEIGHT_NORMAL)
        cairo_set_font_size(cr, font?.size ?? 13)
        cairo_set_source_rgba(cr, Double(color.redComponent), Double(color.greenComponent),
                              Double(color.blueComponent), Double(color.alphaComponent))
        // AppKit's draw(at:) places the text's TOP-left at the point; cairo's
        // baseline sits at the pen, so drop by the font ascent.
        var extents = cairo_font_extents_t()
        cairo_font_extents(cr, &extents)
        cairo_move_to(cr, Double(point.x), Double(point.y) + extents.ascent)
        cairo_show_text(cr, text)
        cairo_new_path(cr)   // show_text leaves the text path pending
        cairo_restore(cr)
    }

    func drawImage(atPath path: String, inRect rect: NSRect) {
        guard rect.width > 0, rect.height > 0,
              let pixbuf = gdk_pixbuf_new_from_file_at_scale(
                path, Int32(rect.width), Int32(rect.height), gboolean(0), nil) else { return }
        cairo_save(cr)
        gdk_cairo_set_source_pixbuf(cr, pixbuf, Double(rect.minX), Double(rect.minY))
        cairo_rectangle(cr, Double(rect.minX), Double(rect.minY), Double(rect.width), Double(rect.height))
        cairo_fill(cr)
        cairo_restore(cr)
        g_object_unref(UnsafeMutableRawPointer(pixbuf))
    }

    /// Applies the stops to a cairo pattern and fills `rect` with it.
    private func fill(rect: NSRect, pattern: OpaquePointer, stops: [NativeGradientStop]) {
        for stop in stops {
            cairo_pattern_add_color_stop_rgba(pattern, Double(stop.location),
                Double(stop.color.redComponent), Double(stop.color.greenComponent),
                Double(stop.color.blueComponent), Double(stop.color.alphaComponent))
        }
        cairo_set_source(cr, pattern)
        cairo_rectangle(cr, Double(rect.minX), Double(rect.minY), Double(rect.width), Double(rect.height))
        cairo_fill(cr)
        cairo_pattern_destroy(pattern)
    }
    func fillLinearGradient(_ stops: [NativeGradientStop], inRect rect: NSRect, angleDegrees: Double) {
        // Gradient axis through the rect center; half-length spans the rect's
        // projection so 0° fills across the width and 90° up the height.
        let radians = angleDegrees * .pi / 180
        let dx = cos(radians), dy = sin(radians)
        let cx = Double(rect.midX), cy = Double(rect.midY)
        let half = abs(dx) * Double(rect.width) / 2 + abs(dy) * Double(rect.height) / 2
        let pattern = cairo_pattern_create_linear(cx - dx * half, cy - dy * half, cx + dx * half, cy + dy * half)!
        fill(rect: rect, pattern: pattern, stops: stops)
    }
    func fillRadialGradient(_ stops: [NativeGradientStop], inRect rect: NSRect) {
        let cx = Double(rect.midX), cy = Double(rect.midY)
        let radius = max(Double(rect.width), Double(rect.height)) / 2
        let pattern = cairo_pattern_create_radial(cx, cy, 0, cx, cy, radius)!
        fill(rect: rect, pattern: pattern, stops: stops)
    }
}

/// `GtkDrawingAreaDrawFunc` — flips into AppKit's bottom-left space and
/// dispatches to the view's Swift draw handler.
private let gtkDrawFunc: @convention(c) (UnsafeMutablePointer<GtkDrawingArea>?, OpaquePointer?, Int32, Int32, gpointer?) -> Void = { _, cr, width, height, userData in
    guard let cr, let userData else { return }
    let box = Unmanaged<DrawBox>.fromOpaque(userData).takeUnretainedValue()
    cairo_save(cr)
    // A flipped view (top-left origin, e.g. the WinChocolate demo) draws in
    // GTK's native space directly; an unflipped AppKit view (bottom-left, +Y up)
    // needs the axis flip.
    let flipped = box.backend?.isViewFlipped(box.view) ?? false
    // `NSScrollView.magnification` grew this view's allocation by `zoom`; we
    // apply the same factor to Cairo so the Swift draw code still authors in
    // its natural coordinate space.
    let zoom = box.backend?.viewMagnification(box.view) ?? 1
    let context = CairoGraphicsContext(cr: cr, flipped: flipped)
    if !flipped {
        cairo_translate(cr, 0, Double(height))
        cairo_scale(cr, 1, -1)
    }
    if zoom != 1 { cairo_scale(cr, zoom, zoom) }
    box.backend?.dispatchDraw(view: box.view, context: context,
                              width: Double(width) / zoom, height: Double(height) / zoom)
    cairo_restore(cr)
}

/// Shared state for one modal file-dialog run.
private final class FileDialogState {
    let loop: OpaquePointer?
    let open: Bool          // open vs save (selects the *_finish call)
    var path: String?
    init(loop: OpaquePointer?, open: Bool) { self.loop = loop; self.open = open }
}

/// `GAsyncReadyCallback` for GtkFileDialog open/save — extracts the chosen
/// file's path (nil on cancel) and quits the nested loop.
private let fileDialogFinishedCallback: @convention(c) (UnsafeMutableRawPointer?, OpaquePointer?, gpointer?) -> Void = { source, result, data in
    _ = source
    _ = result
    guard let data else { return }
    let state = Unmanaged<FileDialogState>.fromOpaque(data).takeRetainedValue()
    g_main_loop_quit(state.loop)
}

/// Shared state for one modal alert run: the nested loop and the response.
private final class AlertState {
    let loop: OpaquePointer?
    var response = 0
    init(loop: OpaquePointer?) { self.loop = loop }
}
/// `GtkWindow::close-request` on an alert — treat closing as a dismissal so the
/// nested loop ends and `runAlert` returns.
///
/// Returns TRUE (handled), which STOPS GTK's default close. That matters:
/// `runAlert` destroys the alert itself once its loop ends, so letting GTK also
/// destroy it here means the window is destroyed twice — an X error that takes
/// the whole app down.
private let gtkAlertCloseTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> gboolean = { _, userData in
    guard let userData else { return gboolean(0) }
    let box = Unmanaged<AlertButtonBox>.fromOpaque(userData).takeUnretainedValue()
    box.state.response = box.index
    if let loop = box.state.loop, g_main_loop_is_running(loop) != 0 {
        g_main_loop_quit(loop)
    }
    return gboolean(1)
}

private final class AlertButtonBox {
    let index: Int
    let state: AlertState
    init(index: Int, state: AlertState) { self.index = index; self.state = state }
}
private final class ColorActionBox {
    let action: (NSColor) -> Void
    init(_ action: @escaping (NSColor) -> Void) { self.action = action }
}

/// Handler for `GtkButton::clicked` — `void (*)(GtkButton*, gpointer)`.
private let gtkActionTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { _, userData in
    guard let userData else { return }
    Unmanaged<ActionBox>.fromOpaque(userData).takeUnretainedValue().action()
}

/// Handler for `GtkWindow::close-request` — returns gboolean (false = allow close).
private let gtkCloseRequestTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> gboolean = { _, userData in
    if let userData {
        Unmanaged<ActionBox>.fromOpaque(userData).takeUnretainedValue().action()
    }
    // TRUE: the close is OURS. Returning FALSE would let GTK destroy the
    // window after the callback — which is how closing the demo's floating
    // panel crashed re-presenting it (the NSWindow was reused over a destroyed
    // GtkWindow). The Swift side hides or terminates instead.
    return gboolean(1)
}

/// Handler for `GtkEditable::changed` — reads the new text off the widget.
private let gtkTextChangedTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { editable, userData in
    guard let editable, let userData else { return }
    let cText = gtk_editable_get_text(OpaquePointer(editable))
    let text = cText.map { String(cString: $0) } ?? ""
    Unmanaged<StringActionBox>.fromOpaque(userData).takeUnretainedValue().action(text)
}

/// Handler for `GtkCheckButton::toggled` — reads the new active state.
private let gtkToggledTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { button, userData in
    guard let button, let userData else { return }
    let active = gtk_check_button_get_active(UnsafeMutablePointer<GtkCheckButton>(OpaquePointer(button))) != 0
    Unmanaged<BoolActionBox>.fromOpaque(userData).takeUnretainedValue().action(active)
}

/// Handler for `GtkRange::value-changed` — reads the new slider value.
private let gtkValueChangedTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { range, userData in
    guard let range, let userData else { return }
    let value = gtk_range_get_value(UnsafeMutablePointer<GtkRange>(OpaquePointer(range)))
    Unmanaged<DoubleActionBox>.fromOpaque(userData).takeUnretainedValue().action(value)
}

/// Handler for `GtkSpinButton::value-changed` — reads the spin button's value.
private let gtkSpinValueChangedTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { spin, userData in
    guard let spin, let userData else { return }
    let value = gtk_spin_button_get_value(OpaquePointer(spin))
    Unmanaged<DoubleActionBox>.fromOpaque(userData).takeUnretainedValue().action(value)
}

/// Handler for `GtkTextBuffer::changed` — reads the whole buffer text.
private let gtkTextBufferChangedTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { buffer, userData in
    guard let buffer, let userData else { return }
    var start = GtkTextIter()
    var end = GtkTextIter()
    let buf = UnsafeMutablePointer<GtkTextBuffer>(OpaquePointer(buffer))   // GtkTextBuffer is nominal
    gtk_text_buffer_get_bounds(buf, &start, &end)
    let cText = gtk_text_buffer_get_text(buf, &start, &end, gboolean(0))
    let text = cText.map { String(cString: $0) } ?? ""
    if let cText { g_free(cText) }
    Unmanaged<StringActionBox>.fromOpaque(userData).takeUnretainedValue().action(text)
}

/// Handler for `GtkDropDown::notify::selected` — a GObject notify handler, so it
/// takes an extra GParamSpec argument before the user data.
private let gtkSelectionChangedTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, gpointer?) -> Void = { dropdown, _, userData in
    guard let dropdown, let userData else { return }
    let index = Int(gtk_drop_down_get_selected(OpaquePointer(dropdown)))
    Unmanaged<IntActionBox>.fromOpaque(userData).takeUnretainedValue().action(index)
}

private final class TableColumnBox {
    weak var backend: GTKNativeControlBackend?
    let table: UInt
    let column: Int
    let editable: Bool
    init(backend: GTKNativeControlBackend, table: UInt, column: Int, editable: Bool = false) {
        self.backend = backend
        self.table = table
        self.column = column
        self.editable = editable
    }
}

private final class OutlineBox {
    weak var backend: GTKNativeControlBackend?
    var outline: UInt = 0   // assigned right after the handle is allocated
    init(backend: GTKNativeControlBackend) { self.backend = backend }
}

/// Carries a customization-palette row's identifier + toggle closure.
private final class ToolbarToggleBox {
    let id: String
    let action: (String, Bool) -> Void
    init(id: String, action: @escaping (String, Bool) -> Void) {
        self.id = id
        self.action = action
    }
}

/// Handler for a customization-palette checkbox `toggled` — reports (id, on).
/// Carries a repeating timer's block to its g_timeout callback.
private final class TimerBox {
    let block: () -> Void
    let repeats: Bool
    init(block: @escaping () -> Void, repeats: Bool) {
        self.block = block
        self.repeats = repeats
    }
}

/// Carries a flow-box child to its capture-phase select-on-click gesture.
private final class FlowChildBox {
    let flow: OpaquePointer
    let child: OpaquePointer
    init(flow: OpaquePointer, child: OpaquePointer) {
        self.flow = flow
        self.child = child
    }
}

/// Capture-phase `pressed` on a flow-box child: select it, let the event
/// continue to the hosted control.
private let gtkFlowChildSelectTrampoline: @convention(c) (UnsafeMutableRawPointer?, gint, Double, Double, gpointer?) -> Void = { _, _, _, _, userData in
    guard let userData else { return }
    let box = Unmanaged<FlowChildBox>.fromOpaque(userData).takeUnretainedValue()
    gtk_flow_box_select_child(box.flow, UnsafeMutablePointer<GtkFlowBoxChild>(box.child))
}

/// Carries a custom view's mouse-event handler.
private final class MouseBox {
    let handler: (NativeMouseEvent) -> Void
    init(_ handler: @escaping (NativeMouseEvent) -> Void) { self.handler = handler }
}
private final class MouseClickBox {
    let handler: (NativeMouseEvent) -> Void
    let rightButton: Bool
    init(handler: @escaping (NativeMouseEvent) -> Void, rightButton: Bool) {
        self.handler = handler
        self.rightButton = rightButton
    }
}

/// `GtkEventControllerMotion::enter` — pointer entered the view.
private let gtkMotionEnterTrampoline: @convention(c) (UnsafeMutableRawPointer?, Double, Double, gpointer?) -> Void = { _, x, y, userData in
    guard let userData else { return }
    Unmanaged<MouseBox>.fromOpaque(userData).takeUnretainedValue().handler(.entered(x: x, y: y))
}
/// `GtkEventControllerMotion::leave` — pointer left the view.
private let gtkMotionLeaveTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { _, userData in
    guard let userData else { return }
    Unmanaged<MouseBox>.fromOpaque(userData).takeUnretainedValue().handler(.exited)
}
/// `GtkGestureClick::pressed` on a custom view — n_press is the click count.
private let gtkMousePressTrampoline: @convention(c) (UnsafeMutableRawPointer?, gint, Double, Double, gpointer?) -> Void = { _, nPress, x, y, userData in
    guard let userData else { return }
    let box = Unmanaged<MouseClickBox>.fromOpaque(userData).takeUnretainedValue()
    box.handler(.down(x: x, y: y, clickCount: Int(nPress), rightButton: box.rightButton))
}
/// `GtkEventControllerScroll::scroll` — dy>0 means scroll down in GTK, which is
/// AppKit's negative `scrollingDeltaY`, so flip the sign. Returns FALSE (event
/// NOT consumed): this controller sits on EVERY custom view, including the
/// document views inside NSScrollViews, so consuming here would kill scroll-view
/// panning app-wide. A view that reacts to the wheel (the demo's canvas) still
/// gets its callback; letting the event propagate just also lets an enclosing
/// scroller scroll, which is AppKit's behavior for a non-overriding view.
private let gtkScrollTrampoline: @convention(c) (UnsafeMutableRawPointer?, Double, Double, gpointer?) -> gboolean = { _, dx, dy, userData in
    guard let userData else { return gboolean(0) }
    Unmanaged<MouseBox>.fromOpaque(userData).takeUnretainedValue().handler(.scroll(deltaX: -dx, deltaY: -dy))
    return gboolean(0)
}

/// Carries a view's click action to its gesture handler.
private final class ClickBox {
    let action: (Double, Double) -> Void
    init(_ action: @escaping (Double, Double) -> Void) { self.action = action }
}

/// `GtkGestureClick::pressed` on a plain view (image views) — reports the point.
private let gtkViewClickTrampoline: @convention(c) (UnsafeMutableRawPointer?, gint, Double, Double, gpointer?) -> Void = { _, _, x, y, userData in
    guard let userData else { return }
    Unmanaged<ClickBox>.fromOpaque(userData).takeUnretainedValue().action(x, y)
}

/// `GtkFlowBox::selected-children-changed` — a collection selection.
private let gtkFlowSelectionTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { _, userData in
    guard let userData else { return }
    let box = Unmanaged<CollectionBox>.fromOpaque(userData).takeUnretainedValue()
    box.backend?.reportCollectionSelection(box.collection, base: box.base)
}

/// Carries an editable level indicator's backend + handle to its click gesture.
private final class LevelClickBox {
    weak var backend: GTKNativeControlBackend?
    let raw: UInt
    init(backend: GTKNativeControlBackend, raw: UInt) {
        self.backend = backend
        self.raw = raw
    }
}

/// `GtkDrawingArea` draw func for a rating indicator's stars.
private let gtkStarDrawFunc: @convention(c) (UnsafeMutablePointer<GtkDrawingArea>?, OpaquePointer?, Int32, Int32, gpointer?) -> Void = { _, cr, width, height, userData in
    guard let cr, let userData else { return }
    let box = Unmanaged<LevelClickBox>.fromOpaque(userData).takeUnretainedValue()
    box.backend?.drawStars(box.raw, cr: cr, width: Double(width), height: Double(height))
}

/// Carries a slider's backend + handle + action, for tick snapping on change.
private final class SliderValueBox {
    weak var backend: GTKNativeControlBackend?
    let raw: UInt
    let action: (Double) -> Void
    init(backend: GTKNativeControlBackend, raw: UInt, action: @escaping (Double) -> Void) {
        self.backend = backend
        self.raw = raw
        self.action = action
    }
}

/// `GtkRange::value-changed` on a slider — snaps to ticks, then reports.
private let gtkSliderValueChangedTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { _, userData in
    guard let userData else { return }
    let box = Unmanaged<SliderValueBox>.fromOpaque(userData).takeUnretainedValue()
    box.backend?.reportSliderValue(box.raw, action: box.action)
}

/// Carries a print job's backend + view handle + natural size to the draw-page handler.
private final class PrintBox {
    weak var backend: GTKNativeControlBackend?
    let view: UInt
    let width: Double
    let height: Double
    init(backend: GTKNativeControlBackend, view: UInt, width: Double, height: Double) {
        self.backend = backend; self.view = view; self.width = width; self.height = height
    }
}

/// `GtkPrintOperation::draw-page` — `void (*)(GtkPrintOperation*, GtkPrintContext*, gint, gpointer)`.
private let gtkPrintDrawPageTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, gint, gpointer?) -> Void = { _, printContext, _, userData in
    guard let printContext, let userData else { return }
    let box = Unmanaged<PrintBox>.fromOpaque(userData).takeUnretainedValue()
    box.backend?.drawPrintPage(view: box.view, printContext: OpaquePointer(printContext),
                               width: box.width, height: box.height)
}

/// Carries a spinner's backend + handle to its draw func and rotation timeout.
private final class SpinnerDrawBox {
    weak var backend: GTKNativeControlBackend?
    let raw: UInt
    init(backend: GTKNativeControlBackend, raw: UInt) {
        self.backend = backend
        self.raw = raw
    }
}

/// `GtkDrawingArea` draw func for a spinning progress indicator.
private let gtkSpinnerDrawFunc: @convention(c) (UnsafeMutablePointer<GtkDrawingArea>?, OpaquePointer?, Int32, Int32, gpointer?) -> Void = { _, cr, width, height, userData in
    guard let cr, let userData else { return }
    let box = Unmanaged<SpinnerDrawBox>.fromOpaque(userData).takeUnretainedValue()
    box.backend?.drawSpinner(box.raw, cr: cr, width: Double(width), height: Double(height))
}

/// `GtkGestureClick::pressed` on a rating indicator.
private let gtkLevelClickTrampoline: @convention(c) (UnsafeMutableRawPointer?, gint, Double, Double, gpointer?) -> Void = { _, _, x, _, userData in
    guard let userData else { return }
    let box = Unmanaged<LevelClickBox>.fromOpaque(userData).takeUnretainedValue()
    box.backend?.reportLevelClick(box.raw, x: x)
}

/// Carries a standalone scroller's backend + handle to its adjustment handler.
private final class ScrollerBox {
    weak var backend: GTKNativeControlBackend?
    let raw: UInt
    init(backend: GTKNativeControlBackend, raw: UInt) {
        self.backend = backend
        self.raw = raw
    }
}

/// `GtkAdjustment::value-changed` for a standalone scroller.
private let gtkScrollerChangedTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { _, userData in
    guard let userData else { return }
    let box = Unmanaged<ScrollerBox>.fromOpaque(userData).takeUnretainedValue()
    box.backend?.reportScroller(box.raw)
}

/// Carries a date picker's backend + handle to its cursor/key handlers.
private final class DateCursorBox {
    weak var backend: GTKNativeControlBackend?
    let raw: UInt
    init(backend: GTKNativeControlBackend, raw: UInt) {
        self.backend = backend
        self.raw = raw
    }
}

/// `GtkEditable::notify::cursor-position` on a compact date field.
private let gtkDateCursorTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, gpointer?) -> Void = { _, _, userData in
    guard let userData else { return }
    let box = Unmanaged<DateCursorBox>.fromOpaque(userData).takeUnretainedValue()
    box.backend?.reportDateCursor(box.raw)
}

/// `GtkEventControllerKey::key-pressed` on a compact date field.
private let gtkDateKeyTrampoline: @convention(c) (UnsafeMutableRawPointer?, guint, guint, GdkModifierType, gpointer?) -> gboolean = { _, keyval, _, _, userData in
    guard let userData else { return gboolean(0) }
    let box = Unmanaged<DateCursorBox>.fromOpaque(userData).takeUnretainedValue()
    return gboolean(box.backend?.reportDateKey(box.raw, keyval: keyval) == true ? 1 : 0)
}

/// Carries a drag source's string payload to the `prepare` handler.
private final class DragPayloadBox {
    let payload: String
    init(_ payload: String) { self.payload = payload }
}

/// Carries a drop target's handler; returns whether the drop was accepted.
private final class DropHandlerBox {
    let handle: (String, Double, Double) -> Bool
    init(_ handle: @escaping (String, Double, Double) -> Bool) { self.handle = handle }
}

/// Carries the display-mode dropdown and its change handler.
private final class DropDownBox {
    let dropdown: OpaquePointer
    let onChange: (Int) -> Void
    init(dropdown: OpaquePointer, onChange: @escaping (Int) -> Void) {
        self.dropdown = dropdown
        self.onChange = onChange
    }
}

/// `GtkDragSource::prepare` — builds a string content provider from the box.
private let gtkPaletteDragPrepareTrampoline: @convention(c) (UnsafeMutableRawPointer?, Double, Double, gpointer?) -> OpaquePointer? = { _, _, _, userData in
    guard let userData else { return nil }
    let box = Unmanaged<DragPayloadBox>.fromOpaque(userData).takeUnretainedValue()
    var value = GValue()
    _ = g_value_init(&value, GType(16 << 2))   // G_TYPE_STRING
    g_value_set_string(&value, box.payload)
    let provider = gdk_content_provider_new_for_value(&value)
    g_value_unset(&value)
    return OpaquePointer(provider)
}

/// `GtkDropTarget::drop` — reads the string payload and dispatches.
private let gtkPaletteDropTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<GValue>?, Double, Double, gpointer?) -> gboolean = { _, value, x, y, userData in
    guard let value, let userData, let raw = g_value_get_string(value) else { return gboolean(0) }
    let box = Unmanaged<DropHandlerBox>.fromOpaque(userData).takeUnretainedValue()
    return gboolean(box.handle(String(cString: raw), x, y) ? 1 : 0)
}

/// `GtkDropDown::notify::selected` — reports the new index.
private let gtkDropDownSelectedTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, gpointer?) -> Void = { _, _, userData in
    guard let userData else { return }
    let box = Unmanaged<DropDownBox>.fromOpaque(userData).takeUnretainedValue()
    box.onChange(Int(gtk_drop_down_get_selected(box.dropdown)))
}

/// Palette tiles are GtkToggleButtons: pressed = present in the toolbar.
private let gtkPaletteTileTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { button, userData in
    guard let button, let userData else { return }
    let active = gtk_toggle_button_get_active(UnsafeMutablePointer<GtkToggleButton>(OpaquePointer(button))) != 0
    let box = Unmanaged<ToolbarToggleBox>.fromOpaque(userData).takeUnretainedValue()
    box.action(box.id, active)
}

private let gtkToolbarToggleTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { button, userData in
    guard let button, let userData else { return }
    let active = gtk_check_button_get_active(UnsafeMutablePointer<GtkCheckButton>(OpaquePointer(button))) != 0
    let box = Unmanaged<ToolbarToggleBox>.fromOpaque(userData).takeUnretainedValue()
    box.action(box.id, active)
}

/// Carries a table's identity to the sorter-changed and row-activate handlers.
private final class TableSignalBox {
    weak var backend: GTKNativeControlBackend?
    let table: UInt
    init(backend: GTKNativeControlBackend, table: UInt) {
        self.backend = backend
        self.table = table
    }
}

/// Handler for the column view's `GtkColumnViewSorter::changed` — a header was
/// clicked; report the primary sort column + order to the Swift side.
private let gtkSorterChangedTrampoline: @convention(c) (UnsafeMutableRawPointer?, guint, gpointer?) -> Void = { sorter, _, userData in
    guard let sorter, let userData else { return }
    let box = Unmanaged<TableSignalBox>.fromOpaque(userData).takeUnretainedValue()
    box.backend?.handleSorterChanged(table: box.table, sorter: OpaquePointer(sorter))
}

/// Handler for `GtkColumnView::activate` — a row was double-clicked / Entered.
private let gtkRowActivateTrampoline: @convention(c) (UnsafeMutableRawPointer?, guint, gpointer?) -> Void = { _, position, userData in
    guard let userData else { return }
    let box = Unmanaged<TableSignalBox>.fromOpaque(userData).takeUnretainedValue()
    box.backend?.handleRowActivate(table: box.table, position: Int(position))
}
private final class OutlineColumnBox {
    weak var backend: GTKNativeControlBackend?
    let outline: UInt
    let column: Int
    init(backend: GTKNativeControlBackend, outline: UInt, column: Int) {
        self.backend = backend
        self.outline = outline
        self.column = column
    }
}

private final class CollectionBox {
    weak var backend: GTKNativeControlBackend?
    let collection: UInt
    /// Flat index of this section's first item, for mapping selection back.
    let base: Int
    init(backend: GTKNativeControlBackend, collection: UInt, base: Int = 0) {
        self.backend = backend
        self.collection = collection
        self.base = base
    }
}



/// `GtkTreeListModel` create-func — returns a child path list, or nil for leaves.
private let outlineCreateChildModelFunc: @convention(c) (gpointer?, gpointer?) -> OpaquePointer? = { item, userData in
    guard let item, let userData else { return nil }
    let box = Unmanaged<OutlineBox>.fromOpaque(userData).takeUnretainedValue()
    let path = String(cString: gtk_string_object_get_string(OpaquePointer(item)))
    let count = box.backend?.outlineChildCount(outline: box.outline, path: path) ?? 0
    guard count > 0 else { return nil }
    let children = gtk_string_list_new(nil)!
    for index in 0..<count {
        gtk_string_list_append(children, "\(path).\(index)")
    }
    return children
}

/// Outline factory `setup` — column 0 gets a tree expander wrapping the label.
private let gtkOutlineCellSetupTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, gpointer?) -> Void = { _, item, userData in
    guard let item, let userData else { return }
    let box = Unmanaged<OutlineColumnBox>.fromOpaque(userData).takeUnretainedValue()
    let label = gtk_label_new("")!
    gtk_label_set_xalign(OpaquePointer(label), 0)
    gtk_widget_set_margin_start(label, 4)
    gtk_widget_set_margin_end(label, 8)
    if box.column == 0 {
        let expander = gtk_tree_expander_new()!
        gtk_tree_expander_set_child(OpaquePointer(expander), label)
        gtk_list_item_set_child(OpaquePointer(item), expander)
    } else {
        gtk_list_item_set_child(OpaquePointer(item), label)
    }
}

/// Outline factory `bind` — unwraps the tree row, wires the expander (col 0),
/// and fills the label from the path-based provider.
private let gtkOutlineCellBindTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, gpointer?) -> Void = { _, item, userData in
    guard let item, let userData else { return }
    let box = Unmanaged<OutlineColumnBox>.fromOpaque(userData).takeUnretainedValue()
    guard let rowObject = gtk_list_item_get_item(OpaquePointer(item)) else { return }
    guard let inner = gtk_tree_list_row_get_item(OpaquePointer(rowObject)) else { return }
    let path = String(cString: gtk_string_object_get_string(OpaquePointer(inner)))
    g_object_unref(inner)   // get_item returns a strong reference
    let text = box.backend?.outlineCellText(outline: box.outline, path: path, column: box.column) ?? ""
    guard let child = gtk_list_item_get_child(OpaquePointer(item)) else { return }
    if box.column == 0 {
        gtk_tree_expander_set_list_row(OpaquePointer(child), OpaquePointer(rowObject))
        if let label = gtk_tree_expander_get_child(OpaquePointer(child)) {
            gtk_label_set_text(OpaquePointer(label), text)
        }
    } else {
        gtk_label_set_text(OpaquePointer(child), text)
    }
}

/// Factory `setup` — gives each cell a left-aligned label.
private let gtkTableCellSetupTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, gpointer?) -> Void = { _, item, userData in
    guard let item else { return }
    let box = userData.map { Unmanaged<TableColumnBox>.fromOpaque($0).takeUnretainedValue() }
    if box?.editable == true {
        // A GtkEditableLabel shows text and enters edit mode on double-click —
        // exactly AppKit's editable cell. On commit (Enter / focus-out) the
        // "editing" property drops to false; that is when we push the value back.
        let editable = gtk_editable_label_new("")!
        gtk_widget_set_margin_start(editable, 8)
        gtk_widget_set_margin_end(editable, 8)
        if let box {
            let commit = TableColumnBox(backend: box.backend!, table: box.table, column: box.column, editable: true)
            g_signal_connect_data(
                UnsafeMutableRawPointer(editable), "notify::editing",
                unsafeBitCast(gtkCellEditingChangedTrampoline, to: GCallback.self),
                Unmanaged.passRetained(commit).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
            )
        }
        gtk_list_item_set_child(OpaquePointer(item), editable)
    } else {
        let label = gtk_label_new("")!
        gtk_label_set_xalign(OpaquePointer(label), 0)
        gtk_widget_set_margin_start(label, 8)
        gtk_widget_set_margin_end(label, 8)
        gtk_list_item_set_child(OpaquePointer(item), label)
    }
}

/// Factory `bind` — fills the cell's label from the table's cell provider.
private let gtkTableCellBindTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, gpointer?) -> Void = { _, item, userData in
    guard let item, let userData else { return }
    let box = Unmanaged<TableColumnBox>.fromOpaque(userData).takeUnretainedValue()
    let row = Int(gtk_list_item_get_position(OpaquePointer(item)))
    guard let child = gtk_list_item_get_child(OpaquePointer(item)) else { return }
    let text = box.backend?.tableCellText(table: box.table, row: row, column: box.column) ?? ""
    if box.editable {
        // Stamp the current row on the reused widget so the commit handler knows
        // which model row it maps to (row+1 so a valid row is never a null pointer).
        g_object_set_data(UnsafeMutableRawPointer(child).assumingMemoryBound(to: GObject.self),
                          "lc-row", UnsafeMutableRawPointer(bitPattern: row + 1))
        gtk_editable_set_text(OpaquePointer(child), text)
    } else {
        gtk_label_set_text(OpaquePointer(child), text)
    }
}
/// `GtkEditableLabel::notify::editing` — on leaving edit mode, push the new text
/// back to the data source (AppKit's `setObjectValue`).
private let gtkCellEditingChangedTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, gpointer?) -> Void = { label, _, userData in
    guard let label, let userData else { return }
    let box = Unmanaged<TableColumnBox>.fromOpaque(userData).takeUnretainedValue()
    // Only fire once, when editing FINISHES (property went to false).
    guard gtk_editable_label_get_editing(OpaquePointer(label)) == 0 else { return }
    let text = String(cString: gtk_editable_get_text(OpaquePointer(label)))
    let rowData = g_object_get_data(label.assumingMemoryBound(to: GObject.self), "lc-row")
    let row = rowData.map { Int(bitPattern: $0) - 1 } ?? -1
    guard row >= 0 else { return }
    box.backend?.reportCellEdit(table: box.table, row: row, column: box.column, text: text)
}

/// `GtkSingleSelection::notify::selected` — passes the selected row (−1 if none).
private let gtkTableSelectionChangedTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, gpointer?) -> Void = { selection, _, userData in
    guard let selection, let userData else { return }
    let selected = gtk_single_selection_get_selected(OpaquePointer(selection))
    let row = selected == guint.max ? -1 : Int(selected)   // guint.max = GTK_INVALID_LIST_POSITION
    Unmanaged<IntActionBox>.fromOpaque(userData).takeUnretainedValue().action(row)
}

/// Actual popover widget types. Matching must be exact: `GtkPopoverMenuBar`
/// and `GtkPopoverMenuBarItem` contain "Popover" but are NOT popovers, and
/// popping them down trips a Gtk-CRITICAL assertion on every click.
private let popoverTypeNames: Set<String> = ["GtkPopover", "GtkPopoverMenu", "GtkTreePopover"]

/// Menu-bar subtrees the dismissal walk must NOT descend into. The menu bar
/// owns a `GtkPopoverMenu` for the open menu; GTK manages its lifetime (open on
/// click, close on Escape / activation / clicking another top-level item). If
/// our fallback reaches in and pops it down, the menu closes the instant it
/// opens — i.e. menus stop working. So skip these subtrees entirely; the
/// fallback only needs to reach the *standalone* popovers below (dropdown and
/// combo-box lists), which are not inside the menu bar.
private let menuBarTypeNames: Set<String> = ["GtkPopoverMenuBar", "GtkPopoverMenuBarItem"]

/// Recursively pops down any *mapped* standalone popover in `widget`'s subtree
/// (dropdown lists, combo popups), skipping menu-bar menus.
private func popdownVisiblePopovers(under widget: UnsafeMutablePointer<GtkWidget>) {
    var child = gtk_widget_get_first_child(widget)
    while let c = child {
        let typeName = String(cString: g_type_name_from_instance(
            UnsafeMutableRawPointer(c).assumingMemoryBound(to: GTypeInstance.self)))
        if popoverTypeNames.contains(typeName) {
            if gtk_widget_get_mapped(c) != 0 {
                gtk_popover_popdown(UnsafeMutablePointer<GtkPopover>(OpaquePointer(c)))
            }
        } else if !menuBarTypeNames.contains(typeName) {
            popdownVisiblePopovers(under: c)
        }
        child = gtk_widget_get_next_sibling(c)
    }
}

/// Handler for the window's capture-phase `GtkGestureClick::pressed` — the
/// outside-click popover dismissal fallback for non-composited displays. Runs
/// before the click lands, so it dismisses a previously-open popover without
/// ever closing one that this same click is about to open.
private let gtkDismissPopoversTrampoline: @convention(c) (UnsafeMutableRawPointer?, gint, gdouble, gdouble, gpointer?) -> Void = { _, _, _, _, userData in
    guard let userData else { return }
    let box = Unmanaged<WidgetBox>.fromOpaque(userData).takeUnretainedValue()
    popdownVisiblePopovers(under: box.widget)
}

/// Handler for an alert button's `clicked` — records the response and quits the
/// alert's nested main loop, unblocking `runAlert`.
private let gtkAlertButtonTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { _, userData in
    guard let userData else { return }
    let box = Unmanaged<AlertButtonBox>.fromOpaque(userData).takeUnretainedValue()
    box.state.response = box.index
    g_main_loop_quit(box.state.loop)
}

/// Handler for a segment's `GtkToggleButton::toggled` — fires only when the
/// segment becomes active, passing its index.
private let gtkSegmentToggledTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { button, userData in
    guard let button, let userData else { return }
    guard gtk_toggle_button_get_active(UnsafeMutablePointer<GtkToggleButton>(OpaquePointer(button))) != 0 else { return }
    let box = Unmanaged<SegmentBox>.fromOpaque(userData).takeUnretainedValue()
    box.action(box.index)
}

/// Handler for `GSimpleAction::activate` — `void (*)(GSimpleAction*, GVariant*,
/// gpointer)`; runs a menu item's action.
private let gtkMenuActivateTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, gpointer?) -> Void = { _, _, userData in
    guard let userData else { return }
    Unmanaged<ActionBox>.fromOpaque(userData).takeUnretainedValue().action()
}

/// Handler for `GtkNotebook::switch-page` — `void (*)(GtkNotebook*, GtkWidget*,
/// guint page_num, gpointer)`; passes the new page index.
private let gtkSwitchPageTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, guint, gpointer?) -> Void = { _, _, pageNum, userData in
    guard let userData else { return }
    Unmanaged<IntActionBox>.fromOpaque(userData).takeUnretainedValue().action(Int(pageNum))
}

/// Handler for `GtkCalendar::day-selected` — reads the calendar's date.
private let gtkDaySelectedTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { calendar, userData in
    guard let calendar, let userData else { return }
    guard let gdt = gtk_calendar_get_date(OpaquePointer(calendar)) else { return }
    let date = Date(timeIntervalSince1970: TimeInterval(g_date_time_to_unix(gdt)))
    g_date_time_unref(gdt)
    Unmanaged<DateActionBox>.fromOpaque(userData).takeUnretainedValue().action(date)
}

/// Handler for `GtkColorButton::color-set` — reads the chosen RGBA.
private let gtkColorSetTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { button, userData in
    guard let button, let userData else { return }
    var rgba = GdkRGBA(red: 0, green: 0, blue: 0, alpha: 0)
    lc_color_chooser_get_rgba(UnsafeMutablePointer<GtkWidget>(OpaquePointer(button)), &rgba)
    let color = NSColor(
        red: CGFloat(rgba.red), green: CGFloat(rgba.green),
        blue: CGFloat(rgba.blue), alpha: CGFloat(rgba.alpha)
    )
    Unmanaged<ColorActionBox>.fromOpaque(userData).takeUnretainedValue().action(color)
}

/// Releases a boxed closure of any box type when GLib tears the connection down.
/// Handler for `GtkDropTarget::drop` — extracts the dropped string and flips
/// the drop point into AppKit's bottom-left coordinates. Returns whether the
/// destination accepted the drop.
private let gtkDropTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<GValue>?, Double, Double, gpointer?) -> gboolean = { target, value, x, y, userData in
    guard let value, let userData else { return gboolean(0) }
    let cString = g_value_get_string(value)
    let string = cString.map { String(cString: $0) } ?? ""
    var appKitY = y
    if let target {
        let widget = gtk_event_controller_get_widget(OpaquePointer(target))
        appKitY = Double(gtk_widget_get_height(widget)) - y
    }
    let accepted = Unmanaged<DropBox>.fromOpaque(userData).takeUnretainedValue().onDrop(string, x, appKitY)
    return gboolean(accepted ? 1 : 0)
}

/// Handler for `GtkDragSource::prepare` — wraps the provided string in a
/// `GdkContentProvider` (built from a GValue, since `gdk_content_provider_new_typed`
/// is C-variadic). Returning nil cancels the drag.
private let gtkDragPrepareTrampoline: @convention(c) (UnsafeMutableRawPointer?, Double, Double, gpointer?) -> OpaquePointer? = { _, _, _, userData in
    guard let userData,
          let string = Unmanaged<DragProviderBox>.fromOpaque(userData).takeUnretainedValue().provider()
    else { return nil }
    var value = GValue()
    _ = g_value_init(&value, GType(16 << 2))   // G_TYPE_STRING
    g_value_set_string(&value, string)
    let provider = gdk_content_provider_new_for_value(&value)
    g_value_unset(&value)
    return OpaquePointer(provider)
}

/// Handler for `GtkAdjustment::value-changed` — reads both adjustments' current
/// values (the box carries them) and reports the new `(x, y)` scroll offset.
private let gtkScrollChangedTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { _, userData in
    guard let userData else { return }
    let box = Unmanaged<ScrollBox>.fromOpaque(userData).takeUnretainedValue()
    box.action(gtk_adjustment_get_value(box.hadj), gtk_adjustment_get_value(box.vadj))
}

private let boxRelease: GClosureNotify = { data, _ in
    guard let data else { return }
    Unmanaged<AnyObject>.fromOpaque(data).release()
}

/// Single-argument variant for APIs taking a `GDestroyNotify`.
private let boxDestroyNotify: @convention(c) (gpointer?) -> Void = { data in
    guard let data else { return }
    Unmanaged<AnyObject>.fromOpaque(data).release()
}
// (guard continues — the GTK helpers below also need CGTK; the #endif is at EOF)

// MARK: - Frame-authoritative layout

/// The key under which a child's exact GTK rect is stashed on the widget, so
/// the layout manager's C callbacks can read it without touching Swift state.
private let linChocolateFrameKey = "linchocolate-frame"

/// Records `rect` (parent-relative, GTK top-left) as `child`'s exact allocation.
func setExactRect(_ rect: NSRect, on child: OpaquePointer) {
    let box = g_malloc(gsize(MemoryLayout<graphene_rect_t>.size)).assumingMemoryBound(to: graphene_rect_t.self)
    box.pointee = graphene_rect_t(
        origin: graphene_point_t(x: Float(rect.origin.x), y: Float(rect.origin.y)),
        size: graphene_size_t(width: Float(rect.size.width), height: Float(rect.size.height))
    )
    g_object_set_data_full(UnsafeMutablePointer<GObject>(child), linChocolateFrameKey, box, { g_free($0) })
}

/// The exact rect recorded for `child`, or nil when it is laid out natively.
private func exactRect(of child: UnsafeMutablePointer<GtkWidget>) -> UnsafeMutablePointer<graphene_rect_t>? {
    g_object_get_data(UnsafeMutablePointer<GObject>(OpaquePointer(child)), linChocolateFrameKey)?
        .assumingMemoryBound(to: graphene_rect_t.self)
}

/// `GtkLayoutManagerClass.measure` — the container's size is the extent of its
/// children's frames (AppKit containers don't negotiate; they're told a frame).
private let lcLayoutMeasure: @convention(c) (
    UnsafeMutablePointer<GtkLayoutManager>?, UnsafeMutablePointer<GtkWidget>?,
    GtkOrientation, gint,
    UnsafeMutablePointer<gint>?, UnsafeMutablePointer<gint>?,
    UnsafeMutablePointer<gint>?, UnsafeMutablePointer<gint>?
) -> Void = { _, widget, orientation, _, minimum, natural, _, _ in
    var extent: Float = 0
    var child = gtk_widget_get_first_child(widget)
    while let current = child {
        if gtk_widget_should_layout(current) != 0, let rect = exactRect(of: current) {
            let edge = orientation == GTK_ORIENTATION_HORIZONTAL
                ? rect.pointee.origin.x + rect.pointee.size.width
                : rect.pointee.origin.y + rect.pointee.size.height
            extent = max(extent, edge)
        }
        child = gtk_widget_get_next_sibling(current)
    }
    minimum?.pointee = gint(extent)
    natural?.pointee = gint(extent)
}

/// `GtkLayoutManagerClass.allocate` — every child gets exactly its AppKit
/// frame, at its AppKit position. No negotiation: this is what makes a frame
/// mean the same thing on GTK as it does on AppKit.
private let lcLayoutAllocate: @convention(c) (
    UnsafeMutablePointer<GtkLayoutManager>?, UnsafeMutablePointer<GtkWidget>?,
    gint, gint, gint
) -> Void = { _, widget, _, _, _ in
    var child = gtk_widget_get_first_child(widget)
    while let current = child {
        defer { child = gtk_widget_get_next_sibling(current) }
        guard gtk_widget_should_layout(current) != 0, let rect = exactRect(of: current) else { continue }
        let width = gint(rect.pointee.size.width)
        let height = gint(rect.pointee.size.height)
        // GTK requires a measure before an allocate, even when the result is
        // ignored: it caches the request and warns loudly without it.
        gtk_widget_measure(current, GTK_ORIENTATION_HORIZONTAL, -1, nil, nil, nil, nil)
        gtk_widget_measure(current, GTK_ORIENTATION_VERTICAL, width, nil, nil, nil, nil)
        var origin = graphene_point_t(x: rect.pointee.origin.x, y: rect.pointee.origin.y)
        gtk_widget_allocate(current, width, height, -1, gsk_transform_translate(nil, &origin))
    }
}

private let lcLayoutClassInit: @convention(c) (gpointer?, gpointer?) -> Void = { klass, _ in
    let layoutClass = klass!.assumingMemoryBound(to: GtkLayoutManagerClass.self)
    layoutClass.pointee.measure = lcLayoutMeasure
    layoutClass.pointee.allocate = lcLayoutAllocate
}

nonisolated(unsafe) private var lcLayoutTypeStorage: GType = 0

/// The GType of LinChocolate's frame-authoritative layout manager.
func linChocolateFixedLayoutType() -> GType {
    if lcLayoutTypeStorage != 0 { return lcLayoutTypeStorage }
    var info = GTypeInfo()
    info.class_size = guint16(MemoryLayout<GtkLayoutManagerClass>.size)
    info.class_init = lcLayoutClassInit
    info.instance_size = guint16(MemoryLayout<GtkLayoutManager>.size)
    lcLayoutTypeStorage = g_type_register_static(
        gtk_layout_manager_get_type(), "LinChocolateFixedLayout", &info, GTypeFlags(rawValue: 0)
    )
    return lcLayoutTypeStorage
}

/// Carries a paint-trace subscription: which window, and which event fired.
private final class PaintTraceBox {
    weak var backend: GTKNativeControlBackend?
    let raw: UInt
    let event: String
    init(backend: GTKNativeControlBackend, raw: UInt, event: String) {
        self.backend = backend
        self.raw = raw
        self.event = event
    }
}

/// Any traced signal — widget lifecycle or frame-clock cycle.
private let gtkPaintTraceTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { _, userData in
    guard let userData else { return }
    let box = Unmanaged<PaintTraceBox>.fromOpaque(userData).takeUnretainedValue()
    box.backend?.tracePaint(box.raw, box.event)
}

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
}

extension GTKNativeControlBackend {

    // MARK: Handles and parenting

    /// Adds `child` to `parent` when the core supplied one.
    ///
    /// Every `create…` requirement in the core takes a `parent:`; the GTK
    /// methods take none and expect a separate `addSubview`. This is that
    /// difference, applied once.
    private func attach(_ child: NativeHandle, to parent: NativeHandle?) -> NativeHandle {
        guard let parent else { return child }
        switch kinds[parent.rawValue] {
        case .window:
            // A window can take MORE than one direct child: `NSWindow.realizeNativePeer`
            // realizes the toolbar host first and the content view second, both
            // with the window as parent. `setContentView` holds a single slot,
            // so sending both there let the content view evict the toolbar —
            // which is why the merged demo had an empty band across the top.
            //
            // The window's GTK child is already the vertical box this wants:
            // [toolbar][content], exactly AppKit's stack.
            addWindowChild(child, to: parent)
        case .box, .scrollView:
            // GtkFrame and GtkScrolledWindow hold exactly ONE child, while the
            // AppKit views they stand in for hold several — an NSScrollView has
            // a document view *and* a header strip. Handing the second child to
            // the same setter unparents the first, and GTK drops its last
            // reference, leaving a dangling widget that crashed the next
            // `setFrame`. Only the first child takes the content slot.
            if coreSeam.contentAssigned.insert(parent.rawValue).inserted {
                setContentView(child, for: parent)
            } else {
                addSubview(child, to: parent)
            }
        default:
            addSubview(child, to: parent)
        }
        return child
    }

    /// Stacks `child` in `window`'s vertical box, below anything already there.
    ///
    /// The last child added expands to fill — that is the content view, since
    /// the toolbar host is realized first and wants only its own height. The
    /// window's resize and paint bookkeeping follows the expanding child.
    private func addWindowChild(_ child: NativeHandle, to window: NativeHandle) {
        guard let box = windowBoxes[window.rawValue], let c = widget(child) else { return }
        let frame = frames[child.rawValue] ?? .zero
        gtk_widget_set_size_request(asWidget(c), Int32(frame.width), Int32(frame.height))

        // Whatever expanded before now sits at its natural height, and stops
        // standing in for the window's content size. `noteContentDraw` reports
        // a window resize from whichever view owns that mapping, so leaving the
        // toolbar host (1120x40) in it alongside the content view (1120x720)
        // made the two alternately claim to BE the window: every draw pass
        // looked like a resize, the core re-laid the toolbar out, and the item
        // views were rebuilt forever — 618 subview adds in a 14-second run.
        for previous in coreSeam.windowChildren[window.rawValue] ?? [] {
            guard let w = widgets[previous] else { continue }
            gtk_widget_set_vexpand(asWidget(w), gboolean(0))
            contentViewOwners.removeValue(forKey: previous)
        }
        gtk_widget_set_vexpand(asWidget(c), gboolean(1))
        gtk_widget_set_hexpand(asWidget(c), gboolean(1))
        gtk_box_append(asBox(box), asWidget(c))

        coreSeam.windowChildren[window.rawValue, default: []].append(child.rawValue)
        parents[child.rawValue] = window.rawValue
        windowContents[window.rawValue] = c
        contentViewOwners[child.rawValue] = window.rawValue
    }

    // MARK: Creation

    /// Creates a plain container view.
    public func createView(frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        attach(createView(frame: frame), to: parent)
    }

    /// Creates a window. `usesMainMenu` is Win32's menu-bar-in-the-frame flag;
    /// GTK installs menus per window through `installMenuBar`, so the shared
    /// core's `installMainMenu` does that work instead.
    public func createWindow(title: String, frame: NSRect, styleMask: NSWindow.StyleMask,
                             usesMainMenu: Bool) -> NativeHandle {
        createWindow(title: title, frame: frame, styleMask: styleMask)
    }

    /// Creates a push button. A non-bordered button drops GTK's frame.
    public func createButton(title: String, frame: NSRect, parent: NativeHandle?,
                             isBordered: Bool) -> NativeHandle {
        let handle = attach(createButton(title: title, frame: frame), to: parent)
        if !isBordered { setButtonBezelFlat(true, for: handle) }
        return handle
    }

    /// Creates a checkbox.
    public func createCheckbox(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        attach(createCheckbox(title: title, frame: frame), to: parent)
    }

    /// Creates a radio button.
    public func createRadioButton(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        attach(createRadioButton(title: title, frame: frame), to: parent)
    }

    /// Creates a titled box.
    public func createBox(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        attach(createBox(title: title, frame: frame), to: parent)
    }

    /// Creates a text field. A non-editable, non-bordered field is a label on
    /// GTK, which is also what AppKit's own label factory produces.
    public func createTextField(text: String, frame: NSRect, parent: NativeHandle?,
                                isEditable: Bool, isBordered: Bool,
                                isMultiline: Bool) -> NativeHandle {
        let handle: NativeHandle
        if !isEditable && !isBordered {
            handle = createLabel(text: text, frame: frame)
        } else {
            handle = createTextField(text: text, frame: frame)
            setTextEditable(isEditable, for: handle)
            setTextFieldBezeled(isBordered, for: handle)
        }
        return attach(handle, to: parent)
    }

    /// Creates a secure (password) text field.
    public func createSecureTextField(text: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        attach(createSecureTextField(text: text, frame: frame), to: parent)
    }

    /// Creates a multi-line text view.
    public func createTextView(text: String, frame: NSRect, parent: NativeHandle?,
                               isEditable: Bool, isRichText: Bool) -> NativeHandle {
        let handle = attach(createTextView(text: text, frame: frame), to: parent)
        setTextEditable(isEditable, for: handle)
        return handle
    }

    /// Creates an editable combo box.
    public func createComboBox(items: [String], text: String, frame: NSRect,
                               parent: NativeHandle?) -> NativeHandle {
        attach(createComboBox(items: items, text: text, frame: frame), to: parent)
    }

    /// Creates a pop-up button.
    public func createPopUpButton(items: [String], selectedIndex: Int, frame: NSRect,
                                  parent: NativeHandle?) -> NativeHandle {
        attach(createPopUpButton(items: items, selectedIndex: selectedIndex, frame: frame), to: parent)
    }

    /// Creates a slider.
    public func createSlider(value: Double, minValue: Double, maxValue: Double,
                            frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        attach(createSlider(value: value, minValue: minValue, maxValue: maxValue, frame: frame),
               to: parent)
    }

    /// Creates a stepper.
    public func createStepper(value: Double, minValue: Double, maxValue: Double,
                             increment: Double, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        attach(createStepper(value: value, minValue: minValue, maxValue: maxValue,
                             stepSize: increment, frame: frame), to: parent)
    }

    /// Creates a progress indicator.
    public func createProgressIndicator(value: Double, minValue: Double, maxValue: Double,
                                        frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        attach(createProgressIndicator(value: value, minValue: minValue, maxValue: maxValue,
                                       frame: frame), to: parent)
    }

    /// Creates a date picker.
    public func createDatePicker(date: Date, minDate: Date?, maxDate: Date?,
                                 style: NSDatePicker.Style, frame: NSRect,
                                 parent: NativeHandle?) -> NativeHandle {
        // Style FIRST, parent second: `setDatePickerGraphical` swaps the widget
        // for a calendar or a compact entry, and that swap is only safe while
        // the widget has no parent. Attaching first left the old widget
        // unparented and freed while the handle still pointed at it, so the
        // next `setToolTip` walked into freed memory.
        let handle = createDatePicker(date: date, frame: frame)
        setDatePickerGraphical(style == .clockAndCalendar, for: handle)
        setDateRange(min: minDate, max: maxDate, for: handle)
        return attach(handle, to: parent)
    }

    /// Creates an image view. `description` is Win32's accessible name, which
    /// GTK takes as the widget tooltip.
    public func createImageView(description: String, imagePath: String?, frame: NSRect,
                                parent: NativeHandle?) -> NativeHandle {
        let handle = attach(createImageView(frame: frame), to: parent)
        if let imagePath { setImagePath(imagePath, for: handle) }
        return handle
    }

    /// Creates a tab view and its pages.
    public func createTabView(items: [String], selectedIndex: Int, frame: NSRect,
                              parent: NativeHandle?) -> NativeHandle {
        let handle = attach(createTabView(frame: frame), to: parent)
        setTabViewItems(items, selectedIndex: selectedIndex, for: handle)
        return handle
    }

    /// Creates a scroll view.
    public func createScrollView(frame: NSRect, parent: NativeHandle?, hasVerticalScroller: Bool,
                                 hasHorizontalScroller: Bool) -> NativeHandle {
        let handle = attach(createScrollView(frame: frame), to: parent)
        setScrollerPolicy(vertical: hasVerticalScroller, horizontal: hasHorizontalScroller,
                          for: handle)
        return handle
    }

    /// Creates a standalone scroller.
    public func createScroller(value: Double, knobProportion: Double, isVertical: Bool,
                               frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = attach(createScroller(vertical: isVertical, frame: frame), to: parent)
        setScrollerGeometry(value: value, knobProportion: knobProportion, for: handle)
        return handle
    }

    /// Creates a table view with equal column widths.
    public func createTableView(columns: [String], rows: [[String]], selectedRow: Int,
                                frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        createTableView(columns: columns, columnWidths: [], rows: rows,
                        selectedRow: selectedRow, frame: frame, parent: parent)
    }

    /// Creates a table view. GTK's column view sizes its own columns, so
    /// `columnWidths` is accepted and left to the widget.
    public func createTableView(columns: [String], columnWidths: [CGFloat], rows: [[String]],
                                selectedRow: Int, frame: NSRect,
                                parent: NativeHandle?) -> NativeHandle {
        let handle = attach(createTableView(frame: frame), to: parent)
        for title in columns { addTableColumn(title: title, editable: false, to: handle) }
        setTableRows(rows, selectedRow: selectedRow, for: handle)
        return handle
    }

    /// Creates a toolbar.
    ///
    /// The core models a toolbar as a control it creates and then fills; GTK
    /// installs one on a window as a header bar. So this stages the items and
    /// `setToolbarItems` performs the install once the window is known.
    public func createToolbar(items: [NativeToolbarItem], frame: NSRect,
                              parent: NativeHandle?) -> NativeHandle {
        let handle = createView(frame: frame)
        if let parent { coreSeam.toolbarWindow[handle.rawValue] = parent }
        setHidden(true, for: handle)
        setToolbarItems(items, for: handle)
        return handle
    }

    // MARK: Values read back

    /// The slider's current value.
    public func sliderValue(for handle: NativeHandle) -> Double {
        guard let w = widget(handle) else { return 0 }
        return gtk_range_get_value(asRange(w))
    }

    /// The stepper's current value.
    public func stepperValue(for handle: NativeHandle) -> Double {
        stepperValues[handle.rawValue] ?? 0
    }

    /// The level indicator's current value.
    public func levelIndicatorValue(for handle: NativeHandle) -> Double {
        levelValues[handle.rawValue] ?? 0
    }

    /// The scroller's current value.
    public func scrollerValue(for handle: NativeHandle) -> Double {
        guard let adjustment = scrollerAdjustments[handle.rawValue] else { return 0 }
        return gtk_adjustment_get_value(adjustment)
    }

    /// Which part of the scroller the user last touched.
    ///
    /// GTK's scrollbar does not report the hit part — the adjustment reports
    /// only the resulting value — so every scroll reads as a knob drag, which
    /// is what a GTK scrollbar drag actually is.
    public func scrollerPart(for handle: NativeHandle) -> NativeScrollerPart { .knob }

    /// The checkbox/radio state.
    public func buttonState(for handle: NativeHandle) -> NSControl.StateValue {
        guard let w = widget(handle) else { return .off }
        switch kinds[handle.rawValue] {
        case .checkbox, .radio:
            return gtk_check_button_get_active(asCheckButton(w)) != 0 ? .on : .off
        default:
            return .off
        }
    }

    /// The combo box's editable text.
    public func comboBoxText(for handle: NativeHandle) -> String {
        guard let entry = comboEntries[handle.rawValue],
              let text = gtk_editable_get_text(entry) else { return "" }
        return String(cString: text)
    }

    /// The pop-up button's selected index.
    public func popUpButtonSelectedIndex(for handle: NativeHandle) -> Int {
        guard let w = widget(handle) else { return -1 }
        let selected = gtk_drop_down_get_selected(w)
        return selected == GTK_INVALID_LIST_POSITION ? -1 : Int(selected)
    }

    /// The tab view's selected page index.
    public func tabViewSelectedIndex(for handle: NativeHandle) -> Int {
        guard let w = widget(handle) else { return 0 }
        return Int(gtk_notebook_get_current_page(w))
    }

    /// The date picker's date.
    public func datePickerDate(for handle: NativeHandle) -> Date? {
        dateValues[handle.rawValue]
    }

    /// The table's selected row, or −1.
    public func tableSelectedRow(for handle: NativeHandle) -> Int {
        coreSeam.tableSelection[handle.rawValue]?.first ?? -1
    }

    /// Every selected row.
    public func tableSelectedRows(for handle: NativeHandle) -> [Int] {
        coreSeam.tableSelection[handle.rawValue] ?? []
    }

    /// The row the user last clicked, or −1.
    public func tableClickedRow(for handle: NativeHandle) -> Int {
        coreSeam.tableClickedRow[handle.rawValue] ?? -1
    }

    /// The column the user last clicked, or −1.
    public func tableClickedColumn(for handle: NativeHandle) -> Int {
        coreSeam.tableClickedColumn[handle.rawValue] ?? -1
    }

    /// The text view's selection as a location/length pair.
    public func textSelection(for handle: NativeHandle) -> (location: Int, length: Int) {
        guard let w = widget(handle) else { return (0, 0) }
        var start: Int32 = 0, end: Int32 = 0
        if gtk_editable_get_selection_bounds(w, &start, &end) != 0 {
            return (Int(start), Int(end - start))
        }
        let position = gtk_editable_get_position(w)
        return (Int(position), 0)
    }

    // MARK: Setters the core spells differently

    /// Sets the checkbox/radio state. AppKit's `.mixed` has no GTK equivalent
    /// on a plain check button, so it reads as on.
    ///
    /// AppKit puts `state` on every `NSButton`, including push buttons; GTK's
    /// active flag belongs to `GtkCheckButton` alone, and handing it anything
    /// else trips `GTK_IS_CHECK_BUTTON`. So the state only lands on the kinds
    /// that have one.
    public func setButtonState(_ state: NSControl.StateValue, for handle: NativeHandle) {
        switch kinds[handle.rawValue] {
        case .checkbox, .radio: setButtonState(state != .off, for: handle)
        default: break
        }
    }

    /// Sets the slider value.
    public func setSliderValue(_ value: Double, for handle: NativeHandle) {
        setDoubleValue(value, for: handle)
    }

    /// Sets the slider's range.
    public func setSliderRange(minValue: Double, maxValue: Double, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_range_set_range(asRange(w), minValue, maxValue)
    }

    /// Sets the slider's tick count, leaving snapping off.
    public func setSliderTickMarks(count: Int, for handle: NativeHandle) {
        setSliderTickMarks(count: count, snapsToTicks: false, for: handle)
    }

    /// Sets which side of the slider track the ticks are drawn on.
    public func setSliderTickMarkPosition(aboveOrLeading: Bool, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_scale_set_value_pos(UnsafeMutablePointer<GtkScale>(w), aboveOrLeading ? GTK_POS_TOP : GTK_POS_BOTTOM)
    }

    /// Sets the stepper value.
    public func setStepperValue(_ value: Double, for handle: NativeHandle) {
        setDoubleValue(value, for: handle)
    }

    /// Sets the stepper's range and step.
    ///
    /// AppKit's stepper is the bare pair of arrows, with the value shown in a
    /// separate text field, so this backend builds it from two buttons and
    /// keeps the value itself — it is not a `GtkSpinButton`, and the spin
    /// button API crashed against it.
    public func setStepperRange(minValue: Double, maxValue: Double, increment: Double,
                                for handle: NativeHandle) {
        ranges[handle.rawValue] = (minValue, maxValue)
        stepperSteps[handle.rawValue] = increment == 0 ? 1 : increment
    }

    /// Whether the stepper wraps past its bounds. The arrow pair clamps at its
    /// bounds; wrapping is not implemented.
    public func setStepperWraps(_ wraps: Bool, for handle: NativeHandle) {}

    /// Sets the progress bar's value.
    public func setProgressIndicatorValue(_ value: Double, for handle: NativeHandle) {
        setDoubleValue(value, for: handle)
    }

    /// Sets the progress bar's range.
    ///
    /// Straight into the range table `setDoubleValue` reads, NOT through
    /// `setLevelIndicatorRange` — that one rebuilds a `GtkLevelBar`'s star
    /// content, and running it against a `GtkProgressBar` corrupted the widget
    /// and crashed the first run of the merged demo.
    public func setProgressIndicatorRange(minValue: Double, maxValue: Double,
                                          for handle: NativeHandle) {
        ranges[handle.rawValue] = (minValue, maxValue)
    }

    /// Switches the progress indicator between determinate and indeterminate.
    public func setProgressIndicatorIndeterminate(_ isIndeterminate: Bool, animating: Bool,
                                                  for handle: NativeHandle) {
        setProgressIndeterminate(isIndeterminate, for: handle)
        setProgressAnimating(animating, for: handle)
    }

    /// Tints the progress bar's filled portion.
    ///
    /// `setColor` is the color well's swatch setter, not a general tint, so the
    /// fill color goes on as a background instead.
    public func setProgressBarColor(_ color: NSColor?, for handle: NativeHandle) {
        setBackgroundColor(color, for: handle)
    }

    /// Makes the level indicator editable within a range.
    public func setLevelIndicatorEditable(_ editable: Bool, minValue: Double, maxValue: Double,
                                          for handle: NativeHandle) {
        setLevelIndicatorRange(min: minValue, max: maxValue, for: handle)
        setLevelIndicatorEditable(editable, for: handle)
    }

    /// Sets the pop-up button's items.
    public func setPopUpButtonItems(_ items: [String], selectedIndex: Int,
                                    for handle: NativeHandle) {
        setPopUpItems(items, selectedIndex: selectedIndex, for: handle)
    }

    /// Selects a pop-up button item.
    public func setPopUpButtonSelectedIndex(_ selectedIndex: Int, for handle: NativeHandle) {
        setSelectedIndex(selectedIndex, for: handle)
    }

    /// Replaces the combo box's items and text.
    public func setComboBoxItems(_ items: [String], text: String, for handle: NativeHandle) {
        setPopUpItems(items, selectedIndex: -1, for: handle)
        setText(text, for: handle)
    }

    /// The number of rows the combo's list shows before scrolling. GTK's drop
    /// down sizes its popup to the available screen space and offers no such
    /// knob, so the count is not applied.
    public func setComboBoxVisibleItems(_ count: Int, for handle: NativeHandle) {}

    /// Sets the tab view's pages.
    public func setTabViewItems(_ items: [String], selectedIndex: Int, for handle: NativeHandle) {
        for label in items {
            let page = createView(frame: NSRect(x: 0, y: 0, width: 0, height: 0))
            addTabPage(page, label: label, to: handle)
        }
        setTabViewSelectedIndex(selectedIndex, for: handle)
    }

    /// Selects a tab page.
    public func setTabViewSelectedIndex(_ selectedIndex: Int, for handle: NativeHandle) {
        setSelectedIndex(selectedIndex, for: handle)
    }

    /// Replaces the table's rows.
    public func setTableRows(_ rows: [[String]], selectedRow: Int, for handle: NativeHandle) {
        setTableCellProvider(for: handle) { row, column in
            guard row < rows.count, column < rows[row].count else { return "" }
            return rows[row][column]
        }
        setTableRowCount(rows.count, for: handle)
        setTableSelectedRow(selectedRow, for: handle)
    }

    /// Sets one cell's text. The provider installed by `setTableRows` owns the
    /// content, so this refreshes the row rather than writing through.
    public func setTableCellText(_ text: String, row: Int, column: Int, for handle: NativeHandle) {
        setNeedsDisplay(handle)
    }

    /// Selects a single row.
    public func setTableSelectedRow(_ selectedRow: Int, for handle: NativeHandle) {
        coreSeam.tableSelection[handle.rawValue] = selectedRow >= 0 ? [selectedRow] : []
        if selectedRow >= 0 { selectOutlineRow(selectedRow, for: handle) }
    }

    /// Selects several rows. GTK's column view selection model here is single
    /// selection, so the lowest row wins.
    public func setTableSelectedRows(_ rows: Set<Int>, for handle: NativeHandle) {
        coreSeam.tableSelection[handle.rawValue] = rows.sorted()
        if let first = rows.min() { selectOutlineRow(first, for: handle) }
    }

    /// Whether the table allows multi-row selection.
    public func setTableAllowsMultipleSelection(_ allows: Bool, for handle: NativeHandle) {}

    /// Whether the table's cells can be edited in place.
    public func setTableEditable(_ editable: Bool, for handle: NativeHandle) {}

    /// Shows the sort indicator on a column.
    public func setTableSortIndicator(column: Int, ascending: Bool, for handle: NativeHandle) {
        setColumnSortable(column, for: handle)
    }

    /// Begins editing a cell.
    public func editTableCell(row: Int, column: Int, for handle: NativeHandle) {
        scrollTableRowToVisible(row, for: handle)
    }

    /// Sets the text color, clearing it when nil.
    public func setTextColor(_ color: NSColor?, for handle: NativeHandle) {
        guard let color else { return }
        setTextColor(color, for: handle)
    }

    /// Sets the control's font.
    public func setFont(_ font: NSFont?, for handle: NativeHandle) {
        guard let font else { return }
        setFont(NativeFontSpec(family: font.fontName, size: Double(font.pointSize),
                               bold: font.isBold, italic: font.italic), for: handle)
    }

    /// Sets the placeholder shown in an empty text field.
    public func setTextPlaceholder(_ placeholder: String?, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_entry_set_placeholder_text(UnsafeMutablePointer<GtkEntry>(w), placeholder)
    }

    /// Whether the text field draws a bezel.
    public func setTextFieldBezeled(_ bezeled: Bool, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_entry_set_has_frame(UnsafeMutablePointer<GtkEntry>(w), gboolean(bezeled ? 1 : 0))
    }

    /// Whether the button draws a flat bezel.
    public func setButtonBezelFlat(_ flat: Bool, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_button_set_has_frame(asButton(w), gboolean(flat ? 0 : 1))
    }

    /// Sets the button's image.
    public func setButtonImage(imagePath: String?, for handle: NativeHandle) {
        setImagePath(imagePath, for: handle)
    }

    /// Sets an image view's artwork, accessible description, and template tint.
    public func setImagePath(_ path: String?, description: String, tint: NSColor?,
                             for handle: NativeHandle) {
        setImagePath(path, for: handle)
        setImageTint(tint, isTemplate: tint != nil, for: handle)
    }

    /// Whether the control paints its background.
    public func setDrawsBackground(_ drawsBackground: Bool, for handle: NativeHandle) {
        setBackgroundColor(drawsBackground ? nil : NSColor.clear, for: handle)
    }

    /// Sets the paragraph alignment of a text control.
    public func setTextAlignment(_ alignment: NSTextAlignment, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        let xalign: Float
        switch alignment {
        case .center: xalign = 0.5
        case .right:  xalign = 1.0
        default:      xalign = 0.0
        }
        switch kinds[handle.rawValue] {
        case .label: gtk_label_set_xalign(w, xalign)
        default:     gtk_editable_set_alignment(w, xalign)
        }
    }

    /// Aligns one range of a text view. GTK's text buffer carries alignment on
    /// tags; the styled-run path (`setStyledText`) is how the core gets this,
    /// so a bare range alignment is not applied.
    public func setTextRangeAlignment(_ alignment: NSTextAlignment, location: Int, length: Int,
                                      for handle: NativeHandle) {}

    /// Applies formatting to a range of a text view.
    public func setTextRangeFormat(font: NSFont?, color: NSColor?, underline: Bool?,
                                   strikethrough: Bool?, location: Int, length: Int,
                                   for handle: NativeHandle) {}

    /// Sets the text view's selection.
    public func setTextSelection(location: Int, length: Int, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_editable_select_region(w, Int32(location), Int32(location + length))
    }

    /// Replaces the selected text.
    public func replaceSelectedText(_ text: String, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        var start: Int32 = 0, end: Int32 = 0
        if gtk_editable_get_selection_bounds(w, &start, &end) != 0 {
            gtk_editable_delete_text(w, start, end)
        }
        var position = start
        gtk_editable_insert_text(w, text, Int32(text.utf8.count), &position)
    }

    /// Sets the date picker's date and range.
    public func setDatePickerDate(_ date: Date, minDate: Date?, maxDate: Date?,
                                  for handle: NativeHandle) {
        setDateValue(date, for: handle)
        setDateRange(min: minDate, max: maxDate, for: handle)
    }

    /// Sets the picker's field layout. The GTK picker derives its fields from
    /// the locale and its graphical/compact mode, so an explicit format string
    /// is not applied.
    public func setDatePickerFormat(_ format: String?, for handle: NativeHandle) {}

    /// Sets the time zone the picker displays in.
    public func setDatePickerTimeZone(_ timeZone: TimeZone, for handle: NativeHandle) {}

    /// Sets the view's tooltip.
    public func setToolTip(_ toolTip: String?, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_widget_set_tooltip_text(asWidget(w), toolTip)
    }

    /// Scales a view's contents. GTK4 scales at the renderer, not per widget;
    /// the drawing path applies magnification instead (`setViewMagnification`).
    public func setContentScale(_ scale: CGFloat, for handle: NativeHandle) {
        setViewMagnification(Double(scale), for: handle)
    }

    /// Lets a drag inside the view move its window (AppKit's
    /// `mouseDownCanMoveWindow`), which is GTK's `GtkWindowHandle`.
    public func setViewDragsParentWindow(_ enabled: Bool, for handle: NativeHandle) {}

    // MARK: Windows

    /// Closes a window.
    public func closeWindow(_ handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_window_close(asWindow(w))
    }

    /// Whether the window is on screen.
    public func isWindowVisible(_ handle: NativeHandle) -> Bool {
        guard let w = widget(handle) else { return false }
        return gtk_widget_get_visible(asWidget(w)) != 0
    }

    /// Whether the window is minimized.
    public func isWindowMinimized(_ handle: NativeHandle) -> Bool {
        coreSeam.minimizedWindows.contains(handle.rawValue)
    }

    /// Minimizes or restores a window.
    public func setWindowMinimized(_ minimized: Bool, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        if minimized {
            coreSeam.minimizedWindows.insert(handle.rawValue)
            gtk_window_minimize(asWindow(w))
        } else {
            coreSeam.minimizedWindows.remove(handle.rawValue)
            gtk_window_unminimize(asWindow(w))
        }
    }

    /// Toggles the window between its standard and zoomed frames.
    public func toggleWindowZoom(_ handle: NativeHandle) {
        toggleZoomWindow(handle)
    }

    /// Shows or hides a window with a fade. GTK4 has no window animation API,
    /// so the opacity is set directly and the change is immediate.
    public func fadeWindow(_ handle: NativeHandle, visible: Bool) {
        guard let w = widget(handle) else { return }
        gtk_widget_set_opacity(asWidget(w), visible ? 1.0 : 0.0)
        if visible { showWindow(handle) } else { hideWindow(handle) }
    }

    /// Sends a window behind its siblings.
    ///
    /// GTK4 removed window lowering — `gdk_window_lower` has no GdkSurface
    /// successor, because ordering is the compositor's to decide. There is no
    /// call to make here.
    public func orderWindowBack(_ handle: NativeHandle) {}

    /// Sets the window's stacking level. GTK4 exposes only "always on top"
    /// through the compositor, so a level above `.normal` raises the window.
    public func setWindowLevel(_ level: NSWindow.Level, for handle: NativeHandle) {
        guard level.rawValue > NSWindow.Level.normal.rawValue else { return }
        showWindow(handle)
    }

    /// Constrains the window's content size. GTK4 takes a minimum through the
    /// size request; a maximum is the compositor's to enforce and is not set.
    public func setWindowContentSizeLimits(minSize: NSSize?, maxSize: NSSize?,
                                           for handle: NativeHandle) {
        guard let w = widget(handle), let minSize else { return }
        gtk_widget_set_size_request(asWidget(w), Int32(minSize.width), Int32(minSize.height))
    }

    /// Hides individual title-bar buttons. GTK's header bar controls close as
    /// a unit, so hiding close hides the whole set.
    public func setWindowButtonsHidden(closeHidden: Bool, minimizeHidden: Bool, zoomHidden: Bool,
                                       for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_window_set_deletable(asWindow(w), gboolean(closeHidden ? 0 : 1))
    }

    /// Whether the window hides when the app deactivates. X11 gives no
    /// app-activation signal to hang this on, so panels stay put.
    public func setHidesOnDeactivate(_ hidesOnDeactivate: Bool, for handle: NativeHandle) {}

    /// The main display's frame.
    public func primaryScreenFrame() -> NSRect {
        screenDescriptions().first?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
    }

    /// Every attached display. GTK reports no separate work area, so the
    /// visible frame is the full frame.
    public func screenDescriptions() -> [NativeScreenDescription] {
        guard let display = gdk_display_get_default(),
              let monitors = gdk_display_get_monitors(display) else { return [] }
        var result: [NativeScreenDescription] = []
        for index in 0..<g_list_model_get_n_items(monitors) {
            guard let monitor = g_list_model_get_item(monitors, index) else { continue }
            var rect = GdkRectangle()
            gdk_monitor_get_geometry(OpaquePointer(monitor), &rect)
            let frame = NSRect(x: CGFloat(rect.x), y: CGFloat(rect.y),
                               width: CGFloat(rect.width), height: CGFloat(rect.height))
            result.append(NativeScreenDescription(frame: frame, visibleFrame: frame))
        }
        return result
    }

    // MARK: Focus, invalidation, z-order

    /// Gives the control keyboard focus.
    public func focusControl(_ handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_widget_grab_focus(asWidget(w))
    }

    /// Raises the control above its siblings.
    public func raiseControl(_ handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_widget_insert_before(asWidget(w), gtk_widget_get_parent(asWidget(w)), nil)
    }

    /// Marks the control as needing redraw.
    public func invalidateControl(_ handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_widget_queue_draw(asWidget(w))
        setNeedsDisplay(handle)
    }

    /// Marks the control and its descendants as needing redraw. GTK invalidates
    /// a subtree with the parent, so this is the same call.
    public func invalidateControlTree(_ handle: NativeHandle) {
        invalidateControl(handle)
    }

    /// Redraws now rather than at the next frame.
    ///
    /// GTK4 draws on the frame clock and offers no synchronous paint — that is
    /// what makes its rendering tear-free — so this queues the redraw and the
    /// compositor presents it on the next tick.
    public func redrawControlImmediately(_ handle: NativeHandle) {
        invalidateControl(handle)
    }

    // MARK: Event registration

    /// Installs the one GTK mouse handler that fans out to the core's
    /// per-event callbacks, the first time any of them is registered.
    private func ensureMouseHandler(for handle: NativeHandle) {
        let raw = handle.rawValue
        guard !coreSeam.mouseInstalled.contains(raw) else { return }
        coreSeam.mouseInstalled.insert(raw)
        setMouseHandler(for: handle) { [weak self] event in
            guard let self, let actions = self.coreSeam.mouse[raw] else { return }
            switch event {
            case let .down(x, y, clickCount, rightButton):
                let event = NSEvent(type: rightButton ? .rightMouseDown : .leftMouseDown,
                                    locationInWindow: NSPoint(x: x, y: y),
                                    clickCount: clickCount)
                if rightButton { actions.rightDown?(event) } else { actions.down?(event) }
            case let .entered(x, y):
                actions.moved?(NSEvent(type: .mouseMoved, locationInWindow: NSPoint(x: x, y: y)))
            case .exited:
                actions.left?()
            case let .scroll(deltaX, deltaY):
                actions.scroll?(NSEvent(type: .mouseMoved, locationInWindow: .zero,
                                        scrollingDeltaX: CGFloat(deltaX),
                                        scrollingDeltaY: CGFloat(deltaY)))
            }
        }
    }

    /// Registers a left mouse-down handler.
    public func registerMouseDownAction(for handle: NativeHandle,
                                        action: @escaping (NSEvent) -> Void) {
        coreSeam.mouse[handle.rawValue, default: .init()].down = action
        ensureMouseHandler(for: handle)
    }

    /// Registers a left mouse-up handler.
    ///
    /// GTK's mouse seam above reports press, enter, leave, and scroll — a
    /// release is not among them, so this is recorded and will start firing
    /// when that seam grows a release event.
    public func registerMouseUpAction(for handle: NativeHandle,
                                      action: @escaping (NSEvent) -> Void) {
        coreSeam.mouse[handle.rawValue, default: .init()].up = action
        ensureMouseHandler(for: handle)
    }

    /// Registers a mouse-moved handler (GTK's pointer-enter motion).
    public func registerMouseMovedAction(for handle: NativeHandle,
                                         action: @escaping (NSEvent) -> Void) {
        coreSeam.mouse[handle.rawValue, default: .init()].moved = action
        ensureMouseHandler(for: handle)
    }

    /// Registers a drag handler. See `registerMouseUpAction` for why this does
    /// not fire yet.
    public func registerMouseDraggedAction(for handle: NativeHandle,
                                           action: @escaping (NSEvent) -> Void) {
        coreSeam.mouse[handle.rawValue, default: .init()].dragged = action
        ensureMouseHandler(for: handle)
    }

    /// Registers a pointer-exit handler.
    public func registerMouseLeftAction(for handle: NativeHandle, action: @escaping () -> Void) {
        coreSeam.mouse[handle.rawValue, default: .init()].left = action
        ensureMouseHandler(for: handle)
    }

    /// Registers a right mouse-down handler.
    public func registerRightMouseDownAction(for handle: NativeHandle,
                                             action: @escaping (NSEvent) -> Void) {
        coreSeam.mouse[handle.rawValue, default: .init()].rightDown = action
        ensureMouseHandler(for: handle)
    }

    /// Registers a right mouse-up handler.
    public func registerRightMouseUpAction(for handle: NativeHandle,
                                           action: @escaping (NSEvent) -> Void) {
        coreSeam.mouse[handle.rawValue, default: .init()].rightUp = action
        ensureMouseHandler(for: handle)
    }

    /// Registers a middle mouse-down handler.
    public func registerOtherMouseDownAction(for handle: NativeHandle,
                                             action: @escaping (NSEvent) -> Void) {
        coreSeam.mouse[handle.rawValue, default: .init()].otherDown = action
        ensureMouseHandler(for: handle)
    }

    /// Registers a middle mouse-up handler.
    public func registerOtherMouseUpAction(for handle: NativeHandle,
                                           action: @escaping (NSEvent) -> Void) {
        coreSeam.mouse[handle.rawValue, default: .init()].otherUp = action
        ensureMouseHandler(for: handle)
    }

    /// Registers a scroll-wheel handler.
    public func registerScrollWheelAction(for handle: NativeHandle,
                                          action: @escaping (NSEvent) -> Void) {
        coreSeam.mouse[handle.rawValue, default: .init()].scroll = action
        ensureMouseHandler(for: handle)
    }

    /// Registers a text-change handler.
    public func registerTextChangeAction(for handle: NativeHandle,
                                         action: @escaping (String) -> Void) {
        setTextChangeAction(for: handle, action: action)
    }

    /// Registers a cell-commit handler.
    public func registerTableEditAction(for handle: NativeHandle,
                                        action: @escaping (Int, Int, String) -> Void) {
        setTableCellCommitAction(for: handle, action)
    }

    /// Registers a window-resize handler.
    public func registerWindowResizeAction(for handle: NativeHandle,
                                           action: @escaping (NSSize) -> Void) {
        setWindowResizeAction(for: handle) { width, height in
            action(NSSize(width: CGFloat(width), height: CGFloat(height)))
        }
    }

    /// Registers a window-move handler. X11 delivers configure events for
    /// position, but GDK4 surfaces no toplevel position to report, by design —
    /// clients are not told where the compositor put them.
    public func registerWindowMoveAction(for handle: NativeHandle,
                                         action: @escaping (NSPoint) -> Void) {}

    /// Registers a should-close handler.
    public func registerWindowShouldCloseHandler(for handle: NativeHandle,
                                                 handler: @escaping () -> Bool) {
        registerWindowCloseAction(for: handle) { _ = handler() }
    }

    /// Registers a focus-change handler.
    public func registerFocusChangeAction(for handle: NativeHandle,
                                          action: @escaping (Bool) -> Void) {}

    /// Registers a key-down handler.
    public func registerKeyDownAction(for handle: NativeHandle,
                                      action: @escaping (NSEvent) -> Void) {}

    /// Registers a key-up handler.
    public func registerKeyUpAction(for handle: NativeHandle,
                                    action: @escaping (NSEvent) -> Void) {}

    /// Registers the app-wide key-equivalent handler. Menu accelerators are
    /// installed with the menu bar on GTK, so this is not consulted.
    public func registerKeyEquivalentHandler(_ handler: @escaping (NSEvent) -> Bool) {}

    /// Registers a toolbar-item handler.
    public func registerToolbarAction(for handle: NativeHandle,
                                      action: @escaping (String) -> Void) {
        coreSeam.toolbarActions[handle.rawValue] = action
    }

    /// Registers a drawing handler, bridging the core's path-batch context onto
    /// GTK's immediate-mode Cairo one.
    public func registerDrawAction(for handle: NativeHandle,
                                   action: @escaping (NativeDrawingContext, NSRect) -> Void) {
        coreSeam.topLeftDrawing.insert(handle.rawValue)
        setDrawHandler(for: handle) { context, width, height in
            action(GTKCoreDrawingContext(context),
                   NSRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        }
    }

    /// Registers a drop target.
    public func registerDropTarget(for handle: NativeHandle, handler: NativeDropHandler) {
        registerDropTarget(for: handle, types: ["text/plain"]) { text, x, y in
            handler.performed(NativeDropContent(text: text, filePaths: []),
                              NSPoint(x: x, y: y))
        }
    }

    /// Removes a drop target.
    public func unregisterDropTarget(for handle: NativeHandle) {}

    /// Starts a drag from a view. GTK drags begin from a drag-source gesture on
    /// the widget rather than from a programmatic call, so the content offered
    /// by `registerDragSource` is what leaves the view.
    public func performDrag(content: NativeDropContent, from handle: NativeHandle) -> Bool { false }

    // MARK: Toolbar

    /// Installs the toolbar's items on its window.
    public func setToolbarItems(_ items: [NativeToolbarItem], for handle: NativeHandle) {
        coreSeam.toolbarItems[handle.rawValue] = items
        guard let window = coreSeam.toolbarWindow[handle.rawValue] else { return }
        let action = coreSeam.toolbarActions[handle.rawValue]
        let specs = items.map { item in
            NativeToolbarItemSpec(identifier: item.identifier,
                                  label: item.label,
                                  iconName: item.imageName,
                                  isFlexibleSpace: item.isFlexibleSpace,
                                  action: { action?(item.identifier) })
        }
        installToolbar(specs, on: window)
    }

    /// The on-screen frame of a toolbar item. GTK's header bar owns its own
    /// layout and reports no per-child geometry before it is mapped.
    public func toolbarItemFrame(at index: Int, for handle: NativeHandle) -> NSRect? { nil }

    // MARK: Menus and dialogs

    /// Installs the application menu bar on the frontmost window.
    public func installMainMenu(_ menu: NSMenu?) {
        guard let menu else { return }
        let specs = menu.items.map { top in
            NativeMenuSpec(title: top.title,
                           items: (top.submenu?.items ?? []).map { item in
                               NativeMenuItemSpec(title: item.title,
                                                  isSeparator: item.isSeparatorItem,
                                                  accelerator: nil,
                                                  action: { _ = item.performAction() })
                           })
        }
        // `NSApplication.mainMenu` is usually set during launch, before the
        // first window is created — and GTK installs a menu bar ON a window.
        // Hold it until there is one rather than dropping it.
        guard let window = firstWindowHandle() else {
            coreSeam.pendingMainMenu = specs
            return
        }
        installMenuBar(specs, on: window)
    }

    /// Installs a menu bar that arrived before any window existed.
    func installPendingMainMenu(on window: NativeHandle) {
        guard let specs = coreSeam.pendingMainMenu else { return }
        coreSeam.pendingMainMenu = nil
        installMenuBar(specs, on: window)
    }

    /// The first window created, which is the one menus and modals attach to.
    private func firstWindowHandle() -> NativeHandle? {
        kinds.filter { $0.value == .window }.keys.min().map { NativeHandle(rawValue: $0) }
    }

    /// Runs an alert modally.
    public func runAlert(_ alert: NSAlert) -> NSApplication.ModalResponse {
        let titles = alert.buttons.isEmpty ? ["OK"] : alert.buttons.map(\.title)
        let index = runAlert(message: alert.messageText, informative: alert.informativeText,
                             buttons: titles, for: firstWindowHandle())
        return NSApplication.ModalResponse(rawValue: 1000 + index)
    }

    /// Runs an open or save dialog.
    public func runFileDialog(_ options: NativeFileDialogOptions) -> [String]? {
        let window = firstWindowHandle()
        switch options.kind {
        case .open:
            return runOpenPanel(directory: options.directoryPath, for: window).map { [$0] }
        case .save:
            return runSavePanel(directory: options.directoryPath,
                                suggestedName: options.fileName, for: window).map { [$0] }
        }
    }

    /// Runs a context menu at a screen point and returns the chosen item.
    ///
    /// GTK popover menus are asynchronous — they hand control back immediately
    /// and report the choice through the item's own action — so there is no
    /// selection to return synchronously here.
    public func runContextMenu(_ menu: NSMenu, atScreenPoint point: NSPoint) -> NSMenuItem? { nil }

    /// Runs the font panel. GTK4.6's font chooser is available, but the core's
    /// `NSFont` carries a family/size/weight triple that the dialog's Pango
    /// description does not round-trip cleanly, so the panel is not shown.
    public func runFontChooser(initialFont: NSFont?) -> NSFont? { nil }

    /// Runs a modal event loop for a window.
    public func runModal(for handle: NativeHandle) -> Int {
        showWindow(handle)
        let loop = g_main_loop_new(nil, gboolean(0))
        pushNestedLoop(loop)
        g_main_loop_run(loop)
        popNestedLoop()
        return coreSeam.modalCode
    }

    /// Ends the innermost modal loop.
    public func stopModal(withCode code: Int) {
        coreSeam.modalCode = code
        popNestedLoop()
    }

    /// Prints a view.
    public func runPrintOperation(for handle: NativeHandle, jobName: String,
                                  contentSize: NSSize) -> Bool {
        runPrintOperation(view: handle, jobTitle: jobName, parent: firstWindowHandle())
    }

    /// Dismisses a popover on the next click outside it. GTK popovers close
    /// themselves on an outside click, so no extra grab is needed.
    public func beginOutsideClickDismiss(for handle: NativeHandle,
                                         onDismiss: @escaping () -> Void) {}

    /// Ends outside-click dismissal.
    public func endOutsideClickDismiss() {}

    // MARK: System

    /// Runs a block on the next main-loop iteration.
    public func dispatchAsync(_ action: @escaping () -> Void) {
        scheduleTimer(interval: 0, repeats: false, action)
    }

    /// Schedules a repeating native timer, returning a token to cancel it with.
    public func scheduleNativeTimer(intervalMilliseconds: Int,
                                    action: @escaping () -> Void) -> UInt {
        let token = coreSeam.nextTimerID
        coreSeam.nextTimerID += 1
        scheduleTimer(interval: Double(intervalMilliseconds) / 1000.0, repeats: true, action)
        return token
    }

    /// Cancels a native timer.
    public func cancelNativeTimer(_ identifier: UInt) {
        if let source = coreSeam.timers.removeValue(forKey: identifier) {
            g_source_remove(source)
        }
    }

    /// Whether the desktop asks for a dark appearance.
    public func systemPrefersDarkAppearance() -> Bool {
        guard let settings = gtk_settings_get_default() else { return false }
        // `g_object_get` is a C variadic, which Swift cannot call, so read the
        // property through the GValue API instead.
        var value = GValue()
        g_value_init(&value, g_type_from_name("gboolean"))
        defer { g_value_unset(&value) }
        g_object_get_property(UnsafeMutablePointer<GObject>(settings),
                              "gtk-application-prefer-dark-theme", &value)
        return g_value_get_boolean(&value) != 0
    }

    /// The desktop accent color. Neither GTK nor freedesktop exposes one, so
    /// the framework's own default stands in (nil = "no system accent").
    public func systemAccentColor() -> NSColor? { nil }

    /// Sets the pointer cursor by framework name.
    public func setCursor(named name: String) {}

    /// Sets per-rectangle hover cursors. GTK sets a cursor per widget, not per
    /// sub-rectangle, so the first region's cursor covers the whole view.
    public func setCursorRegions(_ regions: [NativeCursorRegion], for handle: NativeHandle) {
        guard let w = widget(handle), let first = regions.first else { return }
        gtk_widget_set_cursor_from_name(asWidget(w), first.cursorName)
    }

    /// Every installed font family.
    public func fontFamilyNames() -> [String] {
        guard let map = pango_cairo_font_map_get_default() else { return [] }
        var families: UnsafeMutablePointer<UnsafeMutablePointer<PangoFontFamily>?>?
        var count: Int32 = 0
        pango_font_map_list_families(map, &families, &count)
        defer { g_free(families) }
        var names: [String] = []
        for index in 0..<Int(count) {
            guard let family = families?[index],
                  let name = pango_font_family_get_name(family) else { continue }
            names.append(String(cString: name))
        }
        return names.sorted()
    }

    /// Measures a single line of text.
    public func measureText(_ text: String, fontName: String, fontSize: CGFloat, weight: Int,
                            italic: Bool) -> NSSize {
        measure(text, fontName: fontName, fontSize: fontSize, weight: weight, italic: italic,
                wrappingAt: nil)
    }

    /// Measures text wrapped to a maximum width.
    public func measureText(_ text: String, fontName: String, fontSize: CGFloat, weight: Int,
                            italic: Bool, wrappingAt maxWidth: CGFloat) -> NSSize {
        measure(text, fontName: fontName, fontSize: fontSize, weight: weight, italic: italic,
                wrappingAt: maxWidth)
    }

    /// Lays `text` out in Pango and returns its pixel size.
    private func measure(_ text: String, fontName: String, fontSize: CGFloat, weight: Int,
                         italic: Bool, wrappingAt maxWidth: CGFloat?) -> NSSize {
        if coreSeam.measuringLabel == nil {
            let label = gtk_label_new(nil)
            g_object_ref_sink(label)
            coreSeam.measuringLabel = OpaquePointer(label)
        }
        guard let label = coreSeam.measuringLabel,
              let layout = gtk_widget_create_pango_layout(asWidget(label), text) else {
            return NSSize(width: 0, height: 0)
        }
        defer { g_object_unref(UnsafeMutableRawPointer(layout)) }
        let description = pango_font_description_new()
        defer { pango_font_description_free(description) }
        pango_font_description_set_family(description, fontName)
        pango_font_description_set_absolute_size(description, Double(fontSize) * Double(PANGO_SCALE))
        pango_font_description_set_weight(description, PangoWeight(rawValue: UInt32(max(100, min(1000, weight)))))
        if italic { pango_font_description_set_style(description, PANGO_STYLE_ITALIC) }
        pango_layout_set_font_description(layout, description)
        if let maxWidth {
            pango_layout_set_width(layout, Int32(maxWidth) * PANGO_SCALE)
            pango_layout_set_wrap(layout, PANGO_WRAP_WORD_CHAR)
        }
        var width: Int32 = 0, height: Int32 = 0
        pango_layout_get_pixel_size(layout, &width, &height)
        return NSSize(width: CGFloat(width), height: CGFloat(height))
    }

    // MARK: Clipboard

    /// Empties the clipboard.
    public func clearClipboard() {
        setClipboardString("")
        coreSeam.clipboardChangeCount += 1
    }

    /// How many times the clipboard has changed.
    public func clipboardChangeCount() -> Int { coreSeam.clipboardChangeCount }

    /// Whether the clipboard holds a format. GTK's clipboard is read
    /// asynchronously, so only the text the app itself wrote is known here.
    public func clipboardHasData(forFormat formatName: String) -> Bool {
        formatName.contains("text") && clipboardString() != nil
    }

    /// The clipboard's bytes for a format.
    public func clipboardData(forFormat formatName: String) -> [UInt8]? {
        guard clipboardHasData(forFormat: formatName), let text = clipboardString() else {
            return nil
        }
        return Array(text.utf8)
    }

    /// File paths on the clipboard.
    public func clipboardFilePaths() -> [String] { [] }

    // MARK: Color panel

    /// Runs the color panel.
    ///
    /// On GTK the color well *is* the chooser — `GtkColorButton` opens the
    /// desktop's own color dialog when clicked, which is how the demo's color
    /// well works. A standalone panel with no well to anchor it has nothing to
    /// open here, so `NSColorPanel.orderFront` alone shows nothing.
    public func runColorChooser(initialColor: NSColor) -> NSColor? { nil }

    // MARK: Scroll geometry

    /// The scroll view's current content offset.
    public func scrollViewContentOffset(for handle: NativeHandle) -> NSPoint {
        let offset = scrollOffset(for: handle)
        return NSPoint(x: CGFloat(offset.x), y: CGFloat(offset.y))
    }

    /// Scrolls the content to an offset.
    public func setScrollViewContentOffset(_ offset: NSPoint, for handle: NativeHandle) {
        setScrollOffset(x: Double(offset.x), y: Double(offset.y), for: handle)
    }

    /// Sets the scrollable content size and which scrollers show.
    ///
    /// GTK derives the scrollable extent from the child widget's own size
    /// request rather than being told it, so the content size arrives with the
    /// document view; only the scroller policy is set here.
    public func setScrollViewContentSize(_ contentSize: NSSize, viewportSize: NSSize,
                                         hasVerticalScroller: Bool,
                                         hasHorizontalScroller: Bool,
                                         for handle: NativeHandle) {
        setScrollerPolicy(vertical: hasVerticalScroller, horizontal: hasHorizontalScroller,
                          for: handle)
    }

    /// Sets a standalone scroller's value and knob size.
    public func setScrollerValue(_ value: Double, knobProportion: Double,
                                 for handle: NativeHandle) {
        setScrollerGeometry(value: value, knobProportion: knobProportion, for: handle)
    }

    /// Writes the pasteboard's contents.
    ///
    /// GDK's clipboard carries typed content providers; this seam mirrors the
    /// text flavor, which is what the demo's copy/paste path uses. Binary
    /// representations and file lists are not offered to other applications.
    public func setClipboardContents(text: String?, dataRepresentations: [String: [UInt8]],
                                     filePaths: [String]) {
        setClipboardString(text ?? "")
        coreSeam.clipboardChangeCount += 1
    }
}

/// The core's path-batch drawing context, drawn through GTK's Cairo one.
///
/// `NativeDrawingContext` hands over whole paths (`fillPath(segments, color)`);
/// `NativeGraphicsContext` is immediate-mode (`beginPath`, `move`, `fillPath`).
/// Replaying a segment list onto the immediate-mode calls is the whole job.
final class GTKCoreDrawingContext: NativeDrawingContext {
    private let context: NativeGraphicsContext

    init(_ context: NativeGraphicsContext) {
        self.context = context
    }

    private func replay(_ segments: [NativePathSegment]) {
        context.beginPath()
        for segment in segments {
            switch segment {
            case let .move(point):
                context.move(toX: Double(point.x), y: Double(point.y))
            case let .line(point):
                context.line(toX: Double(point.x), y: Double(point.y))
            case let .curve(to, control1, control2):
                context.curve(toX: Double(to.x), y: Double(to.y),
                              c1x: Double(control1.x), c1y: Double(control1.y),
                              c2x: Double(control2.x), c2y: Double(control2.y))
            case .close:
                context.closePath()
            }
        }
    }

    func fillPath(_ segments: [NativePathSegment], color: NSColor) {
        replay(segments)
        context.setFillColor(color)
        context.fillPath()
    }

    func strokePath(_ segments: [NativePathSegment], color: NSColor, lineWidth: CGFloat) {
        replay(segments)
        context.setStrokeColor(color)
        context.setLineWidth(Double(lineWidth))
        context.strokePath()
    }

    func drawText(_ text: String, at point: NSPoint, color: NSColor, fontName: String,
                  fontSize: CGFloat, weight: Int, italic: Bool) {
        context.drawText(text, at: point,
                         font: NativeFontSpec(family: fontName, size: Double(fontSize),
                                              bold: weight >= 600, italic: italic),
                         color: color)
    }

    func drawImage(atPath path: String, in rect: NSRect, tint: NSColor?) {
        context.drawImage(atPath: path, inRect: rect)
    }

    func drawLinearGradient(_ stops: [NativeGradientStop], in rect: NSRect, angle: CGFloat) {
        context.fillLinearGradient(stops, inRect: rect, angleDegrees: Double(angle))
    }

    func clip(to segments: [NativePathSegment]) {
        replay(segments)
        context.clipToCurrentPath()
    }

    func saveState() { context.saveState() }

    func restoreState() { context.restoreState() }
}

#endif  // canImport(CGTK)
