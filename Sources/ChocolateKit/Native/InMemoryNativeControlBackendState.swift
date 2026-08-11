public final class InMemoryNativeControlBackend: NativeControlBackend {
    /// The kind of a native object — see `NativeControlKind`, which this names
    /// for the backends and tests that grew up spelling it
    /// `InMemoryNativeControlBackend.Kind`.
    public typealias Kind = NativeControlKind
    /// A recorded native object request.
    public typealias Record = InMemoryNativeRecord

    /// One recorded rich-text range formatting request.
    public typealias TextRangeFormat = InMemoryTextRangeFormat
    internal var nextRawHandle: UInt = 1

    /// Recorded native object requests by handle.
    public internal(set) var records: [NativeHandle: Record] = [:]

    /// Registered control actions by handle.
    public internal(set) var actions: [NativeHandle: () -> Void] = [:]

    /// Last actuated scroller part by handle.
    internal var scrollerParts: [NativeHandle: NativeScrollerPart] = [:]

    /// Recorded scroller overlay flag by handle (test-visible).
    public internal(set) var scrollerOverlays: [NativeHandle: Bool] = [:]

    /// Recorded scroller knob style by handle (test-visible).
    public internal(set) var scrollerKnobStyles: [NativeHandle: NativeScrollerKnobStyle] = [:]

    /// Registered text change actions by handle.
    public internal(set) var textChangeActions: [NativeHandle: (String) -> Void] = [:]

    /// Registered mouse-down actions by handle.
    public internal(set) var mouseDownActions: [NativeHandle: (NSEvent) -> Void] = [:]

    /// Registered mouse-up actions by handle.
    public internal(set) var mouseUpActions: [NativeHandle: (NSEvent) -> Void] = [:]

    /// Registered mouse-moved actions by handle.
    public internal(set) var mouseMovedActions: [NativeHandle: (NSEvent) -> Void] = [:]

    /// Registered mouse-dragged actions by handle.
    public internal(set) var mouseDraggedActions: [NativeHandle: (NSEvent) -> Void] = [:]

    /// Registered key-down actions by handle.
    public internal(set) var keyDownActions: [NativeHandle: (NSEvent) -> Void] = [:]

    /// Registered key-up actions by handle.
    public internal(set) var keyUpActions: [NativeHandle: (NSEvent) -> Void] = [:]

    /// Registered native window close actions by handle.
    public internal(set) var windowCloseActions: [NativeHandle: () -> Void] = [:]

    /// Registered native window resize actions by handle.
    public internal(set) var windowResizeActions: [NativeHandle: (NSSize) -> Void] = [:]

    /// Registered toolbar item actions by handle.
    public internal(set) var toolbarActions: [NativeHandle: (String) -> Void] = [:]

    /// The handle most recently asked to take keyboard focus.
    public internal(set) var focusedHandle: NativeHandle?

    /// Handles most recently raised above siblings.
    public internal(set) var raisedHandles: [NativeHandle] = []

    /// Whether the application run loop has been requested.
    public internal(set) var didRunApplication = false

    /// Whether application termination has been requested.
    public internal(set) var didTerminateApplication = false

    /// Most recently installed main menu.
    public internal(set) weak var installedMainMenu: NSMenu?


    /// The recorded owner of each auxiliary window.
    public internal(set) var windowParents: [NativeHandle: NativeHandle] = [:]

    /// Recorded clipboard text, when any.
    public internal(set) var clipboardText: String?

    /// Recorded clipboard data representations by platform format name.
    public internal(set) var clipboardDataRepresentations: [String: [UInt8]] = [:]

    /// Number of recorded clipboard changes.
    public internal(set) var clipboardChanges = 0

    /// Recorded clipboard file paths, when any.
    public internal(set) var clipboardFileList: [String] = []

    /// Registered focus-change actions by handle.
    public internal(set) var focusChangeActions: [NativeHandle: (Bool) -> Void] = [:]

    /// Registered mouse-left actions by handle.
    public internal(set) var mouseLeftActions: [NativeHandle: () -> Void] = [:]

    /// Registered right mouse-down actions by handle.
    public internal(set) var rightMouseDownActions: [NativeHandle: (NSEvent) -> Void] = [:]

    /// Registered right mouse-up actions by handle.
    public internal(set) var rightMouseUpActions: [NativeHandle: (NSEvent) -> Void] = [:]

    /// Registered tertiary mouse-down actions by handle.
    public internal(set) var otherMouseDownActions: [NativeHandle: (NSEvent) -> Void] = [:]

    /// Registered tertiary mouse-up actions by handle.
    public internal(set) var otherMouseUpActions: [NativeHandle: (NSEvent) -> Void] = [:]

    /// Registered scroll-wheel actions by handle.
    public internal(set) var scrollWheelActions: [NativeHandle: (NSEvent) -> Void] = [:]

    /// Registered draw actions by handle.
    public internal(set) var drawActions: [NativeHandle: (NativeDrawingContext, NSRect) -> Void] = [:]

    /// Handles that requested a repaint, in request order.
    public internal(set) var invalidatedHandles: [NativeHandle] = []
    /// Handles invalidated together with their descendant tree.
    public internal(set) var invalidatedTreeHandles: [NativeHandle] = []

    /// File dialog descriptors received through `runFileDialog`, oldest first.
    public internal(set) var fileDialogRequests: [NativeFileDialogOptions] = []

    /// Paths returned by the next `runFileDialog` calls, consumed in order.
    ///
    /// Each element scripts one dialog run; `nil` scripts a user cancel. When
    /// the queue is empty, dialogs report cancel.
    public var scriptedFileDialogPaths: [[String]?] = []

    /// Initial colors received through `runColorChooser`, oldest first.
    public internal(set) var colorChooserRequests: [NSColor] = []

    /// The color returned by the next `runColorChooser` call; `nil` scripts a
    /// user cancel.
    public var nextColorChooserResult: NSColor?

    /// Initial fonts received through `runFontChooser`, oldest first.
    public internal(set) var fontChooserRequests: [NSFont?] = []

    /// The font returned by the next `runFontChooser` call; `nil` scripts a
    /// user cancel.
    public var nextFontChooserResult: NSFont?

    /// Windows that ran modal sessions, oldest first.
    public internal(set) var modalSessions: [NativeHandle] = []

    /// Stop codes recorded through `stopModal`, oldest first.
    public internal(set) var modalStopCodes: [Int] = []

    /// The code returned by the next `runModal` call.
    public var nextModalResponseCode: Int = NSApplication.ModalResponse.alertFirstButtonReturn.rawValue

    /// Recorded indeterminate state by handle.
    public internal(set) var progressIndeterminateStates: [NativeHandle: (isIndeterminate: Bool, animating: Bool)] = [:]

    /// Cursor names requested through `setCursor(named:)`, oldest first.
    public internal(set) var cursorNames: [String] = []

    /// Hover cursor regions by handle.
    public internal(set) var cursorRegions: [NativeHandle: [NativeCursorRegion]] = [:]

    /// Scheduled run-loop timers, oldest first.
    public internal(set) var scheduledTimers: [ScheduledTimer] = []

    /// Identifiers of canceled run-loop timers, oldest first.
    public internal(set) var canceledTimerIdentifiers: [UInt] = []

    internal var timerActions: [UInt: () -> Void] = [:]
    internal var nextTimerIdentifier: UInt = 1

    /// The most recently registered key-equivalent handler.
    public internal(set) var keyEquivalentHandler: ((NSEvent) -> Bool)?

    /// Menus popped through `runContextMenu`, oldest first.
    public internal(set) var poppedContextMenus: [NSMenu] = []

    /// Index into the popped menu's depth-first flattened items selected by the
    /// next `runContextMenu` call; `-1` scripts a user cancel.
    public var nextContextMenuSelection: Int = -1


    /// Recorded in-memory backend state for `testScreenFrame`.
    public var testScreenFrame = NSRect(x: 0, y: 0, width: 1024, height: 768)

    /// Recorded in-memory backend state for `simulatedDarkAppearance`.
    public var simulatedDarkAppearance = false

    /// Recorded in-memory backend state for `simulatedAccentColor`.
    public var simulatedAccentColor: NSColor?

    /// Recorded in-memory backend state for `testScreens`.
    public var testScreens: [NativeScreenDescription]?

    /// Recorded in-memory backend state for `minimizedWindows`.
    public internal(set) var minimizedWindows: Set<NativeHandle> = []

    /// Recorded in-memory backend state for `zoomedWindows`.
    public internal(set) var zoomedWindows: Set<NativeHandle> = []

    /// Recorded in-memory backend state for `fullScreenWindows`.
    public internal(set) var fullScreenWindows: Set<NativeHandle> = []

    /// Recorded in-memory backend state for `windowsOrderedBack`.
    public internal(set) var windowsOrderedBack: [NativeHandle] = []

    /// Recorded in-memory backend state for `windowMoveActions`.
    public internal(set) var windowMoveActions: [NativeHandle: (NSPoint) -> Void] = [:]

    /// Recorded in-memory backend state for `dropHandlers`.
    public internal(set) var dropHandlers: [NativeHandle: NativeDropHandler] = [:]

    /// Recorded in-memory backend state for `unregisteredDropTargets`.
    public internal(set) var unregisteredDropTargets: [NativeHandle] = []

    /// Recorded in-memory backend state for `performedDrags`.
    public internal(set) var performedDrags: [(content: NativeDropContent, handle: NativeHandle)] = []

    /// Recorded in-memory backend state for `nextDragResult`.
    public var nextDragResult = false

    /// Recorded in-memory backend state for `printJobs`.
    public internal(set) var printJobs: [PrintJob] = []

    /// Recorded in-memory backend state for `nextPrintResult`.
    public var nextPrintResult = true

    /// Recorded in-memory backend state for `windowButtonsHidden`.
    public internal(set) var windowButtonsHidden: [NativeHandle: NativeWindowButtonVisibility] = [:]

    /// Recorded in-memory backend state for `fadedWindows`.
    public internal(set) var fadedWindows: [NativeHandle: Bool] = [:]

    /// Recorded in-memory backend state for `windowShouldCloseHandlers`.
    public internal(set) var windowShouldCloseHandlers: [NativeHandle: () -> Bool] = [:]

    /// Recorded in-memory backend state for `multilineTextFields`.
    public internal(set) var multilineTextFields: [NativeHandle: Bool] = [:]

    /// Recorded in-memory backend state for `textRangeAlignments`.
    public internal(set) var textRangeAlignments: [UInt: [TextRangeAlignment]] = [:]

    /// Recorded in-memory backend state for `setFrameCallCounts`.
    public internal(set) var setFrameCallCounts: [NativeHandle: Int] = [:]

    /// Recorded in-memory backend state for `sliderTicksAboveOrLeading`.
    public internal(set) var sliderTicksAboveOrLeading: [NativeHandle: Bool] = [:]

    /// Recorded in-memory backend state for `flatBezelButtons`.
    public internal(set) var flatBezelButtons: [NativeHandle: Bool] = [:]

    /// Recorded in-memory backend state for `bezeledTextFields`.
    public internal(set) var bezeledTextFields: [NativeHandle: Bool] = [:]

    /// Recorded in-memory backend state for `windowDragViewHandles`.
    public internal(set) var windowDragViewHandles: Set<NativeHandle> = []

    /// Recorded in-memory backend state for `outsideClickDismissHandle`.
    public internal(set) var outsideClickDismissHandle: NativeHandle?

    /// Recorded in-memory backend state for `outsideClickDismissAction`.
    public internal(set) var outsideClickDismissAction: (() -> Void)?

    /// Recorded in-memory backend state for `scriptedDisplayScale`.
    public var scriptedDisplayScale: CGFloat = 1.0

    /// Recorded in-memory backend state for `editableLevelRanges`.
    internal var editableLevelRanges: [NativeHandle: (minValue: Double, maxValue: Double)] = [:]

    /// Recorded in-memory backend state for `levelIndicatorValues`.
    internal var levelIndicatorValues: [NativeHandle: Double] = [:]

    /// Recorded in-memory backend state for `stepperWraps`.
    public internal(set) var stepperWraps: [NativeHandle: Bool] = [:]

    /// Recorded in-memory backend state for `tableSelectedRowSets`.
    public internal(set) var tableSelectedRowSets: [NativeHandle: [Int]] = [:]

    /// Recorded in-memory backend state for `tableAllowsMultipleSelection`.
    public internal(set) var tableAllowsMultipleSelection: [NativeHandle: Bool] = [:]

    /// Recorded in-memory backend state for `tableEditableHandles`.
    public internal(set) var tableEditableHandles: Set<NativeHandle> = []

    /// Recorded in-memory backend state for `tableSortIndicators`.
    public internal(set) var tableSortIndicators: [NativeHandle: (column: Int, ascending: Bool)] = [:]

    /// Recorded in-memory backend state for `tableEditActionsByHandle`.
    internal var tableEditActionsByHandle: [NativeHandle: (Int, Int, String) -> Void] = [:]

    /// Recorded in-memory backend state for `tableDoubleClickActionsByHandle`.
    internal var tableDoubleClickActionsByHandle: [NativeHandle: () -> Void] = [:]

    internal var dateStepActions: [NativeHandle: (Int) -> Void] = [:]
    internal var datePickerCursorActions: [NativeHandle: (Int) -> Void] = [:]
    internal var datePickerMoveActions: [NativeHandle: (Int) -> Void] = [:]
    internal var datePickerTypeActions: [NativeHandle: (String) -> Void] = [:]

    /// Rendered framework-owned date-field text by handle.
    public internal(set) var datePickerTexts: [NativeHandle: String] = [:]

    /// Selected framework-owned date-field ranges by handle.
    public internal(set) var datePickerSelections: [NativeHandle: (location: Int, length: Int)] = [:]

    /// Creates an in-memory backend.
    public init() {}
}
