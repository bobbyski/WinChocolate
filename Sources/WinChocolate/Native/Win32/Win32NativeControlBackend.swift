#if os(Windows)
/// Win32 implementation of WinChocolate's native backend.
///
/// This backend owns the first native milestone: top-level windows, a menu bar,
/// push buttons, static text fields, and `WM_COMMAND` dispatch for actions.
public final class Win32NativeControlBackend: NativeControlBackend {
    nonisolated(unsafe) private static weak var activeBackend: Win32NativeControlBackend?

    private var isWindowClassRegistered = false
    private var isViewClassRegistered = false
    var mainMenu: NSMenu?
    var windowHandles: Set<NativeHandle> = []
    var mainMenuWindowHandles: Set<NativeHandle> = []
    var controlActions: [UInt: () -> Void] = [:]
    var textChangeActions: [UInt: (String) -> Void] = [:]
    var mouseDownActions: [UInt: (NSEvent) -> Void] = [:]
    var mouseUpActions: [UInt: (NSEvent) -> Void] = [:]
    var mouseMovedActions: [UInt: (NSEvent) -> Void] = [:]
    var mouseDraggedActions: [UInt: (NSEvent) -> Void] = [:]
    var rightMouseDownActions: [UInt: (NSEvent) -> Void] = [:]
    var rightMouseUpActions: [UInt: (NSEvent) -> Void] = [:]
    var otherMouseDownActions: [UInt: (NSEvent) -> Void] = [:]
    var otherMouseUpActions: [UInt: (NSEvent) -> Void] = [:]
    var scrollWheelActions: [UInt: (NSEvent) -> Void] = [:]
    var activeCursorName: String?
    var keyEquivalentHandler: ((NSEvent) -> Bool)?
    var drawActions: [UInt: (NativeDrawingContext, NSRect) -> Void] = [:]
    var keyDownActions: [UInt: (NSEvent) -> Void] = [:]
    var keyUpActions: [UInt: (NSEvent) -> Void] = [:]
    var windowCloseActions: [UInt: () -> Void] = [:]
    var windowResizeActions: [UInt: (NSSize) -> Void] = [:]
    var originalControlProcedures: [UInt: WNDPROC] = [:]
    var controlHandleAliases: [UInt: NativeHandle] = [:]
    var commandActions: [UInt: () -> Void] = [:]
    var asyncActions: [() -> Void] = []
    var toolbarActions: [UInt: (String) -> Void] = [:]
    var tableColumnTitles: [UInt: [String]] = [:]
    var tableHeaderOwners: [UInt: NativeHandle] = [:]
    var tableSuppressedColumnClicks: [UInt: Int] = [:]
    var tableClickedRows: [UInt: Int] = [:]
    var tableClickedColumns: [UInt: Int] = [:]
    var sliderRanges: [UInt: (minValue: Double, maxValue: Double)] = [:]
    var trackbarHandles: Set<UInt> = []
    var scrollViewMetrics: [UInt: (contentSize: NSSize, viewportSize: NSSize, hasVerticalScroller: Bool, hasHorizontalScroller: Bool, offset: NSPoint)] = [:]
    var stepperRanges: [UInt: (minValue: Double, maxValue: Double, increment: Double, value: Double)] = [:]
    var comboBoxHandles: Set<UInt> = []
    var comboBoxDropdownHeights: [UInt: CGFloat] = [:]
    var groupBoxHandles: Set<UInt> = []
    var customViewHandles: Set<UInt> = []
    var textColors: [UInt: DWORD] = [:]
    var backgroundColors: [UInt: DWORD] = [:]
    var backgroundBrushes: [UInt: HBRUSH] = [:]
    var transparentBackgroundHandles: Set<UInt> = []
    private var isComInitialized = false
    var windowStyles: [UInt: DWORD] = [:]
    var windowMenuFlags: [UInt: Bool] = [:]
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
    public init() {
        Self.activeBackend = self
    }

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
            windowClass.hbrBackground = HBRUSH(bitPattern: 6)
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
        let childHwnd = withWideString(className) { nativeClassName in
            withWideString(text) { nativeText in
                winCreateWindowExW(
                    0,
                    nativeClassName,
                    nativeText,
                    style,
                    Int32(frame.origin.x),
                    Int32(frame.origin.y),
                    Int32(frame.size.width),
                    Int32(frame.size.height),
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

        return nativeHandle(from: childHwnd)
    }

    private var defaultControlFont: HFONT?

    private func defaultUIFont() -> HFONT? {
        if let defaultControlFont {
            return defaultControlFont
        }

        let font = withWideString("Segoe UI") { faceName in
            winCreateFontW(
                -12,
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
#endif
