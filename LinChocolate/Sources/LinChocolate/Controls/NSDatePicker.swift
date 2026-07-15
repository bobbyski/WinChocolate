import Foundation

/// AppKit-shaped date picker (GtkCalendar — the graphical calendar style).
/// Reports selection changes through `onDateChange`; `dateValue` is the
/// selected date.
open class NSDatePicker: NSControl {

    private var backingDate: Date

    /// The selected date. Setting it navigates the calendar; the user's own
    /// picks flow back in via the backend.
    public var dateValue: Date {
        get { backingDate }
        set {
            backingDate = newValue
            backend.setDateValue(newValue, for: handle)
        }
    }

    /// Called when the user picks a day.
    public var onDateChange: ((NSDatePicker) -> Void)?
    /// WinChocolate/AppKit control-action alias + text value (accepted for parity).
    public var onAction: ((NSDatePicker) -> Void)? {
        get { onDateChange }
        set { onDateChange = newValue }
    }
    public var stringValue: String { "\(dateValue)" }

    /// The presentation style (AppKit's `datePickerStyle`). The default compact
    /// text-field style renders a small read-only field; `.clockAndCalendar`
    /// swaps in a full month grid.
    public var datePickerStyle: NSDatePickerStyle = .textFieldAndStepper {
        didSet {
            backend.setDatePickerGraphical(datePickerStyle == .clockAndCalendar, for: handle)
            backend.setDateValue(backingDate, for: handle)
            wireDateChange()
        }
    }

    /// Creates a date picker showing `date`.
    public required convenience init(frame: NSRect) {
        self.init(date: Date(), frame: frame)
    }

    public init(date: Date = Date(), frame: NSRect) {
        self.backingDate = date
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createDatePicker(date: date, frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
        wireDateChange()
    }

    private func wireDateChange() {
        backend.setDateChangeAction(for: handle) { [weak self] date in
            guard let self else { return }
            self.backingDate = date            // sync silently
            self.onDateChange?(self)
            self.sendAction()
        }
    }
}
