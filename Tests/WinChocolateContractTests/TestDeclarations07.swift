import WinChocolate

@MainActor
func testProgressIndicatorStoresRangeValueAndSyncsNativePeer() {
    let backend = InMemoryNativeControlBackend()
    let progress = NSProgressIndicator(frame: NSMakeRect(0, 0, 240, 16))
    progress.minValue = 0
    progress.maxValue = 100
    progress.doubleValue = 30

    expect(progress.doubleValue == 30, "Progress indicator doubleValue was not stored.")
    expect(progress.minValue == 0, "Progress indicator minValue was not stored.")
    expect(progress.maxValue == 100, "Progress indicator maxValue was not stored.")

    let handle = progress.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "progressIndicator", "Progress indicator did not request native peer.")
    expect(backend.records[handle]?.progressMinValue == 0, "Progress indicator minValue was not synced.")
    expect(backend.records[handle]?.progressMaxValue == 100, "Progress indicator maxValue was not synced.")
    expect(backend.records[handle]?.progressValue == 30, "Progress indicator value was not synced.")

    progress.increment(by: 90)
    expect(progress.doubleValue == 100, "Progress indicator did not clamp increment to maxValue.")
    expect(backend.records[handle]?.progressValue == 100, "Progress indicator clamped value was not synced.")

    progress.startAnimation(nil)
    expect(progress.isAnimating, "Progress indicator did not store animation state.")
    progress.stopAnimation(nil)
    expect(!progress.isAnimating, "Progress indicator did not stop animation state.")
}

@MainActor
func testLevelIndicatorStoresRangeValueAndUsesProgressPeer() {
    let backend = InMemoryNativeControlBackend()
    let level = NSLevelIndicator(frame: NSMakeRect(0, 0, 160, 18))
    level.minValue = 0
    level.maxValue = 10
    level.warningValue = 7
    level.criticalValue = 9
    level.doubleValue = 6

    expect(level.doubleValue == 6, "Level indicator doubleValue was not stored.")
    expect(level.intValue == 6, "Level indicator intValue did not reflect doubleValue.")
    expect(level.warningValue == 7, "Level indicator warningValue was not stored.")
    expect(level.criticalValue == 9, "Level indicator criticalValue was not stored.")

    let handle = level.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "progressIndicator", "Level indicator did not request progress-style native peer.")
    expect(backend.records[handle]?.progressMinValue == 0, "Level indicator minValue was not synced.")
    expect(backend.records[handle]?.progressMaxValue == 10, "Level indicator maxValue was not synced.")
    expect(backend.records[handle]?.progressValue == 6, "Level indicator value was not synced.")

    level.doubleValue = 20
    expect(level.doubleValue == 10, "Level indicator did not clamp to maxValue.")
    expect(backend.records[handle]?.progressValue == 10, "Level indicator clamped value was not synced.")
    expect(!level.acceptsFirstResponder, "Non-editable level indicator should skip key-view traversal.")
}

@MainActor
func testButtonBezelAndTextFieldBezel() {
    let backend = InMemoryNativeControlBackend()

    // A square bezel style renders the button flat; rounded stays standard.
    let button = NSButton(title: "Square", frame: NSMakeRect(0, 0, 80, 30))
    button.bezelStyle = .regularSquare
    let buttonHandle = button.realizeNativePeer(in: backend, parent: nil)
    expect(backend.flatBezelButtons[buttonHandle] == true, "Square bezel style did not flatten the button.")
    button.bezelStyle = .rounded
    expect(backend.flatBezelButtons[buttonHandle] == false, "Rounded bezel style did not restore the standard button.")

    // A bezeled text field gets a native client-edge bezel.
    let field = NSTextField.textField(withString: "x")
    field.isBezeled = true
    let fieldHandle = field.realizeNativePeer(in: backend, parent: nil)
    expect(backend.bezeledTextFields[fieldHandle] == true, "isBezeled did not apply a bezel to the field.")
    field.isBezeled = false
    expect(backend.bezeledTextFields[fieldHandle] == false, "Clearing isBezeled did not remove the bezel.")
}

@MainActor
func testDisclosureButtonTogglesAndOrientsTriangle() {
    let backend = InMemoryNativeControlBackend()

    // A disclosure button is framework-drawn on a view peer, not a native button.
    let button = NSButton(title: "", frame: NSMakeRect(0, 0, 20, 20))
    button.bezelStyle = .disclosure
    let handle = button.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[handle]?.kind == "view", "Disclosure button should use a custom-draw view peer.")

    // Closed → right-pointing: the vertical base shares an x (two vertices), and
    // the single apex sits at the maximum x.
    let closed = NSButton.winDisclosureTriangle(in: NSMakeRect(0, 0, 20, 20), isOpen: false)
    let closedXs = closed.map(\.x).sorted()
    expect(abs(closedXs[0] - closedXs[1]) < 0.001 || abs(closedXs[1] - closedXs[2]) < 0.001,
        "A closed disclosure triangle's base should share an x edge.")
    let apexClosedX = closed.map(\.x).max()!
    expect(closed.filter { abs($0.x - apexClosedX) < 0.001 }.count == 1, "The closed triangle should have a single rightmost apex.")

    // Open → down-pointing: the horizontal base shares a y (two vertices) — a
    // different orientation from closed.
    let open = NSButton.winDisclosureTriangle(in: NSMakeRect(0, 0, 20, 20), isOpen: true)
    let openYs = open.map(\.y).sorted()
    expect(abs(openYs[0] - openYs[1]) < 0.001 || abs(openYs[1] - openYs[2]) < 0.001,
        "An open disclosure triangle's base should share a y edge.")

    // Clicking (via performClick) toggles open/closed and fires the action.
    var fired = 0
    button.onAction = { _ in fired += 1 }
    expect(button.state == .off, "A disclosure button should start closed.")
    button.performClick(nil)
    expect(button.state == .on && fired == 1, "First click should open the disclosure and fire the action.")
    button.performClick(nil)
    expect(button.state == .off && fired == 2, "Second click should close the disclosure and fire the action.")
}

@MainActor
func testFrameworkDrawnBezelStylesUseViewPeersAndInteract() {
    let backend = InMemoryNativeControlBackend()

    // Circular, recessed, and inline bezels have no native Win32 form, so each
    // is drawn on a view peer rather than mapped to a native button.
    for style in [NSButton.BezelStyle.circular, .recessed, .inline] {
        let button = NSButton(title: "X", frame: NSMakeRect(0, 0, 44, 24))
        button.bezelStyle = style
        let handle = button.realizeNativePeer(in: backend, parent: nil)
        expect(backend.records[handle]?.kind == "view", "The \(style) bezel should use a custom-draw view peer.")
    }

    // A recessed button is a toggle: clicking latches on, then off.
    let recessed = NSButton(title: "Bold", frame: NSMakeRect(0, 0, 60, 24))
    recessed.bezelStyle = .recessed
    _ = recessed.realizeNativePeer(in: backend, parent: nil)
    var recessedFires = 0
    recessed.onAction = { _ in recessedFires += 1 }
    recessed.performClick(nil)
    expect(recessed.state == .on && recessedFires == 1, "A recessed button should latch on and fire.")
    recessed.performClick(nil)
    expect(recessed.state == .off && recessedFires == 2, "A recessed button should latch back off and fire.")

    // Circular and inline are momentary: they fire without latching state.
    for style in [NSButton.BezelStyle.circular, .inline] {
        let momentary = NSButton(title: "?", frame: NSMakeRect(0, 0, 24, 24))
        momentary.bezelStyle = style
        _ = momentary.realizeNativePeer(in: backend, parent: nil)
        var fires = 0
        momentary.onAction = { _ in fires += 1 }
        momentary.performClick(nil)
        expect(momentary.state == .off && fires == 1, "The \(style) bezel should fire without latching state.")
    }

    // The face/badge fills adapt to appearance (no fixed light island): the dark
    // variants are darker than the light ones.
    expect(NSButton.winBezelFaceColor(isDark: true).redComponent < NSButton.winBezelFaceColor(isDark: false).redComponent,
        "The bezel face fill should be darker under dark appearance.")
    expect(NSButton.winInlineBadgeColor(isDark: true).redComponent < NSButton.winInlineBadgeColor(isDark: false).redComponent,
        "The inline badge fill should be darker under dark appearance.")
}

@MainActor
func testMinorControlCleanups() {
    let backend = InMemoryNativeControlBackend()

    // NSStepper.valueWraps reaches the native peer (native wrap-at-ends).
    let stepper = NSStepper(frame: NSMakeRect(0, 0, 20, 30))
    stepper.valueWraps = true
    let stepperHandle = stepper.realizeNativePeer(in: backend, parent: nil)
    expect(backend.stepperWraps[stepperHandle] == true, "Stepper wrap was not synced to the peer.")
    stepper.valueWraps = false
    expect(backend.stepperWraps[stepperHandle] == false, "Stepper wrap change did not sync.")

    // NSPopUpButton.autoenablesItems + per-item enabled model.
    let popup = NSPopUpButton(frame: NSMakeRect(0, 0, 120, 26))
    popup.addItems(withTitles: ["A", "B", "C"])
    expect(popup.isItemEnabled(at: 1), "Popup items should be enabled by default.")
    popup.autoenablesItems = false
    popup.setItemEnabled(false, at: 1)
    expect(!popup.isItemEnabled(at: 1), "Per-item disable did not apply with autoenablesItems off.")
    popup.autoenablesItems = true
    expect(popup.isItemEnabled(at: 1), "autoenablesItems should override per-item state.")

    // Per-item images round-trip on the item model.
    let popupIcon = NSImage(named: "doc.symbol")
    popup.setImage(popupIcon, forItemAt: 0)
    expect(popup.itemImage(at: 0) === popupIcon, "Popup item image was not stored.")
    expect(popup.itemImage(at: 2) == nil, "Unset popup item image should be nil.")

    // NSSlider.altIncrementValue round-trips.
    let slider = NSSlider(frame: NSMakeRect(0, 0, 120, 20))
    slider.altIncrementValue = 5
    expect(slider.altIncrementValue == 5, "altIncrementValue did not store.")

    // NSButton.sound (NSSound) round-trips.
    let button = NSButton(title: "Beep", frame: NSMakeRect(0, 0, 80, 30))
    let sound = NSSound(named: "Ping")
    button.sound = sound
    expect(button.sound === sound, "Button sound did not store.")
    expect(NSSound(named: "") == nil, "Empty sound name should fail init.")
}

@MainActor
func testLevelIndicatorRatingUsesCustomView() {
    let backend = InMemoryNativeControlBackend()

    // Rating/discrete/relevancy are framework-drawn on a plain view.
    let rating = NSLevelIndicator(frame: NSMakeRect(0, 0, 120, 24))
    rating.levelIndicatorStyle = .rating
    rating.maxValue = 5
    rating.doubleValue = 3
    let handle = rating.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[handle]?.kind == "view", "Rating level indicator should use a custom-draw view peer.")

    // Continuous capacity still uses the native progress bar.
    let bar = NSLevelIndicator(frame: NSMakeRect(0, 0, 120, 24))
    let barHandle = bar.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[barHandle]?.kind == "progressIndicator", "Continuous level indicator should use the progress peer.")
}

@MainActor
func testLevelIndicatorFillColorsAreAppearanceAware() {
    // The framework-drawn styles must adapt to dark mode: the empty-slot track
    // lifts so filled/unfilled items stay distinct against the dark surface, and
    // the whole palette differs between light and dark (no hardcoded light-only
    // colors — the regression these tokens replaced).
    let lightRating = NSLevelIndicator.winFillColors(for: .rating, isDark: false)
    let darkRating = NSLevelIndicator.winFillColors(for: .rating, isDark: true)
    expect(lightRating.off != darkRating.off, "The empty-slot track must differ between light and dark.")
    expect(darkRating.off.redComponent < lightRating.off.redComponent,
        "The dark track should be darker than the light track.")

    // Relevancy keeps the Mac's neutral graphite, not the accent used by rating
    // and discrete capacity, and it too flips with appearance.
    let lightRelevancy = NSLevelIndicator.winFillColors(for: .relevancy, isDark: false)
    let darkRelevancy = NSLevelIndicator.winFillColors(for: .relevancy, isDark: true)
    expect(lightRelevancy.on != lightRating.on, "Relevancy should not use the accent fill that rating does.")
    expect(lightRelevancy.on != darkRelevancy.on, "Relevancy's neutral fill must adapt to appearance.")
    expect(darkRelevancy.on.redComponent > lightRelevancy.on.redComponent,
        "The dark relevancy fill should lift to stay visible on the dark surface.")
}

@MainActor
func testLevelIndicatorEditableClickSetsValue() {
    let backend = InMemoryNativeControlBackend()
    let level = NSLevelIndicator(frame: NSMakeRect(0, 0, 120, 20))
    level.minValue = 0
    level.maxValue = 10
    level.isEditable = true
    var actionCount = 0
    level.onAction = { _ in actionCount += 1 }

    let handle = level.realizeNativePeer(in: backend, parent: nil)
    expect(level.acceptsFirstResponder, "Editable level indicator should accept first responder.")

    // A click at 30% of the width maps to value 3 in [0, 10] and fires the action.
    backend.simulateLevelIndicatorClick(fraction: 0.3, for: handle)
    expect(level.doubleValue == 3, "Level click did not map the fraction to a value.")
    expect(actionCount == 1, "Level click did not fire the action.")

    // Dragging to the far right pins to the maximum.
    backend.simulateLevelIndicatorClick(fraction: 1.0, for: handle)
    expect(level.doubleValue == 10, "Level drag to the end did not reach max.")
    expect(actionCount == 2, "Level drag did not fire the action.")

    // A non-editable indicator ignores clicks.
    let display = NSLevelIndicator(frame: NSMakeRect(0, 0, 120, 20))
    display.maxValue = 10
    let displayHandle = display.realizeNativePeer(in: backend, parent: nil)
    backend.simulateLevelIndicatorClick(fraction: 0.5, for: displayHandle)
    expect(display.doubleValue == 0, "Non-editable level indicator should ignore clicks.")
}

@MainActor
func testScrollerStoresValueAndSyncsNativePeer() {
    let backend = InMemoryNativeControlBackend()
    let scroller = NSScroller(frame: NSMakeRect(0, 0, 20, 120))
    scroller.doubleValue = 0.4
    scroller.knobProportion = 0.25

    expect(scroller.doubleValue == 0.4, "Scroller doubleValue was not stored.")
    expect(scroller.knobProportion == 0.25, "Scroller knobProportion was not stored.")
    expect(scroller.isVertical, "Scroller orientation did not infer vertical frame.")
    expect(!scroller.acceptsFirstResponder, "Scroller should skip key-view traversal.")

    let handle = scroller.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "scroller", "Scroller did not request native scroller peer.")
    expect(backend.records[handle]?.sliderValue == 0.4, "Scroller value was not synced.")
    expect(backend.records[handle]?.scrollerKnobProportion == 0.25, "Scroller knob proportion was not synced.")
    expect(backend.records[handle]?.scrollerIsVertical == true, "Scroller orientation was not synced.")

    scroller.setFloatValue(1.5, knobProportion: -1)
    expect(scroller.doubleValue == 1, "Scroller did not clamp doubleValue.")
    expect(scroller.knobProportion == 0, "Scroller did not clamp knobProportion.")
    expect(backend.records[handle]?.sliderValue == 1, "Scroller clamped value was not synced.")
}

@MainActor
func testScrollerNativeActionUpdatesValue() {
    let backend = InMemoryNativeControlBackend()
    let scroller = NSScroller(frame: NSMakeRect(0, 0, 120, 18))
    var actionCount = 0
    scroller.onAction = { control in
        guard let scroller = control as? NSScroller else {
            expect(false, "Scroller action sender was not scroller.")
            return
        }

        actionCount += 1
        expect(scroller.doubleValue == 0.75, "Scroller action did not read native value.")
        expect(scroller.hitPart == .knob, "Scroller did not report the knob hit part.")
    }

    let handle = scroller.realizeNativePeer(in: backend, parent: nil)
    backend.simulateScrollerPart(.knob, value: 0.75, for: handle)

    expect(actionCount == 1, "Scroller native action was not dispatched.")
}

@MainActor
func testScrollerHitPartReflectsGesture() {
    let backend = InMemoryNativeControlBackend()
    let scroller = NSScroller(frame: NSMakeRect(0, 0, 120, 18))
    let handle = scroller.realizeNativePeer(in: backend, parent: nil)

    // Each backend part maps to the matching AppKit hit part.
    let cases: [(NativeScrollerPart, NSScroller.Part)] = [
        (.decrementLine, .decrementLine),
        (.incrementLine, .incrementLine),
        (.decrementPage, .decrementPage),
        (.incrementPage, .incrementPage),
        (.knob, .knob),
    ]
    for (native, expected) in cases {
        backend.simulateScrollerPart(native, for: handle)
        expect(scroller.hitPart == expected, "Scroller hit part did not follow the \(native) gesture.")
    }
}

@MainActor
func testScrollerAppearancePropagatesToNativePeer() {
    let backend = InMemoryNativeControlBackend()
    let scroller = NSScroller(frame: NSMakeRect(0, 0, 120, 18))
    scroller.scrollerStyle = .overlay
    scroller.knobStyle = .dark
    let handle = scroller.realizeNativePeer(in: backend, parent: nil)

    // The overlay flag and knob style reach the backend at realize time.
    expect(backend.scrollerOverlays[handle] == true,
           "Overlay scroller style did not reach the native peer.")
    expect(backend.scrollerKnobStyles[handle] == .dark,
           "Dark knob style did not reach the native peer.")

    // A later change pushes through as well (the didSet path).
    scroller.knobStyle = .light
    scroller.scrollerStyle = .legacy
    expect(backend.scrollerKnobStyles[handle] == .light,
           "Changing the knob style did not update the native peer.")
    expect(backend.scrollerOverlays[handle] == false,
           "Changing to the legacy style did not update the native peer.")
}

@MainActor
func testDatePickerStoresDateRangeAndSyncsNativePeer() {
    let backend = InMemoryNativeControlBackend()
    let initialDate = Date(timeIntervalSince1970: 1_780_272_000)
    let minDate = Date(timeIntervalSince1970: 1_735_689_600)
    let maxDate = Date(timeIntervalSince1970: 1_893_456_000)
    let picker = NSDatePicker(date: initialDate, frame: NSMakeRect(0, 0, 180, 28))
    var actionCount = 0

    picker.minDate = minDate
    picker.maxDate = maxDate
    picker.onAction = { control in
        expect(control === picker, "Date picker action sender was not picker.")
        actionCount += 1
    }

    expect(picker.dateValue == initialDate, "Date picker dateValue was not stored.")
    expect(picker.minDate == minDate, "Date picker minDate was not stored.")
    expect(picker.maxDate == maxDate, "Date picker maxDate was not stored.")
    expect(picker.acceptsFirstResponder, "Date picker should accept first responder.")

    let handle = picker.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "datePicker", "Date picker did not request native date picker peer.")
    expect(backend.records[handle]?.datePickerDate == initialDate, "Date picker did not sync initial date.")
    expect(backend.records[handle]?.datePickerMinDate == minDate, "Date picker did not sync min date.")
    expect(backend.records[handle]?.datePickerMaxDate == maxDate, "Date picker did not sync max date.")

    let nextDate = Date(timeIntervalSince1970: 1_783_036_800)
    picker.dateValue = nextDate
    expect(backend.records[handle]?.datePickerDate == nextDate, "Date picker date changes did not sync.")

    backend.actions[handle]?()
    expect(actionCount == 1, "Date picker native action did not fire.")
}

@MainActor
func testDatePickerClockAndCalendarStyle() {
    let backend = InMemoryNativeControlBackend()
    let initialDate = Date(timeIntervalSince1970: 1_780_272_000)
    let picker = NSDatePicker(date: initialDate, frame: NSMakeRect(0, 0, 240, 160))
    picker.datePickerStyle = .clockAndCalendar

    let handle = picker.realizeNativePeer(in: backend, parent: nil)

    // The calendar style requests the month-calendar peer, not the text field.
    expect(backend.records[handle]?.kind == "calendarDatePicker", "Clock-and-calendar style did not request a calendar peer.")
    expect(backend.records[handle]?.datePickerDate == initialDate, "Calendar picker did not sync its date.")

    // Value still round-trips through the control.
    let nextDate = Date(timeIntervalSince1970: 1_783_036_800)
    picker.dateValue = nextDate
    expect(backend.records[handle]?.datePickerDate == nextDate, "Calendar picker date change did not sync.")

    // A default-style picker still uses the compact field peer.
    let field = NSDatePicker(date: initialDate, frame: NSMakeRect(0, 0, 180, 28))
    let fieldHandle = field.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[fieldHandle]?.kind == "datePicker", "Default style should still use the field peer.")
}

@MainActor
func testSegmentedControlStoresSegmentsAndDrawsOnAView() {
    let backend = InMemoryNativeControlBackend()
    let segmented = NSSegmentedControl(labels: ["One", "Two"], frame: NSMakeRect(0, 0, 160, 28))
    segmented.setLabel("First", forSegment: 0)
    segmented.setWidth(90, forSegment: 0)
    segmented.setEnabled(false, forSegment: 1)
    segmented.selectedSegment = 0

    expect(segmented.segmentCount == 2, "Segmented control segment count was not stored.")
    expect(
        segmented.label(forSegment: 0) == "First",
        "Segmented control label was not stored; got \(String(describing: segmented.label(forSegment: 0)))."
    )
    expect(segmented.width(forSegment: 0) == 90, "Segmented control width was not stored.")
    expect(!segmented.isEnabled(forSegment: 1), "Segmented control segment enabled state was not stored.")
    expect(segmented.isSelected(forSegment: 0), "Segmented control selected segment was not stored.")

    let handle = segmented.realizeNativePeer(in: backend, parent: nil)

    // The control is framework-drawn on a single view peer (no child buttons).
    expect(backend.records[handle]?.kind == "view", "Segmented control did not request a native container view.")

    // Segment frames honor the fixed width: segment 0 is 90 wide, segment 1
    // takes the remaining 70 of the 160-wide control, laid out left to right.
    let frames = segmented.winSegmentFrames()
    expect(frames.count == 2, "Segmented control should compute one frame per segment.")
    expect(frames[0].size.width == 90, "Fixed-width segment should keep its width; got \(frames[0].size.width).")
    expect(abs(frames[1].origin.x - 90) < 0.001, "The second segment should begin where the first ends.")
    expect(abs(frames[1].size.width - 70) < 0.001, "The automatic segment should take the remaining width.")
}

@MainActor
func testSegmentedControlDrawsSegmentImages() {
    let backend = InMemoryNativeControlBackend()
    let segmented = NSSegmentedControl(labels: ["", "Text"], frame: NSMakeRect(0, 0, 160, 28))
    let iconPath = "C:/icons/seg.png"
    guard let icon = NSImage(contentsOfFile: iconPath) else {
        fatalError("Failed to build the file-backed segment image.")
    }
    icon.isTemplate = true
    segmented.setImage(icon, forSegment: 0)
    segmented.selectedSegment = 1

    expect(segmented.image(forSegment: 0) === icon, "Segmented control did not store the segment image.")

    let handle = segmented.realizeNativePeer(in: backend, parent: nil)
    let recording = backend.performDraw(for: handle, in: segmented.bounds)

    // Segment 0's file-backed image draws, tinted (it is a template) to the
    // segment's label color; segment 1 still draws its text label.
    guard let drawn = recording.images.first(where: { $0.path == iconPath }) else {
        fatalError("Segment image was not drawn. Got \(recording.images.map { $0.path }).")
    }
    expect(drawn.tint != nil, "A template segment image should draw tinted to the label color.")
    expect(drawn.rect.origin.x < 80,
           "The first segment's image should sit within its own (left) segment.")
    expect(recording.texts.contains { $0.text == "Text" },
           "The labeled segment should still draw its text alongside image segments.")
}

@MainActor
func testSegmentedControlSeparatedStyleGapsSegments() {
    // The pure spacing helper: only .separated stands segments apart.
    expect(NSSegmentedControl.winSegmentSpacing(for: .separated) > 0, "Separated style should introduce a gap.")
    expect(NSSegmentedControl.winSegmentSpacing(for: .rounded) == 0, "Joined styles should not gap segments.")
    expect(NSSegmentedControl.winSegmentSpacing(for: .automatic) == 0, "The default joined style should not gap segments.")

    // Joined (default): segment 2 begins exactly where segment 1 ends.
    let joined = NSSegmentedControl(labels: ["A", "B"], frame: NSMakeRect(0, 0, 160, 28))
    let jFrames = joined.winSegmentFrames()
    expect(abs(jFrames[1].origin.x - (jFrames[0].origin.x + jFrames[0].size.width)) < 0.001,
        "Joined segments should be adjacent (no gap).")

    // Separated: a positive gap opens between the two segments, and both still
    // fit inside the control's width.
    let separated = NSSegmentedControl(labels: ["A", "B"], frame: NSMakeRect(0, 0, 160, 28))
    separated.segmentStyle = .separated
    let sFrames = separated.winSegmentFrames()
    let gap = sFrames[1].origin.x - (sFrames[0].origin.x + sFrames[0].size.width)
    expect(abs(gap - NSSegmentedControl.winSegmentSpacing(for: .separated)) < 0.001,
        "Separated segments should be spaced by the style gap; got \(gap).")
    expect(sFrames[1].origin.x + sFrames[1].size.width <= 160.001, "Separated segments should stay inside the control width.")
}

@MainActor
func testSegmentedControlStyleDrivesCornerRadius() {
    // The style sets the outer corner radius the framework draws: a full pill for
    // .capsule (half the height), a modest rounding for the rounded family, and
    // square corners for the textured/small-square family.
    let height: CGFloat = 28
    expect(NSSegmentedControl.winSegmentCornerRadius(for: .capsule, height: height) == height / 2,
        "Capsule should be a full half-height pill.")
    expect(NSSegmentedControl.winSegmentCornerRadius(for: .texturedSquare, height: height) == 0,
        "Textured-square should have square corners.")
    expect(NSSegmentedControl.winSegmentCornerRadius(for: .smallSquare, height: height) == 0,
        "Small-square should have square corners.")
    let rounded = NSSegmentedControl.winSegmentCornerRadius(for: .rounded, height: height)
    expect(rounded > 0 && rounded < height / 2, "Rounded should round modestly, less than a full pill.")
    // The capsule is rounder than the rounded style, which is rounder than square.
    expect(NSSegmentedControl.winSegmentCornerRadius(for: .capsule, height: height) > rounded
        && rounded > NSSegmentedControl.winSegmentCornerRadius(for: .roundRect, height: height) - 3,
        "Corner radius should increase from square → roundRect → rounded → capsule.")
}

@MainActor
func testSegmentedControlPerSegmentImageAndTag() {
    let segmented = NSSegmentedControl(labels: ["Grid", "List"], frame: NSMakeRect(0, 0, 160, 28))

    // Per-segment tags round-trip and follow the selection.
    segmented.setTag(11, forSegment: 0)
    segmented.setTag(22, forSegment: 1)
    expect(segmented.tag(forSegment: 0) == 11, "Segment tag was not stored.")
    expect(segmented.tag(forSegment: 1) == 22, "Second segment tag was not stored.")
    segmented.selectedSegment = 1
    expect(segmented.selectedSegmentTag() == 22, "selectedSegmentTag did not follow the selection.")

    // Per-segment images round-trip through the model (rendering is a follow-up
    // in the framework-drawn control; labels render for now).
    let icon = NSImage(named: "grid.symbol")
    segmented.setImage(icon, forSegment: 0)
    expect(segmented.image(forSegment: 0) === icon, "Segment image was not stored.")
    expect(segmented.image(forSegment: 1) == nil, "Unset segment image should be nil.")
}

@MainActor
func testSegmentedControlPerSegmentMenu() {
    let backend = InMemoryNativeControlBackend()
    let segmented = NSSegmentedControl(labels: ["File", "Options"], frame: NSMakeRect(0, 0, 160, 28))
    let menu = NSMenu(title: "Options")
    menu.addItem(NSMenuItem(title: "A", action: nil, keyEquivalent: ""))
    segmented.setMenu(menu, forSegment: 1)

    expect(segmented.menu(forSegment: 1) === menu, "Segment menu was not stored.")
    expect(segmented.menu(forSegment: 0) == nil, "Segment without a menu should return nil.")

    segmented.realizeNativePeer(in: backend, parent: nil)
    segmented.selectedSegment = 0

    // Clicking the menu segment pops its menu instead of changing selection.
    segmented.winSelectSegment(byClickAt: 1)
    expect(backend.poppedContextMenus.last === menu, "Clicking a menu segment did not pop its menu.")
    expect(segmented.selectedSegment == 0, "A menu segment should not become the selection.")

    // A plain segment still selects normally.
    segmented.winSelectSegment(byClickAt: 0)
    expect(segmented.selectedSegment == 0, "Clicking a plain segment should select it.")
}

@MainActor
func testSegmentedControlActionSelectsSegment() {
    let segmented = NSSegmentedControl(labels: ["One", "Two"], frame: NSMakeRect(0, 0, 160, 28))
    var actionCount = 0
    segmented.onAction = { control in
        guard let segmented = control as? NSSegmentedControl else {
            expect(false, "Segmented action sender was not segmented control.")
            return
        }

        actionCount += 1
        expect(segmented.selectedSegment == 1, "Segmented control did not select clicked segment.")
    }

    segmented.winSelectSegment(byClickAt: 1)
    expect(actionCount == 1, "Segmented control action was not dispatched.")
}

