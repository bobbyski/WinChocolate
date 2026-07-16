#if os(Windows)
/// Win32 implementation of WinChocolate's native backend.
///
/// This backend owns the first native milestone: top-level windows, a menu bar,
/// push buttons, static text fields, and `WM_COMMAND` dispatch for actions.
public final class Win32NativeControlBackend: NativeControlBackend {
    nonisolated(unsafe) static weak var activeBackend: Win32NativeControlBackend?

    private var isWindowClassRegistered = false
    private var isViewClassRegistered = false
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
    var lastFrameDeviceRects: [UInt: (Int32, Int32, Int32, Int32)] = [:]
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
    /// Compact date pickers (`SysDateTimePick32`) whose closed field is
    /// owner-drawn dark — the control has no dark theme part and no color API,
    /// so the resting field is painted by the framework under a dark
    /// appearance (plan 8.5).
    var darkDatePickerFieldHandles: Set<UInt> = []
    var editableLevelHandles: Set<UInt> = []
    var levelIndicatorRanges: [UInt: (minValue: Double, maxValue: Double)] = [:]
    var levelIndicatorValues: [UInt: Double] = [:]
    var scrollViewMetrics: [UInt: (contentSize: NSSize, viewportSize: NSSize, hasVerticalScroller: Bool, hasHorizontalScroller: Bool, offset: NSPoint)] = [:]
    var stepperRanges: [UInt: (minValue: Double, maxValue: Double, increment: Double, value: Double)] = [:]
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
    private var isComInitialized = false
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
    private var defaultControlBackgroundBrush: HBRUSH?
    var fonts: [UInt: HFONT] = [:]
    var bitmaps: [UInt: HBITMAP] = [:]
    var standardToolbarImageOwner: HWND?
    var standardToolbarImageList: HIMAGELIST?
    /// Custom color slots shared across native color chooser openings.
    var colorChooserCustomColors: [DWORD] = Array(repeating: 0x00ff_ffff, count: 16)
    private var nextCommandIdentifier: UInt = 1_000
    private var modalStopCode: Int?
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

    /// Starts the native Windows event loop.
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

    func outerWindowSize(forContentSize size: NSSize, style: DWORD, hasMenu: Bool) -> (width: Int32, height: Int32) {
        var rectangle = RECT(left: 0, top: 0, right: Int32(size.width), bottom: Int32(size.height))
        guard winAdjustWindowRectEx(&rectangle, style, hasMenu ? 1 : 0, 0) != 0 else {
            return (Int32(size.width), Int32(size.height))
        }

        return (rectangle.right - rectangle.left, rectangle.bottom - rectangle.top)
    }

    func ensureComInitialized() {
        guard !isComInitialized else {
            return
        }

        _ = winCoInitializeEx(nil, coinitApartmentThreaded)
        isComInitialized = true
    }

    fileprivate static func dispatchMessage(hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM) -> LRESULT? {
        activeBackend?.dispatchMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
    }

    fileprivate static func dispatchControlMessage(hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM) -> LRESULT? {
        activeBackend?.dispatchControlMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
    }

    fileprivate static func callOriginalControlProcedure(hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM) -> LRESULT {
        activeBackend?.callOriginalControlProcedure(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
            ?? winDefWindowProcW(hwnd, message, wParam, lParam)
    }

    func registerWindowClassIfNeeded() {
        guard !isWindowClassRegistered else {
            return
        }

        withWideString(winChocolateWindowClassName) { className in
            var windowClass = WNDCLASSW()
            windowClass.style = csHRedraw | csVRedraw | csDblClks
            windowClass.lpfnWndProc = winChocolateWindowProcedure
            windowClass.hInstance = winGetModuleHandleW(nil)
            windowClass.hCursor = winLoadCursorW(nil, systemResourcePointer(32_512))
            windowClass.hbrBackground = nil
            windowClass.lpszClassName = className

            withUnsafePointer(to: windowClass) { windowClassPointer in
                let atom = winRegisterClassW(windowClassPointer)
                if atom == 0 {
                    print("WinChocolate: RegisterClassW failed with error \(winGetLastError()).")
                }
            }
        }

        isWindowClassRegistered = true
    }

    func registerViewClassIfNeeded() {
        guard !isViewClassRegistered else {
            return
        }

        withWideString(winChocolateViewClassName) { className in
            var windowClass = WNDCLASSW()
            windowClass.style = csHRedraw | csVRedraw | csDblClks
            windowClass.lpfnWndProc = winChocolateWindowProcedure
            windowClass.hInstance = winGetModuleHandleW(nil)
            windowClass.hCursor = winLoadCursorW(nil, systemResourcePointer(32_512))
            // The view surface erases with the dynamic window background so a
            // dark effective appearance yields dark view surfaces (the class
            // registers on first control creation, after the appearance is
            // decided — the same one-way binding as WinPresentation).
            windowClass.hbrBackground = winCreateSolidBrush(colorRef(from: .windowBackgroundColor))
            windowClass.lpszClassName = className

            withUnsafePointer(to: windowClass) { windowClassPointer in
                let atom = winRegisterClassW(windowClassPointer)
                if atom == 0 {
                    print("WinChocolate: RegisterClassW for view failed with error \(winGetLastError()).")
                }
            }
        }

        isViewClassRegistered = true
    }

    func initializeListViewControls() {
        var initControls = INITCOMMONCONTROLSEX()
        initControls.dwSize = DWORD(MemoryLayout<INITCOMMONCONTROLSEX>.size)
        initControls.dwICC = iccListViewClasses
        withUnsafePointer(to: initControls) { pointer in
            _ = winInitCommonControlsEx(pointer)
        }
    }

    func initializeToolbarControls() {
        var initControls = INITCOMMONCONTROLSEX()
        initControls.dwSize = DWORD(MemoryLayout<INITCOMMONCONTROLSEX>.size)
        initControls.dwICC = iccBarClasses
        withUnsafePointer(to: initControls) { pointer in
            _ = winInitCommonControlsEx(pointer)
        }
    }

    func initializeTabControls() {
        var initControls = INITCOMMONCONTROLSEX()
        initControls.dwSize = DWORD(MemoryLayout<INITCOMMONCONTROLSEX>.size)
        initControls.dwICC = iccTabClasses
        withUnsafePointer(to: initControls) { pointer in
            _ = winInitCommonControlsEx(pointer)
        }
    }

    func initializeUpDownControls() {
        var initControls = INITCOMMONCONTROLSEX()
        initControls.dwSize = DWORD(MemoryLayout<INITCOMMONCONTROLSEX>.size)
        initControls.dwICC = iccUpDownClass
        withUnsafePointer(to: initControls) { pointer in
            _ = winInitCommonControlsEx(pointer)
        }
    }

    func initializeProgressControls() {
        var initControls = INITCOMMONCONTROLSEX()
        initControls.dwSize = DWORD(MemoryLayout<INITCOMMONCONTROLSEX>.size)
        initControls.dwICC = iccProgressClass
        withUnsafePointer(to: initControls) { pointer in
            _ = winInitCommonControlsEx(pointer)
        }
    }

    func initializeDateControls() {
        var initControls = INITCOMMONCONTROLSEX()
        initControls.dwSize = DWORD(MemoryLayout<INITCOMMONCONTROLSEX>.size)
        initControls.dwICC = iccDateClasses
        withUnsafePointer(to: initControls) { pointer in
            _ = winInitCommonControlsEx(pointer)
        }
    }

    func frameWidth(for handle: NativeHandle) -> CGFloat {
        guard let hwnd = hwnd(from: handle) else {
            return 240
        }

        var rectangle = RECT()
        guard winGetClientRect(hwnd, &rectangle) != 0 else {
            return 240
        }

        return CGFloat(max(1, rectangle.right - rectangle.left))
    }

    func createChildWindow(
        className: String,
        text: String,
        frame: NSRect,
        parent: NativeHandle?,
        commandIdentifier: UInt?,
        style: DWORD
    ) -> NativeHandle {
        guard let parentHwnd = parent.flatMap({ hwnd(from: $0) }) else {
            return NativeHandle(rawValue: 0)
        }

        let menuHandle = commandIdentifier.flatMap { HMENU(bitPattern: Int($0)) }
        // Controls are created in device pixels at the display scale (10.7);
        // a no-op at 100%.
        let childHwnd = withWideString(className) { nativeClassName in
            withWideString(text) { nativeText in
                winCreateWindowExW(
                    0,
                    nativeClassName,
                    nativeText,
                    style,
                    winToDevice(frame.origin.x),
                    winToDevice(frame.origin.y),
                    winToDevice(frame.size.width),
                    winToDevice(frame.size.height),
                    parentHwnd,
                    menuHandle,
                    winGetModuleHandleW(nil),
                    nil
                )
            }
        }

        guard let childHwnd else {
            print("WinChocolate: CreateWindowExW child \(className) failed with error \(winGetLastError()).")
            return NativeHandle(rawValue: 0)
        }

        // Native control classes default to the legacy bitmap system font;
        // give every control the standard UI font unless `setFont` overrides.
        if let font = defaultUIFont() {
            _ = winSendMessageW(childHwnd, wmSetFont, UInt(bitPattern: font), 1)
        }

        // A dark effective appearance opts native controls into the system's
        // dark control themes (the same undocumented-but-stable subclasses
        // Explorer and the common dialogs use). Best-effort: classes without
        // a dark theme part keep their light rendering — tracked in 8.5.
        // Rich edit is excluded: the dark theme dims its text rendering while
        // the control already takes explicit colors (EM_SETBKGNDCOLOR + char
        // formats), which the dark path applies directly.
        if NSApplication.shared.effectiveAppearance.winIsDark,
           !className.uppercased().hasPrefix("RICHEDIT") {
            let theme = className.uppercased() == "COMBOBOX" ? "DarkMode_CFD" : "DarkMode_Explorer"
            _ = withWideString(theme) { themeName in
                winSetWindowTheme(childHwnd, themeName, nil)
            }
        }

        return nativeHandle(from: childHwnd)
    }

    // Internal (not private) so the WM_DPICHANGED handler in another file can
    // drop the cached font to rebuild it at the new scale (10.7).
    var defaultControlFont: HFONT?

    private func defaultUIFont() -> HFONT? {
        if let defaultControlFont {
            return defaultControlFont
        }

        // 12pt at the display scale (10.7) so native control text is crisp at
        // HiDPI; a no-op at 100%.
        let pixelHeight = Int32((12 * winDeviceScale).rounded())
        let font = withWideString("Segoe UI") { faceName in
            winCreateFontW(
                -pixelHeight,
                0,
                0,
                0,
                400,
                0,
                0,
                0,
                defaultCharset,
                defaultPrecision,
                defaultPrecision,
                defaultQuality,
                defaultPitchAndFamily,
                faceName
            )
        }
        defaultControlFont = font
        return font
    }

    func nextCommandID() -> UInt {
        let commandIdentifier = nextCommandIdentifier
        nextCommandIdentifier += 1
        return commandIdentifier
    }

    private var solidBrushCache: [DWORD: HBRUSH] = [:]

    func solidBrush(for color: DWORD) -> HBRUSH? {
        if let brush = solidBrushCache[color] {
            return brush
        }

        guard let brush = winCreateSolidBrush(color) else {
            return nil
        }

        solidBrushCache[color] = brush
        return brush
    }

    func inheritedBackgroundColor(behind hwnd: HWND?) -> DWORD {
        var ancestor = winGetParent(hwnd)
        while let current = ancestor {
            let rawAncestor = UInt(bitPattern: current)
            if !transparentBackgroundHandles.contains(rawAncestor),
               let color = backgroundColors[rawAncestor] {
                return color
            }
            ancestor = winGetParent(current)
        }
        return colorRef(from: .windowBackgroundColor)
    }

    func controlBackgroundBrush() -> HBRUSH? {
        if let defaultControlBackgroundBrush {
            return defaultControlBackgroundBrush
        }

        let brush = winCreateSolidBrush(colorRef(from: .windowBackgroundColor))
        defaultControlBackgroundBrush = brush
        return brush
    }

    /// Discards the cached control-background brush so it is rebuilt with the
    /// current appearance's window background (used on a live theme switch).
    func winResetCachedControlBackgroundBrush() {
        if let brush = defaultControlBackgroundBrush {
            _ = winDeleteObject(brush)
        }
        defaultControlBackgroundBrush = nil
    }

    func colorRef(from color: NSColor) -> DWORD {
        colorRef(red: color.redComponent, green: color.greenComponent, blue: color.blueComponent)
    }

    func colorRef(red redComponent: CGFloat, green greenComponent: CGFloat, blue blueComponent: CGFloat) -> DWORD {
        let red = DWORD((min(max(redComponent, 0), 1) * 255).rounded()) & 0xff
        let green = DWORD((min(max(greenComponent, 0), 1) * 255).rounded()) & 0xff
        let blue = DWORD((min(max(blueComponent, 0), 1) * 255).rounded()) & 0xff
        return red | (green << 8) | (blue << 16)
    }

    func invalidate(_ handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        _ = winInvalidateRect(hwnd, nil, 1)
    }

    func clearAppearance(for handle: NativeHandle) {
        textColors.removeValue(forKey: handle.rawValue)
        backgroundColors.removeValue(forKey: handle.rawValue)
        transparentBackgroundHandles.remove(handle.rawValue)
        if let brush = backgroundBrushes.removeValue(forKey: handle.rawValue) {
            _ = winDeleteObject(brush)
        }
        if let font = fonts.removeValue(forKey: handle.rawValue) {
            _ = winDeleteObject(font)
        }
        if let bitmap = bitmaps.removeValue(forKey: handle.rawValue) {
            if let hwnd = hwnd(from: handle) {
                _ = winSendMessageW(hwnd, stmSetImage, WPARAM(imageBitmap), 0)
            }
            _ = winDeleteObject(bitmap)
        }
    }

    func nativeHandle(from hwnd: HWND) -> NativeHandle {
        NativeHandle(rawValue: UInt(bitPattern: hwnd))
    }

    func actionHandle(from hwnd: HWND) -> NativeHandle {
        controlHandleAliases[UInt(bitPattern: hwnd)] ?? nativeHandle(from: hwnd)
    }

    func hwnd(from handle: NativeHandle) -> HWND? {
        guard handle.rawValue != 0 else {
            return nil
        }

        return HWND(bitPattern: handle.rawValue)
    }
}

private func winChocolateWindowProcedure(
    hwnd: HWND?,
    message: UINT,
    wParam: WPARAM,
    lParam: LPARAM
) -> LRESULT {
    if let result = Win32NativeControlBackend.dispatchMessage(
        hwnd: hwnd,
        message: message,
        wParam: wParam,
        lParam: lParam
    ) {
        return result
    }

    return winDefWindowProcW(hwnd, message, wParam, lParam)
}

func winChocolateControlProcedure(
    hwnd: HWND?,
    message: UINT,
    wParam: WPARAM,
    lParam: LPARAM
) -> LRESULT {
    if let result = Win32NativeControlBackend.dispatchControlMessage(
        hwnd: hwnd,
        message: message,
        wParam: wParam,
        lParam: lParam
    ) {
        return result
    }

    return Win32NativeControlBackend.callOriginalControlProcedure(
        hwnd: hwnd,
        message: message,
        wParam: wParam,
        lParam: lParam
    )
}

/// Dispatches thread-timer ticks to the active backend's timer actions.
let runLoopTimerProcedure: @convention(c) (HWND?, UINT, UInt, DWORD) -> Void = { _, _, identifier, _ in
    Win32NativeControlBackend.activeBackend?.timerActions[identifier]?()
}
#endif
