/// Records native-backend operations in memory for deterministic tests.
///
/// It is also the base class a *new* backend starts from. `NativeControlBackend`
/// has 189 requirements and this type implements all of them, so a backend under
/// construction can subclass it and override only what it has really built: the
/// rest keep recording, which is precisely the "honest no-op" the porting rules
/// ask for — nothing crashes, nothing lies, and the recorded state is still
/// inspectable from a test. (That is why the class is not `final`.) A finished
/// backend is expected to override everything and stop inheriting behaviour.
public class InMemoryNativeControlBackend: NativeControlBackend {
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

    /// Handles asked to clip their children to their bounds.
    public internal(set) var clippingHandles: Set<NativeHandle> = []

    /// Handles that measure their children from the bottom edge.
    public internal(set) var unflippedHandles: Set<NativeHandle> = []

    /// AppKit class names reported through `setDebugClassName(_:for:)`.
    ///
    /// Diagnostics only — nothing about rendering may read this. Recorded
    /// rather than dropped so a test can assert which class a handle came from.
    public internal(set) var debugClassNames: [NativeHandle: String] = [:]

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

    // MARK: - Overridable core seam
    //
    // These live in the class body rather than an extension for one
    // reason: Swift cannot override a method declared in an extension, and
    // a backend under construction subclasses this type to inherit honest
    // no-ops for everything it has not built yet. This is the slice a
    // backend must answer for before anything appears on screen.

    /// Updates a recorded control text value.
    public func setText(_ text: String, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.text = text
        records[handle] = record
    }

    /// Updates a recorded control frame.
    public func setFrame(_ frame: NSRect, for handle: NativeHandle) {
        setFrameCallCounts[handle, default: 0] += 1
        guard var record = records[handle] else {
            return
        }

        // Scaled views record magnified native geometry, mirroring Win32.
        let scale = record.contentScale
        record.frame = scale == 1 ? frame : NSRect(
            x: frame.origin.x * scale,
            y: frame.origin.y * scale,
            width: frame.size.width * scale,
            height: frame.size.height * scale
        )
        records[handle] = record
    }

    /// Updates a recorded hidden state.
    public func setHidden(_ isHidden: Bool, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.isHidden = isHidden
        records[handle] = record
    }

    /// Updates a recorded enabled state.
    public func setEnabled(_ isEnabled: Bool, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.isEnabled = isEnabled
        records[handle] = record
    }

    /// Records that the application run loop was requested.
    public func runApplication() {
        didRunApplication = true
    }

    /// Records that application termination was requested.
    public func terminateApplication() {
        didTerminateApplication = true
    }

    /// Runs deferred work immediately in deterministic tests.
    public func dispatchAsync(_ action: @escaping () -> Void) {
        action()
    }

    /// Records the installed main menu.
    public func installMainMenu(_ menu: NSMenu?) {
        installedMainMenu = menu
    }

    /// Records a top-level window creation request.
    public func createWindow(title: String, frame: NSRect, styleMask: NSWindow.StyleMask, usesMainMenu: Bool) -> NativeHandle {
        let handle = makeHandle(kind: "window", text: title, frame: frame, parent: nil)
        records[handle]?.usesMainMenu = usesMainMenu
        records[handle]?.isHidden = true
        return handle
    }

    /// Records that a window should be shown.
    public func showWindow(_ handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.isHidden = false
        records[handle] = record
    }

    /// Removes a recorded native object.
    public func closeWindow(_ handle: NativeHandle) {
        records.removeValue(forKey: handle)
        actions.removeValue(forKey: handle)
        mouseDownActions.removeValue(forKey: handle)
        mouseUpActions.removeValue(forKey: handle)
        mouseMovedActions.removeValue(forKey: handle)
        mouseDraggedActions.removeValue(forKey: handle)
        keyDownActions.removeValue(forKey: handle)
        keyUpActions.removeValue(forKey: handle)
        toolbarActions.removeValue(forKey: handle)
        windowResizeActions.removeValue(forKey: handle)
        windowCloseActions.removeValue(forKey: handle)?()
    }

    /// Records a view creation request.
    public func createView(frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        makeHandle(kind: "view", text: "", frame: frame, parent: parent)
    }

    /// Records a button creation request.
    public func createButton(title: String, frame: NSRect, parent: NativeHandle?, isBordered: Bool) -> NativeHandle {
        makeHandle(kind: "button", text: title, frame: frame, parent: parent)
    }

    /// Performs the `createTextField` operation.
    public func createTextField(
        text: String,
        frame: NSRect,
        parent: NativeHandle?,
        options: NativeTextFieldOptions
    ) -> NativeHandle {
        let kind = options.isEditable ? "editableTextField" : "textField"
        let handle = makeHandle(kind: kind, text: text, frame: frame, parent: parent)
        multilineTextFields[handle] = options.isMultiline
        return handle
    }

    /// Records a control action.
    public func registerAction(for handle: NativeHandle, action: @escaping () -> Void) {
        actions[handle] = action
    }

    /// Measures text with a deterministic estimate for tests.
    public func measureText(_ text: String, font: NativeFontSpec) -> NSSize {
        NSMakeSize(CGFloat(text.count) * font.size * 0.55, font.size * 1.35)
    }

    /// Records a view's clip-to-bounds state.
    public func setClipsToBounds(_ clips: Bool, for handle: NativeHandle) {
        if clips {
            clippingHandles.insert(handle)
        } else {
            clippingHandles.remove(handle)
        }
    }

    /// Whether the backend wants class-name diagnostics. Off, as for every
    /// finished backend.
    ///
    /// Declared here rather than left to the protocol's default for the reason
    /// this whole section exists: a default living in a protocol extension is
    /// not an overridable class member, so a subclass that "overrode" it would
    /// compile only if it dropped `override` — and would then be ignored,
    /// because the conformance witness still resolved to the default. Both
    /// members are therefore class members here.
    public var wantsDebugClassNames: Bool { false }

    /// Records the AppKit class behind a handle, for diagnostics.
    public func setDebugClassName(_ name: String, for handle: NativeHandle) {
        debugClassNames[handle] = name
    }

    /// Records which edge a view measures its children from.
    ///
    /// Declared here, not left to the protocol's default, for the reason given
    /// above: a default in a protocol extension is not an overridable class
    /// member, so a backend that needs to act on it could never be called.
    public func setViewFlipped(_ flipped: Bool, for handle: NativeHandle) {
        if flipped {
            unflippedHandles.remove(handle)
        } else {
            unflippedHandles.insert(handle)
        }
    }

    // MARK: - Overridable core seam · controls
    //
    // Moved here verbatim from `InMemoryNativeControlBackendControls.swift` for
    // the reason given above: an extension method cannot be overridden, and a
    // backend under construction has to be able to replace every creator and
    // every writer one at a time. The bodies are unchanged; only the file is.

    /// Records native title-bar button visibility.
    public func setWindowButtonsHidden(closeHidden: Bool, minimizeHidden: Bool, zoomHidden: Bool, for handle: NativeHandle) {
        windowButtonsHidden[handle] = NativeWindowButtonVisibility(
            close: closeHidden,
            minimize: minimizeHidden,
            zoom: zoomHidden
        )
    }

    /// Records a fade show/hide request and updates visibility.
    public func fadeWindow(_ handle: NativeHandle, visible: Bool) {
        fadedWindows[handle] = visible
        guard var record = records[handle] else {
            return
        }

        record.isHidden = !visible
        records[handle] = record
    }

    /// Records a native window close action.
    public func registerWindowCloseAction(for handle: NativeHandle, action: @escaping () -> Void) {
        windowCloseActions[handle] = action
    }

    /// Records a window close-veto handler.
    public func registerWindowShouldCloseHandler(for handle: NativeHandle, handler: @escaping () -> Bool) {
        windowShouldCloseHandlers[handle] = handler
    }

    /// Records a native window resize action.
    public func registerWindowResizeAction(for handle: NativeHandle, action: @escaping (NSSize) -> Void) {
        windowResizeActions[handle] = action
    }

    /// Removes a recorded native child object.
    public func destroyControl(_ handle: NativeHandle) {
        records.removeValue(forKey: handle)
        actions.removeValue(forKey: handle)
        mouseDownActions.removeValue(forKey: handle)
        mouseUpActions.removeValue(forKey: handle)
        mouseMovedActions.removeValue(forKey: handle)
        mouseDraggedActions.removeValue(forKey: handle)
        keyDownActions.removeValue(forKey: handle)
        keyUpActions.removeValue(forKey: handle)
        toolbarActions.removeValue(forKey: handle)
        windowResizeActions.removeValue(forKey: handle)
    }

    /// Records a checkbox creation request.
    public func createCheckbox(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        makeHandle(kind: "checkbox", text: title, frame: frame, parent: parent)
    }

    /// Records a radio button creation request.
    public func createRadioButton(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        makeHandle(kind: "radioButton", text: title, frame: frame, parent: parent)
    }

    /// Records a box creation request.
    public func createBox(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        makeHandle(kind: "box", text: title, frame: frame, parent: parent)
    }

    /// Records a secure text field creation request.
    public func createSecureTextField(text: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        makeHandle(kind: "secureTextField", text: text, frame: frame, parent: parent)
    }

    /// Records a text view creation request.
    public func createTextView(text: String, frame: NSRect, parent: NativeHandle?, isEditable: Bool, isRichText: Bool) -> NativeHandle {
        let handle = makeHandle(kind: isEditable ? "editableTextView" : "textView", text: text, frame: frame, parent: parent)
        records[handle]?.isTextEditable = isEditable
        records[handle]?.isRichText = isRichText
        return handle
    }

    /// Records a rich-text range formatting request.
    public func setTextRangeFormat(_ format: NativeTextRangeFormat, for handle: NativeHandle) {
        records[handle]?.textRangeFormats.append(TextRangeFormat(
            font: format.font,
            color: format.color,
            underline: format.underline,
            strikethrough: format.strikethrough,
            location: format.range.location,
            length: format.range.length
        ))
    }

    /// Records a paragraph-alignment application.
    public func setTextRangeAlignment(_ alignment: NSTextAlignment, location: Int, length: Int, for handle: NativeHandle) {
        textRangeAlignments[handle.rawValue, default: []].append(TextRangeAlignment(alignment: alignment, location: location, length: length))
    }

    /// Records a pop-up button creation request.
    public func createPopUpButton(items: [String], selectedIndex: Int, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = makeHandle(kind: "popUpButton", text: items.indices.contains(selectedIndex) ? items[selectedIndex] : "", frame: frame, parent: parent)
        records[handle]?.popUpItems = items
        records[handle]?.popUpSelectedIndex = selectedIndex
        return handle
    }

    /// Records a combo-box creation request.
    public func createComboBox(items: [String], text: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = makeHandle(kind: "comboBox", text: text, frame: frame, parent: parent)
        records[handle]?.comboBoxItems = items
        return handle
    }

    /// Records an image-view creation request.
    public func createImageView(description: String, imagePath: String?, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = makeHandle(kind: "imageView", text: description, frame: frame, parent: parent)
        records[handle]?.imagePath = imagePath
        return handle
    }

    /// Records a tab-view creation request.
    public func createTabView(items: [String], selectedIndex: Int, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = makeHandle(kind: "tabView", text: items.indices.contains(selectedIndex) ? items[selectedIndex] : "", frame: frame, parent: parent)
        records[handle]?.tabViewItems = items
        records[handle]?.tabViewSelectedIndex = selectedIndex
        return handle
    }

    /// Records a toolbar creation request.
    public func createToolbar(items: [NativeToolbarItem], frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = makeHandle(kind: "toolbar", text: "", frame: frame, parent: parent)
        records[handle]?.toolbarItems = items
        return handle
    }

    /// Replaces recorded toolbar items.
    public func setToolbarItems(_ items: [NativeToolbarItem], for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.toolbarItems = items
        records[handle] = record
    }

    /// Records a toolbar action.
    public func registerToolbarAction(for handle: NativeHandle, action: @escaping (String) -> Void) {
        toolbarActions[handle] = action
    }

    /// Records a slider creation request.
    public func createSlider(value: Double, minValue: Double, maxValue: Double, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = makeHandle(kind: "slider", text: "", frame: frame, parent: parent)
        records[handle]?.sliderMinValue = minValue
        records[handle]?.sliderMaxValue = maxValue
        records[handle]?.sliderValue = value
        return handle
    }

    /// Records a progress indicator creation request.
    public func createProgressIndicator(value: Double, minValue: Double, maxValue: Double, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = makeHandle(kind: "progressIndicator", text: "", frame: frame, parent: parent)
        records[handle]?.progressMinValue = minValue
        records[handle]?.progressMaxValue = maxValue
        records[handle]?.progressValue = value
        return handle
    }

    /// Records a scroller creation request.
    public func createScroller(value: Double, knobProportion: Double, isVertical: Bool, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = makeHandle(kind: "scroller", text: "", frame: frame, parent: parent)
        records[handle]?.sliderMinValue = 0
        records[handle]?.sliderMaxValue = 1
        records[handle]?.sliderValue = value
        records[handle]?.scrollerKnobProportion = knobProportion
        records[handle]?.scrollerIsVertical = isVertical
        return handle
    }

    /// Records a stepper creation request.
    public func createStepper(
        configuration: NativeStepperConfiguration,
        frame: NSRect,
        parent: NativeHandle?
    ) -> NativeHandle {
        let handle = makeHandle(kind: "stepper", text: "", frame: frame, parent: parent)
        records[handle]?.stepperMinValue = configuration.minValue
        records[handle]?.stepperMaxValue = configuration.maxValue
        records[handle]?.stepperIncrement = configuration.increment
        records[handle]?.stepperValue = configuration.value
        return handle
    }

    /// Records a date picker creation request.
    public func createDatePicker(
        configuration: NativeDatePickerConfiguration,
        frame: NSRect,
        parent: NativeHandle?
    ) -> NativeHandle {
        let kind = configuration.style == .clockAndCalendar ? "calendarDatePicker" : "datePicker"
        let handle = makeHandle(kind: kind, text: "", frame: frame, parent: parent)
        records[handle]?.datePickerDate = configuration.date
        records[handle]?.datePickerMinDate = configuration.minDate
        records[handle]?.datePickerMaxDate = configuration.maxDate
        // The stepper is the observable half of `.textFieldAndStepper` — the
        // style is named for it, and a field without one is the bug this
        // records so a test can catch.
        records[handle]?.datePickerShowsStepper = configuration.style == .textFieldAndStepper
        return handle
    }

    // MARK: - Overridable core seam · drawing, timers, cursors, menus
    //
    // Moved verbatim from `InMemoryNativeControlBackendDrawing.swift`.

    /// Records a modal stop request.
    public func stopModal(withCode code: Int) {
        modalStopCodes.append(code)
    }

    /// Deterministic word-wrap estimate: the single-line metrics (`0.55 ×
    /// pointSize` per character, `1.35 × pointSize` per line) greedily packed
    /// into `maxWidth`-wide lines. Height is line count × line height; width is
    /// the widest packed line (≤ `maxWidth`).
    public func measureText(_ text: String, font: NativeFontSpec, wrappingAt maxWidth: CGFloat) -> NSSize {
        let charWidth = font.size * 0.55
        let lineHeight = font.size * 1.35
        guard maxWidth > 0, charWidth > 0 else {
            return measureText(text, font: font)
        }

        let maxChars = max(1, Int(maxWidth / charWidth))
        var lineCount = 0
        var widestChars = 0
        for paragraph in text.split(separator: "\n", omittingEmptySubsequences: false) {
            var currentChars = 0
            var lineStarted = false
            for word in paragraph.split(separator: " ", omittingEmptySubsequences: false) {
                let addition = lineStarted ? word.count + 1 : word.count
                if lineStarted, currentChars + addition > maxChars {
                    lineCount += 1
                    widestChars = max(widestChars, currentChars)
                    currentChars = word.count
                } else {
                    currentChars += addition
                }
                lineStarted = true
            }
            lineCount += 1
            widestChars = max(widestChars, currentChars)
        }

        let width = min(CGFloat(widestChars) * charWidth, maxWidth)
        return NSMakeSize(width, CGFloat(max(lineCount, 1)) * lineHeight)
    }

    /// Records native progress indeterminate state.
    public func setProgressIndicatorIndeterminate(_ isIndeterminate: Bool, animating: Bool, for handle: NativeHandle) {
        progressIndeterminateStates[handle] = (isIndeterminate, animating)
    }

    /// Records a cursor request.
    public func setCursor(named name: String) {
        cursorNames.append(name)
    }

    /// Records a view's hover cursor regions.
    public func setCursorRegions(_ regions: [NativeCursorRegion], for handle: NativeHandle) {
        cursorRegions[handle] = regions
    }

    /// Records a run-loop timer request.
    public func scheduleNativeTimer(intervalMilliseconds: Int, action: @escaping () -> Void) -> UInt {
        let identifier = nextTimerIdentifier
        nextTimerIdentifier += 1
        scheduledTimers.append(ScheduledTimer(identifier: identifier, intervalMilliseconds: intervalMilliseconds))
        timerActions[identifier] = action
        return identifier
    }

    /// Records a run-loop timer cancellation.
    public func cancelNativeTimer(_ identifier: UInt) {
        timerActions.removeValue(forKey: identifier)
        canceledTimerIdentifiers.append(identifier)
    }

    /// Records the key-equivalent handler.
    public func registerKeyEquivalentHandler(_ handler: @escaping (NSEvent) -> Bool) {
        keyEquivalentHandler = handler
    }

    /// Records the pop request and performs the scripted flat-item selection.
    public func runContextMenu(_ menu: NSMenu, atScreenPoint point: NSPoint) -> NSMenuItem? {
        poppedContextMenus.append(menu)
        let items = flattenedItems(of: menu)
        guard items.indices.contains(nextContextMenuSelection) else {
            return nil
        }

        let item = items[nextContextMenuSelection]
        _ = item.performAction()
        return item
    }

    // MARK: - Overridable core seam · date editing
    //
    // Moved verbatim from `InMemoryNativeControlBackendDateEditing.swift`.

    /// Records framework-rendered date-field text.
    public func setDatePickerText(_ text: String, for handle: NativeHandle) {
        datePickerTexts[handle] = text
    }

    /// Records the selected date-field character range.
    public func setDatePickerSelection(location: Int, length: Int, for handle: NativeHandle) {
        datePickerSelections[handle] = (location, length)
    }

    /// Registers a simulated date-step action.
    public func setDateStepAction(for handle: NativeHandle, action: @escaping (Int) -> Void) {
        dateStepActions[handle] = action
    }

    /// Registers a simulated date-field cursor action.
    public func setDatePickerCursorAction(for handle: NativeHandle, action: @escaping (Int) -> Void) {
        datePickerCursorActions[handle] = action
    }

    /// Registers a simulated date-field movement action.
    public func setDatePickerMoveAction(for handle: NativeHandle, action: @escaping (Int) -> Void) {
        datePickerMoveActions[handle] = action
    }

    /// Registers a simulated date-field typing action.
    public func setDatePickerTypeAction(for handle: NativeHandle, action: @escaping (String) -> Void) {
        datePickerTypeActions[handle] = action
    }

    // MARK: - Overridable core seam · tables, input registration, dialogs
    //
    // Moved verbatim from `InMemoryNativeControlBackendWindows.swift`.

    /// Records a date-picker display format.
    public func setDatePickerFormat(_ format: String?, for handle: NativeHandle) {
        records[handle]?.datePickerFormat = format
    }

    /// Records a button image file path.
    public func setButtonImage(imagePath: String?, for handle: NativeHandle) {
        records[handle]?.buttonImagePath = imagePath
    }

    /// Replaces recorded table rows.
    public func setTableRows(_ rows: [[String]], selectedRow: Int, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.tableRows = rows
        record.tableSelectedRow = selectedRow
        records[handle] = record
    }

    /// Updates a single recorded table cell.
    public func setTableCellText(_ text: String, row: Int, column: Int, for handle: NativeHandle) {
        guard var record = records[handle],
              record.tableRows.indices.contains(row),
              record.tableRows[row].indices.contains(column) else {
            return
        }
        record.tableRows[row][column] = text
        records[handle] = record
    }

    /// Updates recorded table selection.
    public func setTableSelectedRow(_ selectedRow: Int, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.tableSelectedRow = selectedRow
        record.tableClickedColumn = -1
        records[handle] = record
        tableSelectedRowSets[handle] = selectedRow >= 0 ? [selectedRow] : []
    }

    /// Records native multiple-selection enablement.
    public func setTableAllowsMultipleSelection(_ allows: Bool, for handle: NativeHandle) {
        tableAllowsMultipleSelection[handle] = allows
    }

    /// Records a multiple-row selection.
    public func setTableSelectedRows(_ rows: Set<Int>, for handle: NativeHandle) {
        tableSelectedRowSets[handle] = rows.sorted()
        records[handle]?.tableSelectedRow = rows.min() ?? -1
        records[handle]?.tableClickedColumn = -1
    }

    /// Records table editability.
    public func setTableEditable(_ editable: Bool, for handle: NativeHandle) {
        if editable {
            tableEditableHandles.insert(handle)
        } else {
            tableEditableHandles.remove(handle)
        }
    }

    /// No-op edit trigger for the in-memory backend (see `simulateTableEdit`).
    public func editTableCell(row: Int, column: Int, for handle: NativeHandle) {}

    /// Records a sort indicator (column < 0 clears it).
    public func setTableSortIndicator(column: Int, ascending: Bool, for handle: NativeHandle) {
        if column < 0 {
            tableSortIndicators.removeValue(forKey: handle)
        } else {
            tableSortIndicators[handle] = (column, ascending)
        }
    }

    /// Records the in-place-edit commit callback.
    public func registerTableEditAction(for handle: NativeHandle, action: @escaping (Int, Int, String) -> Void) {
        tableEditActionsByHandle[handle] = action
    }

    /// Records the row double-click callback.
    public func registerTableDoubleClickAction(for handle: NativeHandle, action: @escaping () -> Void) {
        tableDoubleClickActionsByHandle[handle] = action
    }

    /// Records a table row visibility request.
    public func scrollTableRowToVisible(_ row: Int, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.tableVisibleRow = row
        records[handle] = record
    }

    /// Records a text change action.
    public func registerTextChangeAction(for handle: NativeHandle, action: @escaping (String) -> Void) {
        textChangeActions[handle] = action
    }

    /// Records a focus-change action.
    public func registerFocusChangeAction(for handle: NativeHandle, action: @escaping (Bool) -> Void) {
        focusChangeActions[handle] = action
    }

    /// Records a mouse-down action.
    public func registerMouseDownAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        mouseDownActions[handle] = action
    }

    /// Records a mouse-up action.
    public func registerMouseUpAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        mouseUpActions[handle] = action
    }

    /// Records a mouse-moved action.
    public func registerMouseMovedAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        mouseMovedActions[handle] = action
    }

    /// Records a mouse-left action.
    public func registerMouseLeftAction(for handle: NativeHandle, action: @escaping () -> Void) {
        mouseLeftActions[handle] = action
    }

    /// Records a mouse-dragged action.
    public func registerMouseDraggedAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        mouseDraggedActions[handle] = action
    }

    /// Records a right mouse-down action.
    public func registerRightMouseDownAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        rightMouseDownActions[handle] = action
    }

    /// Records a right mouse-up action.
    public func registerRightMouseUpAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        rightMouseUpActions[handle] = action
    }

    /// Records a tertiary mouse-down action.
    public func registerOtherMouseDownAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        otherMouseDownActions[handle] = action
    }

    /// Records a tertiary mouse-up action.
    public func registerOtherMouseUpAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        otherMouseUpActions[handle] = action
    }

    /// Records a scroll-wheel action.
    public func registerScrollWheelAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        scrollWheelActions[handle] = action
    }

    /// Records a draw action.
    public func registerDrawAction(for handle: NativeHandle, action: @escaping (NativeDrawingContext, NSRect) -> Void) {
        drawActions[handle] = action
    }

    /// Records a repaint request.
    public func invalidateControl(_ handle: NativeHandle) {
        invalidatedHandles.append(handle)
    }

    /// Records a repaint request for a control and its descendants.
    public func invalidateControlTree(_ handle: NativeHandle) {
        invalidatedHandles.append(handle)
        invalidatedTreeHandles.append(handle)
    }

    /// Records a synchronous repaint request.
    public func redrawControlImmediately(_ handle: NativeHandle) {
        invalidatedHandles.append(handle)
        invalidatedTreeHandles.append(handle)
    }

    /// Records a key-down action.
    public func registerKeyDownAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        keyDownActions[handle] = action
    }

    /// Records a key-up action.
    public func registerKeyUpAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        keyUpActions[handle] = action
    }

    /// Returns the default alert response without displaying UI.
    public func runAlert(_ alert: NSAlert) -> NSApplication.ModalResponse {
        .alertFirstButtonReturn
    }

    /// Records the request and returns the next scripted dialog result.
    public func runFileDialog(_ options: NativeFileDialogOptions) -> [String]? {
        fileDialogRequests.append(options)
        guard !scriptedFileDialogPaths.isEmpty else {
            return nil
        }

        return scriptedFileDialogPaths.removeFirst()
    }

    /// Records the request and returns the scripted color chooser result.
    public func runColorChooser(initialColor: NSColor) -> NSColor? {
        colorChooserRequests.append(initialColor)
        return nextColorChooserResult
    }

    /// Records the request and returns the scripted font chooser result.
    public func runFontChooser(initialFont: NSFont?) -> NSFont? {
        fontChooserRequests.append(initialFont)
        return nextFontChooserResult
    }

    /// Records the modal session and returns the scripted stop code.
    public func runModal(for handle: NativeHandle) -> Int {
        modalSessions.append(handle)
        return nextModalResponseCode
    }

    // MARK: - Overridable core seam · text, scroll views, tables, appearance
    //
    // Moved verbatim from `InMemoryNativeControlBackendText.swift`.

    /// Records a date picker's time zone.
    public func setDatePickerTimeZone(_ timeZone: TimeZone, for handle: NativeHandle) {
        records[handle]?.datePickerTimeZone = timeZone
    }

    /// Records a scroll view creation request.
    public func createScrollView(frame: NSRect, parent: NativeHandle?, hasVerticalScroller: Bool, hasHorizontalScroller: Bool) -> NativeHandle {
        makeHandle(kind: "scrollView", text: "", frame: frame, parent: parent)
    }

    /// Records scroll-view document and viewport geometry.
    public func setScrollViewContentSize(_ contentSize: NSSize, viewportSize: NSSize, hasVerticalScroller: Bool, hasHorizontalScroller: Bool, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.scrollViewContentSize = contentSize
        record.scrollViewViewportSize = viewportSize
        records[handle] = record
    }

    /// Records a scroll-view visible origin.
    public func setScrollViewContentOffset(_ offset: NSPoint, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        let maxX = max(0, record.scrollViewContentSize.width - record.scrollViewViewportSize.width)
        let maxY = max(0, record.scrollViewContentSize.height - record.scrollViewViewportSize.height)
        record.scrollViewContentOffset = NSPoint(
            x: min(max(offset.x, 0), maxX),
            y: min(max(offset.y, 0), maxY)
        )
        records[handle] = record
    }

    /// Records a table view creation request.
    public func createTableView(
        columns: [String],
        content: NativeTableContent,
        frame: NSRect,
        parent: NativeHandle?
    ) -> NativeHandle {
        createTableView(columns: columns, columnWidths: [], content: content, frame: frame, parent: parent)
    }

    /// Records a table view creation request with explicit column widths.
    public func createTableView(
        columns: [String],
        columnWidths: [CGFloat],
        content: NativeTableContent,
        frame: NSRect,
        parent: NativeHandle?
    ) -> NativeHandle {
        let handle = makeHandle(kind: "tableView", text: "", frame: frame, parent: parent)
        records[handle]?.tableColumns = columns
        records[handle]?.tableColumnWidths = columnWidths
        records[handle]?.tableRows = content.rows
        records[handle]?.tableSelectedRow = content.selectedRow
        records[handle]?.tableClickedRow = -1
        records[handle]?.tableClickedColumn = -1
        return handle
    }

    /// Records a text selection, clamped to the stored text like a native edit control.
    public func setTextSelection(location: Int, length: Int, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        let textLength = record.text.utf16.count
        let clampedLocation = min(max(0, location), textLength)
        record.textSelectionLocation = clampedLocation
        record.textSelectionLength = min(max(0, length), textLength - clampedLocation)
        records[handle] = record
    }

    /// Replaces the recorded selection in the stored text and moves the
    /// selection to the end of the inserted text, mirroring `EM_REPLACESEL`.
    public func replaceSelectedText(_ text: String, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        var units = Array(record.text.utf16)
        let location = min(max(0, record.textSelectionLocation), units.count)
        let length = min(max(0, record.textSelectionLength), units.count - location)
        let replacement = Array(text.utf16)
        units.replaceSubrange(location..<(location + length), with: replacement)
        record.text = String(decoding: units, as: UTF16.self)
        record.textSelectionLocation = location + replacement.count
        record.textSelectionLength = 0
        records[handle] = record
    }

    /// Records whether an edit control accepts keyboard editing.
    public func setTextEditable(_ isEditable: Bool, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.isTextEditable = isEditable
        records[handle] = record
    }

    /// Records the content scale applied to a custom-drawn view.
    public func setContentScale(_ scale: CGFloat, for handle: NativeHandle) {
        records[handle]?.contentScale = scale
    }

    /// Records placeholder text.
    public func setTextPlaceholder(_ placeholder: String?, for handle: NativeHandle) {
        records[handle]?.placeholder = placeholder
    }

    /// Records text alignment.
    public func setTextAlignment(_ alignment: NSTextAlignment, for handle: NativeHandle) {
        records[handle]?.textAlignment = alignment
    }

    /// Records the slider tick-mark count.
    public func setSliderTickMarks(count: Int, for handle: NativeHandle) {
        records[handle]?.sliderTickMarkCount = count
    }

    /// Records the slider tick-mark side.
    public func setSliderTickMarkPosition(aboveOrLeading: Bool, for handle: NativeHandle) {
        sliderTicksAboveOrLeading[handle] = aboveOrLeading
    }

    /// Records a button's flat-bezel state.
    public func setButtonBezelFlat(_ flat: Bool, for handle: NativeHandle) {
        flatBezelButtons[handle] = flat
    }

    /// Records a text field's bezel state.
    public func setTextFieldBezeled(_ bezeled: Bool, for handle: NativeHandle) {
        bezeledTextFields[handle] = bezeled
    }

    /// Records the slider orientation.
    public func setSliderVertical(_ isVertical: Bool, for handle: NativeHandle) {
        records[handle]?.sliderIsVertical = isVertical
    }

    /// Records the combo-box visible item count.
    public func setComboBoxVisibleItems(_ count: Int, for handle: NativeHandle) {
        records[handle]?.comboBoxVisibleItems = count
    }

    /// Records the progress/level bar color.
    public func setProgressBarColor(_ color: NSColor?, for handle: NativeHandle) {
        records[handle]?.progressBarColor = color
    }

    /// Records window content size limits.
    public func setWindowContentSizeLimits(minSize: NSSize?, maxSize: NSSize?, for handle: NativeHandle) {
        records[handle]?.minContentSize = minSize
        records[handle]?.maxContentSize = maxSize
    }

    /// Records whether a view's background click drags its window.
    public func setViewDragsParentWindow(_ enabled: Bool, for handle: NativeHandle) {
        if enabled {
            windowDragViewHandles.insert(handle)
        } else {
            windowDragViewHandles.remove(handle)
        }
    }

    /// Records the start of an outside-click dismiss watch.
    public func beginOutsideClickDismiss(for handle: NativeHandle, onDismiss: @escaping () -> Void) {
        outsideClickDismissHandle = handle
        outsideClickDismissAction = onDismiss
    }

    /// Records the end of an outside-click dismiss watch.
    public func endOutsideClickDismiss() {
        outsideClickDismissHandle = nil
        outsideClickDismissAction = nil
    }

    /// Records that a control should be raised above siblings.
    public func raiseControl(_ handle: NativeHandle) {
        raisedHandles.append(handle)
    }

    /// Records native focus movement.
    public func focusControl(_ handle: NativeHandle) {
        focusedHandle = handle
    }

    /// Updates a recorded text color.
    public func setTextColor(_ color: NSColor?, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.textColor = color
        records[handle] = record
    }

    /// Updates a recorded background color.
    public func setBackgroundColor(_ color: NSColor?, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.backgroundColor = color
        records[handle] = record
    }

    /// Updates whether a recorded control draws its own background.
    public func setDrawsBackground(_ drawsBackground: Bool, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.drawsBackground = drawsBackground
        records[handle] = record
    }

    // MARK: - Overridable core seam · control values
    //
    // Moved verbatim from `InMemoryNativeControlBackendTables.swift`.

    /// Records tooltip text for a native handle.
    public func setToolTip(_ toolTip: String?, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.toolTip = toolTip
        records[handle] = record
    }

    /// Returns the scripted display scale.
    public func winDisplayScale() -> CGFloat { scriptedDisplayScale }

    /// Records the explicit accessibility name pushed from `accessibilityLabel`.
    public func setAccessibilityName(_ name: String?, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.accessibilityName = name
        records[handle] = record
    }

    /// Updates a recorded font.
    public func setFont(_ font: NSFont?, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.font = font
        records[handle] = record
    }

    /// Records an image-view bitmap source update.
    public func setImagePath(_ imagePath: String?, description: String, tint: NSColor?, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.imagePath = imagePath
        record.imageTint = tint
        record.text = description
        records[handle] = record
    }

    /// Updates a recorded button state.
    public func setButtonState(_ state: NSControl.StateValue, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.buttonState = state
        records[handle] = record
    }

    /// Replaces recorded pop-up button items.
    public func setPopUpButtonItems(_ items: [String], selectedIndex: Int, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.popUpItems = items
        record.popUpSelectedIndex = selectedIndex
        record.text = items.indices.contains(selectedIndex) ? items[selectedIndex] : ""
        records[handle] = record
    }

    /// Updates recorded pop-up button selection.
    public func setPopUpButtonSelectedIndex(_ selectedIndex: Int, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.popUpSelectedIndex = selectedIndex
        record.text = record.popUpItems.indices.contains(selectedIndex) ? record.popUpItems[selectedIndex] : ""
        records[handle] = record
    }

    /// Replaces recorded combo-box items.
    public func setComboBoxItems(_ items: [String], text: String, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.comboBoxItems = items
        record.text = text
        records[handle] = record
    }

    /// Replaces recorded tab-view items.
    public func setTabViewItems(_ items: [String], selectedIndex: Int, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.tabViewItems = items
        record.tabViewSelectedIndex = selectedIndex
        record.text = items.indices.contains(selectedIndex) ? items[selectedIndex] : ""
        records[handle] = record
    }

    /// Updates recorded tab-view selection.
    public func setTabViewSelectedIndex(_ selectedIndex: Int, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.tabViewSelectedIndex = selectedIndex
        record.text = record.tabViewItems.indices.contains(selectedIndex) ? record.tabViewItems[selectedIndex] : ""
        records[handle] = record
    }

    /// Updates recorded slider range.
    public func setSliderRange(minValue: Double, maxValue: Double, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.sliderMinValue = minValue
        record.sliderMaxValue = maxValue
        records[handle] = record
    }

    /// Updates recorded slider value.
    public func setSliderValue(_ value: Double, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.sliderValue = value
        records[handle] = record
    }

    /// Updates recorded progress indicator range.
    public func setProgressIndicatorRange(minValue: Double, maxValue: Double, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.progressMinValue = minValue
        record.progressMaxValue = maxValue
        records[handle] = record
    }

    /// Updates recorded progress indicator value.
    public func setProgressIndicatorValue(_ value: Double, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.progressValue = value
        records[handle] = record
    }

    /// Records whether a level indicator is editable and its value range.
    public func setLevelIndicatorEditable(_ editable: Bool, minValue: Double, maxValue: Double, for handle: NativeHandle) {
        if editable {
            editableLevelRanges[handle] = (min(minValue, maxValue), max(minValue, maxValue))
        } else {
            editableLevelRanges.removeValue(forKey: handle)
        }
    }

    /// Updates recorded scroller state.
    public func setScrollerValue(_ value: Double, knobProportion: Double, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.sliderValue = value
        record.scrollerKnobProportion = knobProportion
        records[handle] = record
    }

    /// Records the scroller's requested appearance.
    public func setScrollerAppearance(overlay: Bool, knobStyle: NativeScrollerKnobStyle, for handle: NativeHandle) {
        scrollerOverlays[handle] = overlay
        scrollerKnobStyles[handle] = knobStyle
    }

    /// Updates recorded stepper range.
    public func setStepperRange(minValue: Double, maxValue: Double, increment: Double, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.stepperMinValue = minValue
        record.stepperMaxValue = maxValue
        record.stepperIncrement = increment
        records[handle] = record
    }

    /// Updates recorded stepper value.
    public func setStepperValue(_ value: Double, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.stepperValue = value
        records[handle] = record
    }

    /// Performs the `setStepperWraps` operation.
    public func setStepperWraps(_ wraps: Bool, for handle: NativeHandle) {
        stepperWraps[handle] = wraps
    }

    /// Updates recorded date picker state.
    public func setDatePickerDate(_ date: Date, minDate: Date?, maxDate: Date?, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.datePickerDate = date
        record.datePickerMinDate = minDate
        record.datePickerMaxDate = maxDate
        records[handle] = record
    }

    // MARK: - Overridable core seam · application, screens, clipboard, drag, print
    //
    // Moved verbatim from `InMemoryNativeControlBackendApplication.swift`.

    /// Records a native window level change.
    public func setWindowLevel(_ level: NSWindow.Level, for handle: NativeHandle) {
        records[handle]?.windowLevel = level.rawValue
    }

    /// Records whether a native window hides while the application is inactive.
    public func setHidesOnDeactivate(_ hidesOnDeactivate: Bool, for handle: NativeHandle) {
        records[handle]?.hidesOnDeactivate = hidesOnDeactivate
    }

    /// Records the owning window of an auxiliary window (AppKit's panel-to-owner
    /// relationship), so tests can assert a panel was actually paired.
    public func setWindowParent(_ parent: NativeHandle, for handle: NativeHandle) {
        windowParents[handle] = parent
    }

    /// Returns a fixed font family list for deterministic tests.
    public func fontFamilyNames() -> [String] {
        ["Arial", "Consolas", "Courier New", "Georgia", "Segoe UI", "Tahoma", "Times New Roman", "Verdana"]
    }

    /// Reads the recorded clipboard text.
    public func clipboardString() -> String? {
        clipboardText
    }

    /// Records new clipboard text.
    public func setClipboardString(_ string: String) {
        setClipboardContents(text: string, dataRepresentations: [:])
    }

    /// Reads the recorded clipboard file paths.
    public func clipboardFilePaths() -> [String] {
        clipboardFileList
    }

    /// Records a combined clipboard update.
    public func setClipboardContents(text: String?, dataRepresentations: [String: [UInt8]], filePaths: [String]) {
        clipboardText = text
        clipboardDataRepresentations = dataRepresentations
        clipboardFileList = filePaths
        clipboardChanges += 1
    }

    /// Reads recorded clipboard bytes for a format name.
    public func clipboardData(forFormat formatName: String) -> [UInt8]? {
        clipboardDataRepresentations[formatName]
    }

    /// Returns whether a recorded format is present.
    public func clipboardHasData(forFormat formatName: String) -> Bool {
        clipboardDataRepresentations[formatName] != nil
    }

    /// Clears the recorded clipboard.
    public func clearClipboard() {
        clipboardText = nil
        clipboardDataRepresentations = [:]
        clipboardFileList = []
        clipboardChanges += 1
    }

    /// The recorded clipboard change count.
    public func clipboardChangeCount() -> Int {
        clipboardChanges
    }

    /// Returns the scripted system theme preference.
    public func systemPrefersDarkAppearance() -> Bool {
        simulatedDarkAppearance
    }

    /// Returns the scripted accent color.
    public func systemAccentColor() -> NSColor? {
        simulatedAccentColor
    }

    /// Returns the (test-configurable) primary screen frame.
    public func primaryScreenFrame() -> NSRect {
        testScreenFrame
    }

    /// Returns the (test-configurable) attached screens.
    public func screenDescriptions() -> [NativeScreenDescription] {
        testScreens ?? [NativeScreenDescription(frame: testScreenFrame, visibleFrame: testScreenFrame)]
    }

    /// Records a window minimize/restore.
    public func setWindowMinimized(_ minimized: Bool, for handle: NativeHandle) {
        if minimized {
            minimizedWindows.insert(handle)
        } else {
            minimizedWindows.remove(handle)
        }
    }

    /// Records a window zoom toggle.
    public func toggleWindowZoom(_ handle: NativeHandle) {
        if zoomedWindows.contains(handle) {
            zoomedWindows.remove(handle)
        } else {
            zoomedWindows.insert(handle)
        }
    }

    /// Records a window being sent to the back.
    public func orderWindowBack(_ handle: NativeHandle) {
        windowsOrderedBack.append(handle)
    }

    /// Records a window entering or exiting full-screen presentation.
    public func setWindowFullScreen(_ fullScreen: Bool, for handle: NativeHandle) {
        if fullScreen {
            fullScreenWindows.insert(handle)
        } else {
            fullScreenWindows.remove(handle)
        }
    }

    /// Records a window-move action.
    public func registerWindowMoveAction(for handle: NativeHandle, action: @escaping (NSPoint) -> Void) {
        windowMoveActions[handle] = action
    }

    /// Records a drop-target registration.
    public func registerDropTarget(for handle: NativeHandle, handler: NativeDropHandler) {
        dropHandlers[handle] = handler
    }

    /// Records a drop-target removal.
    public func unregisterDropTarget(for handle: NativeHandle) {
        dropHandlers.removeValue(forKey: handle)
        unregisteredDropTargets.append(handle)
    }

    /// Records an outbound drag and returns the scripted result.
    public func performDrag(content: NativeDropContent, from handle: NativeHandle) -> Bool {
        performedDrags.append((content: content, handle: handle))
        return nextDragResult
    }

    /// Records a print job, rendering the view into a recording context.
    public func runPrintOperation(for handle: NativeHandle, jobName: String, contentSize: NSSize) -> Bool {
        guard nextPrintResult else {
            return false
        }
        let recording = RecordingDrawingContext()
        drawActions[handle]?(recording, NSRect(origin: NSZeroPoint, size: contentSize))
        printJobs.append(PrintJob(handle: handle, jobName: jobName, contentSize: contentSize, recording: recording))
        return true
    }
}
