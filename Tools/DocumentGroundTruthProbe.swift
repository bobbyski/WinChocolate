// Ground-truth probe for the document architecture — Docs/NSDOCUMENT_PLAN.md item 0.1.
//
// Reads Apple's real behaviour rather than guessing it: raw enum values, the
// untitled-document naming sequence, what an edited document's window title
// actually is, autosave defaults, and the NSError a failed read produces.
//
// This runs against REAL AppKit on a Mac. It is the specification for the
// ChocolateKit implementation — every number it prints is a value the port has
// to reproduce, and the house rule is that we measure them rather than assume
// them (see the memory note "Probe real AppKit, don't guess").
//
// Build & run, from anywhere:
//   Tools/document-ground-truth.sh
//
// Or by hand, with the absolute path:
//   swiftc -sdk "$(xcrun --show-sdk-path --sdk macosx)" -target arm64-apple-macos13.0 \
//       -o /tmp/docprobe \
//       /Users/bobby/AIResearch/WinChocolate/Tools/DocumentGroundTruthProbe.swift && /tmp/docprobe
//
// ---------------------------------------------------------------------------
// Results, macOS 26.4 SDK, 2026-08-30. The full transcript lives in
// Docs/NSDOCUMENT_PLAN.md § Ground Truth; the findings that overturned an
// assumption are repeated here so nobody re-derives them from the file:
//
//   • #selector(NSDocument.save(_:)) is the ObjC selector "saveDocument:".
//     Apple's SWIFT name for saveDocument: IS save(_:) — renamed by the
//     importer in Swift 3. So ChocolateKit's existing save(_:)/saveAs(_:) are
//     CORRECT AppKit API, not invented convenience. What is missing is
//     saveTo(_:) and revertToSaved(_:).
//   • NSDocumentController.autosavingDelay defaults to 0.0 — no periodic
//     autosave at all. ChocolateKit's hard-coded 30-second timer is invented.
//   • windowTitle(forDocumentDisplayName:) returns the PLAIN name even when the
//     document is edited. The dirty marker is NSWindow.isDocumentEdited, which
//     AppKit sets for you. ChocolateKit's "*" prefix is a divergence.
//   • NSDocument().data(ofType:) does not throw — AppKit RAISES an ObjC
//     exception ("subclass responsibility"), terminating the process.
// ---------------------------------------------------------------------------

import AppKit
import Foundation

func line(_ title: String) {
    print("\n=== \(title) ===")
}

// --- Raw enum values --------------------------------------------------------
line("NSDocument.SaveOperationType raw values")
let saveOps: [(String, NSDocument.SaveOperationType)] = [
    ("saveOperation", .saveOperation),
    ("saveAsOperation", .saveAsOperation),
    ("saveToOperation", .saveToOperation),
    ("autosaveInPlaceOperation", .autosaveInPlaceOperation),
    ("autosaveElsewhereOperation", .autosaveElsewhereOperation),
    ("autosaveAsOperation", .autosaveAsOperation)
]
for (name, value) in saveOps {
    print("  \(name) = \(value.rawValue)")
}

line("NSDocument.ChangeType raw values")
let changes: [(String, NSDocument.ChangeType)] = [
    ("changeDone", .changeDone),
    ("changeUndone", .changeUndone),
    ("changeRedone", .changeRedone),
    ("changeCleared", .changeCleared),
    ("changeReadOtherContents", .changeReadOtherContents),
    ("changeAutosaved", .changeAutosaved),
    ("changeDiscardable", .changeDiscardable)
]
for (name, value) in changes {
    print("  \(name) = \(value.rawValue)")
}

// --- A concrete document class ---------------------------------------------
final class ProbeDocument: NSDocument {
    var text = ""

    override class var readableTypes: [String] { ["public.plain-text"] }
    override class var writableTypes: [String] { ["public.plain-text"] }

    override func data(ofType typeName: String) throws -> Data {
        Data(text.utf8)
    }

    override func read(from data: Data, ofType typeName: String) throws {
        text = String(decoding: data, as: UTF8.self)
    }
}

final class ProbeController: NSDocumentController {
    override func documentClass(forType typeName: String) -> AnyClass? { ProbeDocument.self }
    override var defaultType: String? { "public.plain-text" }
    override var documentClassNames: [String] { ["ProbeDocument"] }
}

let controller = ProbeController()

line("NSDocumentController defaults")
print("  shared is our subclass: \(NSDocumentController.shared === controller)")
print("  autosavingDelay = \(controller.autosavingDelay)")
print("  maximumRecentDocumentCount = \(controller.maximumRecentDocumentCount)")
print("  hasEditedDocuments = \(controller.hasEditedDocuments)")
print("  currentDirectory = \(String(describing: controller.currentDirectory))")

// --- Untitled naming sequence ----------------------------------------------
line("Untitled naming sequence (displayName / defaultDraftName)")
var made: [NSDocument] = []
for index in 1...4 {
    guard let document = try? controller.makeUntitledDocument(ofType: "public.plain-text") else {
        print("  \(index): makeUntitledDocument threw")
        continue
    }
    controller.addDocument(document)
    made.append(document)
    print("  \(index): displayName=\(document.displayName.debugDescription) "
          + "defaultDraftName=\(document.defaultDraftName().debugDescription) "
          + "fileURL=\(String(describing: document.fileURL))")
}

// --- Edited state and window title ------------------------------------------
line("Edited state → window title")
let document = made.first ?? ProbeDocument()
let window = NSWindow(contentRect: NSMakeRect(0, 0, 320, 200),
                      styleMask: [.titled, .closable],
                      backing: .buffered,
                      defer: false)
let windowController = NSWindowController(window: window)
document.addWindowController(windowController)

print("  clean: isDocumentEdited=\(document.isDocumentEdited)")
print("         windowTitle(forDocumentDisplayName:) = "
      + windowController.windowTitle(forDocumentDisplayName: document.displayName).debugDescription)
print("         window.title = \(window.title.debugDescription)")
print("         window.isDocumentEdited = \(window.isDocumentEdited)")

document.updateChangeCount(.changeDone)
windowController.synchronizeWindowTitleWithDocumentName()

print("  edited: isDocumentEdited=\(document.isDocumentEdited)")
print("          windowTitle(forDocumentDisplayName:) = "
      + windowController.windowTitle(forDocumentDisplayName: document.displayName).debugDescription)
print("          window.title = \(window.title.debugDescription)")
print("          window.isDocumentEdited = \(window.isDocumentEdited)")
print("          window.representedURL = \(String(describing: window.representedURL))")
print("          hasUnautosavedChanges = \(document.hasUnautosavedChanges)")

document.updateChangeCount(.changeCleared)
print("  cleared: isDocumentEdited=\(document.isDocumentEdited)")

// --- Change-count tokens ----------------------------------------------------
line("Change-count token round-trip")
document.updateChangeCount(.changeDone)
let token = document.changeCountToken(for: .saveOperation)
print("  token = \(token) (type \(type(of: token)))")
document.updateChangeCount(withToken: token, for: .saveOperation)
print("  after updateChangeCount(withToken:for:): isDocumentEdited=\(document.isDocumentEdited)")

// --- Document class defaults ------------------------------------------------
line("NSDocument class defaults")
print("  ProbeDocument.autosavesInPlace = \(ProbeDocument.autosavesInPlace)")
print("  ProbeDocument.autosavesDrafts = \(ProbeDocument.autosavesDrafts)")
print("  ProbeDocument.preservesVersions = \(ProbeDocument.preservesVersions)")
print("  ProbeDocument.usesUbiquitousStorage = \(ProbeDocument.usesUbiquitousStorage)")
print("  ProbeDocument.isNativeType(\"public.plain-text\") = \(ProbeDocument.isNativeType("public.plain-text"))")
print("  ProbeDocument.canConcurrentlyReadDocuments(ofType:) = "
      + "\(ProbeDocument.canConcurrentlyReadDocuments(ofType: "public.plain-text"))")
print("  document.keepBackupFile = \(document.keepBackupFile)")
print("  document.isEntireFileLoaded = \(document.isEntireFileLoaded)")
print("  document.isInViewingMode = \(document.isInViewingMode)")
print("  document.isDraft = \(document.isDraft)")
print("  document.isLocked = \(document.isLocked)")
print("  document.hasUndoManager = \(document.hasUndoManager)")
print("  document.undoManager is nil: \(document.undoManager == nil)")
print("  document.windowNibName = \(String(describing: document.windowNibName))")
print("  document.windowForSheet === window: \(document.windowForSheet === window)")
print("  fileNameExtension(forType:saveOperation:) = "
      + String(describing: document.fileNameExtension(forType: "public.plain-text",
                                                      saveOperation: .saveOperation)))
print("  writableTypes(for: .saveOperation) = \(document.writableTypes(for: .saveOperation))")

// --- Errors -----------------------------------------------------------------
line("Errors a failed read/write produces")
let missing = URL(fileURLWithPath: "/definitely/not/here/probe.txt")
do {
    let opened = try ProbeDocument(contentsOf: missing, ofType: "public.plain-text")
    print("  unexpected success: \(opened)")
} catch let error as NSError {
    print("  init(contentsOf:ofType:) domain=\(error.domain) code=\(error.code)")
    print("    localizedDescription=\(error.localizedDescription.debugDescription)")
    print("    failureReason=\(String(describing: error.localizedFailureReason))")
    print("    recoverySuggestion=\(String(describing: error.localizedRecoverySuggestion))")
}

// NOTE: `NSDocument().data(ofType:)` does NOT throw — AppKit raises an ObjC
// exception ("dataOfType:error: is a subclass responsibility but has not been
// overridden."), which terminates the process. Recorded, not re-run.

do {
    let unwritable = URL(fileURLWithPath: "/probe-no-permission.txt")
    try document.write(to: unwritable, ofType: "public.plain-text")
    print("  write to / unexpectedly succeeded")
} catch let error as NSError {
    print("  write(to:ofType:) domain=\(error.domain) code=\(error.code)")
    print("    localizedDescription=\(error.localizedDescription.debugDescription)")
}

line("Cocoa error code constants")
print("  NSFileReadUnknownError = \(NSFileReadUnknownError)")
print("  NSFileReadNoSuchFileError = \(NSFileReadNoSuchFileError)")
print("  NSFileReadCorruptFileError = \(NSFileReadCorruptFileError)")
print("  NSFileReadNoPermissionError = \(NSFileReadNoPermissionError)")
print("  NSFileWriteUnknownError = \(NSFileWriteUnknownError)")
print("  NSFileWriteNoPermissionError = \(NSFileWriteNoPermissionError)")
print("  NSFileWriteOutOfSpaceError = \(NSFileWriteOutOfSpaceError)")
print("  NSFileWriteInvalidFileNameError = \(NSFileWriteInvalidFileNameError)")
print("  NSUserCancelledError = \(NSUserCancelledError)")
print("  NSCocoaErrorDomain = \(NSCocoaErrorDomain)")

// --- Window controller lazy loading -----------------------------------------
line("NSWindowController lazy window loading")

// A controller must have a `windowNibName` for the lazy path to exist at all:
// with none, AppKit reports the window loaded straight away and `loadWindow()`
// is never consulted. Overriding `loadWindow()` alongside the name keeps a real
// nib out of the measurement, so what is left is purely the timing question.
final class LazyController: NSWindowController {
    var loadWindowCalls = 0
    var willLoadCalls = 0
    var didLoadCalls = 0

    override var windowNibName: NSNib.Name? { "NoSuchNib" }

    override func loadWindow() {
        loadWindowCalls += 1
        window = NSWindow(contentRect: NSMakeRect(0, 0, 100, 100),
                          styleMask: [.titled],
                          backing: .buffered,
                          defer: false)
    }

    override func windowWillLoad() {
        willLoadCalls += 1
    }

    override func windowDidLoad() {
        didLoadCalls += 1
    }
}
let lazyController = LazyController()
print("  constructed:   isWindowLoaded=\(lazyController.isWindowLoaded) "
      + "loadWindow=\(lazyController.loadWindowCalls) "
      + "willLoad=\(lazyController.willLoadCalls) didLoad=\(lazyController.didLoadCalls)")
let loadedWindow = lazyController.window
print("  after .window: isWindowLoaded=\(lazyController.isWindowLoaded) "
      + "loadWindow=\(lazyController.loadWindowCalls) "
      + "willLoad=\(lazyController.willLoadCalls) didLoad=\(lazyController.didLoadCalls) "
      + "window=\(loadedWindow != nil)")
_ = lazyController.window
print("  second read:   loadWindow=\(lazyController.loadWindowCalls) — loads once, not per access")

// The form the demos actually use: a window handed in up front is loaded
// immediately and carries no nib name.
let directController = NSWindowController(window: window)
print("  init(window:): isWindowLoaded=\(directController.isWindowLoaded) "
      + "windowNibName=\(String(describing: directController.windowNibName))")
print("  shouldCascadeWindows default = \(lazyController.shouldCascadeWindows)")
print("  shouldCloseDocument default = \(lazyController.shouldCloseDocument)")

// --- Responder chain: how a document is reached -----------------------------
line("Responder chain — supplementalTarget")
// Apple's Swift name for the ObjC selector `saveDocument:` is `save(_:)`.
let saveSelector = #selector(NSDocument.save(_:))
print("  #selector(NSDocument.save(_:)) = \(NSStringFromSelector(saveSelector))")
let supplemental = windowController.supplementalTarget(forAction: saveSelector, sender: nil)
        as AnyObject?
print("    supplementalTarget = \(String(describing: supplemental)) "
      + "(is the document: \(supplemental === document))")
print("  document.responds(to: Selector(\"saveDocument:\")) = "
      + "\(document.responds(to: NSSelectorFromString("saveDocument:")))")
print("  document.responds(to: Selector(\"save:\")) = "
      + "\(document.responds(to: NSSelectorFromString("save:")))")
print("  window.nextResponder = \(String(describing: window.nextResponder))")
print("  windowController.nextResponder = \(String(describing: windowController.nextResponder))")
print("  NSApp.nextResponder = \(String(describing: NSApp?.nextResponder))")

line("Done")
