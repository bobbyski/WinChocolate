/// A date picker control.
///
/// This first slice stores AppKit-shaped date state and uses the native backend
/// to create a classic Windows date-time picker where available.
open class NSDatePicker: NSControl {
    /// Visual style for the date picker.
    public enum Style: Sendable {
        case textFieldAndStepper
        case clockAndCalendar
        case textField
    }

    /// Which date/time elements the picker presents.
    public struct ElementFlags: OptionSet, Sendable {
        public let rawValue: UInt

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        public static let yearMonthDay = ElementFlags(rawValue: 1 << 0)
        public static let hourMinuteSecond = ElementFlags(rawValue: 1 << 1)
        public static let timeZone = ElementFlags(rawValue: 1 << 2)

        /// Hour and minute, without seconds.
        public static let hourMinute = ElementFlags(rawValue: 1 << 3)
    }

    /// Selected date.
    open var dateValue: Date {
        didSet {
            dateValue = clampedDate(dateValue)
            syncNativeDate()
        }
    }

    /// Earliest selectable date.
    open var minDate: Date? {
        didSet {
            dateValue = clampedDate(dateValue)
            syncNativeDate()
        }
    }

    /// Latest selectable date.
    open var maxDate: Date? {
        didSet {
            dateValue = clampedDate(dateValue)
            syncNativeDate()
        }
    }

    /// Requested visual style.
    open var datePickerStyle: Style = .textFieldAndStepper

    /// Requested element flags.
    ///
    /// Controls which fields the picker shows: a date, a time, or both. The
    /// native picker's display format follows this.
    open var datePickerElements: ElementFlags = [.yearMonthDay] {
        didSet {
            applyDatePickerFormat()
        }
    }

    /// The native display format for the current element flags, taken from the
    /// user's locale so the picker shows dates the system's way (US on a US
    /// machine). `nil` lets the native control use its own locale short date.
    private var nativeDateFormat: String? {
        let showsDate = datePickerElements.contains(.yearMonthDay)
        let showsTime = datePickerElements.contains(.hourMinuteSecond) || datePickerElements.contains(.hourMinute)
        let locale = Locale.current
        switch (showsDate, showsTime) {
        case (true, true):
            return "\(locale.shortDatePattern) \(locale.timePattern)"
        case (false, true):
            return locale.timePattern
        default:
            return nil
        }
    }

    private func applyDatePickerFormat() {
        guard let nativeHandle else {
            return
        }

        realizedBackend?.setDatePickerFormat(nativeDateFormat, for: nativeHandle)
    }

    /// Creates a date picker with the current date.
    public override init(frame frameRect: NSRect) {
        self.dateValue = Date()
        super.init(frame: frameRect)
    }

    /// Creates a date picker with an explicit date.
    public init(date: Date, frame: NSRect) {
        self.dateValue = date
        super.init(frame: frame)
    }

    /// Date pickers accept keyboard focus.
    open override var acceptsFirstResponder: Bool {
        true
    }

    /// Creates the native date picker peer.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createDatePicker(date: dateValue, minDate: minDate, maxDate: maxDate, showsCalendar: datePickerStyle == .clockAndCalendar, frame: frame, parent: parent)
    }

    /// Wires native date change notifications into the control action path.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        if let format = nativeDateFormat {
            backend.setDatePickerFormat(format, for: handle)
        }
        backend.registerAction(for: handle) { [weak self, weak backend] in
            guard let self, let backend, let nativeHandle = self.nativeHandle else {
                return
            }

            if let date = backend.datePickerDate(for: nativeHandle) {
                self.dateValue = self.clampedDate(date)
            }
            self.sendAction()
        }
        return handle
    }

    /// Human-readable date for demo and test output, formatted through
    /// `DateFormatter` so no date math lives in this control. The format
    /// follows the picker's elements (date, time, or both).
    open var stringValue: String {
        let formatter = DateFormatter()
        let showsTime = datePickerElements.contains(.hourMinuteSecond) || datePickerElements.contains(.hourMinute)
        let showsDate = datePickerElements.contains(.yearMonthDay) || !showsTime
        formatter.dateStyle = showsDate ? .short : .none
        formatter.timeStyle = showsTime ? .medium : .none
        return formatter.string(from: dateValue)
    }

    private func syncNativeDate() {
        guard let nativeHandle else {
            return
        }

        realizedBackend?.setDatePickerDate(dateValue, minDate: minDate, maxDate: maxDate, for: nativeHandle)
    }

    private func clampedDate(_ date: Date) -> Date {
        if let minDate, date < minDate {
            return minDate
        }
        if let maxDate, date > maxDate {
            return maxDate
        }
        return date
    }

}
