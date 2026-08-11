import WinChocolate

@MainActor
func testTimeZoneOffsetsAndNames() {
    #if os(Windows)
    let summer = Date(timeIntervalSince1970: 1_780_272_000) // 2026-06-01 UTC
    let winter = Date(timeIntervalSince1970: 1_765_584_000) // 2025-12-13 UTC

    // A fixed-offset zone is constant, and rejects nonsense.
    let plusFive = TimeZone(secondsFromGMT: 5 * 3_600 + 30 * 60)!
    expect(plusFive.secondsFromGMT(for: summer) == 19_800, "A fixed zone did not report its offset.")
    expect(plusFive.identifier == "GMT+0530", "A fixed zone's identifier was wrong: \(plusFive.identifier).")
    expect(!plusFive.isDaylightSavingTime(for: summer), "A fixed zone must never report DST.")
    expect(TimeZone(secondsFromGMT: 40 * 3_600) == nil, "An impossible offset should not construct.")

    // UTC resolves by name; an IANA name does not (Windows has no such
    // database), and returning nil is better than quietly returning the wrong
    // zone.
    expect(TimeZone(identifier: "UTC")?.secondsFromGMT(for: summer) == 0, "UTC did not resolve to a zero offset.")
    expect(TimeZone(identifier: "America/New_York") == nil, "An IANA identifier should not silently resolve.")

    // The system zone reports a plausible offset and names itself, and its
    // summer/winter answers are self-consistent: DST adds an hour to standard
    // time, and a zone without DST reports the same offset all year.
    let system = TimeZone.current
    expect(abs(system.secondsFromGMT(for: summer)) <= 14 * 3_600, "The system zone offset is out of range.")
    expect(!system.identifier.isEmpty, "The system zone did not name itself.")
    expect(system.longName(for: summer)?.isEmpty == false, "The system zone had no display name.")

    let summerOffset = system.secondsFromGMT(for: summer)
    let winterOffset = system.secondsFromGMT(for: winter)
    if summerOffset == winterOffset {
        expect(!system.isDaylightSavingTime(for: summer) && !system.isDaylightSavingTime(for: winter),
               "A zone with one offset all year must not report DST.")
        expect(system.longName(for: summer) == system.longName(for: winter),
               "A zone without DST should not change its name across the year.")
    } else {
        // Whichever half of the year has the larger offset is the daylight one
        // — true in either hemisphere, since DST always adds.
        let daylight = max(summerOffset, winterOffset)
        let daylightDate = summerOffset == daylight ? summer : winter
        let standardDate = summerOffset == daylight ? winter : summer
        expect(system.isDaylightSavingTime(for: daylightDate), "The larger offset should be the daylight one.")
        expect(!system.isDaylightSavingTime(for: standardDate), "The smaller offset should be standard time.")
        expect(system.longName(for: daylightDate) != system.longName(for: standardDate),
               "Daylight and standard time should not share a display name.")
    }
    #endif
}

@MainActor
func testDateFormatterPatternsAndRoundTrip() {
    #if os(Windows)
    let formatter = DateFormatter()
    // This test is about the pattern engine, not zones: pin it to GMT so a
    // wall clock and its instant coincide and the assertions below hold
    // wherever they run.
    formatter.timeZone = TimeZone(secondsFromGMT: 0)!

    // Round-trip a date+time through parse and format.
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    guard let date = formatter.date(from: "2026-06-01 12:34:56") else {
        expect(false, "date(from:) failed to parse a valid date.")
        return
    }
    let roundTrip = formatter.string(from: date)
    expect(roundTrip == "2026-06-01 12:34:56", "Round-trip date+time mismatch. Got \(roundTrip).")

    // Month names.
    formatter.dateFormat = "MMMM d, yyyy"
    expect(formatter.string(from: date) == "June 1, 2026", "Long month name was wrong.")
    formatter.dateFormat = "MMM d"
    expect(formatter.string(from: date) == "Jun 1", "Short month name was wrong.")

    // 12-hour clock with meridiem, both directions.
    formatter.dateFormat = "h:mm a"
    expect(formatter.string(from: date) == "12:34 PM", "12-hour PM format was wrong.")
    guard let morning = formatter.date(from: "9:05 AM") else {
        expect(false, "12-hour parse failed.")
        return
    }
    formatter.dateFormat = "HH:mm"
    expect(formatter.string(from: morning) == "09:05", "AM parse/format was wrong.")

    // The Unix epoch is a Thursday.
    formatter.dateFormat = "yyyy-MM-dd"
    guard let epoch = formatter.date(from: "1970-01-01") else {
        expect(false, "Epoch parse failed.")
        return
    }
    expect(epoch.timeIntervalSince1970 == 0, "Epoch parse was not zero.")
    formatter.dateFormat = "EEEE"
    expect(formatter.string(from: epoch) == "Thursday", "Epoch weekday was wrong.")

    // Style presets drive output when dateFormat is empty. Medium and short
    // join with ", " — ICU's en_US rule, which the full and long styles spell
    // as " at " (that is where AppKit's "May 31, 2026 at 8:00:00 PM" comes
    // from).
    let styled = DateFormatter()
    styled.timeZone = TimeZone(secondsFromGMT: 0)!
    styled.dateStyle = .medium
    styled.timeStyle = .short
    expect(styled.string(from: date) == "Jun 1, 2026, 12:34 PM", "Style preset format was wrong.")

    let longStyle = DateFormatter()
    longStyle.timeZone = TimeZone(secondsFromGMT: 0)!
    longStyle.dateStyle = .full
    longStyle.timeStyle = .full
    let fullText = longStyle.string(from: date)
    expect(fullText.contains(" at "), "The full style should join with ' at ', got \(fullText).")
    expect(fullText.hasPrefix("Monday, June 1, 2026"), "The full style's date half was wrong, got \(fullText).")

    // Quoted literals pass through.
    formatter.dateFormat = "yyyy 'at' HH:mm"
    expect(formatter.string(from: date) == "2026 at 12:34", "Quoted literal was not handled.")

    // A non-matching string parses to nil.
    formatter.dateFormat = "yyyy-MM-dd"
    expect(formatter.date(from: "not a date") == nil, "Bad input should parse to nil.")
    #endif
}

@MainActor
func testWindowMovableByBackground() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
    }

    // isMovableByWindowBackground marks the content view as a window-drag area.
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 400, 300),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let content = NSView(frame: NSMakeRect(0, 0, 400, 300))
    window.contentView = content
    window.isMovableByWindowBackground = true
    _ = window.realizeNativePeer()

    guard let contentHandle = content.nativeHandle else {
        expect(false, "Content view did not realize.")
        return
    }
    expect(backend.windowDragViewHandles.contains(contentHandle), "Movable-by-background did not mark the content view.")
    window.isMovableByWindowBackground = false
    expect(!backend.windowDragViewHandles.contains(contentHandle), "Clearing movable-by-background did not unmark the view.")
}

@MainActor
func testPanelBecomesKeyOnlyIfNeeded() {
    let backend = InMemoryNativeControlBackend()
    // A becomesKeyOnlyIfNeeded panel becomes key only with an editable view.
    let barePanel = NSPanel(
        contentRect: NSMakeRect(0, 0, 200, 120),
        styleMask: [.titled, .utilityWindow],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    barePanel.becomesKeyOnlyIfNeeded = true
    let bareContent = NSView(frame: NSMakeRect(0, 0, 200, 120))
    bareContent.addSubview(NSButton(title: "Close", frame: NSMakeRect(10, 10, 80, 28)))
    barePanel.contentView = bareContent
    expect(!barePanel.canBecomeKey, "A button-only key-only panel should not become key.")

    let editPanel = NSPanel(
        contentRect: NSMakeRect(0, 0, 200, 120),
        styleMask: [.titled, .utilityWindow],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    editPanel.becomesKeyOnlyIfNeeded = true
    let editContent = NSView(frame: NSMakeRect(0, 0, 200, 120))
    let editField = NSTextField(string: "", frame: NSMakeRect(10, 10, 160, 24))
    editField.isEditable = true
    editContent.addSubview(editField)
    editPanel.contentView = editContent
    expect(editPanel.canBecomeKey, "A panel hosting an editable field should be able to become key.")

    // Without the flag, panels always can become key.
    editPanel.becomesKeyOnlyIfNeeded = false
    expect(barePanel.canBecomeKey == false, "barePanel still keyed off its own flag.")
}

@MainActor
func testColorWellStyleAndBorder() {
    // NSColorWell style and border are configurable.
    let well = NSColorWell(frame: NSMakeRect(0, 0, 44, 24))
    expect(well.colorWellStyle == .default && well.isBordered, "Color well defaults were wrong.")
    well.colorWellStyle = .minimal
    well.isBordered = false
    expect(well.colorWellStyle == .minimal && !well.isBordered, "Color well style/border did not update.")
}

@MainActor
func testWindowMovableByBackgroundAndPanelKeyAndColorWell() {
    testWindowMovableByBackground()
    testPanelBecomesKeyOnlyIfNeeded()
    testColorWellStyleAndBorder()
}

@MainActor
func testDatePickerElementFormats() {
    let backend = InMemoryNativeControlBackend()

    // Date-only shows the locale's short date, which is where AppKit's
    // four-digit year comes from (its "Mdyyyy" template, our LOCALE_SSHORTDATE).
    let dateOnly = NSDatePicker(frame: NSMakeRect(0, 0, 160, 24))
    let dateHandle = dateOnly.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[dateHandle]?.datePickerFormat == Locale.current.shortDatePattern,
           "Date-only picker did not use the locale short date pattern.")

    // Time-only uses the locale time pattern.
    let timeOnly = NSDatePicker(frame: NSMakeRect(0, 0, 160, 24))
    timeOnly.datePickerElements = [.hourMinuteSecond]
    let timeHandle = timeOnly.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[timeHandle]?.datePickerFormat == Locale.current.timePattern, "Time picker did not use the locale time pattern.")

    // Date and time join with ", ", matching AppKit's template output
    // ("M/d/yyyy, h:mm:ss a"). It used to join with a bare space.
    let both = NSDatePicker(frame: NSMakeRect(0, 0, 200, 24))
    both.datePickerElements = [.yearMonthDay, .hourMinuteSecond]
    let bothHandle = both.realizeNativePeer(in: backend, parent: nil)
    let expectedBoth = "\(Locale.current.shortDatePattern), \(Locale.current.timePattern)"
    expect(backend.records[bothHandle]?.datePickerFormat == expectedBoth, "Date-time picker format was wrong.")

    // Changing elements after realization re-applies the format.
    both.datePickerElements = [.hourMinuteSecond]
    expect(backend.records[bothHandle]?.datePickerFormat == Locale.current.timePattern, "Element change did not re-apply the format.")

    // Hour-minute drops the seconds by using the locale's own short time.
    let hourMinute = NSDatePicker(frame: NSMakeRect(0, 0, 160, 24))
    hourMinute.datePickerElements = [.hourMinute]
    let hourMinuteHandle = hourMinute.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[hourMinuteHandle]?.datePickerFormat == Locale.current.shortTimePattern,
           "Hour-minute picker did not use the locale short time pattern.")

    // Year-month drops the day but keeps the locale's field order and its
    // numeric shape, as Apple's "yyyyM" template does ("5/2026").
    let yearMonth = NSDatePicker(frame: NSMakeRect(0, 0, 160, 24))
    yearMonth.datePickerElements = [.yearMonth]
    let yearMonthHandle = yearMonth.realizeNativePeer(in: backend, parent: nil)
    let yearMonthFormat = backend.records[yearMonthHandle]?.datePickerFormat ?? ""
    expect(!yearMonthFormat.isEmpty && !yearMonthFormat.contains("d"),
           "Year-month picker should not show a day field, got \(yearMonthFormat).")
    expect(yearMonthFormat.contains("M") && yearMonthFormat.contains("yyyy"),
           "Year-month picker lost its month or year, got \(yearMonthFormat).")

    // The era renders as the control's era field.
    let era = NSDatePicker(frame: NSMakeRect(0, 0, 200, 24))
    era.datePickerElements = [.yearMonthDay, .era]
    let eraHandle = era.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[eraHandle]?.datePickerFormat?.contains("gg") == true,
           "Era element did not add an era field.")
}

@MainActor
func testDatePickerElementFlagsMatchApple() {
    // Apple's real raw values, read out of AppKit. The previous values here
    // were invented `1 << n` bits: symbolic use compiled either way, so only a
    // raw value or a cross-pair `contains` check can catch it.
    expect(NSDatePicker.ElementFlags.hourMinute.rawValue == 0x000c, "hourMinute is not Apple's 0x000c.")
    expect(NSDatePicker.ElementFlags.hourMinuteSecond.rawValue == 0x000e, "hourMinuteSecond is not Apple's 0x000e.")
    expect(NSDatePicker.ElementFlags.timeZone.rawValue == 0x0010, "timeZone is not Apple's 0x0010.")
    expect(NSDatePicker.ElementFlags.yearMonth.rawValue == 0x00c0, "yearMonth is not Apple's 0x00c0.")
    expect(NSDatePicker.ElementFlags.yearMonthDay.rawValue == 0x00e0, "yearMonthDay is not Apple's 0x00e0.")
    expect(NSDatePicker.ElementFlags.era.rawValue == 0x0100, "era is not Apple's 0x0100.")

    // And they are cumulative — the wider flag contains the narrower one, so
    // the wider one has to be tested first.
    expect(NSDatePicker.ElementFlags.hourMinuteSecond.contains(.hourMinute),
           "hourMinuteSecond must contain hourMinute.")
    expect(NSDatePicker.ElementFlags.yearMonthDay.contains(.yearMonth),
           "yearMonthDay must contain yearMonth.")
    expect(!NSDatePicker.ElementFlags.hourMinute.contains(.hourMinuteSecond),
           "hourMinute must not contain hourMinuteSecond.")
    expect(!NSDatePicker.ElementFlags.yearMonth.contains(.yearMonthDay),
           "yearMonth must not contain yearMonthDay.")

    // Apple's styles are raw-valued too.
    expect(NSDatePicker.Style.textFieldAndStepper.rawValue == 0, "textFieldAndStepper is not Apple's 0.")
    expect(NSDatePicker.Style.clockAndCalendar.rawValue == 1, "clockAndCalendar is not Apple's 1.")
    expect(NSDatePicker.Style.textField.rawValue == 2, "textField is not Apple's 2.")
}

@MainActor
func testDatePickerStringValueIsFullDateAndTime() {
    // AppKit's stringValue is DateFormatter(dateStyle: .full, timeStyle: .full)
    // and does NOT vary with datePickerElements — a date-only picker returns
    // the same full string, times and zone included. (Probed on real AppKit:
    // "Sunday, May 31, 2026 at 8:00:00 PM Eastern Daylight Time".)
    let seed = Date(timeIntervalSince1970: 1_780_272_000)
    let full = DateFormatter()
    full.dateStyle = .full
    full.timeStyle = .full

    let dateOnly = NSDatePicker(date: seed, frame: NSMakeRect(0, 0, 200, 24))
    expect(dateOnly.stringValue == full.string(from: seed),
           "Date-only stringValue was not the full date and time, got \(dateOnly.stringValue).")

    let dateAndTime = NSDatePicker(date: seed, frame: NSMakeRect(0, 0, 200, 24))
    dateAndTime.datePickerElements = [.yearMonthDay, .hourMinuteSecond]
    expect(dateAndTime.stringValue == dateOnly.stringValue,
           "stringValue must not vary with datePickerElements.")

    // It is a real full string, not a short date: it names the weekday and the
    // zone, and joins the halves with " at " as ICU does.
    expect(dateOnly.stringValue.contains(" at "), "Full stringValue should join date and time with ' at '.")
    expect(dateOnly.stringValue.contains("2026"), "Full stringValue should carry a four-digit year.")
    expect(dateOnly.stringValue.count > "6/1/2026".count,
           "stringValue looks like the old short date: \(dateOnly.stringValue).")
}

@MainActor
func testDatePickerRendersLocalWallClock() {
    // A Date is an instant; the field shows it in the picker's zone. The
    // backend used to be handed UTC with the time fields zeroed, so the demo's
    // 2026-06-01T00:00Z rendered "6/1/2026 12:00:00 AM" instead of AppKit's
    // "5/31/2026, 8:00:00 PM" (Eastern).
    let backend = InMemoryNativeControlBackend()
    let seed = Date(timeIntervalSince1970: 1_780_272_000)
    let picker = NSDatePicker(date: seed, frame: NSMakeRect(0, 0, 200, 24))
    picker.datePickerElements = [.yearMonthDay, .hourMinuteSecond]
    let handle = picker.realizeNativePeer(in: backend, parent: nil)

    // The framework resolves the zone and pushes it: a SYSTEMTIME carries no
    // zone, so the backend cannot place the instant without being told.
    expect(backend.records[handle]?.datePickerTimeZone?.identifier == TimeZone.current.identifier,
           "The picker did not push its resolved zone to the peer.")
    expect(backend.records[handle]?.datePickerDate == seed,
           "The peer should hold the instant itself, not a shifted wall clock.")

    // The value survives the round trip, time of day included — the read path
    // used to keep only year/month/day, silently resetting any typed time.
    let withTime = Date(timeIntervalSince1970: 1_780_272_000 + 20 * 3_600 + 34 * 60 + 56)
    picker.dateValue = withTime
    expect(backend.records[handle]?.datePickerDate == withTime, "The peer lost the time of day.")
}

@MainActor
func testDatePickerStyleRequestsAStepper() {
    // AppKit's default style is .textFieldAndStepper — a field WITH a stepper
    // and no calendar popup. The Windows peer used to be created without
    // DTS_UPDOWN, so the style named after a stepper had none and showed a
    // drop-down calendar button instead.
    let backend = InMemoryNativeControlBackend()
    let seed = Date(timeIntervalSince1970: 1_780_272_000)

    let byDefault = NSDatePicker(date: seed, frame: NSMakeRect(0, 0, 180, 28))
    expect(byDefault.datePickerStyle == .textFieldAndStepper, "The default style is not Apple's .textFieldAndStepper.")
    let defaultHandle = byDefault.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[defaultHandle]?.datePickerShowsStepper == true,
           "The default style did not ask for a stepper.")

    // A bare field has no stepper...
    let field = NSDatePicker(date: seed, frame: NSMakeRect(0, 0, 180, 28))
    field.datePickerStyle = .textField
    let fieldHandle = field.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[fieldHandle]?.datePickerShowsStepper == false,
           "A .textField picker should have no stepper.")

    // ...and neither does the calendar.
    let calendar = NSDatePicker(date: seed, frame: NSMakeRect(0, 0, 240, 160))
    calendar.datePickerStyle = .clockAndCalendar
    let calendarHandle = calendar.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[calendarHandle]?.datePickerShowsStepper == false,
           "A calendar picker should have no stepper.")
}

#if !os(Windows)
@MainActor
func testDatePickerFieldEditing() {
    let backend = InMemoryNativeControlBackend()
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US")
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let seed = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15))!
    let picker = NSDatePicker(date: seed, frame: NSMakeRect(0, 0, 180, 28))
    picker.locale = calendar.locale
    picker.timeZone = calendar.timeZone
    let handle = picker.realizeNativePeer(in: backend, parent: nil)
    let initialText = backend.datePickerTexts[handle]

    backend.simulateDatePickerTyping("12", for: handle)
    expect(calendar.component(.month, from: picker.dateValue) == 12,
           "Typing did not replace the selected date segment.")
    let typedText = backend.datePickerTexts[handle]
    expect(typedText != initialText, "Typing did not refresh the displayed date-field text.")

    backend.simulateDateStep(1, for: handle)
    expect(calendar.component(.day, from: picker.dateValue) == 16,
           "The date stepper did not change the selected segment.")
    expect(backend.datePickerTexts[handle] != typedText,
           "Stepping did not refresh the displayed date-field text.")
}
#endif

@MainActor
func testButtonImageAndAlternateTitle() {
    let backend = InMemoryNativeControlBackend()

    // A toggle button swaps to its alternate title in the on state.
    let toggle = NSButton(title: "Play", frame: NSMakeRect(0, 0, 100, 28))
    toggle.setButtonType(.switch)
    toggle.alternateTitle = "Pause"
    let toggleHandle = toggle.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[toggleHandle]?.text == "Play", "Off-state button did not show the base title.")

    toggle.state = .on
    expect(backend.records[toggleHandle]?.text == "Pause", "On-state button did not swap to the alternate title.")
    toggle.state = .off
    expect(backend.records[toggleHandle]?.text == "Play", "Returning off did not restore the base title.")

    // An image reaches the backend by file path.
    let button = NSButton(title: "Icon", frame: NSMakeRect(0, 0, 80, 28))
    button.image = NSImage(contentsOfFile: "C:/icons/star.png")
    button.imagePosition = .imageLeft
    let handle = button.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[handle]?.buttonImagePath == "C:/icons/star.png", "Button image path did not reach the backend.")

    // Clearing the image removes it.
    button.image = nil
    expect(backend.records[handle]?.buttonImagePath == nil, "Clearing the button image did not reach the backend.")
}

@MainActor
func testTextFieldDelegateEditingCallbacks() {
    let backend = InMemoryNativeControlBackend()
    let field = NSTextField(string: "", frame: NSMakeRect(0, 0, 160, 24))
    field.isEditable = true
    let delegate = RecordingTextFieldDelegate()
    field.delegate = delegate
    let handle = field.realizeNativePeer(in: backend, parent: nil)

    // Focus in → begin editing; native text change → change; focus out → end.
    backend.simulateFocusChange(gained: true, for: handle)
    expect(delegate.began == 1, "controlTextDidBeginEditing did not fire on focus.")

    backend.textChangeActions[handle]?("Choc")
    expect(delegate.changed == 1, "controlTextDidChange did not fire on a native edit.")
    expect(delegate.lastChangedText == "Choc", "Change notification carried the wrong text.")
    expect(field.stringValue == "Choc", "Text field did not adopt the edited text.")

    backend.simulateFocusChange(gained: false, for: handle)
    expect(delegate.ended == 1, "controlTextDidEndEditing did not fire on focus loss.")

    // A non-editable label does not register focus editing callbacks.
    let label = NSTextField(string: "Label", frame: NSMakeRect(0, 0, 80, 20))
    let labelDelegate = RecordingTextFieldDelegate()
    label.delegate = labelDelegate
    let labelHandle = label.realizeNativePeer(in: backend, parent: nil)
    expect(backend.focusChangeActions[labelHandle] == nil, "A label registered an editing focus watch.")
}

@MainActor
func testPopUpButtonTagsAndPullsDown() {
    let popUp = NSPopUpButton(frame: NSMakeRect(0, 0, 120, 24), pullsDown: true)
    expect(popUp.pullsDown, "pullsDown flag was not retained from the initializer.")

    popUp.addItems(withTitles: ["Red", "Green", "Blue"])
    popUp.setTag(10, forItemAt: 0)
    popUp.setTag(20, forItemAt: 1)
    popUp.setTag(30, forItemAt: 2)

    expect(popUp.tag(atIndex: 1) == 20, "Item tag did not read back.")
    expect(popUp.indexOfItem(withTag: 30) == 2, "indexOfItem(withTag:) was wrong.")
    expect(popUp.indexOfItem(withTag: 99) == -1, "Missing tag did not return -1.")

    expect(popUp.selectItem(withTag: 20), "selectItem(withTag:) did not find the tag.")
    expect(popUp.indexOfSelectedItem == 1, "selectItem(withTag:) selected the wrong item.")
    expect(popUp.selectedTag() == 20, "selectedTag() did not match the selection.")
    expect(!popUp.selectItem(withTag: 99), "selectItem(withTag:) accepted a missing tag.")

    // Removing an item keeps titles and tags aligned.
    popUp.removeItem(at: 0)
    expect(popUp.tag(atIndex: 0) == 20, "Tags did not stay aligned with titles after removal.")
    expect(popUp.indexOfItem(withTag: 10) == -1, "Removed item's tag lingered.")
}

@MainActor
func testAlertHelpAndIconConfiguration() {
    let alert = NSAlert()
    alert.messageText = "Delete the file?"
    alert.showsHelp = true
    alert.helpAnchor = "trash-help"
    expect(alert.showsHelp, "showsHelp was not stored.")
    expect(alert.helpAnchor == "trash-help", "helpAnchor was not stored.")

    // A delegate that handles help suppresses the fallback closure.
    final class HelpDelegate: NSObject, NSAlertDelegate {
        var asked = 0
        func alertShowHelp(_ alert: NSAlert) -> Bool {
            asked += 1
            return true
        }
    }
    let delegate = HelpDelegate()
    alert.delegate = delegate
    expect(alert.delegate?.alertShowHelp(alert) == true, "Alert delegate help routing failed.")
    expect(delegate.asked == 1, "Help delegate was not consulted.")

    // The default delegate implementation reports help unhandled.
    final class PlainDelegate: NSObject, NSAlertDelegate {}
    expect(PlainDelegate().alertShowHelp(alert) == false, "Default alertShowHelp should be false.")

    // A custom icon is retained for the composed panel.
    alert.icon = NSImage(named: "custom")
    expect(alert.icon != nil, "Custom alert icon was not stored.")
}

@MainActor
func testCommonControlDepthWiresToBackend() {
    let backend = InMemoryNativeControlBackend()

    // Text field: placeholder + alignment reach the peer.
    let field = NSTextField(string: "", frame: NSMakeRect(0, 0, 120, 24))
    field.isEditable = true
    field.placeholderString = "Search"
    field.alignment = .center
    let fieldHandle = field.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[fieldHandle]?.placeholder == "Search", "Placeholder did not reach the backend.")
    expect(backend.records[fieldHandle]?.textAlignment == .center, "Alignment did not reach the backend.")
    field.alignment = .right
    expect(backend.records[fieldHandle]?.textAlignment == .right, "Alignment change did not sync.")

    // Slider: tick marks + vertical + tick snapping.
    let slider = NSSlider(frame: NSMakeRect(0, 0, 120, 24))
    slider.minValue = 0
    slider.maxValue = 10
    slider.numberOfTickMarks = 11
    slider.isVertical = true
    let sliderHandle = slider.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[sliderHandle]?.sliderTickMarkCount == 11, "Tick-mark count did not reach the backend.")
    expect(backend.records[sliderHandle]?.sliderIsVertical == true, "Vertical orientation did not reach the backend.")
    expect(slider.closestTickMarkValue(toValue: 4.4) == 4, "Tick snapping picked the wrong value.")

    // Combo box: visible items + forward completion.
    let combo = NSComboBox(frame: NSMakeRect(0, 0, 140, 24))
    combo.addItems(withObjectValues: ["Apple", "Apricot", "Banana"])
    combo.numberOfVisibleItems = 8
    combo.completes = true
    let comboHandle = combo.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[comboHandle]?.comboBoxVisibleItems == 8, "Visible-item count did not reach the backend.")
    expect(combo.completedString(forPrefix: "ap") == "Apple", "Completion did not find the first prefix match.")
    expect(combo.completedString(forPrefix: "ban") == "Banana", "Completion missed a later item.")
    expect(combo.completedString(forPrefix: "z") == nil, "Completion matched a non-prefix.")

    // Button: key equivalent fires the action.
    let button = NSButton(title: "OK", frame: NSMakeRect(0, 0, 80, 28))
    button.keyEquivalent = "\r"
    var clicks = 0
    button.onAction = { _ in clicks += 1 }
    _ = button.realizeNativePeer(in: backend, parent: nil)
    let returnEvent = NSEvent(type: .keyDown, locationInWindow: NSMakePoint(0, 0), keyCode: 0x0d, characters: "\r", modifierFlags: [])
    expect(button.performKeyEquivalent(with: returnEvent), "Return key equivalent was not recognized.")
    expect(clicks == 1, "Key equivalent did not fire the action.")
    let otherEvent = NSEvent(type: .keyDown, locationInWindow: NSMakePoint(0, 0), keyCode: 0x41, characters: "a", modifierFlags: [])
    expect(!button.performKeyEquivalent(with: otherEvent), "Unrelated key wrongly matched the equivalent.")

    testLevelIndicatorThresholdColors(backend: backend)
}

@MainActor
func testLevelIndicatorThresholdColors(backend: InMemoryNativeControlBackend) {
    // Level indicator: warning/critical recolor the bar.
    let level = NSLevelIndicator(frame: NSMakeRect(0, 0, 120, 20))
    level.minValue = 0
    level.maxValue = 100
    level.warningValue = 60
    level.criticalValue = 85
    let levelHandle = level.realizeNativePeer(in: backend, parent: nil)
    level.doubleValue = 40
    expect(backend.records[levelHandle]?.progressBarColor == nil, "Below-threshold bar was colored.")
    level.doubleValue = 70
    expect(backend.records[levelHandle]?.progressBarColor != nil, "Warning threshold did not color the bar.")
    level.doubleValue = 95
    expect(backend.records[levelHandle]?.progressBarColor == .red, "Critical threshold did not turn the bar red.")
}

@MainActor
func testSegmentedControlKeyboardSelection() {
    let segmented = NSSegmentedControl(labels: ["One", "Two", "Three"], frame: NSMakeRect(0, 0, 180, 24))
    segmented.trackingMode = .selectOne
    segmented.selectedSegment = 0
    var actions = 0
    segmented.onAction = { _ in actions += 1 }

    let right = NSEvent(type: .keyDown, locationInWindow: NSMakePoint(0, 0), keyCode: 0x27, characters: nil, modifierFlags: [])
    segmented.keyDown(with: right)
    expect(segmented.selectedSegment == 1, "Right arrow did not advance the segment.")
    segmented.keyDown(with: right)
    expect(segmented.selectedSegment == 2, "Right arrow did not keep advancing.")
    segmented.keyDown(with: right)
    expect(segmented.selectedSegment == 2, "Right arrow moved past the last segment.")

    let left = NSEvent(type: .keyDown, locationInWindow: NSMakePoint(0, 0), keyCode: 0x25, characters: nil, modifierFlags: [])
    segmented.keyDown(with: left)
    expect(segmented.selectedSegment == 1, "Left arrow did not move back.")
    expect(actions == 3, "Keyboard selection did not send actions.")

    // A disabled segment is skipped.
    segmented.setEnabled(false, forSegment: 0)
    segmented.keyDown(with: left)
    expect(segmented.selectedSegment == 1, "Left arrow did not skip the disabled first segment.")
}

@MainActor
func testWindowSizeLimitsAndPopoverDismiss() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
    }

    // Window content size limits reach the backend.
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 400, 300),
        styleMask: [.titled, .resizable],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    window.contentMinSize = NSMakeSize(320, 240)
    window.contentMaxSize = NSMakeSize(800, 600)
    let windowHandle = window.realizeNativePeer()
    expect(backend.records[windowHandle]?.minContentSize == NSMakeSize(320, 240), "Min content size did not reach the backend.")
    expect(backend.records[windowHandle]?.maxContentSize == NSMakeSize(800, 600), "Max content size did not reach the backend.")

    // Transient popover registers an outside-click dismiss and closes on it.
    let anchor = NSView(frame: NSMakeRect(10, 10, 40, 20))
    window.contentView = NSView(frame: NSMakeRect(0, 0, 400, 300))
    window.contentView?.addSubview(anchor)
    window.makeKeyAndOrderFront(nil)

    let controller = NSViewController()
    controller.view = NSView(frame: NSMakeRect(0, 0, 200, 120))
    let popover = NSPopover()
    popover.behavior = .transient
    popover.contentViewController = controller
    popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .maxY)

    expect(popover.isShown, "Popover did not show.")
    expect(backend.outsideClickDismissHandle != nil, "Transient popover did not register an outside-click watch.")

    backend.simulateOutsideClick()
    expect(!popover.isShown, "Outside click did not dismiss the transient popover.")
    expect(backend.outsideClickDismissHandle == nil, "Dismiss watch was not torn down after closing.")
}

