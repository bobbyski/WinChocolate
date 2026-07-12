import Foundation

/// AppKit-shaped date picker (GtkCalendar — the graphical calendar style).
/// Reports selection changes through `onDateChange`; `dateValue` is the
/// selected date.
public final class NSDatePicker: NSView {

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

    /// Creates a calendar date picker showing `date`.
    public init(date: Date = Date(), frame: NSRect) {
        self.backingDate = date
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createDatePicker(date: date, frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
        backend.setDateChangeAction(for: handle) { [weak self] date in
            guard let self else { return }
            self.backingDate = date            // sync silently
            self.onDateChange?(self)
        }
    }
}
