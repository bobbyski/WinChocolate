extension InMemoryNativeControlBackend {
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

    /// Reads a scroll-view visible origin.
    public func scrollViewContentOffset(for handle: NativeHandle) -> NSPoint {
        records[handle]?.scrollViewContentOffset ?? NSZeroPoint
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

    /// Updates a recorded control text value.
    public func setText(_ text: String, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.text = text
        records[handle] = record
    }

    /// Reads a recorded text selection.
    public func textSelection(for handle: NativeHandle) -> (location: Int, length: Int) {
        guard let record = records[handle] else {
            return (0, 0)
        }

        return (record.textSelectionLocation, record.textSelectionLength)
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

    /// Number of `setFrame` calls that reached the backend per handle. Used to
    /// verify the framework coalesces duplicate frame pushes (flicker guard).

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

    /// Whether slider ticks were placed above/leading, for tests.

    /// Records the slider tick-mark side.
    public func setSliderTickMarkPosition(aboveOrLeading: Bool, for handle: NativeHandle) {
        sliderTicksAboveOrLeading[handle] = aboveOrLeading
    }

    /// Whether a button was set to a flat bezel, for tests.

    /// Records a button's flat-bezel state.
    public func setButtonBezelFlat(_ flat: Bool, for handle: NativeHandle) {
        flatBezelButtons[handle] = flat
    }

    /// Whether a text field was given a client-edge bezel, for tests.

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

    /// Handles whose background click drags the parent window.

    /// Records whether a view's background click drags its window.
    public func setViewDragsParentWindow(_ enabled: Bool, for handle: NativeHandle) {
        if enabled {
            windowDragViewHandles.insert(handle)
        } else {
            windowDragViewHandles.remove(handle)
        }
    }

    /// The handle currently watched for an outside-click dismiss, if any.

    /// The recorded outside-click dismiss action, for tests to invoke.

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

    /// Simulates a click outside the watched window, firing the dismiss action.
    public func simulateOutsideClick() {
        outsideClickDismissAction?()
    }

    /// Records that a control should be raised above siblings.
    public func raiseControl(_ handle: NativeHandle) {
        raisedHandles.append(handle)
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

    /// Updates recorded tooltip text.
}
