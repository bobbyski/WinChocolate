#if os(Windows)
extension Win32NativeControlBackend {
    /// Shows the platform print dialog and, when the user confirms, renders a
    /// view's custom drawing into the printer.
    ///
    /// The printer device context is scaled from its native resolution to
    /// 96-DPI logical points with a world transform, so the view's `draw(_:)`
    /// output prints at the size it renders on screen.
    public func runPrintOperation(for handle: NativeHandle, jobName: String, contentSize: NSSize) -> Bool {
        guard let drawAction = drawActions[handle.rawValue] else {
            return false
        }

        var dialog = PRINTDLGW()
        dialog.lStructSize = UINT(MemoryLayout<PRINTDLGW>.stride)
        dialog.hwndOwner = keyWindowHandleForDialogs()
        dialog.flags = pdReturnDC | pdNoSelection | pdNoPageNums | pdUseDevModeCopies
        dialog.nCopies = 1
        guard winPrintDlgW(&dialog) != 0, let printerContext = dialog.hDC else {
            return false
        }
        defer {
            _ = winDeleteDC(printerContext)
        }

        var documentInfo = DOCINFOW()
        documentInfo.cbSize = Int32(MemoryLayout<DOCINFOW>.stride)
        let started = withWideString(jobName) { name -> Bool in
            documentInfo.lpszDocName = name
            return winStartDocW(printerContext, &documentInfo) > 0
        }
        guard started else {
            return false
        }

        guard winStartPage(printerContext) > 0 else {
            _ = winAbortDoc(printerContext)
            return false
        }

        // Scale printer device pixels to 96-DPI logical points.
        let scaleX = Float(winGetDeviceCaps(printerContext, logPixelsX)) / 96
        let scaleY = Float(winGetDeviceCaps(printerContext, logPixelsY)) / 96
        _ = winSetGraphicsMode(printerContext, gmAdvanced)
        var transform = XFORM()
        transform.eM11 = max(scaleX, 0.01)
        transform.eM22 = max(scaleY, 0.01)
        _ = winSetWorldTransform(printerContext, &transform)

        let context = Win32DrawingContext(deviceContext: printerContext)
        drawAction(context, NSRect(origin: NSZeroPoint, size: contentSize))

        _ = winEndPage(printerContext)
        _ = winEndDoc(printerContext)
        return true
    }

    /// The key window's HWND, used to parent modal dialogs.
    private func keyWindowHandleForDialogs() -> HWND? {
        guard let keyWindow = NSApplication.shared.keyWindow, let handle = keyWindow.nativeHandle else {
            return nil
        }
        return hwnd(from: handle)
    }
}
#endif
