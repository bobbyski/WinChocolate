// How a Windows window shows that its document has unsaved changes.
//
// This is the other half of a deliberate move. `NSWindowController` used to
// return "*Untitled" from `windowTitle(forDocumentDisplayName:)`, which was a
// divergence: real AppKit returns the display name UNCHANGED and marks
// dirtiness through `NSWindow.isDocumentEdited`, drawing a dot in the close
// button (measured — Docs/NSDOCUMENT_PLAN.md § Ground Truth).
//
// The asterisk was not wrong, it was in the wrong place. Windows has no
// close-button dot; its convention for an unsaved document is exactly that
// asterisk in the title bar — "*Untitled - Notepad". So the API now says what
// Apple says, and the asterisk lives here, where a platform rendering belongs.
//
// Keeping it here also means the app's own `window.title` is never rewritten:
// the asterisk is applied to the native caption on top of whatever the title
// is, so reading `window.title` back gives the document's name, not a name with
// punctuation stuck to it.

#if os(Windows)

extension Win32NativeControlBackend {
    /// Reflects a window's document state in its native caption.
    ///
    /// - Parameters:
    ///   - handle: The window whose caption to update.
    ///   - edited: Whether the document has unsaved changes.
    ///   - representedPath: The file the window stands for, if any. Recorded
    ///     for the system menu and drag-out behaviour; the caption itself keeps
    ///     showing the document's display name.
    public func setWindowDocumentEdited(_ handle: NativeHandle,
                                        edited: Bool,
                                        representedPath: String?) {
        representedPaths[handle.rawValue] = representedPath

        let wasEdited = documentEditedHandles.contains(handle.rawValue)
        guard wasEdited != edited else {
            return
        }

        if edited {
            documentEditedHandles.insert(handle.rawValue)
        } else {
            documentEditedHandles.remove(handle.rawValue)
        }

        applyDocumentEditedCaption(handle, edited: edited)
    }

    /// Adds or removes the leading asterisk on a window's caption.
    ///
    /// Reads the caption back from the window rather than tracking it, so this
    /// stays correct when the application sets `window.title` itself between
    /// edits — which a document window does on every save.
    private func applyDocumentEditedCaption(_ handle: NativeHandle, edited: Bool) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        let current = windowCaption(hwnd)
        let bare = current.hasPrefix("*") ? String(current.dropFirst()) : current
        let updated = edited ? "*\(bare)" : bare
        guard updated != current else {
            return
        }

        withWideString(updated) { value in
            _ = winSetWindowTextW(hwnd, value)
        }
    }

    /// Reads a window's current caption text.
    private func windowCaption(_ hwnd: HWND?) -> String {
        let length = Int(winGetWindowTextLengthW(hwnd))
        guard length > 0 else {
            return ""
        }

        // +1 for the terminating null the API writes.
        var buffer = [UInt16](repeating: 0, count: length + 1)
        let copied = Int(winGetWindowTextW(hwnd, &buffer, Int32(buffer.count)))
        guard copied > 0 else {
            return ""
        }
        return String(decoding: buffer[0..<copied], as: UTF16.self)
    }
}

extension Win32NativeControlBackend {
    /// Shows the Windows page-setup dialog and folds the result into `printInfo`.
    ///
    /// `PageSetupDlgW` reports paper size and margins in **hundredths of a
    /// millimetre** (its `PSD_INHUNDREDTHSOFMILLIMETERS` mode), while
    /// `NSPrintInfo` is in points. The conversion is the only interesting part:
    /// 1 point is 1/72 inch and 1 inch is 2,540 hundredths of a millimetre, so
    /// points = hundredths × 72 / 2540.
    ///
    /// Returns false when the user cancels, so a cancelled Page Setup leaves a
    /// document's settings — and its change count — alone.
    public func runPageLayout(for printInfo: NSPrintInfo) -> Bool {
        var setup = PAGESETUPDLGW()
        setup.lStructSize = DWORD(MemoryLayout<PAGESETUPDLGW>.stride)
        setup.hwndOwner = keyWindowHandleForDialogs()
        setup.flags = psdMargins | psdInHundredthsOfMillimeters

        setup.rtMargin = RECT(
            left: hundredths(fromPoints: printInfo.leftMargin),
            top: hundredths(fromPoints: printInfo.topMargin),
            right: hundredths(fromPoints: printInfo.rightMargin),
            bottom: hundredths(fromPoints: printInfo.bottomMargin))

        guard winPageSetupDlgW(&setup) != 0 else {
            return false
        }

        printInfo.paperSize = NSSize(width: points(fromHundredths: setup.ptPaperSize.x),
                                     height: points(fromHundredths: setup.ptPaperSize.y))
        printInfo.leftMargin = points(fromHundredths: setup.rtMargin.left)
        printInfo.topMargin = points(fromHundredths: setup.rtMargin.top)
        printInfo.rightMargin = points(fromHundredths: setup.rtMargin.right)
        printInfo.bottomMargin = points(fromHundredths: setup.rtMargin.bottom)
        // Wider than tall is what landscape means, and it is the only
        // orientation signal the dialog gives back.
        printInfo.orientation = setup.ptPaperSize.x > setup.ptPaperSize.y ? .landscape : .portrait
        return true
    }

    /// Converts hundredths of a millimetre to typographic points.
    private func points(fromHundredths value: Int32) -> CGFloat {
        CGFloat(value) * 72.0 / 2540.0
    }

    /// Converts typographic points to hundredths of a millimetre.
    private func hundredths(fromPoints value: CGFloat) -> Int32 {
        Int32((value * 2540.0 / 72.0).rounded())
    }
}

#endif
