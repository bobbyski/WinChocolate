extension InMemoryNativeControlBackend {
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

    /// Last fade visibility requested per window, for tests.

    /// Records a native window close action.
    public func registerWindowCloseAction(for handle: NativeHandle, action: @escaping () -> Void) {
        windowCloseActions[handle] = action
    }

    /// Registered window close-veto handlers by handle.

    /// Records a window close-veto handler.
    public func registerWindowShouldCloseHandler(for handle: NativeHandle, handler: @escaping () -> Bool) {
        windowShouldCloseHandlers[handle] = handler
    }

    /// Simulates a title-bar close request, honoring the veto handler.
    @discardableResult
    public func requestWindowClose(_ handle: NativeHandle) -> Bool {
        if windowShouldCloseHandlers[handle]?() == false {
            return false
        }

        closeWindow(handle)
        return true
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

    /// Records a text field creation request.
    /// Whether a text-field handle was created multi-line, for tests.

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

    /// A recorded paragraph-alignment application.
    public struct TextRangeAlignment: Equatable {
        /// The applied alignment.
        public let alignment: NSTextAlignment

        /// The range start in UTF-16 units.
        public let location: Int

        /// The range length in UTF-16 units.
        public let length: Int

        /// Creates a recorded alignment application.
        public init(alignment: NSTextAlignment, location: Int, length: Int) {
            self.alignment = alignment
            self.location = location
            self.length = length
        }
    }

    /// Paragraph-alignment applications per handle, oldest first.

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

    /// Returns the recorded toolbar item frame using the same simple sizing model as the in-memory toolbar.
    public func toolbarItemFrame(at index: Int, for handle: NativeHandle) -> NSRect? {
        guard let record = records[handle], record.toolbarItems.indices.contains(index) else {
            return nil
        }

        var x: CGFloat = 8
        for itemIndex in 0..<index {
            x += toolbarItemWidth(record.toolbarItems[itemIndex], toolbarWidth: record.frame.size.width)
        }

        let width = toolbarItemWidth(record.toolbarItems[index], toolbarWidth: record.frame.size.width)
        return NSMakeRect(x, 0, width, record.frame.size.height)
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

    /// Records a date picker's zone.
}
