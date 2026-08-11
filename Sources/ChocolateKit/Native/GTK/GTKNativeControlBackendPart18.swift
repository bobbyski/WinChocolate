#if canImport(CGTK)
import CGTK
import CGTKCompat
import Foundation

extension GTKNativeControlBackend {

    // MARK: Handles and parenting

    /// Adds `child` to `parent` when the core supplied one.
    ///
    /// Every `create…` requirement in the core takes a `parent:`; the GTK
    /// methods take none and expect a separate `addSubview`. This is that
    /// difference, applied once.
    internal func attach(_ child: NativeHandle, to parent: NativeHandle?) -> NativeHandle {
        guard let parent else { return child }
        switch kinds[parent.rawValue] {
        case .window:
            // A window can take MORE than one direct child: `NSWindow.realizeNativePeer`
            // realizes the toolbar host first and the content view second, both
            // with the window as parent. `setContentView` holds a single slot,
            // so sending both there let the content view evict the toolbar —
            // which is why the merged demo had an empty band across the top.
            //
            // The window's GTK child is already the vertical box this wants:
            // [toolbar][content], exactly AppKit's stack.
            addWindowChild(child, to: parent)
        case .box, .scrollView:
            // GtkFrame and GtkScrolledWindow hold exactly ONE child, while the
            // AppKit views they stand in for hold several — an NSScrollView has
            // a document view *and* a header strip. Handing the second child to
            // the same setter unparents the first, and GTK drops its last
            // reference, leaving a dangling widget that crashed the next
            // `setFrame`. Only the first child takes the content slot.
            if coreSeam.contentAssigned.insert(parent.rawValue).inserted {
                setContentView(child, for: parent)
            } else {
                addSubview(child, to: parent)
            }
        default:
            addSubview(child, to: parent)
        }
        return child
    }

    /// Stacks `child` in `window`'s vertical box, below anything already there.
    ///
    /// The last child added expands to fill — that is the content view, since
    /// the toolbar host is realized first and wants only its own height. The
    /// window's resize and paint bookkeeping follows the expanding child.
    internal func addWindowChild(_ child: NativeHandle, to window: NativeHandle) {
        guard let box = windowBoxes[window.rawValue], let c = widget(child) else { return }
        let frame = frames[child.rawValue] ?? .zero
        gtk_widget_set_size_request(asWidget(c), Int32(frame.width), Int32(frame.height))

        // Whatever expanded before now sits at its natural height, and stops
        // standing in for the window's content size. `noteContentDraw` reports
        // a window resize from whichever view owns that mapping, so leaving the
        // toolbar host (1120x40) in it alongside the content view (1120x720)
        // made the two alternately claim to BE the window: every draw pass
        // looked like a resize, the core re-laid the toolbar out, and the item
        // views were rebuilt forever — 618 subview adds in a 14-second run.
        for previous in coreSeam.windowChildren[window.rawValue] ?? [] {
            guard let w = widgets[previous] else { continue }
            gtk_widget_set_vexpand(asWidget(w), gboolean(0))
            contentViewOwners.removeValue(forKey: previous)
        }
        gtk_widget_set_vexpand(asWidget(c), gboolean(1))
        gtk_widget_set_hexpand(asWidget(c), gboolean(1))
        gtk_box_append(asBox(box), asWidget(c))

        coreSeam.windowChildren[window.rawValue, default: []].append(child.rawValue)
        parents[child.rawValue] = window.rawValue
        windowContents[window.rawValue] = c
        contentViewOwners[child.rawValue] = window.rawValue
    }

    // MARK: Creation

    /// Creates a plain container view.
    public func createView(frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        attach(createView(frame: frame), to: parent)
    }

    /// Creates a window. `usesMainMenu` is Win32's menu-bar-in-the-frame flag;
    /// GTK installs menus per window through `installMenuBar`, so the shared
    /// core's `installMainMenu` does that work instead.
    public func createWindow(title: String, frame: NSRect, styleMask: NSWindow.StyleMask,
                             usesMainMenu: Bool) -> NativeHandle {
        let handle = createWindow(title: title, frame: frame, styleMask: styleMask)
        if usesMainMenu { primaryWindows.insert(handle.rawValue) }
        return handle
    }

    /// Creates a push button. A non-bordered button drops GTK's frame.
    public func createButton(title: String, frame: NSRect, parent: NativeHandle?,
                             isBordered: Bool) -> NativeHandle {
        let handle = attach(createButton(title: title, frame: frame), to: parent)
        if !isBordered { setButtonBezelFlat(true, for: handle) }
        return handle
    }

    /// Creates a checkbox.
    public func createCheckbox(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        attach(createCheckbox(title: title, frame: frame), to: parent)
    }

    /// Creates a radio button.
    public func createRadioButton(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        attach(createRadioButton(title: title, frame: frame), to: parent)
    }

    /// Creates a titled box.
    public func createBox(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        attach(createBox(title: title, frame: frame), to: parent)
    }

    /// Creates a text field. A non-editable, non-bordered field is a label on
    /// GTK, which is also what AppKit's own label factory produces.
    public func createTextField(
        text: String,
        frame: NSRect,
        parent: NativeHandle?,
        options: NativeTextFieldOptions
    ) -> NativeHandle {
        let handle: NativeHandle
        if !options.isEditable && !options.isBordered {
            handle = createLabel(text: text, frame: frame)
        } else {
            handle = createTextField(text: text, frame: frame)
            setTextEditable(options.isEditable, for: handle)
            setTextFieldBezeled(options.isBordered, for: handle)
        }
        return attach(handle, to: parent)
    }

    /// Creates a secure (password) text field.
    public func createSecureTextField(text: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        attach(createSecureTextField(text: text, frame: frame), to: parent)
    }

    /// Creates a multi-line text view.
    public func createTextView(text: String, frame: NSRect, parent: NativeHandle?,
                               isEditable: Bool, isRichText: Bool) -> NativeHandle {
        let handle = attach(createTextView(text: text, frame: frame), to: parent)
        setTextEditable(isEditable, for: handle)
        return handle
    }

    /// Creates an editable combo box.
    public func createComboBox(items: [String], text: String, frame: NSRect,
                               parent: NativeHandle?) -> NativeHandle {
        attach(createComboBox(items: items, text: text, frame: frame), to: parent)
    }

    /// Creates a pop-up button.
    public func createPopUpButton(items: [String], selectedIndex: Int, frame: NSRect,
                                  parent: NativeHandle?) -> NativeHandle {
        attach(createPopUpButton(items: items, selectedIndex: selectedIndex, frame: frame), to: parent)
    }

    /// Creates a slider.
    public func createSlider(value: Double, minValue: Double, maxValue: Double,
                            frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        attach(createSlider(value: value, minValue: minValue, maxValue: maxValue, frame: frame),
               to: parent)
    }

    /// Creates a stepper.
    public func createStepper(
        configuration: NativeStepperConfiguration,
        frame: NSRect,
        parent: NativeHandle?
    ) -> NativeHandle {
        attach(createStepper(
            value: configuration.value,
            minValue: configuration.minValue,
            maxValue: configuration.maxValue,
            stepSize: configuration.increment,
            frame: frame
        ), to: parent)
    }

    /// Creates a progress indicator.
    public func createProgressIndicator(value: Double, minValue: Double, maxValue: Double,
                                        frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        attach(createProgressIndicator(value: value, minValue: minValue, maxValue: maxValue,
                                       frame: frame), to: parent)
    }

    /// Creates a date picker.
    public func createDatePicker(
        configuration: NativeDatePickerConfiguration,
        frame: NSRect,
        parent: NativeHandle?
    ) -> NativeHandle {
        // Style FIRST, parent second: `setDatePickerGraphical` swaps the widget
        // for a calendar or a compact entry, and that swap is only safe while
        // the widget has no parent. Attaching first left the old widget
        // unparented and freed while the handle still pointed at it, so the
        // next `setToolTip` walked into freed memory.
        let handle = createDatePicker(date: configuration.date, frame: frame)
        setDatePickerGraphical(configuration.style == .clockAndCalendar, for: handle)
        setDateRange(min: configuration.minDate, max: configuration.maxDate, for: handle)
        return attach(handle, to: parent)
    }

    /// Creates an image view. `description` is Win32's accessible name, which
    /// GTK takes as the widget tooltip.
    public func createImageView(description: String, imagePath: String?, frame: NSRect,
                                parent: NativeHandle?) -> NativeHandle {
        let handle = attach(createImageView(frame: frame), to: parent)
        if let imagePath { setImagePath(imagePath, for: handle) }
        return handle
    }

    /// Creates a tab view and its pages.
    public func createTabView(items: [String], selectedIndex: Int, frame: NSRect,
                              parent: NativeHandle?) -> NativeHandle {
        let handle = attach(createTabView(frame: frame), to: parent)
        setTabViewItems(items, selectedIndex: selectedIndex, for: handle)
        return handle
    }

    /// Creates a scroll view.
    public func createScrollView(frame: NSRect, parent: NativeHandle?, hasVerticalScroller: Bool,
                                 hasHorizontalScroller: Bool) -> NativeHandle {
        let handle = attach(createScrollView(frame: frame), to: parent)
        setScrollerPolicy(vertical: hasVerticalScroller, horizontal: hasHorizontalScroller,
                          for: handle)
        return handle
    }

    /// Creates a standalone scroller.
    public func createScroller(value: Double, knobProportion: Double, isVertical: Bool,
                               frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = attach(createScroller(vertical: isVertical, frame: frame), to: parent)
        setScrollerGeometry(value: value, knobProportion: knobProportion, for: handle)
        return handle
    }

    /// Creates a table view with equal column widths.
    public func createTableView(
        columns: [String],
        content: NativeTableContent,
        frame: NSRect,
        parent: NativeHandle?
    ) -> NativeHandle {
        createTableView(columns: columns, columnWidths: [], content: content, frame: frame, parent: parent)
    }

    /// Creates a table view. GTK's column view sizes its own columns, so
    /// `columnWidths` is accepted and left to the widget.
    public func createTableView(
        columns: [String],
        columnWidths: [CGFloat],
        content: NativeTableContent,
        frame: NSRect,
        parent: NativeHandle?
    ) -> NativeHandle {
        let handle = attach(createTableView(frame: frame), to: parent)
        for title in columns { addTableColumn(title: title, editable: false, to: handle) }
        setTableRows(content.rows, selectedRow: content.selectedRow, for: handle)
        return handle
    }

    /// Creates a toolbar.
    ///
    /// The core models a toolbar as a control it creates and then fills; GTK
    /// installs one on a window as a header bar. So this stages the items and
    /// `setToolbarItems` performs the install once the window is known.
    public func createToolbar(items: [NativeToolbarItem], frame: NSRect,
                              parent: NativeHandle?) -> NativeHandle {
        let handle = createView(frame: frame)
        if let parent { coreSeam.toolbarWindow[handle.rawValue] = parent }
        setHidden(true, for: handle)
        setToolbarItems(items, for: handle)
        return handle
    }

    // MARK: Values read back

    /// The slider's current value.
    public func sliderValue(for handle: NativeHandle) -> Double {
        guard let w = widget(handle) else { return 0 }
        return gtk_range_get_value(asRange(w))
    }

    /// The stepper's current value.
    public func stepperValue(for handle: NativeHandle) -> Double {
        stepperValues[handle.rawValue] ?? 0
    }

    /// The level indicator's current value.
    public func levelIndicatorValue(for handle: NativeHandle) -> Double {
        levelValues[handle.rawValue] ?? 0
    }

    /// The scroller's current value.
    public func scrollerValue(for handle: NativeHandle) -> Double {
        guard let adjustment = scrollerAdjustments[handle.rawValue] else { return 0 }
        return gtk_adjustment_get_value(adjustment)
    }

    /// Which part of the scroller the user last touched.
    ///
    /// GTK's scrollbar does not report the hit part — the adjustment reports
    /// only the resulting value — so every scroll reads as a knob drag, which
    /// is what a GTK scrollbar drag actually is.
    public func scrollerPart(for handle: NativeHandle) -> NativeScrollerPart { .knob }

    /// The checkbox/radio state.
    public func buttonState(for handle: NativeHandle) -> NSControl.StateValue {
        guard let w = widget(handle) else { return .off }
        switch kinds[handle.rawValue] {
        case .checkbox, .radio:
            return gtk_check_button_get_active(asCheckButton(w)) != 0 ? .on : .off
        default:
            return .off
        }
    }

    /// The combo box's editable text.
    public func comboBoxText(for handle: NativeHandle) -> String {
        guard let entry = comboEntries[handle.rawValue],
              let text = gtk_editable_get_text(entry) else { return "" }
        return String(cString: text)
    }

    /// The pop-up button's selected index.
    public func popUpButtonSelectedIndex(for handle: NativeHandle) -> Int {
        guard let w = widget(handle) else { return -1 }
        let selected = gtk_drop_down_get_selected(w)
        return selected == GTK_INVALID_LIST_POSITION ? -1 : Int(selected)
    }

    /// The tab view's selected page index.
    public func tabViewSelectedIndex(for handle: NativeHandle) -> Int {
        guard let w = widget(handle) else { return 0 }
        return Int(gtk_notebook_get_current_page(w))
    }

    /// The date picker's date.
    public func datePickerDate(for handle: NativeHandle) -> Date? {
        dateValues[handle.rawValue]
    }

    /// The table's selected row, or −1.
    public func tableSelectedRow(for handle: NativeHandle) -> Int {
        coreSeam.tableSelection[handle.rawValue]?.first ?? -1
    }

    /// Every selected row.
    public func tableSelectedRows(for handle: NativeHandle) -> [Int] {
        coreSeam.tableSelection[handle.rawValue] ?? []
    }

    /// The row the user last clicked, or −1.
    public func tableClickedRow(for handle: NativeHandle) -> Int {
        coreSeam.tableClickedRow[handle.rawValue] ?? -1
    }

    /// The column the user last clicked, or −1.
    public func tableClickedColumn(for handle: NativeHandle) -> Int {
        coreSeam.tableClickedColumn[handle.rawValue] ?? -1
    }

    /// The text view's selection as a location/length pair.
    public func textSelection(for handle: NativeHandle) -> (location: Int, length: Int) {
        guard isEditableKind(handle), let w = widget(handle) else { return (0, 0) }
        var start: Int32 = 0, end: Int32 = 0
        if gtk_editable_get_selection_bounds(w, &start, &end) != 0 {
            return (Int(start), Int(end - start))
        }
        let position = gtk_editable_get_position(w)
        return (Int(position), 0)
    }

}

#endif
