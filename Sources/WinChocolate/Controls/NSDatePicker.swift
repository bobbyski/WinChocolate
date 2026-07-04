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

    /// The native display format for the current element flags, or `nil` for
    /// the default date display.
    private var nativeDateFormat: String? {
        let showsDate = datePickerElements.contains(.yearMonthDay)
        let showsTime = datePickerElements.contains(.hourMinuteSecond)
        switch (showsDate, showsTime) {
        case (true, true):
            return "yyyy'-'MM'-'dd HH':'mm':'ss"
        case (false, true):
            return "HH':'mm':'ss"
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
        backend.createDatePicker(date: dateValue, minDate: minDate, maxDate: maxDate, frame: frame, parent: parent)
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

    /// Human-readable date for demo and test output.
    open var stringValue: String {
        let components = Self.utcDateComponents(for: dateValue)
        return "\(Self.padded(components.year, digits: 4))-\(Self.padded(components.month, digits: 2))-\(Self.padded(components.day, digits: 2))"
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

    private static func utcDateComponents(for date: Date) -> (year: Int, month: Int, day: Int) {
        let days = Int((date.timeIntervalSince1970 / 86_400.0).rounded(.down))
        let z = days + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365
        var year = yoe + era * 400
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let day = doy - (153 * mp + 2) / 5 + 1
        let month = mp + (mp < 10 ? 3 : -9)
        year += month <= 2 ? 1 : 0
        return (year, month, day)
    }

    private static func padded(_ value: Int, digits: Int) -> String {
        let text = String(value)
        guard text.count < digits else {
            return text
        }

        return String(repeating: "0", count: digits - text.count) + text
    }
}
