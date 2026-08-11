#if os(Windows)
extension Win32NativeControlBackend {
    func updateSliderPosition(from scrollParameter: WPARAM, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        let range = sliderRanges[handle.rawValue] ?? (0, 1)
        let current = Double(winSendMessageW(hwnd, sbmGetPos, 0, 0))
        let code = scrollParameter & 0xffff
        let thumb = Double((scrollParameter >> 16) & 0xffff)
        let pageStep = max(1, ((range.maxValue - range.minValue) / 10).rounded())
        let nextValue: Double

        switch code {
        case sbLineLeft:
            nextValue = current - 1
        case sbLineRight:
            nextValue = current + 1
        case sbPageLeft:
            nextValue = current - pageStep
        case sbPageRight:
            nextValue = current + pageStep
        case sbThumbPosition, sbThumbTrack:
            nextValue = thumb
        case sbTop:
            nextValue = range.minValue
        case sbBottom:
            nextValue = range.maxValue
        default:
            nextValue = current
        }

        setSliderValue(nextValue, for: handle)
    }

    func updateScrollViewPosition(from scrollParameter: WPARAM, message: UINT, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle), var metrics = scrollViewMetrics[handle.rawValue] else {
            return
        }

        let isVertical = message == wmVScroll
        let bar = isVertical ? sbVert : sbHorz
        var scrollInfo = SCROLLINFO(cbSize: UINT(MemoryLayout<SCROLLINFO>.size), fMask: sifAll)
        guard withUnsafeMutablePointer(to: &scrollInfo, { pointer in winGetScrollInfo(hwnd, bar, pointer) }) != 0 else {
            return
        }

        let current = Double(scrollInfo.nPos)
        let page = max(1, Double(scrollInfo.nPage))
        let line = max(1, page / 10)
        let maximum = max(0, Double(scrollInfo.nMax) - page + 1)
        let context = ScrollPositionContext(
            current: current,
            line: line,
            page: page,
            thumb: Double(scrollInfo.nTrackPos),
            maximum: maximum
        )
        let nextPosition = scrollViewPosition(for: scrollParameter & 0xffff, context: context)

        let clampedPosition = min(max(nextPosition, 0), maximum)
        if isVertical {
            metrics.offset = NSPoint(x: metrics.offset.x, y: clampedPosition)
        } else {
            metrics.offset = NSPoint(x: clampedPosition, y: metrics.offset.y)
        }
        scrollViewMetrics[handle.rawValue] = metrics
        updateScrollViewBars(for: handle)
    }

    func scrollViewPosition(for code: WPARAM, context: ScrollPositionContext) -> Double {
        switch code {
        case sbLineLeft: return context.current - context.line
        case sbLineRight: return context.current + context.line
        case sbPageLeft: return context.current - context.page
        case sbPageRight: return context.current + context.page
        case sbThumbPosition, sbThumbTrack: return context.thumb
        case sbTop: return 0
        case sbBottom: return context.maximum
        default: return context.current
        }
    }

    func updateStepperPosition(from scrollParameter: WPARAM, for handle: NativeHandle) {
        guard stepperRanges[handle.rawValue] != nil else {
            return
        }

        let range = stepperRanges[handle.rawValue]
            ?? WinStepperRange(minValue: 0, maxValue: 100, increment: 1, value: 0)
        let code = scrollParameter & 0xffff
        let thumb = Double((scrollParameter >> 16) & 0xffff)
        let nextValue: Double

        switch code {
        case sbLineLeft:
            nextValue = range.value + range.increment
        case sbLineRight:
            nextValue = range.value - range.increment
        case sbPageLeft:
            nextValue = range.value + range.increment
        case sbPageRight:
            nextValue = range.value - range.increment
        case sbThumbPosition, sbThumbTrack:
            nextValue = thumb
        case sbTop:
            nextValue = range.maxValue
        case sbBottom:
            nextValue = range.minValue
        default:
            nextValue = range.value
        }

        setStepperValue(nextValue, for: handle)
    }

    func updateStepperPosition(position: Int32, delta: Int32, for handle: NativeHandle) {
        guard let range = stepperRanges[handle.rawValue], delta != 0 else {
            return
        }

        // The framework's tracked value is the base — NOT the control's iPos,
        // which does not reflect UDM_SETPOS32 reliably (observed reporting 0
        // for a stepper positioned at 50, which froze the value at 0+1).
        let direction = delta > 0 ? 1.0 : -1.0
        setStepperValue(range.value + (direction * range.increment), for: handle)
    }

    func updateStepperPosition(fromClickAt point: NSPoint, hwnd: HWND, for handle: NativeHandle) {
        guard let range = stepperRanges[handle.rawValue] else {
            return
        }

        var rectangle = RECT()
        let height: Double
        if winGetClientRect(hwnd, &rectangle) != 0 {
            height = Double(max(1, rectangle.bottom - rectangle.top))
        } else {
            height = 1
        }

        let direction = point.y < height / 2 ? 1.0 : -1.0
        setStepperValue(range.value + (direction * range.increment), for: handle)
    }

    func tableHitTest(at point: POINT, hwnd: HWND?) -> (row: Int, column: Int) {
        guard let hwnd else {
            return (-1, -1)
        }

        var hitTest = LVHITTESTINFO()
        hitTest.pt = point
        withUnsafeMutablePointer(to: &hitTest) { hitTestPointer in
            _ = winSendMessageW(hwnd, lvmSubItemHitTest, 0, Int(bitPattern: hitTestPointer))
        }

        return (Int(hitTest.iItem), Int(hitTest.iSubItem))
    }

    func headerHitTestAtCursor(hwnd: HWND?) -> Int {
        guard let hwnd else {
            return -1
        }

        var point = POINT()
        guard winGetCursorPos(&point) != 0,
              winScreenToClient(hwnd, &point) != 0 else {
            return -1
        }

        var hitTest = HDHITTESTINFO()
        hitTest.pt = point
        withUnsafeMutablePointer(to: &hitTest) { hitTestPointer in
            _ = winSendMessageW(hwnd, hdmHitTest, 0, Int(bitPattern: hitTestPointer))
        }

        return Int(hitTest.iItem)
    }

    func subclassChildControl(_ hwnd: HWND, handle: NativeHandle) {
        let replacement = unsafeBitCast(winChocolateControlProcedure as WNDPROC, to: LONG_PTR.self)
        let previous = winSetWindowLongPtrW(hwnd, gwlpWndProc, replacement)
        guard previous != 0 else {
            return
        }

        originalControlProcedures[UInt(bitPattern: hwnd)] = unsafeBitCast(previous, to: WNDPROC.self)
        controlHandleAliases[UInt(bitPattern: hwnd)] = handle
    }

    func subclassControlForTabKey(_ handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        subclassChildControl(hwnd, handle: handle)
    }

    func subclassFirstChildControlForTabKey(_ handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle),
              let child = winGetWindow(hwnd, gwChild) else {
            return
        }

        subclassChildControl(child, handle: handle)
    }

    func callOriginalControlProcedure(hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM) -> LRESULT {
        guard let hwnd,
              let originalProcedure = originalControlProcedures[UInt(bitPattern: hwnd)] else {
            return winDefWindowProcW(hwnd, message, wParam, lParam)
        }

        return winCallWindowProcW(originalProcedure, hwnd, message, wParam, lParam)
    }

    func point(from lParam: LPARAM) -> NSPoint {
        let x = Int16(bitPattern: UInt16(lParam & 0xffff))
        let y = Int16(bitPattern: UInt16((lParam >> 16) & 0xffff))
        // Windows reports mouse coordinates in device pixels; convert back to
        // logical points so the framework hit-tests in point space (10.7).
        // A no-op at 100%.
        return NSMakePoint(winToPoints(CGFloat(x)), winToPoints(CGFloat(y)))
    }

    func mouseLocation(from lParam: LPARAM, in hwnd: HWND?) -> NSPoint {
        let localPoint = point(from: lParam)
        guard let hwnd else {
            return localPoint
        }

        var screenPoint = POINT(x: Int32(localPoint.x), y: Int32(localPoint.y))
        _ = winClientToScreen(hwnd, &screenPoint)

        if let rootWindow = rootWindow(for: hwnd) {
            _ = winScreenToClient(rootWindow, &screenPoint)
        }

        return NSMakePoint(CGFloat(screenPoint.x), CGFloat(screenPoint.y))
    }

    func rootWindow(for hwnd: HWND) -> HWND? {
        var candidate: HWND? = hwnd
        while let current = candidate {
            guard let parent = winGetParent(current) else {
                return current
            }
            candidate = parent
        }
        return nil
    }

    func keyEvent(type: NSEvent.EventType, wParam: WPARAM) -> NSEvent {
        let keyCode = UInt16(wParam & 0xffff)
        let modifierFlags = modifierFlags(forKeyCode: keyCode, eventType: type)
        return NSEvent(
            type: type,
            locationInWindow: NSMakePoint(0, 0),
            keyCode: keyCode,
            characters: characters(forVirtualKey: keyCode, modifierFlags: modifierFlags),
            modifierFlags: modifierFlags
        )
    }

    func characters(forVirtualKey virtualKey: UInt16, modifierFlags: NSEvent.ModifierFlags) -> String? {
        let shiftIsDown = modifierFlags.contains(.shift)
        switch virtualKey {
        case 0x30...0x39:
            return UnicodeScalar(UInt32(virtualKey)).map(String.init)
        case 0x41...0x5a:
            let scalar = shiftIsDown ? UInt32(virtualKey) : UInt32(virtualKey + 32)
            return UnicodeScalar(scalar).map(String.init)
        case UInt16(vkSpace):
            return " "
        case UInt16(vkTab):
            return "\t"
        case UInt16(vkReturn):
            return "\n"
        case UInt16(vkEscape):
            return "\u{1b}"
        case UInt16(vkBack):
            return "\u{8}"
        default:
            return nil
        }
    }

    func modifierFlags(forKeyCode keyCode: UInt16, eventType: NSEvent.EventType) -> NSEvent.ModifierFlags {
        var flags = currentModifierFlags()
        guard let eventFlag = modifierFlag(forVirtualKey: keyCode) else {
            return flags
        }

        switch eventType {
        case .keyDown:
            flags.insert(eventFlag)
        case .keyUp:
            flags.remove(eventFlag)
        default:
            break
        }

        return flags
    }

    func currentModifierFlags() -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if keyIsDown(vkShift) || keyIsDown(vkLShift) || keyIsDown(vkRShift) {
            flags.insert(.shift)
        }
        if keyIsDown(vkControl) || keyIsDown(vkLControl) || keyIsDown(vkRControl) {
            flags.insert(.control)
        }
        if keyIsDown(vkMenu) || keyIsDown(vkLMenu) || keyIsDown(vkRMenu) {
            flags.insert(.option)
        }
        if keyIsDown(vkLWin) || keyIsDown(vkRWin) {
            flags.insert(.command)
        }
        return flags
    }

    func modifierFlag(forVirtualKey virtualKey: UInt16) -> NSEvent.ModifierFlags? {
        switch Int32(virtualKey) {
        case vkShift, vkLShift, vkRShift:
            return .shift
        case vkControl, vkLControl, vkRControl:
            return .control
        case vkMenu, vkLMenu, vkRMenu:
            return .option
        case vkLWin, vkRWin:
            return .command
        default:
            return nil
        }
    }

    func keyIsDown(_ virtualKey: Int32) -> Bool {
        (winGetKeyState(virtualKey) & Int16(bitPattern: 0x8000)) != 0
    }
}
#endif

