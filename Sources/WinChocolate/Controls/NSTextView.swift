/// The methods a text view delegate uses to respond to editing.
@MainActor
public protocol NSTextViewDelegate: NSObjectProtocol {
    /// Tells the delegate that editing changed the text view's text.
    func textDidChange(_ notification: NSNotification)
}

extension NSTextViewDelegate {
    /// Default no-op so delegates only implement the callbacks they need.
    public func textDidChange(_ notification: NSNotification) {}
}

/// A multiline text editing view.
///
/// This first slice provides the common AppKit `string` surface and maps to a
/// native multiline Windows edit control.
open class NSTextView: NSControl, NSFontChanging {
    /// Posted to the delegate when editing changes the text.
    public static let textDidChangeNotification = "NSTextDidChangeNotification"

    private var isUpdatingFromNative = false

    /// Selection kept for text views that are not realized yet.
    private var storedSelectedRange = NSRange(location: 0, length: 0)

    /// The text view's current string.
    open var string: String {
        didSet {
            guard !isUpdatingFromNative, let nativeHandle else {
                return
            }

            realizedBackend?.setText(string, for: nativeHandle)
        }
    }

    /// Whether the text view accepts editing.
    open var isEditable: Bool {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setTextEditable(isEditable, for: nativeHandle)
        }
    }

    /// Whether the text view accepts selection.
    open var isSelectable: Bool

    /// Whether the text view keeps rich text with per-range attributes.
    ///
    /// Rich text views realize the platform's rich-edit peer, which
    /// `setFont(_:range:)`, `setTextColor(_:range:)`, and selection-scoped
    /// `changeFont(_:)` format through. Set before the view realizes; plain
    /// text remains the default, matching the classic multiline control.
    open var isRichText: Bool = false

    /// Whether editing changes register with the undo manager.
    open var allowsUndo = false

    /// Whether the view participates in font-panel changes. Stored for
    /// AppKit shape; rich text views apply `changeFont(_:)` regardless.
    open var usesFontPanel: Bool = false

    /// Creates a scroll view wrapping a fresh text view as its document,
    /// matching AppKit's factory shape.
    public class func scrollableTextView() -> NSScrollView {
        let scrollView = NSScrollView(frame: NSRect(origin: NSZeroPoint, size: NSMakeSize(200, 100)))
        let textView = NSTextView(frame: NSRect(origin: NSZeroPoint, size: NSMakeSize(200, 100)))
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        return scrollView
    }

    private var storedUndoManager: NSUndoManager?

    /// The undo manager recording this text view's edits.
    ///
    /// The window's shared manager is used when the view is installed in a
    /// window; standalone text views vend their own.
    open var undoManager: NSUndoManager? {
        if let windowManager = window?.undoManager {
            return windowManager
        }
        if storedUndoManager == nil {
            storedUndoManager = NSUndoManager()
        }
        return storedUndoManager
    }

    /// The text view delegate, notified when editing changes the text.
    open weak var delegate: NSTextViewDelegate?

    /// The text color, when explicitly set.
    open var textColor: NSColor? {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setTextColor(textColor, for: nativeHandle)
        }
    }

    // `font` is inherited from `NSControl` (AppKit's declaration point).

    /// Applies a live font panel change (`NSFontChanging`, as on Apple).
    ///
    /// Rich text views convert the selected range, matching AppKit; plain
    /// views (or an empty selection) convert the whole view's font.
    open func changeFont(_ sender: NSFontManager?) {
        let converted = (sender ?? NSFontManager.shared).convert(font ?? NSFont.systemFont(ofSize: 13))
        let selection = selectedRange
        if isRichText && selection.length > 0 {
            setFont(converted, range: selection)
            return
        }

        font = converted
    }

    /// Applies a font to a character range of a rich text view.
    open func setFont(_ font: NSFont, range: NSRange) {
        guard let nativeHandle else {
            return
        }

        realizedBackend?.setTextRangeFormat(font: font, color: nil, underline: nil, strikethrough: nil, location: range.location, length: range.length, for: nativeHandle)
    }

    /// Applies paragraph alignment to the paragraphs covering a character
    /// range of a rich text view, matching AppKit's `setAlignment(_:range:)`.
    open func setAlignment(_ alignment: NSTextAlignment, range: NSRange) {
        guard let nativeHandle else {
            return
        }

        realizedBackend?.setTextRangeAlignment(alignment, location: range.location, length: range.length, for: nativeHandle)
    }

    /// Applies a color to a character range of a rich text view.
    ///
    /// A `nil` color leaves the range unchanged in this slice; resetting to
    /// the default color arrives with attribute enumeration.
    open func setTextColor(_ color: NSColor?, range: NSRange) {
        guard let nativeHandle, let color else {
            return
        }

        realizedBackend?.setTextRangeFormat(font: nil, color: color, underline: nil, strikethrough: nil, location: range.location, length: range.length, for: nativeHandle)
    }

    private var storedTextStorage: NSTextStorage?
    private var isApplyingTextStorage = false

    /// The text storage holding the view's attributed contents.
    ///
    /// Created on first access seeded with the current text. Edits to the
    /// storage apply back to the view: the plain text always follows, and
    /// rich text views also receive the attribute runs (font, color,
    /// underline, strikethrough) as native character formatting.
    open var textStorage: NSTextStorage? {
        if let storedTextStorage {
            return storedTextStorage
        }

        let storage = NSTextStorage(string: string)
        storage.winDidEdit = { [weak self] storage in
            self?.applyTextStorage(storage)
        }
        storedTextStorage = storage
        return storage
    }

    private func applyTextStorage(_ storage: NSTextStorage) {
        guard !isApplyingTextStorage else {
            return
        }

        isApplyingTextStorage = true
        defer {
            isApplyingTextStorage = false
        }

        // Setting the text resets native character formats to the default,
        // so re-applying every run afterward leaves unattributed stretches
        // at the control's defaults.
        string = storage.string
        guard isRichText, let nativeHandle, let realizedBackend else {
            return
        }

        storage.enumerateAttributes(in: NSMakeRange(0, storage.length)) { attributes, range, _ in
            let underlineStyle = attributes[.underlineStyle] as? Int
            let strikethroughStyle = attributes[.strikethroughStyle] as? Int
            realizedBackend.setTextRangeFormat(
                font: attributes[.font] as? NSFont,
                color: attributes[.foregroundColor] as? NSColor,
                underline: underlineStyle.map { $0 != 0 },
                strikethrough: strikethroughStyle.map { $0 != 0 },
                location: range.location,
                length: range.length,
                for: nativeHandle
            )
            if let paragraph = attributes[.paragraphStyle] as? NSParagraphStyle, paragraph.alignment != .natural {
                realizedBackend.setTextRangeAlignment(paragraph.alignment, location: range.location, length: range.length, for: nativeHandle)
            }
        }
    }

    /// The selected character range, in UTF-16 units.
    ///
    /// Realized text views read and write the live native selection; unrealized
    /// text views keep the range and apply it when the native peer appears.
    open var selectedRange: NSRange {
        get {
            guard let nativeHandle, let realizedBackend else {
                return storedSelectedRange
            }

            let selection = realizedBackend.textSelection(for: nativeHandle)
            return NSRange(location: selection.location, length: selection.length)
        }
        set {
            storedSelectedRange = newValue
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setTextSelection(location: newValue.location, length: newValue.length, for: nativeHandle)
        }
    }

    /// Creates a text view with a frame.
    public required init(frame frameRect: NSRect) {
        self.string = ""
        self.isEditable = true
        self.isSelectable = true
        super.init(frame: frameRect)
    }

    /// Replaces all text in the receiver.
    open func setString(_ string: String) {
        self.string = string
    }

    /// Selects a character range, matching AppKit's method form.
    open func setSelectedRange(_ charRange: NSRange) {
        selectedRange = charRange
    }

    /// Appends text to the receiver.
    open func insertText(_ text: String) {
        insertText(text, replacementRange: NSMakeRange(string.utf16.count, 0))
    }

    /// Inserts text, replacing a character range.
    ///
    /// A `replacementRange` location of `NSNotFound` replaces the current
    /// selection, matching AppKit. The selection collapses to the end of the
    /// inserted text.
    open func insertText(_ string: String, replacementRange: NSRange) {
        let range = replacementRange.location == NSNotFound ? selectedRange : replacementRange

        var units = Array(self.string.utf16)
        let location = min(max(0, range.location), units.count)
        let length = min(max(0, range.length), units.count - location)
        let replacement = Array(string.utf16)
        units.replaceSubrange(location..<(location + length), with: replacement)
        let updatedString = String(decoding: units, as: UTF16.self)
        storedSelectedRange = NSRange(location: location + replacement.count, length: 0)

        guard let nativeHandle, let realizedBackend else {
            self.string = updatedString
            return
        }

        // The native replacement keeps the edit undoable, so update the local
        // string without pushing a whole-text reset back to the control.
        realizedBackend.setTextSelection(location: location, length: length, for: nativeHandle)
        realizedBackend.replaceSelectedText(string, for: nativeHandle)
        isUpdatingFromNative = true
        self.string = updatedString
        isUpdatingFromNative = false
    }

    /// Scrolls so text in a character range is visible.
    ///
    /// The classic edit control scrolls to its caret, so this first slice
    /// moves the selection to the range, which carries `EM_SCROLLCARET` along.
    open func scrollRangeToVisible(_ range: NSRange) {
        selectedRange = range
    }

    /// Copies the selected text to the general pasteboard.
    ///
    /// Rich text views whose contents came through `textStorage` also stage
    /// an RTF representation, so formatting survives pasting into other
    /// applications.
    open override func copy(_ sender: Any?) {
        guard let selectedText = currentSelectedText() else {
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(selectedText, forType: .string)

        if isRichText, let storage = storedTextStorage, storage.string == string,
           let rtfData = storage.rtf(from: selectedRange) {
            pasteboard.setData(rtfData, forType: .rtf)
        }
    }

    /// Deletes the selected text after copying it to the general pasteboard.
    open override func cut(_ sender: Any?) {
        guard isEditable, currentSelectedText() != nil else {
            return
        }

        copy(sender)
        insertText("", replacementRange: selectedRange)
    }

    /// Inserts the general pasteboard's text at the selection.
    open override func paste(_ sender: Any?) {
        guard isEditable, let text = NSPasteboard.general.string(forType: .string) else {
            return
        }

        insertText(text, replacementRange: selectedRange)
    }

    /// Selects all text.
    open func selectAll(_ sender: Any?) {
        selectedRange = NSMakeRange(0, string.utf16.count)
    }

    /// The selected substring, or `nil` when the selection is empty.
    private func currentSelectedText() -> String? {
        let selection = selectedRange
        guard selection.length > 0 else {
            return nil
        }

        let units = Array(string.utf16)
        let location = min(max(0, selection.location), units.count)
        let length = min(max(0, selection.length), units.count - location)
        guard length > 0 else {
            return nil
        }

        return String(decoding: units[location..<(location + length)], as: UTF16.self)
    }

    /// Creates the native multiline text peer.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createTextView(text: string, frame: frame, parent: parent, isEditable: isEditable, isRichText: isRichText)
    }

    /// Ensures the text view has a native peer and registers text-change dispatch.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        backend.setTextColor(textColor, for: handle)
        backend.setFont(font, for: handle)
        if storedSelectedRange != NSRange(location: 0, length: 0) {
            backend.setTextSelection(location: storedSelectedRange.location, length: storedSelectedRange.length, for: handle)
        }
        backend.registerTextChangeAction(for: handle) { [weak self] text in
            guard let self else {
                return
            }

            _ = self.window?.makeFirstResponder(self)
            self.updateStringFromNative(text)
        }
        return handle
    }

    private var hasOpenTypingUndoGroup = false
    private var typingGroupIsInsertion = false

    private func updateStringFromNative(_ text: String) {
        let previousText = string
        isUpdatingFromNative = true
        string = text
        objectValue = text
        isUpdatingFromNative = false
        if !isApplyingTextStorage {
            storedTextStorage?.winSyncPlainText(text)
        }
        if allowsUndo && previousText != text {
            registerTypingUndo(previousText: previousText, text: text)
        }
        winMainActor { delegate?.textDidChange(NSNotification(name: Self.textDidChangeNotification, object: self)) }
    }

    /// Registers undo state for one native edit, coalescing typing bursts.
    ///
    /// Word-sized granularity like AppKit: consecutive single-unit
    /// insertions share one undo action until a whitespace unit ends the
    /// word, consecutive single-unit deletions share one action, switching
    /// between inserting and deleting starts a new action, and larger edits
    /// (paste, cut) always stand alone.
    private func registerTypingUndo(previousText: String, text: String) {
        let delta = text.utf16.count - previousText.utf16.count
        let isSingleInsertion = delta == 1
        let isSingleDeletion = delta == -1

        let continuesGroup = hasOpenTypingUndoGroup
            && ((isSingleInsertion && typingGroupIsInsertion) || (isSingleDeletion && !typingGroupIsInsertion))
        if !continuesGroup {
            registerUndoReplacingText(with: previousText)
        }

        if isSingleInsertion {
            // A whitespace unit finishes the word and closes its group.
            hasOpenTypingUndoGroup = !insertedUnitIsWhitespace(previousText: previousText, text: text)
            typingGroupIsInsertion = true
        } else if isSingleDeletion {
            hasOpenTypingUndoGroup = true
            typingGroupIsInsertion = false
        } else {
            hasOpenTypingUndoGroup = false
        }
    }

    /// Whether a single-unit insertion added a whitespace character.
    private func insertedUnitIsWhitespace(previousText: String, text: String) -> Bool {
        let oldUnits = Array(previousText.utf16)
        let newUnits = Array(text.utf16)
        var index = 0
        while index < oldUnits.count && oldUnits[index] == newUnits[index] {
            index += 1
        }
        let inserted = newUnits[index]
        return inserted == 32 || inserted == 9 || inserted == 10 || inserted == 13
    }

    /// Registers an undo action restoring earlier text.
    ///
    /// The handler registers its own inverse before applying, so performing
    /// an undo records the matching redo (and vice versa) through the undo
    /// manager's stack routing.
    private func registerUndoReplacingText(with previousText: String) {
        guard let manager = undoManager else {
            return
        }

        manager.registerUndo(withTarget: self) { target in
            target.registerUndoReplacingText(with: target.string)
            target.applyUndoText(previousText)
        }
        manager.setActionName("Typing")
    }

    private func applyUndoText(_ text: String) {
        hasOpenTypingUndoGroup = false
        string = text
        objectValue = text
        selectedRange = NSMakeRange(text.utf16.count, 0)
        winMainActor { delegate?.textDidChange(NSNotification(name: Self.textDidChangeNotification, object: self)) }
    }
}

/// AppKit-compatible global constant for the text-change notification name.
public let NSTextDidChangeNotification = NSTextView.textDidChangeNotification
