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
internal struct GTKCollectionFlowGeometry {
    let interitem: Double
    let line: Double
    let horizontal: Bool
}

internal struct GTKRGB {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
}

internal struct GTKGeometryAllocation {
    var width = -1
    var height = -1
    var x = Double.nan
    var y = Double.nan
}

internal struct GTKCustomizationWidgets {
    let content: UnsafeMutablePointer<GtkWidget>
    let stripHolder: UnsafeMutablePointer<GtkWidget>
    let paletteHolder: UnsafeMutablePointer<GtkWidget>
}

internal let gtkCompactControlCSS = """
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

/// GTK implementation of WinChocolate's native control backend.
public final class GTKNativeControlBackend: NativeControlBackend {

    internal var nextRaw: UInt = 1
    /// State the core-protocol seam needs (see "The core seam" at the end of
    /// this file). One property, because Swift cannot add stored properties in
    /// an extension and the class body has enough dictionaries already.
    let coreSeam = CoreSeamState()
    internal var widgets: [UInt: OpaquePointer] = [:]   // handle -> GtkWidget*
    internal var kinds: [UInt: InMemoryNativeControlBackend.Kind] = [:]
    internal var frames: [UInt: NSRect] = [:]
    internal var parents: [UInt: UInt] = [:]   // child -> parent, for repositioning
    internal var childrenByParent: [UInt: [UInt]] = [:]   // parent -> children, in add order
    internal var ranges: [UInt: (min: Double, max: Double)] = [:]   // slider/progress
    internal var indeterminateProgress: Set<UInt> = []
    internal var progressSpinners: Set<UInt> = []
    internal var progressPulseSources: [UInt: guint] = [:]
    internal var spinnerPhase: [UInt: Int] = [:]         // spinner -> rotation step
    internal var spinnerSources: [UInt: guint] = [:]     // spinner -> animation timeout
    internal var spinnerAnimating: Set<UInt> = []
    internal var stepperValues: [UInt: Double] = [:]     // stepper -> current value
    internal var stepperSteps: [UInt: Double] = [:]      // stepper -> increment
    internal var valueChangeActions: [UInt: (Double) -> Void] = [:]
    /// The target/action bridge is registered by both `NSControl` and some
    /// concrete subclasses while a peer is realized. GObject connections are
    /// additive, so retain the current handler and replace it on re-registration.
    internal var actionSignalHandlers: [UInt: (widget: OpaquePointer, id: gulong)] = [:]
    internal var comboEntries: [UInt: OpaquePointer] = [:]   // combo -> its GtkEntry child
    internal var splitPaneCounts: [UInt: Int] = [:]           // paned -> panes added
    internal var viewFixeds: [UInt: OpaquePointer] = [:]      // view -> child-hosting GtkFixed
    internal var datePickerEntries: [UInt: OpaquePointer] = [:]   // compact picker -> its GtkEntry
    internal var dateValues: [UInt: Date] = [:]                   // picker -> current date
    internal var dateRanges: [UInt: (min: Date?, max: Date?)] = [:]
    internal var dateStepActions: [UInt: (Int) -> Void] = [:]
    internal var dateCursorActions: [UInt: (Int) -> Void] = [:]
    internal var dateMoveActions: [UInt: (Int) -> Void] = [:]
    internal var dateTypeActions: [UInt: (String) -> Void] = [:]
    internal var levelValues: [UInt: Double] = [:]
    internal var levelStyles: [UInt: Int] = [:]
    internal var levelEditable: Set<UInt> = []
    internal var levelThresholds: [UInt: (warning: Double, critical: Double)] = [:]
    internal var levelChangeActions: [UInt: (Double) -> Void] = [:]
    internal var levelClickGestures: Set<UInt> = []   // indicators already wired for clicks
    internal var graphicalCalendars: [UInt: OpaquePointer] = [:]   // clockAndCalendar -> its GtkCalendar
    internal var suppressCalendarReport: Set<UInt> = []
    internal var scrollerAdjustments: [UInt: UnsafeMutablePointer<GtkAdjustment>] = [:]
    internal var scrollerActions: [UInt: (Double) -> Void] = [:]
    internal var suppressScrollerReport: Set<UInt> = []
    internal var suppressCursorReport: Set<UInt> = []
    internal var dateChangeActions: [UInt: (Date) -> Void] = [:]
    internal var viewDrawAreas: [UInt: OpaquePointer] = [:]   // view -> GtkDrawingArea
    internal var drawHandlers: [UInt: (NativeGraphicsContext, Double, Double) -> Void] = [:]
    internal var windowBoxes: [UInt: OpaquePointer] = [:]     // window -> vertical GtkBox child
    /// Windows whose document currently has unsaved changes, so the title-bar
    /// asterisk is added and removed exactly once per transition.
    internal var documentEditedHandles: Set<UInt> = []
    /// The file each window stands for, when it stands for one.
    internal var documentRepresentedPaths: [UInt: String?] = [:]
    internal var windowContents: [UInt: OpaquePointer] = [:]  // window -> current content widget
    internal var windowMenuBars: [UInt: OpaquePointer] = [:]  // window -> GtkPopoverMenuBar
    internal var windowToolbars: [UInt: OpaquePointer] = [:]  // window -> toolbar GtkBox
    internal var windowToolbarViews: [UInt: [OpaquePointer]] = [:] // window -> embedded view widgets (survive rebuild)
    internal var flippedViews: Set<UInt> = []  // parents that position children top-left
    internal var viewMagnifications: [UInt: Double] = [:]   // view -> NSScrollView magnification factor
    internal var graphicalDatePickers: Set<UInt> = []  // date pickers shown as a GtkCalendar
    internal var radiosByParent: [UInt: [UInt]] = [:]   // radio buttons grouped per superview
    // GTK 4.10 deprecated per-widget CSS providers (gtk_widget_get_style_context /
    // gtk_style_context_add_provider). The replacement is display-wide providers
    // plus a per-widget class: every styled widget carries a unique `lc-w<handle>`
    // class, and all rules at one priority live in a single provider that is
    // rebuilt whenever any of them changes.
    internal var scopedProviders: [Int32: UnsafeMutablePointer<GtkCssProvider>] = [:]  // priority -> provider
    internal var scopedRules: [Int32: [String: String]] = [:]       // priority -> ruleID -> css
    internal var segmentButtons: [UInt: [OpaquePointer]] = [:] // segmented -> its toggle buttons
    internal var tokenEntries: [UInt: OpaquePointer] = [:]     // token field -> its entry
    internal var tokenChips: [UInt: [OpaquePointer]] = [:]     // token field -> chip buttons
    internal var tokenValues: [UInt: [String]] = [:]           // token field -> tokens
    internal var tokenActions: [UInt: ([String]) -> Void] = [:]
    internal var tableColumnViews: [UInt: OpaquePointer] = [:] // table -> GtkColumnView
    internal var tableSelections: [UInt: OpaquePointer] = [:]  // table -> GtkSingleSelection
    internal var tableLists: [UInt: OpaquePointer] = [:]       // table -> GtkStringList model
    internal var tableRowCounts: [UInt: Int] = [:]
    internal var tableColumnCounts: [UInt: Int] = [:]
    internal var tableColumnObjects: [UInt: [OpaquePointer]] = [:] // table -> GtkColumnViewColumn list
    internal var tableProviders: [UInt: (Int, Int) -> String] = [:]
    internal var tableSortActions: [UInt: (Int, Bool) -> Void] = [:]     // (columnIndex, ascending)
    internal var tableActivateActions: [UInt: (Int) -> Void] = [:]       // double-click / Enter (row)
    internal var collectionLists: [UInt: OpaquePointer] = [:]  // collection -> GtkStringList
    internal var collectionItemCounts: [UInt: Int] = [:]
    internal var collectionProviders: [UInt: (Int) -> String] = [:]
    internal var collectionViewProviders: [UInt: (Int) -> NativeHandle?] = [:]
    internal var collectionFlows: [UInt: OpaquePointer] = [:]          // legacy single-flow lookup
    internal var collectionStacks: [UInt: OpaquePointer] = [:]         // collection -> vertical GtkBox
    internal var collectionSectionSpecs: [UInt: [NativeCollectionSection]] = [:]
    internal var collectionSectionFlows: [UInt: [(flow: OpaquePointer, base: Int)]] = [:]
    internal var collectionFlowGeometry: [UInt: GTKCollectionFlowGeometry] = [:]
    internal var windowResizeActions: [UInt: (Double, Double) -> Void] = [:]
    internal var windowCloseActions: [UInt: () -> Void] = [:]
    internal var windowShouldCloseHandlers: [UInt: () -> Bool] = [:]
    internal var primaryWindows: Set<UInt> = []
    internal var contentViewOwners: [UInt: UInt] = [:]     // content view -> its window
    internal var lastContentSizes: [UInt: NSSize] = [:]
    /// Windows that have already been through first-show setup.
    internal var presentedWindows: Set<UInt> = []
    // ── Paint tracing (LINCHOCOLATE_PAINT_TRACE=1) ────────────────────────────
    // Answers "where do the repaints come from" with evidence instead of
    // theory: every window lifecycle step and every frame-clock cycle is logged
    // with a timestamp, the window's size and its content's allocation, so a
    // repaint storm shows up as either repeated frames at a STABLE size (damage
    // /expose) or frames whose size KEEPS CHANGING (re-layout).
    internal lazy var paintTrace: Bool =
        !(ProcessInfo.processInfo.environment["LINCHOCOLATE_PAINT_TRACE"] ?? "").isEmpty
    internal let paintTraceStart = g_get_monotonic_time()
    internal var paintTraceFrames: [UInt: Int] = [:]
    internal var paintTraceLastSize: [UInt: (Int32, Int32)] = [:]
    internal var paintTraceMapped: [UInt: gint64] = [:]
    internal var paintTraceReported: Set<UInt> = []   // collection -> GtkFlowBox
    internal var collectionSelectionActions: [UInt: (Int) -> Void] = [:]
    internal var suppressCollectionSelection: Set<UInt> = []
    internal var clickActionBoxes: [UInt: Bool] = [:]
    internal var outlineColumnViews: [UInt: OpaquePointer] = [:]
    internal var outlineRootLists: [UInt: OpaquePointer] = [:]
    internal var outlineRootCounts: [UInt: Int] = [:]
    internal var outlineColumnCounts: [UInt: Int] = [:]
    internal var outlineChildCountProviders: [UInt: (String) -> Int] = [:]
    internal var outlineCellTextProviders: [UInt: (String, Int) -> String] = [:]
    internal var widgetFonts: [UInt: NativeFontSpec] = [:]     // style state per widget
    internal var widgetTextColors: [UInt: NSColor] = [:]
    internal var menuActionCounter = 0                         // unique GAction names
    internal var nonComposited = false                         // display lacks alpha compositing
    internal var mainLoop: OpaquePointer?   // GMainLoop* (opaque in the GTK import)
    internal var nestedLoops: [OpaquePointer] = []
    internal var stoppingNestedLoops: Set<OpaquePointer> = []
    internal var prefersDarkAppearance = false
    internal var clipboardMirror: String?
    internal var customizationState: CustomizationPanelState?
    internal var popoverParented: Set<UInt> = []
    internal var editableTableColumns: [UInt: Set<Int>] = [:]
    internal var tableCommitActions: [UInt: (Int, Int, String) -> Void] = [:]
    internal var imageViewPaths: [UInt: String] = [:]
    internal var imageViewTints: [UInt: GTKRGB] = [:]
    internal var zoomedWindows: Set<UInt> = []
    internal var preZoomContentSize: [UInt: (Int32, Int32)] = [:]
    internal var sliderSnapTicks: [UInt: Int] = [:]
    internal var suppressSliderReport: Set<UInt> = []

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
    internal func installCompactControlStyle() {
        guard let display = gdk_display_get_default() else { return }
        let css = gtkCompactControlCSS
        guard let provider = gtk_css_provider_new() else { return }
        lc_css_provider_load(provider, css)
        // 590 < the toolbar/app provider (600) so per-widget rules still win.
        gtk_style_context_add_provider_for_display(display, OpaquePointer(provider), 590)

        // The GtkColorChooserDialog the well opens packs its palette, editor and
        // action buttons flush against the window border. Inset them so the
        // controls have breathing room, like AppKit's colour panel. This must
        // sit ABOVE the theme (600) — the Adwaita rules that zero these margins
        // would otherwise win — so it rides at USER priority (800).
        installColorChooserStyle(on: display)
    }

    internal func installColorChooserStyle(on display: OpaquePointer) {
        let css = """
            colorchooser { padding: 16px 16px 8px 16px; }
            box.dialog-action-area { margin: 0 16px 14px 0; }
            """
        guard let provider = gtk_css_provider_new() else {
            return
        }
        lc_css_provider_load(provider, css)
        gtk_style_context_add_provider_for_display(display, OpaquePointer(provider), 800)
    }

    /// Display-wide CSS for the Apple-look toolbar (the deliberate Apple
    /// look-and-feel exception, Goal 2): a light gradient strip with a hairline
    /// bottom border and flat, hover-highlighted text buttons.
}

#endif
