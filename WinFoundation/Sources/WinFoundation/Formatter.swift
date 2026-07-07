/// The abstract base for value formatters, matching Foundation's `Formatter`.
///
/// Controls hold a `Formatter?` and call `string(for:)` to render an
/// `objectValue` for display and `editingString(for:)` while editing. Concrete
/// subclasses (currently `NumberFormatter`) provide the real conversion.
/// Foundation's pointer-based `getObjectValue(_:for:errorDescription:)` uses
/// `AutoreleasingUnsafeMutablePointer`, which the shim cannot reproduce; parsing
/// user text back into a value is done through the concrete subclass API
/// (`NumberFormatter.number(from:)`), which the control wiring calls directly.
open class Formatter {
    /// Creates a formatter.
    public init() {}

    /// Returns the display string for an object, or `nil` when it cannot format it.
    open func string(for obj: Any?) -> String? {
        nil
    }

    /// Returns the string to show while the field is being edited.
    ///
    /// Defaults to `string(for:)`, matching Foundation.
    open func editingString(for obj: Any?) -> String? {
        string(for: obj)
    }
}
