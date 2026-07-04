/// The text-system storage object holding a text view's attributed contents.
///
/// This slice keeps AppKit's shape — `NSTextStorage` is a mutable attributed
/// string a text view exposes through `textStorage` — without the layout
/// manager machinery: edits notify the owning text view directly, which
/// re-applies text and attribute runs to its native peer. Batches wrapped in
/// `beginEditing()`/`endEditing()` deliver one notification at the end.
open class NSTextStorage: NSMutableAttributedString {
    /// Called after edits, outside `beginEditing`/`endEditing` batches.
    ///
    /// The owning text view installs this to sync its native peer; the
    /// layout-manager pipeline arrives with later text-system work.
    var winDidEdit: ((NSTextStorage) -> Void)?

    override func didMutate() {
        winDidEdit?(self)
    }

    /// Replaces the contents with plain text without notifying.
    ///
    /// Used when native editing changes the view's text: the storage follows
    /// the control. The first run's attributes carry over as the uniform
    /// attributes of the new text; per-range attributes of the edited
    /// contents are not reconstructed from the native control in this slice.
    func winSyncPlainText(_ text: String) {
        units = Array(text.utf16)
        let carried = runs.first?.attributes ?? [:]
        runs = units.isEmpty ? [] : [Run(length: units.count, attributes: carried)]
    }
}
