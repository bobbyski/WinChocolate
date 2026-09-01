// ChocolateNoteDemo — Windows Notepad, on whichever framework it was built
// against.
//
// This file is character-for-character identical in every Chocolate's copy of
// the demo. The import switch below is the entire integration point; every line
// after it is ordinary AppKit. Nothing here knows about Win32, GTK, the DOM, or
// a cell grid.
//
// WHY THIS APP. CounterDemo proves a button can be clicked on five renderers.
// A Notepad proves something harder: that the *document architecture* works —
// New, Open, Save, Save As, Open Recent, dirty tracking, the save-changes
// prompt on close and on quit, undo, and a File menu wired the way every real
// AppKit app wires one.
//
// And that last part is the point of the whole exercise. Look at the File menu
// below: **the items have no target.** `saveDocument:` is not sent to any
// object this file knows about. It travels up the responder chain from the key
// window, through the window controller, and is offered to whichever document
// is in front. That is exactly how a document-based AppKit app is written, and
// making it work here is what Phases 2-5 of Docs/NSDOCUMENT_PLAN.md were for.
//
// The Swift names look mismatched with those selectors and are not: Apple's
// Swift name for `saveDocument:` is `save(_:)`, renamed by the importer in
// Swift 3. `#selector(NSDocument.save(_:))` really does print "saveDocument:".

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

let app = NSApplication.shared

// MARK: - The document controller
//
// Created FIRST, and deliberately so: as on Apple, the first document
// controller instantiated becomes the shared one. An app that lets something
// else create a plain controller first finds its New and Open items making the
// wrong kind of document — or no document at all.

/// Supplies `NoteDocument` for every type this app handles.
final class NoteDocumentController: NSDocumentController {
    override func documentClass(forType typeName: String) -> AnyClass? {
        NoteDocument.self
    }

    override var defaultType: String? { "txt" }

    override var documentClassNames: [String] { ["NoteDocument"] }

    override func displayName(forType typeName: String) -> String? { "Text Document" }
}

let documentController = NoteDocumentController()

/// The controller for the window the user is looking at, if any.
@MainActor func frontNoteController() -> NoteWindowController? {
    (documentController.currentDocument?.windowControllers.first as? NoteWindowController)
        ?? (app.keyWindow?.windowController as? NoteWindowController)
}

/// The note the user is looking at, if any.
@MainActor func frontNote() -> NoteDocument? {
    frontNoteController()?.document as? NoteDocument
}

// MARK: - Menu bar

let menuBar = NSMenu()

// --- File ------------------------------------------------------------------
//
// Every item here that acts on a document has NO TARGET. That is not an
// oversight and not a shortcut: it is how AppKit document apps are written, and
// it is what lets one menu serve any number of open notes.

let fileMenuItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
let fileMenu = NSMenu(title: "File")

fileMenu.addItem(NSMenuItem(title: "New", selectorName: "newDocument:", keyEquivalent: "n"))
fileMenu.addItem(NSMenuItem(title: "New Window", keyEquivalent: "N") {
    // A second window onto a NEW note, which is what Notepad's New Window does.
    documentController.newDocument(nil)
})
fileMenu.addItem(NSMenuItem(title: "Open…", selectorName: "openDocument:", keyEquivalent: "o"))

let openRecentItem = NSMenuItem(title: "Open Recent", action: nil, keyEquivalent: "")
let openRecentMenu = NSMenu(title: "Open Recent")
openRecentItem.submenu = openRecentMenu
fileMenu.addItem(openRecentItem)

fileMenu.addSeparator()
fileMenu.addItem(NSMenuItem(title: "Save", selectorName: "saveDocument:", keyEquivalent: "s"))
fileMenu.addItem(NSMenuItem(title: "Save As…", selectorName: "saveDocumentAs:", keyEquivalent: "S"))
fileMenu.addItem(NSMenuItem(title: "Revert to Saved",
                            selectorName: "revertDocumentToSaved:", keyEquivalent: ""))
fileMenu.addSeparator()
fileMenu.addItem(NSMenuItem(title: "Page Setup…", selectorName: "runPageLayout:", keyEquivalent: ""))
fileMenu.addItem(NSMenuItem(title: "Print…", selectorName: "printDocument:", keyEquivalent: "p"))
fileMenu.addSeparator()

let quitItem = NSMenuItem(title: "Exit", action: Selector("terminate:"), keyEquivalent: "q")
quitItem.target = app
fileMenu.addItem(quitItem)

fileMenuItem.submenu = fileMenu
menuBar.addItem(fileMenuItem)

/// Rebuilds Open Recent from the controller's list.
///
/// AppKit fills this menu from a nib-declared class, which there is no
/// equivalent of here — so the app builds it from `recentDocumentURLs`, which
/// is real API. Inventing a framework hook for it would have been the wrong
/// kind of convenience.
@MainActor func rebuildOpenRecentMenu() {
    while openRecentMenu.numberOfItems > 0 {
        openRecentMenu.removeItem(at: 0)
    }

    for url in documentController.recentDocumentURLs {
        openRecentMenu.addItem(NSMenuItem(title: url.lastPathComponent, keyEquivalent: "") {
            documentController.openDocument(withContentsOf: url, display: true) { _, _, error in
                if let error {
                    documentController.presentError(error)
                }
            }
            rebuildOpenRecentMenu()
        })
    }

    if documentController.recentDocumentURLs.isEmpty {
        let empty = NSMenuItem(title: "No Recent Documents", action: nil, keyEquivalent: "")
        empty.isEnabled = false
        openRecentMenu.addItem(empty)
    } else {
        openRecentMenu.addSeparator()
        openRecentMenu.addItem(NSMenuItem(title: "Clear Menu",
                                          selectorName: "clearRecentDocuments:",
                                          keyEquivalent: ""))
    }
}

// --- Edit ------------------------------------------------------------------

let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
let editMenu = NSMenu(title: "Edit")

editMenu.addItem(NSMenuItem(title: "Undo", keyEquivalent: "z") {
    frontNote()?.undoManager?.undo()
})
editMenu.addItem(NSMenuItem(title: "Redo", keyEquivalent: "Z") {
    frontNote()?.undoManager?.redo()
})
editMenu.addSeparator()
editMenu.addItem(NSMenuItem(title: "Cut", selectorName: "cut:", keyEquivalent: "x"))
editMenu.addItem(NSMenuItem(title: "Copy", selectorName: "copy:", keyEquivalent: "c"))
editMenu.addItem(NSMenuItem(title: "Paste", selectorName: "paste:", keyEquivalent: "v"))
editMenu.addItem(NSMenuItem(title: "Select All", selectorName: "selectAll:", keyEquivalent: "a"))
editMenu.addSeparator()
editMenu.addItem(NSMenuItem(title: "Find…", keyEquivalent: "f") {
    presentFindPanel()
})
editMenu.addItem(NSMenuItem(title: "Find Next", keyEquivalent: "g") {
    findNext(reverse: false)
})
editMenu.addItem(NSMenuItem(title: "Find Previous", keyEquivalent: "G") {
    findNext(reverse: true)
})
editMenu.addItem(NSMenuItem(title: "Replace…", keyEquivalent: "r") {
    presentReplacePanel()
})
editMenu.addItem(NSMenuItem(title: "Go To…", keyEquivalent: "l") {
    presentGoToPanel()
})
editMenu.addSeparator()
editMenu.addItem(NSMenuItem(title: "Time/Date", keyEquivalent: "") {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm yyyy-MM-dd"
    frontNoteController()?.insertDateAndTime(formatter.string(from: Date()))
})

editMenuItem.submenu = editMenu
menuBar.addItem(editMenuItem)

// --- Format ----------------------------------------------------------------

let formatMenuItem = NSMenuItem(title: "Format", action: nil, keyEquivalent: "")
let formatMenu = NSMenu(title: "Format")

let wordWrapItem = NSMenuItem(title: "Word Wrap", keyEquivalent: "") {
    frontNoteController()?.toggleWordWrap()
    syncFormatMenuState()
}
formatMenu.addItem(wordWrapItem)
formatMenu.addItem(NSMenuItem(title: "Font…", keyEquivalent: "") {
    frontNoteController()?.chooseFont()
})

formatMenuItem.submenu = formatMenu
menuBar.addItem(formatMenuItem)

/// Ticks Word Wrap to match the front window.
@MainActor func syncFormatMenuState() {
    wordWrapItem.state = (frontNoteController()?.wrapsText ?? true) ? .on : .off
    statusBarItem.state = (frontNoteController()?.showsStatusBar ?? true) ? .on : .off
}

// --- View ------------------------------------------------------------------

let viewMenuItem = NSMenuItem(title: "View", action: nil, keyEquivalent: "")
let viewMenu = NSMenu(title: "View")

viewMenu.addItem(NSMenuItem(title: "Zoom In", keyEquivalent: "+") {
    frontNoteController()?.zoomIn()
})
viewMenu.addItem(NSMenuItem(title: "Zoom Out", keyEquivalent: "-") {
    frontNoteController()?.zoomOut()
})
viewMenu.addItem(NSMenuItem(title: "Restore Default Zoom", keyEquivalent: "0") {
    frontNoteController()?.resetZoom()
})
viewMenu.addSeparator()

let statusBarItem = NSMenuItem(title: "Status Bar", keyEquivalent: "") {
    frontNoteController()?.toggleStatusBar()
    syncFormatMenuState()
}
viewMenu.addItem(statusBarItem)

viewMenuItem.submenu = viewMenu
menuBar.addItem(viewMenuItem)

// --- Help ------------------------------------------------------------------

let helpMenuItem = NSMenuItem(title: "Help", action: nil, keyEquivalent: "")
let helpMenu = NSMenu(title: "Help")
helpMenu.addItem(NSMenuItem(title: "About ChocolateNote", keyEquivalent: "") {
    let alert = NSAlert()
    alert.messageText = "ChocolateNote"
    alert.informativeText = "One Notepad, five renderers. The same source runs on real "
        + "AppKit, Win32, GTK, WebAssembly, and a terminal."
    alert.addButton(withTitle: "OK")
    _ = alert.runModal()
})
helpMenuItem.submenu = helpMenu
menuBar.addItem(helpMenuItem)

app.mainMenu = menuBar

// MARK: - Find, Replace, and Go To
//
// Notepad's dialogs, built from an alert with a text field — the simplest thing
// that is still real AppKit. `NSTextFinder` exists in the framework but its
// panel UI does not, on any backend, so a demo that used it would look like it
// worked and do nothing.

/// What Find is currently looking for.
var searchTerm = ""

/// Asks for a search term and finds the first match.
@MainActor func presentFindPanel() {
    guard let term = askForText(title: "Find", prompt: "Find what:", initial: searchTerm) else {
        return
    }
    searchTerm = term
    findNext(reverse: false)
}

/// Finds the next (or previous) occurrence of the search term.
@MainActor func findNext(reverse: Bool) {
    guard !searchTerm.isEmpty, let controller = frontNoteController() else {
        return
    }

    let text = controller.editor.string
    let caret = controller.editor.selectedRange
    guard let range = search(text, for: searchTerm,
                             from: caret.location + (reverse ? 0 : caret.length),
                             reverse: reverse) else {
        // `NSBeep()` is gone from modern AppKit; `NSSound.beep()` is the
        // spelling that exists on all five renderers.
        NSSound.beep()
        return
    }
    controller.editor.setSelectedRange(range)
    controller.editor.scrollRangeToVisible(range)
}

/// Asks for a term and a replacement, and replaces every occurrence.
@MainActor func presentReplacePanel() {
    guard let term = askForText(title: "Replace", prompt: "Find what:", initial: searchTerm),
          !term.isEmpty,
          let replacement = askForText(title: "Replace", prompt: "Replace with:", initial: ""),
          let controller = frontNoteController() else {
        return
    }

    searchTerm = term
    let updated = controller.editor.string.replacingOccurrences(of: term, with: replacement)
    controller.editor.string = updated
    frontNote()?.text = updated
    frontNote()?.updateChangeCount(.changeDone)
}

/// Asks for a line number and moves the caret there.
@MainActor func presentGoToPanel() {
    guard let entered = askForText(title: "Go To Line", prompt: "Line number:", initial: "1"),
          let line = Int(entered.trimmingCharacters(in: .whitespaces)) else {
        return
    }
    frontNoteController()?.goToLine(line)
}

/// Finds a substring's range, forwards or backwards from an offset.
///
/// Written against `String` rather than a text-finder API so it behaves
/// identically on all five renderers — the point of the app is that the same
/// source works everywhere, and search is not what is being proven here.
@MainActor func search(_ text: String, for term: String,
                       from offset: Int, reverse: Bool) -> NSRange? {
    let characters = Array(text)
    let needle = Array(term)
    guard !needle.isEmpty, needle.count <= characters.count else {
        return nil
    }

    let last = characters.count - needle.count
    let start = max(0, min(offset, last))
    // Wrapping both ways, so Find Next past the end starts again at the top —
    // which is what every editor does and what users expect.
    let order: [Int] = reverse
        ? Array(stride(from: start - 1, through: 0, by: -1)) + Array(stride(from: last, to: start - 1, by: -1))
        : Array(start...last) + Array(0..<start)

    for index in order where index >= 0 && index <= last {
        if Array(characters[index..<(index + needle.count)]) == needle {
            return NSMakeRange(index, needle.count)
        }
    }
    return nil
}

/// A one-field prompt, built from an alert and a text field.
@MainActor func askForText(title: String, prompt: String, initial: String) -> String? {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = prompt
    alert.addButton(withTitle: "OK")
    alert.addButton(withTitle: "Cancel")

    let field = NSTextField(frame: NSMakeRect(0, 0, 240, 24))
    field.stringValue = initial
    alert.accessoryView = field

    guard alert.runModal() == .alertFirstButtonReturn else {
        return nil
    }
    return field.stringValue
}

// MARK: - Launch

/// Keeps the menus and the recent list current, and opens the first note.
final class NoteAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Launch callbacks arrive on the UI thread on every renderer; the
        // protocol is not annotated that way on all of them, so this asserts
        // what is already true rather than hopping.
        MainActor.assumeIsolated {
            // Only if nothing is open yet. Real AppKit opens an untitled
            // document for a document-based app *before* this callback runs, so
            // creating one unconditionally gave two windows on macOS and one
            // everywhere else — caught by actually launching it. Asking first
            // is what makes the same line correct on all five renderers.
            if documentController.documents.isEmpty {
                documentController.newDocument(nil)
            }
            rebuildOpenRecentMenu()
            syncFormatMenuState()
        }
    }

    /// Notepad quits when its last window closes.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

let delegate = NoteAppDelegate()
app.delegate = delegate
app.run()
