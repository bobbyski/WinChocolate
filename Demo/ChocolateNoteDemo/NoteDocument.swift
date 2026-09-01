// The document behind every ChocolateNoteDemo window.
//
// This file is the SAME source in every Chocolate's copy of the demo, and it is
// ordinary AppKit throughout: nothing here knows whether it is saving to NTFS,
// ext4, or a dictionary in a browser tab. That is the claim the whole app
// exists to make.

#if canImport(TUIChocolate)
import TUIChocolate
#elseif os(WASI)
import WASMChocolate
#elseif os(Linux)
import LinChocolate
#elseif os(Windows)
import WinChocolate
#elseif canImport(AppKit)
import AppKit
#endif

/// A plain-text note, saved as UTF-8.
///
/// The smallest honest `NSDocument` subclass: it overrides the two rungs of the
/// read/write ladder that every text document needs and nothing else. Word
/// wrap, zoom, and the status bar all belong to the window, not here — a
/// document knows its bytes and nothing about how they are displayed.
final class NoteDocument: NSDocument {
    /// The note's text.
    ///
    /// `nonisolated(unsafe)` because `NSDocument`'s read and write methods are
    /// nonisolated on Apple — they can run off the main thread during a save —
    /// while this demo is single-threaded throughout. Marking it is how the
    /// same source compiles against real AppKit and the Chocolates alike.
    nonisolated(unsafe) var text = ""

    /// The types this document reads, as its Info.plist would declare.
    override class var readableTypes: [String] { ["txt", "text", "md", "log"] }

    /// The types this document writes.
    override class var writableTypes: [String] { ["txt"] }

    /// Notepad's own extension choice for a new file.
    override func fileNameExtension(forType typeName: String,
                                    saveOperation: NSDocument.SaveOperationType) -> String? {
        "txt"
    }

    // MARK: - The read/write ladder

    /// The bytes to save.
    override func data(ofType typeName: String) throws -> Data {
        Data(text.utf8)
    }

    /// Loads the note from bytes.
    ///
    /// Invalid UTF-8 is replaced rather than rejected, which is what a text
    /// editor should do: refusing to open a slightly-corrupt file helps nobody,
    /// and the user can see and fix whatever came through.
    override func read(from data: Data, ofType typeName: String) throws {
        text = String(decoding: data, as: UTF8.self)
    }

    // MARK: - Windows

    /// Builds the note's window.
    ///
    /// Constructed with a nib name it will never read: that is what puts the
    /// controller on AppKit's LAZY path, where the window is not built until
    /// something asks for it. `NoteWindowController.loadWindow()` then builds
    /// it in code. The alternative — handing over a finished window — works
    /// too, and would skip the load sequence this demo exists partly to
    /// exercise.
    override func makeWindowControllers() {
        addWindowController(NoteWindowController(windowNibName: NSNib.Name("NoteWindow")))
    }
}
