/// The methods a text view delegate uses to respond to editing.
public protocol NSTextViewDelegate: AnyObject {
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
open class NSTextView: NSControl {
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

    /// Whether editing changes register with the undo manager.
    open var allowsUndo = false

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

    /// The text font, when explicitly set.
    open var font: NSFont? {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setFont(font, for: nativeHandle)
        }
    }

    /// Swift-native callback invoked when editing changes the text.
    open var onTextChanged: ((NSTextView) -> Void)?

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
    public override init(frame frameRect: NSRect) {
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

    /// Creates the native multiline text peer.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createTextView(text: string, frame: frame, parent: parent, isEditable: isEditable)
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
        if allowsUndo && previousText != text {
            registerTypingUndo(previousText: previousText, text: text)
        }
        onTextChanged?(self)
        delegate?.textDidChange(NSNotification(name: Self.textDidChangeNotification, object: self))
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
        onTextChanged?(self)
        delegate?.textDidChange(NSNotification(name: Self.textDidChangeNotification, object: self))
    }
}

/// AppKit-compatible global constant for the text-change notification name.
public let NSTextDidChangeNotification = NSTextView.textDidChangeNotification
