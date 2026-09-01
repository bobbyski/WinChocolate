// How a GTK window shows that its document has unsaved changes, and how it
// runs page setup.
//
// The asterisk story, in short: `NSWindowController` used to return "*Untitled"
// from `windowTitle(forDocumentDisplayName:)`. Real AppKit returns the display
// name UNCHANGED and marks dirtiness through `NSWindow.isDocumentEdited`
// (measured — Docs/NSDOCUMENT_PLAN.md § Ground Truth). The asterisk was not
// wrong, it was in the wrong layer. GTK desktops use the same convention
// Windows does, so it lives here now, applied to the native title on top of
// whatever the application set — which means reading `window.title` back gives
// the document's name, not a name with punctuation stuck to it.

#if canImport(CGTK)

import CGTK

extension GTKNativeControlBackend {
    /// Reflects a window's document state in its native title bar.
    ///
    /// - Parameters:
    ///   - handle: The window whose title to update.
    ///   - edited: Whether the document has unsaved changes.
    ///   - representedPath: The file the window stands for, if any. Recorded so
    ///     the title can be rebuilt correctly; the visible title stays the
    ///     document's display name.
    public func setWindowDocumentEdited(_ handle: NativeHandle,
                                        edited: Bool,
                                        representedPath: String?) {
        documentRepresentedPaths[handle.rawValue] = representedPath

        let wasEdited = documentEditedHandles.contains(handle.rawValue)
        guard wasEdited != edited else {
            return
        }

        if edited {
            documentEditedHandles.insert(handle.rawValue)
        } else {
            documentEditedHandles.remove(handle.rawValue)
        }

        guard let widget = widget(handle) else {
            return
        }

        // Read the title back rather than tracking it, so this stays correct
        // when the application sets the title itself between edits — which a
        // document window does on every save.
        let current = gtk_window_get_title(asWindow(widget)).map { String(cString: $0) } ?? ""
        let bare = current.hasPrefix("*") ? String(current.dropFirst()) : current
        let updated = edited ? "*\(bare)" : bare
        guard updated != current else {
            return
        }
        gtk_window_set_title(asWindow(widget), updated)
    }

    /// Shows a page-setup dialog and folds the result into `printInfo`.
    ///
    /// GTK's page setup is `gtk_print_run_page_setup_dialog`, which is
    /// **synchronous and always returns a page setup** — it gives back the one
    /// it was handed when the user cancels, with no way to tell the two apart.
    /// That is a problem here: `NSDocument.runModalPageLayout` treats "accepted"
    /// as an edit worth recording, so reporting a cancel as an accept would mark
    /// documents dirty for doing nothing.
    ///
    /// So the values are compared: if nothing came back different, the dialog is
    /// reported as cancelled. A user who opens page setup and changes nothing
    /// gets the same outcome as one who cancels, which is the right answer for
    /// the change count either way.
    public func runPageLayout(for printInfo: NSPrintInfo) -> Bool {
        let setup = gtk_page_setup_new()
        defer { g_object_unref(setup) }

        // GTK works in points for margins, which is what NSPrintInfo uses too,
        // so these need no conversion — unlike the Windows dialog.
        gtk_page_setup_set_left_margin(setup, Double(printInfo.leftMargin), GTK_UNIT_POINTS)
        gtk_page_setup_set_right_margin(setup, Double(printInfo.rightMargin), GTK_UNIT_POINTS)
        gtk_page_setup_set_top_margin(setup, Double(printInfo.topMargin), GTK_UNIT_POINTS)
        gtk_page_setup_set_bottom_margin(setup, Double(printInfo.bottomMargin), GTK_UNIT_POINTS)
        gtk_page_setup_set_orientation(
            setup,
            printInfo.orientation == .landscape ? GTK_PAGE_ORIENTATION_LANDSCAPE
                                                : GTK_PAGE_ORIENTATION_PORTRAIT)

        // Same parent the file dialogs use, so page setup is modal to the
        // window the user is actually looking at.
        let parent = firstWindowHandle().flatMap { widget($0) }.map { asWindow($0) }
        guard let result = gtk_print_run_page_setup_dialog(parent, setup, nil) else {
            return false
        }
        defer { g_object_unref(result) }

        let width = gtk_page_setup_get_paper_width(result, GTK_UNIT_POINTS)
        let height = gtk_page_setup_get_paper_height(result, GTK_UNIT_POINTS)
        let left = gtk_page_setup_get_left_margin(result, GTK_UNIT_POINTS)
        let right = gtk_page_setup_get_right_margin(result, GTK_UNIT_POINTS)
        let top = gtk_page_setup_get_top_margin(result, GTK_UNIT_POINTS)
        let bottom = gtk_page_setup_get_bottom_margin(result, GTK_UNIT_POINTS)
        let landscape = gtk_page_setup_get_orientation(result) == GTK_PAGE_ORIENTATION_LANDSCAPE

        let changed = !nearlyEqual(width, Double(printInfo.paperSize.width))
            || !nearlyEqual(height, Double(printInfo.paperSize.height))
            || !nearlyEqual(left, Double(printInfo.leftMargin))
            || !nearlyEqual(right, Double(printInfo.rightMargin))
            || !nearlyEqual(top, Double(printInfo.topMargin))
            || !nearlyEqual(bottom, Double(printInfo.bottomMargin))
            || landscape != (printInfo.orientation == .landscape)

        guard changed else {
            return false
        }

        printInfo.paperSize = NSSize(width: CGFloat(width), height: CGFloat(height))
        printInfo.leftMargin = CGFloat(left)
        printInfo.rightMargin = CGFloat(right)
        printInfo.topMargin = CGFloat(top)
        printInfo.bottomMargin = CGFloat(bottom)
        printInfo.orientation = landscape ? .landscape : .portrait
        return true
    }

    /// Whether two point measurements are the same to within a rounding error.
    ///
    /// GTK stores its page setup in millimetres internally and converts on the
    /// way out, so a value that went in unchanged can come back a hair
    /// different. An exact comparison would call every cancelled dialog a
    /// change.
    private func nearlyEqual(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) < 0.5
    }
}

#endif
