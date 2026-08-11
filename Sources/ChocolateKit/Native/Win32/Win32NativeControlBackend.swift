#if os(Windows)
struct WinDeviceRect: Equatable {
    let x: Int32
    let y: Int32
    let width: Int32
    let height: Int32
}

struct WinScrollViewMetrics {
    let contentSize: NSSize
    let viewportSize: NSSize
    let hasVerticalScroller: Bool
    let hasHorizontalScroller: Bool
    var offset: NSPoint
}

struct WinStepperRange {
    let minValue: Double
    let maxValue: Double
    let increment: Double
    var value: Double
}

/// Win32 implementation of WinChocolate's native backend.
///
/// This backend owns the first native milestone: top-level windows, a menu bar,
/// push buttons, static text fields, and `WM_COMMAND` dispatch for actions.
public final class Win32NativeControlBackend: NativeControlBackend {
    nonisolated(unsafe) static weak var activeBackend: Win32NativeControlBackend?

    var isWindowClassRegistered = false
    var isViewClassRegistered = false
    var mainMenu: NSMenu?
    var windowHandles: Set<NativeHandle> = []
    var mainMenuWindowHandles: Set<NativeHandle> = []
    var controlActions: [UInt: () -> Void] = [:]
    var textChangeActions: [UInt: (String) -> Void] = [:]
    var focusChangeActions: [UInt: (Bool) -> Void] = [:]
    var mouseDownActions: [UInt: (NSEvent) -> Void] = [:]
    var mouseUpActions: [UInt: (NSEvent) -> Void] = [:]
    var mouseMovedActions: [UInt: (NSEvent) -> Void] = [:]
    var mouseLeftActions: [UInt: () -> Void] = [:]
    var dropHandlers: [UInt: NativeDropHandler] = [:]
    var dropTargetObjects: [UInt: UnsafeMutableRawPointer] = [:]
    var mouseDraggedActions: [UInt: (NSEvent) -> Void] = [:]
    var rightMouseDownActions: [UInt: (NSEvent) -> Void] = [:]
    var rightMouseUpActions: [UInt: (NSEvent) -> Void] = [:]
    var otherMouseDownActions: [UInt: (NSEvent) -> Void] = [:]
    var otherMouseUpActions: [UInt: (NSEvent) -> Void] = [:]
    var scrollWheelActions: [UInt: (NSEvent) -> Void] = [:]
    var activeCursorName: String?
    var cursorRegions: [UInt: [NativeCursorRegion]] = [:]
    // The shared tooltips_class32 host window and the control HWNDs that have a
    // tool registered on it (so a repeat set updates rather than re-adds).
    var tooltipWindow: HWND?
    var tooltipRegisteredControls: Set<UInt> = []
    // The last device rect (x, y, w, h) each window/control was moved to, so a
    // `setFrame` to an unchanged rect skips the native `MoveWindow` (which would
    // repaint and flicker). Cleared on control teardown.
    var lastFrameDeviceRects: [UInt: WinDeviceRect] = [:]
    var timerActions: [UInt: () -> Void] = [:]
    var keyEquivalentHandler: ((NSEvent) -> Bool)?
    var drawActions: [UInt: (NativeDrawingContext, NSRect) -> Void] = [:]
    var keyDownActions: [UInt: (NSEvent) -> Void] = [:]
    var keyUpActions: [UInt: (NSEvent) -> Void] = [:]
    var windowCloseActions: [UInt: () -> Void] = [:]
    var windowShouldCloseHandlers: [UInt: () -> Bool] = [:]
    var windowResizeActions: [UInt: (NSSize) -> Void] = [:]
    var windowMoveActions: [UInt: (NSPoint) -> Void] = [:]
    /// Saved window style and frame while a window is in full screen, keyed by
    /// handle, so exiting full screen restores the original chrome and bounds.
    var fullScreenSavedState: [UInt: (style: LONG_PTR, rect: RECT)] = [:]
    var originalControlProcedures: [UInt: WNDPROC] = [:]
    var controlHandleAliases: [UInt: NativeHandle] = [:]
    var commandActions: [UInt: () -> Void] = [:]
    var asyncActions: [() -> Void] = []
    var toolbarActions: [UInt: (String) -> Void] = [:]
    var tableColumnTitles: [UInt: [String]] = [:]
    var tableHeaderOwners: [UInt: NativeHandle] = [:]
    /// The sorted column and direction per table handle, so the dark owner-drawn
    /// header can render the sort glyph itself (the native `HDF_SORTUP` flag is
    /// skipped under dark because the themed header repaints the sorted column
    /// on top of the owner-draw).
    var tableSortIndicators: [UInt: (column: Int, ascending: Bool)] = [:]
    /// Raw header hwnds we've subclassed to owner-draw under dark mode.
    var darkTableHeaderHwnds: Set<UInt> = []
    var tableSuppressedColumnClicks: [UInt: Int] = [:]
    var tableClickedRows: [UInt: Int] = [:]
    var tableClickedColumns: [UInt: Int] = [:]
    var tableEditableHandles: Set<UInt> = []
    var tableEditActions: [UInt: (Int, Int, String) -> Void] = [:]
    var tableDoubleClickActions: [UInt: () -> Void] = [:]
    var sliderRanges: [UInt: (minValue: Double, maxValue: Double)] = [:]
    var trackbarHandles: Set<UInt> = []
    var scrollerHandles: Set<UInt> = []
    var scrollerParts: [UInt: NativeScrollerPart] = [:]
    var monthCalHandles: Set<UInt> = []

    /// Static-classed image-view peers: their clicks route through the mouse
    /// event actions (AppKit image views never fire an action on click; app
    /// subclasses override `mouseDown`), not the control-action path.
    var imageViewHandles: Set<UInt> = []
    var monthCalDates: [UInt: Date] = [:]
    /// The zone each date picker renders its wall clock in — the framework
    /// resolves `NSDatePicker.timeZone` and pushes it here.
    var datePickerTimeZones: [UInt: TimeZone] = [:]
    /// Compact date pickers (`SysDateTimePick32`) whose closed field is
    /// owner-drawn dark — the control has no dark theme part and no color API,
    /// so the resting field is painted by the framework under a dark
    /// appearance (plan 8.5).
    var darkDatePickerFieldHandles: Set<UInt> = []
    var editableLevelHandles: Set<UInt> = []
    var levelIndicatorRanges: [UInt: (minValue: Double, maxValue: Double)] = [:]
    var levelIndicatorValues: [UInt: Double] = [:]
    var scrollViewMetrics: [UInt: WinScrollViewMetrics] = [:]
    var stepperRanges: [UInt: WinStepperRange] = [:]
    var comboBoxHandles: Set<UInt> = []
    var comboBoxDropdownHeights: [UInt: CGFloat] = [:]
    var groupBoxHandles: Set<UInt> = []
    var customViewHandles: Set<UInt> = []
    var textColors: [UInt: DWORD] = [:]
    var backgroundColors: [UInt: DWORD] = [:]
    /// Explicit rich-edit text colors, restored after WM_SETTEXT resets the
    /// control's default character format.
    var richEditTextColors: [UInt: DWORD] = [:]
    var backgroundBrushes: [UInt: HBRUSH] = [:]
    var transparentBackgroundHandles: Set<UInt> = []
    var isComInitialized = false
    var windowStyles: [UInt: DWORD] = [:]
    var windowMenuFlags: [UInt: Bool] = [:]
    var hidesOnDeactivateHandles: Set<UInt> = []
    var deactivateHiddenHandles: Set<UInt> = []
    var cachedFontFamilyNames: [String]?
    var contentScales: [UInt: CGFloat] = [:]
    var richTextHandles: Set<UInt> = []
    var multilineTextHandles: Set<UInt> = []
    var windowDragViewHandles: Set<UInt> = []
    var windowMinContentSizes: [UInt: NSSize] = [:]
    var windowMaxContentSizes: [UInt: NSSize] = [:]
    /// Whether Msftedit.dll has been loaded to register rich-edit classes.
    nonisolated(unsafe) static var isRichEditLibraryLoaded = false
    var defaultControlBackgroundBrush: HBRUSH?
    var fonts: [UInt: HFONT] = [:]
    var bitmaps: [UInt: HBITMAP] = [:]
    var standardToolbarImageOwner: HWND?
    var standardToolbarImageList: HIMAGELIST?
    // Internal so the WM_DPICHANGED handler can rebuild it at a new scale.
    var defaultControlFont: HFONT?
    var solidBrushCache: [DWORD: HBRUSH] = [:]
    /// Custom color slots shared across native color chooser openings.
    var colorChooserCustomColors: [DWORD] = Array(repeating: 0x00ff_ffff, count: 16)
    var nextCommandIdentifier: UInt = 1_000
    var modalStopCode: Int?
    var marqueePositions: [UInt: Int32] = [:]
    var nativeMenuRegistry: [UInt: (menu: NSMenu, entries: [(identifier: UInt, item: NSMenuItem)])] = [:]

    /// Creates a Win32 backend.
    /// The primary display's device scale (device pixels per logical point),
    /// e.g. 1.0 at 96 DPI, 1.5 at 144 DPI (10.7). Point-based frames, fonts,
    /// custom-view paint transforms, text measurement, and input coordinates
    /// all convert through this. It is 1.0 when the display is at 100% (or when
    /// DPI awareness could not be declared), which makes the scaling a strict
    /// no-op on the common path.
    var winDeviceScale: CGFloat = 1

    /// Creates a value with the supplied arguments.
    public init() {
        Self.activeBackend = self
        // Declare per-monitor-v2 DPI awareness before any window or device
        // context exists, so Windows renders our GDI content and native
        // controls at the real display DPI instead of bitmap-scaling them soft
        // (10.7). Fall back to system-DPI awareness on pre-1703 Windows.
        //
        // Only adopt a manual device scale when *we* successfully declared
        // awareness: if the process is already DPI-aware (e.g. a manifest set
        // it) our call fails, and the safest assumption is that geometry is
        // still being handled as before — scaling manually on top would
        // double-scale at HiDPI. In that case winDeviceScale stays 1 (the
        // point≈pixel path), a strict no-op.
        let declaredAwareness =
            winSetProcessDpiAwarenessContext(winDpiAwarenessPerMonitorV2) != 0 ||
            winSetProcessDPIAware() != 0
        if declaredAwareness {
            let systemDpi = winGetDpiForSystem()
            if systemDpi > 0 {
                winDeviceScale = CGFloat(systemDpi) / 96.0
            }
        }
        // The modern presentation (plan 8.2) binds ComCtl32 v6 visual styles
        // before any window class or common control exists; classic keeps the
        // unthemed v5 look. One-way for the process lifetime.
        if WinPresentation.selected == .modern {
            Self.enableModernVisualStyles()
        }
    }

    /// The device scale used by point↔pixel conversions (overrides the
    /// protocol default so `NSScreen.winDisplayScale` and callers see the real
    /// DPI the process declared awareness for).
    public func winDisplayScale() -> CGFloat { winDeviceScale }

    /// Converts a point-space value to device pixels at the current scale.
    func winToDevice(_ value: CGFloat) -> Int32 { Int32((value * winDeviceScale).rounded()) }

    /// Converts a device-pixel value back to point space.
    func winToPoints(_ value: CGFloat) -> CGFloat { value / winDeviceScale }

    /// The pump that lets `RunLoop.main` drive the Win32 message loop.
    public func makeRunLoopPump() -> RunLoopPlatformPump? {
        Win32RunLoopPump()
    }

    /// Starts the native Windows event loop.
    ///
    /// Retained as the fallback for `NSApplication.run()` when no run-loop pump
    /// is used; the pump path (the default on Win32) drives the same dispatch
    /// through `RunLoop.main`.
    public func runApplication() {
        var message = MSG()
        while winGetMessageW(&message, nil, 0, 0) > 0 {
            withUnsafePointer(to: message) { messagePointer in
                _ = winTranslateMessage(messagePointer)
                _ = winDispatchMessageW(messagePointer)
            }
        }
    }

    /// Runs a nested modal event loop until `stopModal` or the window closes.
    public func runModal(for handle: NativeHandle) -> Int {
        guard let modalHwnd = hwnd(from: handle) else {
            return NSApplication.ModalResponse.cancel.rawValue
        }

        // Save any outer modal state so modal sessions can nest.
        let outerStopCode = modalStopCode
        modalStopCode = nil

        var message = MSG()
        while modalStopCode == nil, winIsWindow(modalHwnd) != 0, winGetMessageW(&message, nil, 0, 0) > 0 {
            withUnsafePointer(to: message) { messagePointer in
                _ = winTranslateMessage(messagePointer)
                _ = winDispatchMessageW(messagePointer)
            }
        }

        let code = modalStopCode ?? NSApplication.ModalResponse.cancel.rawValue
        modalStopCode = outerStopCode
        return code
    }

    /// Stops the innermost modal event loop with a response code.
    public func stopModal(withCode code: Int) {
        modalStopCode = code
    }

    /// Schedules a repeating native timer dispatched by the message loop.
    public func scheduleNativeTimer(intervalMilliseconds: Int, action: @escaping () -> Void) -> UInt {
        let identifier = winSetTimerWithProcedure(nil, 0, UINT(max(1, intervalMilliseconds)), runLoopTimerProcedure)
        timerActions[identifier] = action
        return identifier
    }

    /// Cancels a scheduled native timer.
    public func cancelNativeTimer(_ identifier: UInt) {
        timerActions.removeValue(forKey: identifier)
        _ = winKillTimer(nil, identifier)
    }

    /// Requests native application termination.
    public func terminateApplication() {
        winPostQuitMessage(0)
    }

    /// Schedules work after the current native message dispatch returns.
    public func dispatchAsync(_ action: @escaping () -> Void) {
        asyncActions.append(action)
        let targetWindow = windowHandles.first.flatMap { hwnd(from: $0) }
        _ = winPostMessageW(targetWindow, wmWinChocolateAsync, 0, 0)
    }

    /// Creates a native view child.
    public func createView(frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        registerViewClassIfNeeded()
        let handle = createChildWindow(
            className: winChocolateViewClassName,
            text: "",
            frame: frame,
            parent: parent,
            commandIdentifier: nil,
            style: wsChild | wsVisible | wsClipChildren
        )
        customViewHandles.insert(handle.rawValue)
        return handle
    }
}
#endif
