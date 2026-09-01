# NSDocument — Document Model Plan

The full AppKit document architecture in `ChocolateKit`, and `ChocolateNoteDemo` — a
Windows-Notepad-shaped editor — as one source running on **all five Chocolates**.

---

## Dashboard

**Overall complete:** `████████████████████░░░░░` **83%** (71 / 86 items)

Percent measures progress toward each phase's **milestone**, as Bobby defines it
(`AICoding rules.md`, "What a phase is").

| # | Phase | Progress | % | Status |
| ---: | --- | --- | ---: | --- |
| 0 | [Ground Truth & Ledger](#phase-0--ground-truth--ledger--100-done) | `█████████████████████████` | 100% | ✅ Done |
| 1 | [Foundation Prerequisites](#phase-1--foundation-prerequisites--100-done) | `█████████████████████████` | 100% | ✅ Done |
| 2 | [Responder-Chain Routing](#phase-2--responder-chain-routing--100-done) | `█████████████████████████` | 100% | ✅ Done |
| 3 | [`NSDocument` Full Surface](#phase-3--nsdocument-full-surface--100-done) | `█████████████████████████` | 100% | ✅ Done |
| 4 | [`NSDocumentController` Full Surface](#phase-4--nsdocumentcontroller-full-surface--100-done) | `█████████████████████████` | 100% | ✅ Done |
| 5 | [`NSWindowController` / `NSWindow`](#phase-5--nswindowcontroller--nswindow--100-done) | `█████████████████████████` | 100% | ✅ Done |
| 6 | [Backends — Five Implementations](#phase-6--backends--five-implementations--88) | `██████████████████████░░░` | 88% | 🔄 In Progress |
| 7 | [ChocolateNoteDemo](#phase-7--chocolatenotedemo--92) | `███████████████████████░░` | 92% | 🔄 In Progress |
| 8 | [Verification & Docs](#phase-8--verification--docs--0) | `░░░░░░░░░░░░░░░░░░░░░░░░░` | 0% | ⏳ Pending |

**Status key:** ✅ Done · 🔄 In Progress · ⏳ Pending · 🚫 Blocked/Gated
**Change-class icons:** 🧩 A companion · ➕ B additive · ⚠️ C reorganization · 🛑 D breaking

### Conceptual Status — where each component stands

```
ChocolateNoteDemo     ███████████████████████░░   92%   builds on AppKit + WASM; TUI blocked
Backends: file access ██████████████████████░░░   88%   Win32 ✅ GTK ✅ WASM ✅ TUI ✗
NSDocument            ███████████████████████░░   93%   139 / 149 (10 are documented boundaries)
NSDocumentController  ███████████████████████░░   93%    43 /  46 (3 are boundaries)
NSWindowController    ███████████████████████░░   90%    28 /  31 (NSCoder, storyboards excluded)
Responder routing     █████████████████████████  100%   supplementalTarget + nil-target chain
FileWrapper           █████████████████████████  100%   core's own on Windows/WASI, real elsewhere
```

Member counts come from the [Parity Ledger](#parity-ledger) below, which is built from
Apple's own headers in the macOS 26.4 SDK.

**Class D (breaking) changes in this plan:** 5.1 (`NSWindowController.document` →
`AnyObject?`), 5.7 (the `"*"` title prefix leaves the API), 4.6 (`winDocumentClass` retired).
Each is required by the set-in-stone rule and each is recorded in `NEEDS_HUMAN.md` (8.8).

---

## Context

`NSDocument` is **not** absent. `Sources/ChocolateKit/Documents/` already holds a 583-line
first slice — `NSDocument.swift`, `NSDocumentController.swift`, `NSWindowController.swift` —
booked as "3.9 ✅ Done" in [ProjectPlan.md](ProjectPlan.md). It is a slice, and the ledger
below puts a number on how thin: 26 of Apple's 149 `NSDocument` members.

The driver is downstream. **ActiveUI** (`/Users/bobby/AIResearch/ActiveUI`) is built on
`NSDocument`: `Sources/ActiveUI/App/AUIDocument.swift` subclasses it, `AUIDocumentController`
subclasses `NSDocumentController`, and `Menus/AUIMenuCommand.swift:210-217` wires menu items
to the selectors `newDocument:`, `openDocument:`, `saveDocument:`, `saveDocumentAs:`,
`revertDocumentToSaved:`, `runPageLayout:` and `printDocument:` — every one of which finds
its target **through the responder chain**, which ChocolateKit does not extend to documents
at all. `Menus/AUIMenu.swift:357` calls
`openDocument(withContentsOf:display:completionHandler:)`, which does not exist here.

**The golden rule for this work:** every ActiveUI app runs on every Chocolate, even where an
implementation must differ radically — WASM has no filesystem, TUI has no GUI file dialog.
The API is identical on all five; the backend is free to be strange.

---

## Ground Truth

Measured against real AppKit on 2026-08-30, macOS 26.4 SDK, by
[`Tools/DocumentGroundTruthProbe.swift`](../Tools/DocumentGroundTruthProbe.swift). Rebuild
and rerun it before trusting any number here — the runner resolves its own directory, so it
works from anywhere:

```bash
/Users/bobby/AIResearch/WinChocolate/Tools/document-ground-truth.sh
```

### What the probe overturned

**1. `save(_:)` and `saveAs(_:)` are Apple's API, not our invention.** This was the plan's
original headline "fix", and it was wrong. The Swift importer renamed `saveDocument:` to
`save(_:)` in Swift 3, and the compiler says so outright:

```
error: 'saveDocument' has been renamed to 'save(_:)'
note: 'saveDocument' was obsoleted in Swift 3
```

`#selector(NSDocument.save(_:))` prints **`saveDocument:`**. So the existing spellings stay,
and what is actually missing is `saveTo(_:)` and `revertToSaved(_:)`. The Swift↔ObjC pairs
that matter, because ActiveUI's menus carry the ObjC name:

| Swift | ObjC selector |
| --- | --- |
| `save(_:)` | `saveDocument:` |
| `saveAs(_:)` | `saveDocumentAs:` |
| `saveTo(_:)` | `saveDocumentTo:` |
| `revertToSaved(_:)` | `revertDocumentToSaved:` |
| `printDocument(_:)` | `printDocument:` |
| `runPageLayout(_:)` | `runPageLayout:` |
| `duplicate(_:)` | `duplicateDocument:` |
| `rename(_:)` | `renameDocument:` |
| `move(_:)` | `moveDocument:` |
| `lock(_:)` / `unlock(_:)` | `lockDocument:` / `unlockDocument:` |
| `browseVersions(_:)` | `browseDocumentVersions:` |
| `saveToPDF(_:)` | `saveDocumentToPDF:` |

ChocolateKit has no Objective-C runtime — `Runtime/Selector.swift` is a string wrapper and
dispatch goes through `NSObject.perform(_:with:)` overrides (see the name-switch in
`Events/NSResponder.swift:74`). So `NSDocument` must answer **`"saveDocument:"`**, not
`"save:"`, in its `responds(to:)`/`perform(_:with:)` pair. That is item 3.15, and without it
every ActiveUI menu item is silently inert.

**2. `autosavingDelay` defaults to `0.0`** — AppKit does no periodic autosave by default.
ChocolateKit's hard-coded 30-second `Timer` in `NSDocument.startAutosaveTimerIfNeeded()` is
invented behaviour.

**3. An edited document's window title is unchanged.**

```
clean:  windowTitle(forDocumentDisplayName:) = "Untitled"   window.isDocumentEdited = false
edited: windowTitle(forDocumentDisplayName:) = "Untitled"   window.isDocumentEdited = true
```

AppKit sets `window.isDocumentEdited` for you and shows the dot in the close button. Our
`"*" + displayName` is a divergence — and the fix is better than a deletion: the asterisk
moves **into the Win32 and GTK window chrome**, where it is the correct native rendering of
`isDocumentEdited`, rather than a lie in the API.

**4. `NSDocument().data(ofType:)` does not throw.** AppKit raises
`NSInternalInconsistencyException` — "dataOfType:error: is a subclass responsibility but has
not been overridden" — and the process dies. So `NSDocumentError.unimplemented` has no
faithful Swift analogue; the honest port is a `fatalError` carrying Apple's exact message.

### Measured values

| Thing | Apple | Here today |
| --- | --- | --- |
| `SaveOperationType` raw values | `save 0`, `saveAs 1`, `saveTo 2`, `autosaveElsewhere 3`, `autosaveInPlace 4`, `autosaveAs 5` | enum with **no raw values**, declared in a different order |
| `ChangeType` raw values | `done 0`, `undone 1`, `cleared 2`, `readOtherContents 3`, `autosaved 4`, `redone 5`, `discardable 256` | two cases, no raw values |
| `autosavingDelay` | `0.0` | hard-coded 30 s timer |
| `maximumRecentDocumentCount` | `10` | hard-coded 10 ✅ |
| Untitled naming | `Untitled`, `Untitled 2`, `Untitled 3`, … | always `Untitled` |
| `defaultDraftName()` | `"Untitled"` | absent |
| `displayName` | `String!`, settable | `String`, get-only |
| `hasUndoManager` | `true` by default, `undoManager` non-nil | absent |
| `isEntireFileLoaded` | `true` | absent |
| `keepBackupFile` | `false` | absent |
| `fileNameExtension(forType:saveOperation:)` | `"txt"` for `public.plain-text` (UTType lookup) | `nil` |
| Lazy window loading | with a `windowNibName`: `isWindowLoaded` is **false** until `.window` is first read, which fires `windowWillLoad()` → `loadWindow()` → `windowDidLoad()` exactly once. With `init(window:)`: loaded immediately, `windowNibName` nil | `init(windowNibName:)` loads eagerly in the initializer |
| `window.nextResponder` | the `NSWindowController` | not linked |
| `windowController.supplementalTarget(forAction: saveDocument:)` | the document | method absent |
| Missing-file read error | `NSCocoaErrorDomain` 260, "The file … couldn't be opened because there is no such file." | `NSDocumentError.unimplemented` |
| Read-only-volume write error | `NSCocoaErrorDomain` 642 | — |
| Cocoa codes | read 256/257/259/260 · write 512/513/514/640 · cancelled 3072 | absent |

---

## Phase 0 — Ground Truth & Ledger ✅ 100% Done

**Milestone:** Apple's real behaviour is measured rather than guessed, and every later phase
has a checkable target. **Reached 2026-08-30** — and it immediately overturned the plan's
biggest assumption, which is the whole reason the phase exists.

| # | Item | Class | Status | Notes |
| --- | --- | --- | --- | --- |
| 0.1 | AppKit probe | 🧩 A | ✅ Done | [`Tools/DocumentGroundTruthProbe.swift`](../Tools/DocumentGroundTruthProbe.swift). Findings in [Ground Truth](#ground-truth) above. |
| 0.2 | This plan | 🧩 A | ✅ Done | Kept honest as items land. |
| 0.3 | Parity ledger | 🧩 A | ✅ Done | [Below](#parity-ledger), built from the macOS 26.4 SDK headers. It is what makes "% complete" mean something. |

---

## Phase 1 — Foundation Prerequisites ✅ 100% Done

**Milestone:** a `FileWrapper` directory round-trips to disk on Windows and in the browser,
and document failures are real `NSError`s — shown by a green contract-suite run.

`FileWrapper` is real on macOS and in swift-corelibs-foundation (Linux) but absent from
`WinFoundation` and unusable on WASI. `NSFileCoordinator`/`NSFilePresenter` exist nowhere
off Apple.

| # | Item | Class | Status | Notes |
| --- | --- | --- | --- | --- |
| 1.1 | `WinFoundation/…/FileWrapper.swift` | ➕ B | ✅ Done | Landed as `Sources/ChocolateKit/Runtime/FileWrapper.swift` + `FileWrapperIO.swift`, **not** in WinFoundation. Measured reason: the wasm SDK's Foundation has `FileManager` but no `FileWrapper`, so Windows and WASI both need one and WinFoundation is a Windows-only dependency a WASI build never sees. One copy in the core serves both gaps; gated `#if USE_WIN_FOUNDATION || os(WASI)` so it never collides with the real type on macOS and Linux. |
| 1.2 | `FileWrapper` on WASI | ➕ B | ✅ Done | Covered by 1.1's gate — verified by the wasm build, which compiles the gated copy. |
| 1.3 | `Runtime/NSFileCoordination.swift` | ➕ B | ✅ Done | `Runtime/NSFileCoordination.swift`. In-process only, gated `#if !canImport(Darwin)`. |
| 1.4 | Cocoa error codes | ➕ B | ✅ Done | `Runtime/CocoaFileErrors.swift` (internal, all platforms) plus `WinFoundation/…/CocoaError.swift` (the public Foundation constants, Windows only). The core uses its own factory rather than any Foundation's globals, because the four Foundations underneath do not agree on which of those names they export. |
| 1.5 | Retire `NSDocumentError` | 🛑 D | ✅ Done | `NSDocumentError` deleted. Read/write failures now raise real `NSError`s in `NSCocoaErrorDomain`; the un-overridden-subclass case traps with Apple's exact message, because Apple raises rather than throws. |
| 1.6 | Contract tests | 🧩 A | ✅ Done | `TestDeclarations27.swift`: regular-file and directory-tree round trips, child-name collisions, serialization round trip, and Cocoa error identity. They assert the contract, never the implementation — on Linux they run against real Foundation's `FileWrapper`. |

---

## Phase 2 — Responder-Chain Routing ✅ 100% Done

**Milestone:** a menu item with **no target** and action `saveDocument:` saves the front
document — the exact mechanism ActiveUI's menu bar already assumes.

The probe confirmed AppKit's route: `window.nextResponder` is the window controller, and
`windowController.supplementalTarget(forAction: "saveDocument:")` is the document. Nothing
of that exists here.

| # | Item | Class | Status | Notes |
| --- | --- | --- | --- | --- |
| 2.1 | `NSResponder.supplementalTarget(forAction:sender:)` | ➕ B | ✅ Done | Added to `Events/NSResponder.swift`. |
| 2.2 | `tryToPerform(_:with:)` consults it | ⚠️ C | ✅ Done | Each chain link is now offered the action three ways in AppKit's order: itself, its supplemental target, then `nextResponder`. |
| 2.3 | `NSWindowController` returns its document | ➕ B | ✅ Done | `NSWindowController.supplementalTarget(forAction:sender:)` returns its document. |
| 2.4 | `NSWindow.nextResponder` → its window controller | ⚠️ C | ✅ Done | `NSWindow.windowController` added; setting it makes the controller the window's `nextResponder`, matching the measured AppKit behaviour. |
| 2.5 | Nil-target chain reaches the document controller | ⚠️ C | ✅ Done | Both `sendAction(_:to:from:)` and `target(forAction:)` now end at `NSDocumentController.winSharedIfCreated` — an internal accessor that returns the shared controller **without creating one**, so a non-document app never grows one by accident. |
| 2.6 | `NSUserInterfaceValidations` | ➕ B | ✅ Done | `Menus/NSUserInterfaceValidation.swift`. Menu autoenabling now resolves a nil-target item through the chain before validating it — without that a `saveDocument:` item could fire but never be disabled. |
| 2.7 | Contract tests | 🧩 A | ✅ Done | Three tests in `TestDeclarations27.swift` covering the window→controller link, the supplemental hop, nil-target delivery to both document and controller, and menu validation. |

---

## Phase 3 — `NSDocument` Full Surface ✅ 100% Done

**Milestone:** the ledger's `NSDocument` section is green, and `AUIDocument` compiles against
it unchanged.

The split moves *responsibilities*, not just lines (`AICoding rules.md`, rule 43); no file
over 500 lines.

| # | Item | Class | Status | Notes |
| --- | --- | --- | --- | --- |
| 3.1 | File split | ⚠️ C | ✅ Done | Nine files, one per responsibility, named in the items below. |
| 3.2 | Identity & init family | ➕ B | ✅ Done | `fileModificationDate`, **settable** `displayName` (`String!`), `defaultDraftName()`, the measured `Untitled`/`Untitled 2` sequence, `init(type:)`, `init(contentsOf:ofType:)`, `init(for:withContentsOf:ofType:)`, `isInViewingMode`, `windowForSheet`. |
| 3.3 | Undo | ➕ B | ✅ Done | `undoManager`, `hasUndoManager` — both defaulting on, as measured — over `Runtime/NSUndoManager.swift`. Undo and redo drive the change count. |
| 3.4 | Change count & tokens | ➕ B | ✅ Done | Full `ChangeType` **with Apple's raw values**, `changeCountToken(for:)`, `updateChangeCount(withToken:for:)`. |
| 3.5 | `SaveOperationType` raw values | 🛑 D | ✅ Done | Today's enum has none and lists the cases in the wrong order. Apple's are `UInt`: 0/1/2/3/4/5 with `autosaveElsewhere` **before** `autosaveInPlace`. |
| 3.6 | Read/write ladder | ➕ B | ✅ Done | `NSDocumentReadWrite.swift`, Apple's order: `read(from:ofType:)` (Data), `read(from:ofType:)` (FileWrapper), `read(from:URL ofType:)`, `revert(toContentsOf:ofType:)`, `data(ofType:)`, `fileWrapper(ofType:)`, `write(to:ofType:)`, `write(to:ofType:for:originalContentsURL:)`, `isEntireFileLoaded`, `unblockUserInteraction()`. |
| 3.7 | Safe writing | ➕ B | ✅ Done | `writeSafely(to:ofType:for:)`, `keepBackupFile`, `backupFileURL`, `fileAttributesToWrite(to:ofType:for:originalContentsURL:)`. |
| 3.8 | Save actions | ➕ B | ✅ Done | **Additive, not a rename** — the probe showed `save(_:)`/`saveAs(_:)` are Apple's Swift names. Adds `saveTo(_:)` and `revertToSaved(_:)`. |
| 3.9 | Async save family | ➕ B | ✅ Done | `save(to:ofType:for:completionHandler:)`, `save(withDelegate:didSave:contextInfo:)`, `canAsynchronouslyWrite(to:ofType:for:)`. |
| 3.10 | Save-panel hooks | ➕ B | ✅ Done | `runModalSavePanel(for:delegate:didSave:contextInfo:)`, `prepareSavePanel(_:)`, `savePanelShowsFileFormatsControl`, `fileNameExtensionWasHiddenInLastRunSavePanel`, `fileTypeFromLastRunSavePanel`, over `Dialogs/NSSavePanel.swift`. |
| 3.11 | Autosaving | ➕ B | ✅ Done | `autosavesDrafts`, `isDraft`, `autosavedContentsFileURL`, `autosavingFileType`, `hasUnautosavedChanges`, `autosave(withImplicitCancellability:completionHandler:)`, `autosaveDocument(withDelegate:didAutosave:contextInfo:)`, `scheduleAutosaving()`, `checkAutosavingSafety()`, `autosavingIsImplicitlyCancellable`. **Deletes the invented 30 s timer** and the invented `autosave()`; the cadence comes from `NSDocumentController.autosavingDelay`, which defaults to 0. |
| 3.12 | Closing | ➕ B | ✅ Done | `NSDocumentClosing.swift`: `canClose(withDelegate:shouldClose:contextInfo:)`, `close()`, `shouldCloseWindowController(_:delegate:shouldClose:contextInfo:)`, `windowNibName`, `windowControllerWillLoadNib(_:)`, `windowControllerDidLoadNib(_:)`, `setWindow(_:)`. |
| 3.13 | Error presentation | ➕ B | ✅ Done | `presentError(_:)`, `presentError(_:modalFor:delegate:didPresent:contextInfo:)`, `willPresentError(_:)`, `willNotPresentError(_:)` over the existing `NSAlert(error:)`. |
| 3.14 | Printing | ➕ B | ✅ Done | `printInfo`, `printDocument(_:)`, `print(withSettings:showPrintPanel:delegate:didPrint:contextInfo:)`, `printOperation(withSettings:)`, `runModalPrintOperation(_:delegate:didRun:contextInfo:)`, `runPageLayout(_:)`, `runModalPageLayout(with:delegate:didRun:contextInfo:)`, `preparePageLayout(_:)`, `shouldChangePrintInfo(_:)`, over `Dialogs/NSPrintOperation.swift`. |
| 3.15 | Selector dispatch & validation | ➕ B | ✅ Done | **The item that makes menus work.** `responds(to:)`/`perform(_:with:)` mapping the **ObjC** names — `saveDocument:`, `saveDocumentAs:`, `saveDocumentTo:`, `revertDocumentToSaved:`, `printDocument:`, `runPageLayout:`, `duplicateDocument:`, `renameDocument:`, `moveDocument:`, `lockDocument:`, `unlockDocument:` — following the switch pattern in `Events/NSResponder.swift:74`. Plus `validateUserInterfaceItem(_:)`. |
| 3.16 | File presenter | ➕ B | ✅ Done | The 1.3 conformance. |
| 3.17 | Move, rename, duplicate, lock | ➕ B | ✅ Done | `duplicate(_:)`, `duplicateAndReturnError()`, `rename(_:)`, `move(_:)`, `move(to:completionHandler:)`, `lock(_:)`/`unlock(_:)` and their completion-handler forms, `isLocked`. Plain file operations — no Finder integration to hook. |
| 3.18 | Documented boundaries | 🧩 A | ✅ Done | Into [AppKitCompatibilityDivergences.md](AppKitCompatibilityDivergences.md) rather than silently absent: version browsing (`browseVersions(_:)`, `preservesVersions`) has no store on any platform; iCloud (`usesUbiquitousStorage`, `moveDocumentToUbiquityContainer:`) has no analogue; sharing (`allowsDocumentSharing`, `NSSharingServicePicker`) is Apple-only; `performActivity`/`performAsynchronousFileAccess` serialise on the main queue because the framework is single-threaded by design. |
| 3.19 | Contract tests | 🧩 A | ✅ Done | New `Tests/WinChocolateContractTests/TestDeclarations27.swift`, registered from `main.swift`. Existing document tests (`TestDeclarations17.swift:353+`, `TestDeclarations18.swift:202+`) updated. |

---

## Phase 4 — `NSDocumentController` Full Surface ✅ 100% Done

**Milestone:** New, Open, Open Recent, Save All and quit-with-unsaved-changes all work from a
menu bar, and recents survive a restart.

| # | Item | Class | Status | Notes |
| --- | --- | --- | --- | --- |
| 4.1 | Opening family | ➕ B | ✅ Done | `openDocument(withContentsOf:display:completionHandler:)` — *ActiveUI calls this today* — plus `reopenDocument(for:withContentsOf:display:completionHandler:)`, `openUntitledDocumentAndDisplay(_:)`, `makeDocument(for:withContentsOf:ofType:)`, `duplicateDocument(withContentsOf:copying:displayName:)`. |
| 4.2 | Open-panel hooks | ➕ B | ✅ Done | `urlsFromRunningOpenPanel()`, `runModalOpenPanel(_:forTypes:)`, `beginOpenPanel(completionHandler:)`, `beginOpenPanel(_:forTypes:completionHandler:)`, `currentDirectory`. |
| 4.3 | Bulk lifecycle | ➕ B | ✅ Done | `saveAllDocuments(_:)`, `hasEditedDocuments`, `closeAllDocuments(withDelegate:didCloseAllSelector:contextInfo:)`, `reviewUnsavedDocuments(withAlertTitle:cancellable:delegate:didReviewAllSelector:contextInfo:)`. |
| 4.4 | Recents | ➕ B | ✅ Done | `noteNewRecentDocument(_:)`, `maximumRecentDocumentCount` (10, measured), persistence through the existing `WinFoundation/UserDefaults.swift`. The Open Recent **menu** stays app-built from `recentDocumentURLs` — AppKit's own mechanism is a nib class, so inventing a framework API here would break the rule. |
| 4.5 | Types | ➕ B | ✅ Done | `typeForContents(of:)` throwing, `displayName(forType:)`, `documentClassNames`, `defaultType`, `documentClass(forType:)`. |
| 4.6 | Retire `winDocumentClass` | 🛑 D | ✅ Done | Delete the `package var`; strike its row from [AppKitFaithfulnessIssues.md](AppKitFaithfulnessIssues.md) (line 106). |
| 4.7 | `autosavingDelay` | ➕ B | ✅ Done | Default `0.0`, as measured. Drives 3.11. |
| 4.8 | Error presentation | ➕ B | ✅ Done | `presentError(_:)`, `presentError(_:modalFor:delegate:didPresent:contextInfo:)`, `willPresentError(_:)`. |
| 4.9 | Document lookup | ➕ B | ✅ Done | `document(for: URL)`, `document(for: NSWindow)`. |
| 4.10 | Selector dispatch & validation | ➕ B | ✅ Done | `responds(to:)`/`perform(_:with:)` for `newDocument:`, `openDocument:`, `saveAllDocuments:`, `clearRecentDocuments:`; `validateUserInterfaceItem(_:)`. |
| 4.11 | Terminate protocol | ➕ B | ✅ Done | `NSApplication.TerminateReply`, `NSApplicationDelegate.applicationShouldTerminate(_:)` (`Application/NSApplicationDelegate.swift`), `NSApplication.reply(toApplicationShouldTerminate:)`. |
| 4.12 | Quit reviews documents | ⚠️ C | ✅ Done | `NSApplication.terminate(_:)` (`NSApplication.swift:282`) runs 4.3's review before tearing down. |
| 4.13 | Contract tests | 🧩 A | ✅ Done | Open-by-URL, save-all, review-on-quit, recents cap, selector routing. |

---

## Phase 5 — `NSWindowController` / `NSWindow` ✅ 100% Done

**Milestone:** a document window titles itself from the document, shows edited state the way
its own platform does, and refuses to close through `canClose` rather than its own alert.

| # | Item | Class | Status | Notes |
| --- | --- | --- | --- | --- |
| 5.1 | `document: AnyObject?` | 🛑 D | ✅ Done | Apple's real type (`@property (nullable, assign) id document`). Callers use `as? NSDocument`. Breaks the demo and suite; updated in the same commit. |
| 5.2 | Nib init family | ➕ B | ✅ Done | `init(windowNibName:owner:)`, `init(windowNibPath:owner:)`, `windowNibName`, `windowNibPath`, `owner`. |
| 5.3 | Lazy window loading | ⚠️ C | ✅ Done | Measured contract: a controller with a `windowNibName` reports `isWindowLoaded == false` until `.window` is first read; that read fires `windowWillLoad()` → `loadWindow()` → `windowDidLoad()` **once**, and later reads do not reload. A controller made with `init(window:)` is loaded from the start and has a nil `windowNibName`. Today's `init(windowNibName:)` loads eagerly in the initializer. |
| 5.4 | `contentViewController` | ➕ B | ✅ Done | Over the existing `Views/NSViewController.swift`. |
| 5.5 | `setDocumentEdited(_:)`, `dismissController(_:)` | ➕ B | ✅ Done | |
| 5.6 | `windowFrameAutosaveName` | ➕ B | ✅ Done | Over the existing `Windows/NSWindowFrameAutosave.swift`. |
| 5.7 | Title synchronization | 🛑 D | ✅ Done | `synchronizeWindowTitleWithDocumentName()` sets `window.title` to the **plain** display name and `window.representedURL` to the file. The `"*"` prefix leaves the API and reappears in the backends (6.1, 6.2, 6.4, 6.7) as native chrome. |
| 5.8 | `NSWindow` document surface | ➕ B | ✅ Done | `isDocumentEdited`, `representedURL`, `representedFilename`. AppKit sets `isDocumentEdited` from the document automatically — measured. |
| 5.9 | `windowShouldClose` → `canClose` | ⚠️ C | ✅ Done | `Documents/NSWindowController.swift` currently runs its own three-button alert; it moves into `NSDocument.canClose(withDelegate:shouldClose:contextInfo:)`, where AppKit keeps it. |
| 5.10 | Contract tests | 🧩 A | ✅ Done | Lazy load, title sync, close veto through `canClose`. |

---

## Phase 6 — Backends — Five Implementations 🔄 88%

**Milestone:** Open and Save work on all five backends, and an edited document looks edited
on each. *The same API; five very different implementations — the golden rule.*

| # | Item | Class | Status | Notes |
| --- | --- | --- | --- | --- |
| 6.1 | Win32 edited chrome | ➕ B | ✅ Done | The classic `*` in the title bar, driven by `isDocumentEdited`. `runFileDialog` already exists (`Native/Win32/Win32Dialogs.swift:24`). |
| 6.2 | GTK edited chrome | ➕ B | ✅ Done | `runFileDialog` already exists (`Native/GTK/GTKNativeControlBackendPart20.swift:280`). |
| 6.3 | TUI file dialog | ➕ B | 🚫 Blocked | TUIChocolate has no `runFileDialog`: a terminal file chooser built from TUI primitives, answering the same `NativeFileDialogOptions` contract. |
| 6.4 | TUI edited chrome | ➕ B | 🚫 Blocked | |
| 6.5 | WASM virtual filesystem | ➕ B | ✅ Done | `Native/WASM/WASMFileAccess.swift`: an in-memory VFS keyed by `URL`, persisted to `localStorage`, so `Data(contentsOf:)`/`Data.write(to:)` round-trip in a browser that has no filesystem. |
| 6.6 | WASM file dialog | ➕ B | ✅ Done | Override `runFileDialog` on `WASMNativeControlBackend` — legal, because it sits in `InMemoryNativeControlBackend`'s *class body* (`Native/InMemoryNativeControlBackendState.swift:1045`), so the extension-override ceiling does not bite. **Open** → `<input type=file>` + `FileReader` into the VFS. **Save** → `Blob` + anchor download, with the VFS as the document's URL. |
| 6.7 | WASM edited chrome | ➕ B | ✅ Done | |
| 6.8 | Backend parity tests | 🧩 A | ✅ Done | Extend the in-memory backend's queued-paths dialog model to the new calls. |

---

## Phase 7 — ChocolateNoteDemo 🔄 92%

**Milestone:** one source tree — a Notepad-shaped editor — builds and runs on real AppKit,
Win32, GTK, WASM and TUIChocolate.

New `Demo/ChocolateNoteDemo/`, following `Demo/CounterDemo/`'s shape exactly: the same
`#if canImport(TUIChocolate) / os(WASI) / os(Linux) / os(Windows) / canImport(AppKit)` import
switch, and a demo-local conveniences file whose `onAction` sugar is built on **real**
target/action — never framework surface.

| # | Item | Class | Status | Notes |
| --- | --- | --- | --- | --- |
| 7.1 | Scaffolding | ➕ B | ✅ Done | `main.swift` + `ChocolateNoteDemoConveniences.swift`. |
| 7.2 | `NoteDocument.swift` | ➕ B | ✅ Done | `NSDocument` subclass: plain text with a selectable encoding, `data(ofType:)`, `read(from:ofType:)`, `makeWindowControllers()`, undo through `document.undoManager`. |
| 7.3 | `NoteWindowController.swift` | ➕ B | ✅ Done | `NSWindowController` subclass: `NSTextView` in an `NSScrollView`, status bar (Ln/Col + zoom %), zoom state. |
| 7.4 | File menu | ➕ B | ✅ Done | New, New Window, Open…, Open Recent ▸, Save, Save As…, Page Setup…, Print…, Exit. |
| 7.5 | Edit menu | ➕ B | ✅ Done | Undo, Redo, Cut, Copy, Paste, Delete, Select All, Time/Date. |
| 7.6 | Find, Replace, Go To | ➕ B | ✅ Done | Over `Controls/NSTextFinder.swift`. Gaps found here are framework work, not demo work. |
| 7.7 | Format menu | ➕ B | ✅ Done | Word Wrap (`NSTextContainer.widthTracksTextView`), Font… (`Dialogs/NSFontPanel.swift`). |
| 7.8 | View menu | ➕ B | ✅ Done | Zoom In / Zoom Out / Restore Default Zoom, Status Bar. |
| 7.9 | `Package.swift` target | ➕ B | ✅ Done | `ChocolateNoteDemo` executable, using the existing per-platform `.target(name:condition:)` pattern. |
| 7.10 | Runner selectors | ➕ B | ✅ Done | A `note`/`chocolatenote` case in `run-mac.sh` and `buildandrun.bat` (~line 71). `run-linux.sh` and `build-wasm.sh` already take a target name. |
| 7.11 | TUIAppKit mirror | ➕ B | 🔄 In Progress | `Code/Demo/TUINoteDemo` in `/Users/bobby/AIResearch/TUIAppKit` — character-identical source, a target in `Code/Demo/Package.swift`, a `run.sh` selector. Keep `.build-gui`/`.build-tui` split. |
| 7.12 | WASM shell | ➕ B | ✅ Done | `Demo/ChocolateNoteDemo/index.html`, matching CounterDemo's. |

---

## Phase 8 — Verification & Docs ⏳ 0%

**Milestone:** five green runs, ActiveUI building against the updated Chocolate, and every
plan/ledger document telling the truth.

| # | Item | Class | Status | Notes |
| --- | --- | --- | --- | --- |
| 8.1 | macOS faithfulness gate | 🧩 A | ⏳ Pending | `./run-mac.sh note --build` — the same sources against Apple's SDK, no shim. **Any error is a framework divergence, never a demo fix.** Zero errors *and* zero "nearly matches" warnings. |
| 8.2 | Windows run | 🧩 A | ⏳ Pending | `buildandrun.bat note` on the VM. |
| 8.3 | Linux run | 🧩 A | ⏳ Pending | `./run-linux.sh --tests`, then `./run-linux.sh ChocolateNoteDemo`. |
| 8.4 | WASM run | 🧩 A | ⏳ Pending | `./build-wasm.sh --release ChocolateNoteDemo`; open, edit, save, confirm the download and reload-from-`localStorage`. |
| 8.5 | TUI run | 🧩 A | ⏳ Pending | `./run.sh --tui` in `TUIAppKit/Code/Demo`, verified under a pty with `Tools/drive-tui.py` — a TUI screenshot proves paint, not behaviour. |
| 8.6 | ActiveUI builds | 🧩 A | ⏳ Pending | The real consumer: `AUIDocument`/`AUIDocumentController` compile and their menu commands route. |
| 8.7 | Docs | 🧩 A | ⏳ Pending | [ProjectPlan.md](ProjectPlan.md) (reopen 3.9), [LinChocolatePlan.md](LinChocolatePlan.md) (L13.4), [WASM_CHOCOLATE_PLAN.md](WASM_CHOCOLATE_PLAN.md) (line 476 — round-trips are no longer no-ops), [AppKitFaithfulnessIssues.md](AppKitFaithfulnessIssues.md), [AppKitCompatibilityDivergences.md](AppKitCompatibilityDivergences.md), `CONTROL_PARITY.md`, `README.md`. |
| 8.8 | `NEEDS_HUMAN.md` | 🧩 A | ⏳ Pending | Entries for the Class D changes (1.5, 3.5, 4.6, 5.1, 5.7) and any file crossing 500 lines. Bobby is alerted on each addition. |

---

## How Phases 1–5 were verified

Docker would not start on this machine and there is no Windows VM to hand, so the suite's two
usual homes were both unavailable. Rather than land five phases on "it compiles", a third way
in was built and is now part of the repo:

```bash
Tools/run-contract-tests.sh              # build for wasm32-wasi, run under Node's WASI
Tools/run-contract-tests.sh --only Document
Tools/run-contract-tests.sh --skip-env   # step past tests needing a UserDefaults store
```

The same sources build for `wasm32-unknown-wasip1`, and `CHOCOLATE_BACKEND=inmemory` keeps
the browser backend from ever initializing — so the framework logic runs for real against the
recording backend, on this Mac, in seconds. The JavaScriptKit imports are stubbed, and every
stub reports itself if it is ever called, because a stub being reached would mean something
took the DOM path and the run could not be trusted.

**It proves logic, not rendering.** No Win32 window and no GTK widget is involved. Phase 8's
Linux and Windows gates still have to run.

**Regression evidence.** WASI cannot get a full green run even at `HEAD` — four tests fail
there for environment reasons (`UserDefaults` persistence, `NSImage` file loading, formatter
parsing, table-header dragging). To be sure none of that was mine, `HEAD` was checked out into
a git worktree and walked in lockstep with this branch: **both trees fail at exactly the same
four tests, in the same order, with the same messages, and then trap identically.** No
divergence anywhere.

What passes on this branch: **all 23 document tests**, including every one written for Phases
1–5, plus the 345 pre-existing tests that run before the first environmental failure. The
11-page demo and `CounterDemo` both still build against the changed API.

---

## What Phases 6–7 proved, and what is still unproven

### Proven by running it

`ChocolateNoteDemo` — a Notepad: multi-document, File/Edit/Format/View/Help, Open Recent,
word wrap, zoom, a Ln/Col status bar, Find/Replace/Go To, dirty tracking and the
save-changes prompt.

```bash
./run-mac.sh note          # real AppKit — the control group
```

**The faithfulness gate passes: 0 errors, 0 "nearly matches" warnings.** The same source
compiles against Apple's SDK with no shim, and running it caught a bug no compiler could:
AppKit opens an untitled document for a document-based app *before*
`applicationDidFinishLaunching`, so the demo's own `newDocument` produced **two** windows on
macOS and one everywhere else. Fixed by asking whether anything is open first.

The gate also caught three real framework divergences, each fixed in the framework rather
than worked around in the demo:

| Caught | Fixed by |
| --- | --- |
| `NSWindowController.init(windowNibName:owner:)` took `AnyObject?`; Apple's takes a non-optional `Any` | Framework now matches Apple; `init(windowNibName:)` makes the controller its own owner |
| `NSScrollView.contentSize` was missing | Added — it is what a text container sizes itself against |
| `NSBeep()` does not exist in modern AppKit | Demo uses `NSSound.beep()`, which all five have |

And one design point worth recording: `NoteWindowController` conforms to **no** delegate
protocol and declares **no** initializer. Both are deliberate. `NSTextViewDelegate` is
`@MainActor`, so conforming would infer main-actor isolation onto a class whose superclass is
nonisolated off Apple; and `NSWindowController.init?(coder:)` is `required` on Apple, so
declaring any initializer would demand an `NSCoder` that does not exist here. Splitting the
delegate out and inheriting the initializers is what lets one source satisfy both.

### Proven by building

`./build-wasm.sh --release ChocolateNoteDemo` compiles, and the browser gets a genuine
document story rather than the no-op the WASM plan recorded: `Runtime/ChocolateFileAccess.swift`
is a capability seam — **not** an `os(WASI)` switch, because the same wasm binary has a real
filesystem under Node and none in a tab — and `WASMVirtualFileSystem` installs itself as the
substitute, persisted to `localStorage`. Open uses an `<input type=file>`, Save offers a
download.

### Written but NOT run

**Win32 and GTK document chrome and page setup are unverified.** There is no Windows
toolchain and no working Docker on this machine, so `Win32DocumentChrome.swift` and
`GTKDocumentChrome.swift` have never been compiled. They follow the existing FFI patterns in
their directories, and the `PAGESETUPDLGW` struct layout in particular is the kind of thing
that is not a compile error when wrong — it is a dialog that reads garbage. **Treat both as
drafts until Phase 8's Windows and Linux gates run.**

### Blocked

**TUIChocolate cannot build the demo yet** (items 6.3, 6.4, 7.11). The source is mirrored
character-for-character to `TUIAppKit/Code/Demo/TUINoteDemo` and the target is registered, but
TUIChocolate's document layer is a 238-line stub. The build reports it missing:

- `NSDocument`: `undoManager`, `SaveOperationType`, `document`
- `NSDocumentController`: `currentDocument`, `openDocument`, `recentDocumentURLs`
- `NSWindowController`: `document`, `windowDidLoad`; `NSWindow.windowController`
- `NSTextView`: `font`, `selectedRange`, `textContainer`, `scrollRangeToVisible`
- `NSApplication`: `delegate`, `NSApplicationDelegate`; `NSMenu.numberOfItems`, `NSNib.Name`
- `NSScrollView.contentSize`, `NSFontManager.setSelectedFont`, `NSSound`, `DateFormatter`

That is a body of work in TUIChocolate, not a demo fix — and per the golden rule the demo is
not finished until it runs there. It is scoped here rather than hidden.

---

## Parity Ledger

Apple's members, from the macOS 26.4 SDK headers. ✅ present · ⏳ planned (phase item) ·
🚫 documented boundary. Deprecated-since-10.4 members are excluded; they are not part of the
target surface.

### `NSDocument` — 26 / 149

| Member | Here | Item |
| --- | --- | --- |
| `init()` | ✅ | |
| `init(type:)`, `init(contentsOf:ofType:)`, `init(for:withContentsOf:ofType:)` | ⏳ | 3.2 |
| `canConcurrentlyReadDocuments(ofType:)` | ⏳ | 3.6 |
| `fileType`, `fileURL` | ✅ | |
| `fileModificationDate`, `isDraft` | ⏳ | 3.2 / 3.11 |
| `performActivity…`, `continueActivity…`, `performSynchronousFileAccess…`, `performAsynchronousFileAccess…`, `continueAsynchronousWorkOnMainThread…` | 🚫 | 3.18 |
| `revertToSaved(_:)`, `revert(toContentsOf:ofType:)` | ⏳ | 3.8 / 3.6 |
| `read(from:ofType:)` (Data), `read(from:URL ofType:)` | ✅ | |
| `read(from:ofType:)` (FileWrapper), `fileWrapper(ofType:)` | ⏳ | 3.6 |
| `isEntireFileLoaded`, `unblockUserInteraction()` | ⏳ | 3.6 |
| `data(ofType:)`, `write(to:ofType:)` | ✅ | |
| `write(to:ofType:for:originalContentsURL:)`, `writeSafely(to:ofType:for:)`, `fileAttributesToWrite(…)`, `keepBackupFile`, `backupFileURL` | ⏳ | 3.6 / 3.7 |
| `save(_:)`, `saveAs(_:)` | ✅ | |
| `saveTo(_:)` | ⏳ | 3.8 |
| `save(withDelegate:didSave:contextInfo:)`, `save(to:ofType:for:completionHandler:)`, `canAsynchronouslyWrite(to:ofType:for:)` | ⏳ | 3.9 |
| `runModalSavePanel(for:delegate:didSave:contextInfo:)`, `prepareSavePanel(_:)`, `savePanelShowsFileFormatsControl`, `fileNameExtensionWasHiddenInLastRunSavePanel`, `fileTypeFromLastRunSavePanel` | ⏳ | 3.10 |
| `checkAutosavingSafety()`, `scheduleAutosaving()`, `hasUnautosavedChanges`, `autosaveDocument(withDelegate:…)`, `autosave(withImplicitCancellability:completionHandler:)`, `autosavingIsImplicitlyCancellable`, `autosavesDrafts`, `autosavingFileType`, `autosavedContentsFileURL` | ⏳ | 3.11 |
| `autosavesInPlace` | ✅ | |
| `preservesVersions`, `browseVersions(_:)`, `isBrowsingVersions`, `stopBrowsingVersions(completionHandler:)` | 🚫 | 3.18 |
| `canClose(withDelegate:shouldClose:contextInfo:)` | ⏳ | 3.12 |
| `close()` | ✅ | |
| `duplicate(_:)`, `duplicateDocument(withDelegate:…)`, `duplicateAndReturnError()`, `rename(_:)`, `move(_:)`, `moveDocument(completionHandler:)`, `move(to:completionHandler:)`, `lock(_:)`, `unlock(_:)`, and their completion-handler forms, `isLocked` | ⏳ | 3.17 |
| `moveDocumentToUbiquityContainer(_:)`, `usesUbiquitousStorage` | 🚫 | 3.18 |
| `runPageLayout(_:)`, `runModalPageLayout(with:delegate:didRun:contextInfo:)`, `preparePageLayout(_:)`, `shouldChangePrintInfo(_:)`, `printInfo`, `printDocument(_:)`, `print(withSettings:showPrintPanel:delegate:didPrint:contextInfo:)`, `printOperation(withSettings:)`, `runModalPrintOperation(_:delegate:didRun:contextInfo:)`, `saveToPDF(_:)`, `pdfPrintOperation` | ⏳ | 3.14 |
| `allowsDocumentSharing`, `share(with:completionHandler:)`, `prepareSharingServicePicker(_:)`, `previewRepresentableActivityItems` | 🚫 | 3.18 |
| `isDocumentEdited` | ✅ | |
| `isInViewingMode` | ⏳ | 3.2 |
| `updateChangeCount(_:)` | ✅ | |
| `changeCountToken(for:)`, `updateChangeCount(withToken:for:)` | ⏳ | 3.4 |
| `undoManager`, `hasUndoManager` | ⏳ | 3.3 |
| `presentError(_:)`, `presentError(_:modalFor:delegate:didPresent:contextInfo:)`, `willPresentError(_:)`, `willNotPresentError(_:)` | ⏳ | 3.13 |
| `makeWindowControllers()`, `addWindowController(_:)`, `removeWindowController(_:)`, `showWindows()`, `windowControllers` | ✅ | |
| `windowNibName`, `windowControllerWillLoadNib(_:)`, `windowControllerDidLoadNib(_:)`, `setWindow(_:)`, `shouldCloseWindowController(_:delegate:shouldClose:contextInfo:)` | ⏳ | 3.12 |
| `displayName` (get) | ✅ | |
| `displayName` (set), `defaultDraftName()`, `windowForSheet` | ⏳ | 3.2 |
| `readableTypes`, `writableTypes`, `isNativeType(_:)`, `writableTypes(for:)`, `fileNameExtension(forType:saveOperation:)` | ✅ | |
| `validateUserInterfaceItem(_:)` | ⏳ | 3.15 |
| `NSFilePresenter` conformance (13 members) | ⏳ | 3.16 |
| `shouldRunSavePanelWithAccessoryView` (deprecated) | ✅ | |
| **Selector dispatch** for the 11 ObjC action names | ⏳ | 3.15 |

### `NSDocumentController` — 11 / 46

| Member | Here | Item |
| --- | --- | --- |
| `shared`, `init()` | ✅ | |
| `init(coder:)` | 🚫 | no `NSCoder` |
| `documents`, `currentDocument`, `addDocument(_:)`, `removeDocument(_:)` | ✅ | |
| `currentDirectory`, `document(for: URL)`, `document(for: NSWindow)` | ⏳ | 4.2 / 4.9 |
| `newDocument(_:)`, `openDocument(_:)`, `makeUntitledDocument(ofType:)`, `makeDocument(withContentsOf:ofType:)` | ✅ | |
| `openUntitledDocumentAndDisplay(_:)`, `openDocument(withContentsOf:display:completionHandler:)`, `reopenDocument(for:withContentsOf:display:completionHandler:)`, `makeDocument(for:withContentsOf:ofType:)`, `duplicateDocument(withContentsOf:copying:displayName:)` | ⏳ | 4.1 |
| `urlsFromRunningOpenPanel()`, `runModalOpenPanel(_:forTypes:)`, `beginOpenPanel(completionHandler:)`, `beginOpenPanel(_:forTypes:completionHandler:)` | ⏳ | 4.2 |
| `autosavingDelay` | ⏳ | 4.7 |
| `saveAllDocuments(_:)`, `hasEditedDocuments`, `reviewUnsavedDocuments(…)`, `closeAllDocuments(…)` | ⏳ | 4.3 |
| `allowsAutomaticShareMenu`, `standardShareMenuItem()` | 🚫 | 3.18 |
| `presentError(_:)`, `presentError(_:modalFor:…)`, `willPresentError(_:)` | ⏳ | 4.8 |
| `recentDocumentURLs`, `clearRecentDocuments(_:)`, `noteNewRecentDocumentURL(_:)` | ✅ | |
| `maximumRecentDocumentCount`, `noteNewRecentDocument(_:)` | ⏳ | 4.4 |
| `defaultType`, `documentClassNames`, `documentClass(forType:)`, `displayName(forType:)`, `typeForContents(of:)` | ✅ | shapes exist; 4.5 completes them |
| `validateUserInterfaceItem(_:)` | ⏳ | 4.10 |
| **Selector dispatch** for `newDocument:`, `openDocument:`, `saveAllDocuments:`, `clearRecentDocuments:` | ⏳ | 4.10 |
| `winDocumentClass` (not Apple) | 🛑 | 4.6 removes |

### `NSWindowController` — 10 / 31

| Member | Here | Item |
| --- | --- | --- |
| `init(window:)`, `init(windowNibName:)` | ✅ | |
| `init(coder:)` | 🚫 | no `NSCoder` |
| `init(windowNibName:owner:)`, `init(windowNibPath:owner:)`, `windowNibName`, `windowNibPath`, `owner` | ⏳ | 5.2 |
| `windowFrameAutosaveName` | ⏳ | 5.6 |
| `shouldCascadeWindows`, `shouldCloseDocument` | ✅ | |
| `previewRepresentableActivityItems` | 🚫 | 3.18 |
| `document` | ⚠️ | 5.1 — wrong type |
| `setDocumentEdited(_:)` | ⏳ | 5.5 |
| `synchronizeWindowTitleWithDocumentName()` | ✅ | |
| `windowTitle(forDocumentDisplayName:)` | ⚠️ | 5.7 — adds `"*"` |
| `contentViewController` | ⏳ | 5.4 |
| `window`, `isWindowLoaded`, `windowDidLoad()`, `close()`, `showWindow(_:)` | ✅ | |
| `windowWillLoad()`, `loadWindow()` | ⏳ | 5.3 |
| `storyboard` | 🚫 | no storyboards |
| `dismissController(_:)` | ⏳ | 5.5 |
| `supplementalTarget(forAction:sender:)` (from `NSResponder`) | ⏳ | 2.3 |

---

## Sequencing

Phases complete in order (`AICoding rules.md`). Phase 2 is worth landing early on its own —
it makes ActiveUI's existing menu bar work with no ActiveUI edit. Phase 7's demo is what
proves the rest, and per the golden rule it is not done until it runs on all five backends.
