// The two enums a document's saving and dirty-state API is written in terms of.
//
// They live here rather than inside `NSDocument.swift` because nested types are
// one of the few things Swift lets an extension add without losing anything —
// unlike the methods, which have to be declared in the class body to stay
// overridable. Keeping them out shortens a file that Swift already forces to be
// long.
//
// Every raw value below was measured from the macOS 26.4 SDK by
// `Tools/DocumentGroundTruthProbe.swift`. They are not guessable, and two of
// them are actively counter-intuitive.

extension NSDocument {
    /// A change to the document's edited state.
    ///
    /// Note `changeRedone` is **5**, not 3 — it was added years after the
    /// others, so it sits at the end of the numbering rather than beside
    /// `changeUndone` where the name suggests. Assuming the obvious order would
    /// have put three of these cases on the wrong integer.
    public enum ChangeType: UInt, Sendable {
        /// A change was made; the document becomes edited.
        case changeDone = 0

        /// A change was undone; the document may become clean again.
        case changeUndone = 1

        /// The document was saved; it is no longer edited.
        case changeCleared = 2

        /// The document re-read its contents from elsewhere.
        case changeReadOtherContents = 3

        /// The document was autosaved.
        case changeAutosaved = 4

        /// A change was redone; the document becomes edited again.
        case changeRedone = 5

        /// Modifies another change to say its result could be recreated, so it
        /// need not force a save.
        case changeDiscardable = 256
    }

    /// What kind of save is being performed.
    ///
    /// The order is the trap: **`autosaveElsewhere` is 3 and `autosaveInPlace`
    /// is 4**, which is the reverse of the order the names are usually listed
    /// in — including in this framework's own first draft, which had them
    /// swapped.
    public enum SaveOperationType: UInt, Sendable {
        /// A plain save to the document's own URL.
        case saveOperation = 0

        /// A save to a new URL, which becomes the document's.
        case saveAsOperation = 1

        /// A copy written elsewhere; the document keeps its own URL.
        case saveToOperation = 2

        /// An autosave to a scratch location, for a document with no URL yet.
        case autosaveElsewhereOperation = 3

        /// An autosave over the document's own file.
        case autosaveInPlaceOperation = 4

        /// An autosave that establishes a new document.
        case autosaveAsOperation = 5
    }

    /// What a document hands a delegate when reporting an outcome.
    ///
    /// Stands in for the three arguments AppKit's callback selectors take; see
    /// `NSDocument.notify(_:_:succeeded:contextInfo:)` for why it has to exist.
    public struct CallbackInfo {
        /// The document reporting the outcome.
        ///
        /// Optional because `NSDocumentController`'s bulk callbacks —
        /// "did you review them all?", "did they all close?" — are about the
        /// whole set rather than any one document.
        public let document: NSDocument?

        /// Whether the operation succeeded — `didSave`, `shouldClose`, and so on.
        public let succeeded: Bool

        /// The caller's context, passed through untouched.
        public let contextInfo: UnsafeMutableRawPointer?
    }
}
