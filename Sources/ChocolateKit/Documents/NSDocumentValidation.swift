// How a menu item finds a document.
//
// THE THING TO UNDERSTAND HERE: a menu item carries an Objective-C selector
// name. Apple's Swift name for `saveDocument:` is `save(_:)` — the importer
// renamed it in Swift 3, and `#selector(NSDocument.save(_:))` really does
// print "saveDocument:" (measured; Docs/NSDOCUMENT_PLAN.md § Ground Truth).
//
// This framework has no Objective-C runtime, so `Runtime/Selector.swift` is a
// string wrapper and dispatch is a name switch — the same pattern as
// `Events/NSResponder.swift`. Every name below is therefore the OBJECTIVE-C
// one, and a name missing from this table fails silently: the menu item looks
// perfectly correct and does nothing at all. That is why they are listed in one
// place rather than spread across the code that implements them.

extension NSDocument {
    /// The Objective-C action names a document answers, mapped to its methods.
    ///
    /// Read by `responds(to:)` and `perform(_:with:)`, which live in the class
    /// body: Swift will not let a method override be declared in an extension
    /// for a class with no Objective-C runtime behind it.
    internal static var winDocumentActions: [String: (NSDocument, Any?) -> Void] {
        [
            "saveDocument:": { document, sender in document.save(sender) },
            "saveDocumentAs:": { document, sender in document.saveAs(sender) },
            "saveDocumentTo:": { document, sender in document.saveTo(sender) },
            "revertDocumentToSaved:": { document, sender in document.revertToSaved(sender) },
            "printDocument:": { document, sender in document.printDocument(sender) },
            "runPageLayout:": { document, sender in document.runPageLayout(sender) },
            "duplicateDocument:": { document, sender in document.duplicate(sender) },
            "renameDocument:": { document, sender in document.rename(sender) },
            "moveDocument:": { document, sender in document.move(sender) },
            "lockDocument:": { document, sender in document.lock(sender) },
            "unlockDocument:": { document, sender in document.unlock(sender) },
        ]
    }
}

// The conformances are declared here while their implementations stay in the
// class body — that split is what keeps `validateUserInterfaceItem(_:)` and
// `validateMenuItem(_:)` overridable by a document subclass, which they are on
// Apple. A witness declared inside the conforming extension would not be.
extension NSDocument: NSUserInterfaceValidations {}
extension NSDocument: NSMenuItemValidation {}

#if !canImport(Darwin)

extension NSDocument: NSFilePresenter {
    /// The file this document is presenting.
    public var presentedItemURL: URL? {
        fileURL
    }

    /// Saves pending changes when another reader wants the file.
    public func savePresentedItemChanges(completionHandler: @escaping (Error?) -> Void) {
        guard isDocumentEdited, fileURL != nil else {
            completionHandler(nil)
            return
        }
        save(nil)
        completionHandler(lastError)
    }

    /// Follows the file when something else moves or renames it.
    public func presentedItemDidMove(to newURL: URL) {
        fileURL = newURL
        synchronizeWindowTitles()
    }

    /// Notices that the file changed underneath the document.
    ///
    /// A document with unsaved edits is deliberately left alone: silently
    /// replacing what somebody is typing would lose their work.
    public func presentedItemDidChange() {
        guard let fileURL, !isDocumentEdited else {
            return
        }
        try? revert(toContentsOf: fileURL, ofType: fileType ?? fileURL.pathExtension)
    }
}

#endif
