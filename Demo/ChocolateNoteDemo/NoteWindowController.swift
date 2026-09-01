// The window a note is edited in: a text view, a status bar, and the Format and
// View state Notepad keeps per window.
//
// This file is the SAME source in every Chocolate's copy of the demo.

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

/// A top-left-origin content view, matching the other demos' convention.
final class NoteContentView: NSView {
    override var isFlipped: Bool { true }
}

/// One note window.
///
/// ```
///   ┌──────────────────────────────────┐
///   │ *Untitled                        │  ← title; the * is the BACKEND's
///   ├──────────────────────────────────┤    rendering of isDocumentEdited
///   │                                  │
///   │   NSTextView in an NSScrollView   │
///   │                                  │
///   ├──────────────────────────────────┤
///   │ Ln 1, Col 1            100%      │  ← status bar (View ▸ Status Bar)
///   └──────────────────────────────────┘
/// ```
///
/// The controller builds its window in `loadWindow()` rather than up front, so
/// the demo exercises the lazy-loading path AppKit actually uses — measured in
/// `Docs/NSDOCUMENT_PLAN.md`: `isWindowLoaded` stays false until `window` is
/// first read.
/// Carries the editor's callbacks to the window controller.
///
/// Deliberately a separate object rather than a conformance on the controller.
/// `NSTextViewDelegate` is `@MainActor`, so conforming would infer main-actor
/// isolation onto the whole controller — which clashes with the nonisolated
/// `NSWindowController` the Chocolates declare, while compiling fine against
/// Apple's `@MainActor` one. Splitting the delegate out is what lets ONE source
/// satisfy both, and it is better design anyway: the controller manages a
/// window, and this listens to a text view.
final class NoteEditorDelegate: NSObject, NSTextViewDelegate {
    /// The controller told about edits. Weak: the controller owns this.
    ///
    /// `nonisolated(unsafe)` because the delegate protocol is `@MainActor` while
    /// `NSWindowController` is not on every renderer, so wiring the two would
    /// otherwise be an isolation crossing. The app is single-threaded — the same
    /// reason `DemoNoteDocument.text` carries the annotation.
    nonisolated(unsafe) weak var controller: NoteWindowController?

    /// Mirrors the editor's text into the document and marks it edited.
    func textDidChange(_ notification: Notification) {
        controller?.recordEdit()
    }

    /// Keeps the status bar current as the caret moves.
    func textViewDidChangeSelection(_ notification: Notification) {
        controller?.refreshStatusBar()
    }
}

final class NoteWindowController: NSWindowController {
    /// The editor.
    private(set) var editor = NSTextView(frame: NSMakeRect(0, 0, 600, 380))

    /// The scroller the editor lives in.
    private var scrollView = NSScrollView(frame: NSMakeRect(0, 0, 600, 380))

    /// The editor's delegate, kept alive by the controller that owns it.
    private let editorDelegate = NoteEditorDelegate()

    /// The left half of the status bar: the caret's line and column.
    private var positionLabel = NSTextField(labelWithString: "Ln 1, Col 1")

    /// The right half: the current zoom.
    private var zoomLabel = NSTextField(labelWithString: "100%")

    /// Whether the status bar is showing.
    private(set) var showsStatusBar = true

    /// Whether the editor wraps long lines.
    private(set) var wrapsText = true

    /// The current zoom, as a multiplier of the base font size.
    private(set) var zoom: CGFloat = 1

    /// The font size the editor draws at 100%.
    private let baseFontSize: CGFloat = 13

    /// The note this window is editing.
    private var note: NoteDocument? {
        document as? NoteDocument
    }

    // NOTE: this class deliberately declares NO initializer of its own.
    //
    // `NSWindowController.init?(coder:)` is `required` on Apple, so a subclass
    // that declares any designated initializer must also provide that one — and
    // there is no `NSCoder` to provide it with off Apple. Declaring none means
    // every initializer is inherited, and the same source compiles on all five
    // renderers. `NoteDocument.makeWindowControllers()` builds one with
    // `init(windowNibName:owner:)`, which is what puts it on the lazy path.

    /// Builds the window, the editor, and the status bar.
    override func loadWindow() {
        let frame = NSMakeRect(140, 140, 620, 440)
        let created = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        let content = NoteContentView(frame: NSMakeRect(0, 0, frame.width, frame.height))

        editor = NSTextView(frame: NSMakeRect(0, 0, frame.width, frame.height - statusBarHeight))
        editor.isEditable = true
        editor.allowsUndo = true
        editorDelegate.controller = self
        editor.delegate = editorDelegate
        editor.font = NSFont.userFixedPitchFont(ofSize: baseFontSize)

        scrollView = NSScrollView(frame: editor.frame)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.documentView = editor

        positionLabel = NSTextField(labelWithString: "Ln 1, Col 1")
        positionLabel.frame = NSMakeRect(10, frame.height - statusBarHeight + 4, 220, 18)
        zoomLabel = NSTextField(labelWithString: "100%")
        zoomLabel.frame = NSMakeRect(frame.width - 70, frame.height - statusBarHeight + 4, 60, 18)

        content.addSubview(scrollView)
        content.addSubview(positionLabel)
        content.addSubview(zoomLabel)
        created.contentView = content

        window = created
    }

    /// Puts the document's text into the editor once everything is wired.
    override func windowDidLoad() {
        super.windowDidLoad()
        editor.string = note?.text ?? ""
        applyWrapping()
        applyZoom()
        updateStatusBar()
    }

    /// How tall the status bar is when it is showing.
    private var statusBarHeight: CGFloat {
        showsStatusBar ? 26 : 0
    }

    // MARK: - Editing

    /// Mirrors the editor's text into the document and marks it edited.
    ///
    /// The plain AppKit idiom: an edit is reported by bumping the document's
    /// change count. That count is what makes the window show the document as
    /// dirty and what makes closing ask about saving.
    func recordEdit() {
        guard let note else {
            return
        }
        note.text = editor.string
        note.updateChangeCount(.changeDone)
        updateStatusBar()
    }

    /// Recomputes the status bar after a selection change.
    func refreshStatusBar() {
        updateStatusBar()
    }

    // MARK: - Format menu

    /// Turns word wrap on or off.
    func toggleWordWrap() {
        wrapsText.toggle()
        applyWrapping()
    }

    /// Applies the current wrap setting to the editor.
    ///
    /// Wrapping is a text-container property, not a text-view one: a container
    /// that tracks the view's width forces lines to fold, and one that does not
    /// lets them run on and the scroll view scroll sideways.
    private func applyWrapping() {
        guard let container = editor.textContainer else {
            return
        }
        container.widthTracksTextView = wrapsText
        scrollView.hasHorizontalScroller = !wrapsText
        if wrapsText {
            container.containerSize = NSSize(width: scrollView.contentSize.width,
                                             height: CGFloat.greatestFiniteMagnitude)
        } else {
            container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                             height: CGFloat.greatestFiniteMagnitude)
        }
    }

    /// Shows the font panel for the editor's font.
    func chooseFont() {
        let manager = NSFontManager.shared
        manager.setSelectedFont(editor.font ?? NSFont.systemFont(ofSize: baseFontSize),
                                isMultiple: false)
        manager.orderFrontFontPanel(nil)
    }

    // MARK: - View menu

    /// Zooms in, out, or back to 100%.
    func zoomIn() {
        setZoom(min(zoom + 0.1, 3))
    }

    /// Zooms out, to a floor that is still readable.
    func zoomOut() {
        setZoom(max(zoom - 0.1, 0.5))
    }

    /// Restores the default zoom.
    func resetZoom() {
        setZoom(1)
    }

    /// Applies a zoom level.
    private func setZoom(_ newZoom: CGFloat) {
        zoom = newZoom
        applyZoom()
        updateStatusBar()
    }

    /// Resizes the editor's font to the current zoom.
    private func applyZoom() {
        let name = editor.font?.fontName
        let sized = NSFont(name: name ?? "", size: baseFontSize * zoom)
            ?? NSFont.userFixedPitchFont(ofSize: baseFontSize * zoom)
        editor.font = sized
    }

    /// Shows or hides the status bar, resizing the editor to match.
    func toggleStatusBar() {
        showsStatusBar.toggle()
        positionLabel.isHidden = !showsStatusBar
        zoomLabel.isHidden = !showsStatusBar

        guard let contentView = window?.contentView else {
            return
        }
        scrollView.frame = NSMakeRect(0, 0, contentView.bounds.width,
                                      contentView.bounds.height - statusBarHeight)
        editor.frame = NSMakeRect(0, 0, scrollView.frame.width, scrollView.frame.height)
        applyWrapping()
    }

    // MARK: - Edit menu

    /// Inserts the current date and time, as Notepad's F5 does.
    func insertDateAndTime(_ stamp: String) {
        editor.insertText(stamp, replacementRange: editor.selectedRange)
        recordEdit()
    }

    /// Moves the caret to the start of a line, for Go To.
    func goToLine(_ line: Int) {
        let lines = editor.string.components(separatedBy: "\n")
        guard line >= 1, line <= lines.count else {
            return
        }

        var offset = 0
        for index in 0..<(line - 1) {
            offset += lines[index].count + 1
        }
        editor.setSelectedRange(NSMakeRange(offset, 0))
        editor.scrollRangeToVisible(NSMakeRange(offset, 0))
        updateStatusBar()
    }

    // MARK: - Status bar

    /// Recomputes the caret position and zoom readouts.
    ///
    /// Counted from the text rather than tracked incrementally, because every
    /// edit and every caret move can change it and a stale readout is worse
    /// than none.
    private func updateStatusBar() {
        let caret = editor.selectedRange.location
        let text = editor.string
        var line = 1
        var column = 1
        var index = 0

        for character in text {
            if index >= caret {
                break
            }
            if character == "\n" {
                line += 1
                column = 1
            } else {
                column += 1
            }
            index += 1
        }

        positionLabel.stringValue = "Ln \(line), Col \(column)"
        zoomLabel.stringValue = "\(Int((zoom * 100).rounded()))%"
    }
}
