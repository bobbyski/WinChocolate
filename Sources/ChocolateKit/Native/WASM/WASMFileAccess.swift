// Documents in a browser tab.
//
// ---------------------------------------------------------------------------
// The problem, stated plainly.
//
// A browser tab has no filesystem. WASI's `Data(contentsOf:)` and
// `Data.write(to:)` have nothing underneath them, and there is no directory to
// put an open panel in front of. Yet `NSDocument` is written entirely in terms
// of URLs, and the golden rule says the same app runs here as everywhere else.
//
// So this file supplies the two things the browser genuinely lacks:
//
//   1. A VIRTUAL FILESYSTEM keyed by URL, persisted to `localStorage`, so a
//      document's read/write round-trips and survives a reload.
//   2. A FILE DIALOG made of the two things a browser really has: an
//      `<input type=file>` for opening, and an anchor download for saving.
//
// The seam is `runFileDialog`, which is the same call Win32 answers with
// comdlg32 and GTK answers with its own chooser. Same API, wildly different
// implementation — which is the point.
//
// WHAT IS HONESTLY DIFFERENT, and cannot be otherwise:
//
//   * Opening is ASYNCHRONOUS in a browser. A file input reports its choice
//     through an event, and there is no way to block a wasm call until it
//     arrives. `runFileDialog` therefore returns the picked file on the *next*
//     call after the user chooses; the first call opens the picker and reports
//     no selection. `NSDocumentController.openDocument(_:)` is a no-op that
//     one time, and the document opens when the user picks. This is stated
//     rather than hidden, because a silent "nothing happened" would be worse.
//   * Saving writes to the VFS immediately and *offers* a download. Whether
//     the file reaches the user's disk is the browser's decision, not ours.
// ---------------------------------------------------------------------------

#if canImport(JavaScriptKit)

import JavaScriptKit
import SwiftDOM

/// The in-memory filesystem a browser document lives in.
///
/// Keyed by path so it matches what `URL.path` gives back, and mirrored into
/// `localStorage` so a reload does not lose the user's work.
///
/// ```
///   NSDocument.write(to:)  ──▶  Data.write(to:)  ──▶  WASMVirtualFileSystem
///                                                            │
///                                                            ├─▶ localStorage
///                                                            └─▶ download offer
/// ```
public final class WASMVirtualFileSystem: ChocolateFileStore {
    /// The one filesystem for this page.
    public static let shared = WASMVirtualFileSystem()

    /// The key every file is stored under in `localStorage`, as one blob.
    ///
    /// One key rather than one per file: `localStorage` is synchronous and
    /// string-only, and a single JSON blob keeps a save to one write instead of
    /// a scattered set that could half-fail.
    private static let storageKey = "ChocolateDocuments"

    /// File contents by path.
    ///
    /// This IS the store the core reads and writes through — it is installed as
    /// `ChocolateFileAccess.substitute`, so there is exactly one copy of a
    /// document's bytes. Two stores would drift the moment something saved
    /// through one and reloaded through the other.
    private var files: [String: [UInt8]] = [:]

    /// Loads whatever a previous visit left behind and takes over file access.
    private init() {
        restore()
    }

    /// Makes this the filesystem the framework's documents use.
    ///
    /// Called by the browser backend at startup. Nothing installs it in a
    /// headless wasm process, which is deliberate: Node gives that process a
    /// real preopened directory, and using it is more honest than pretending.
    public static func install() {
        ChocolateFileAccess.substitute = shared
    }

    /// Whether a file exists at a path.
    public func fileExists(atPath path: String) -> Bool {
        files[path] != nil
    }

    /// Every path currently held, sorted.
    public var allPaths: [String] {
        files.keys.sorted()
    }

    /// The bytes at a path, or nil when there is no such file.
    public func contents(atPath path: String) -> [UInt8]? {
        files[path]
    }

    /// Writes bytes to a path and persists the filesystem.
    public func write(_ bytes: [UInt8], toPath path: String) {
        files[path] = bytes
        persist()
    }

    /// Removes a file, if it is there.
    public func removeFile(atPath path: String) {
        guard files.removeValue(forKey: path) != nil else {
            return
        }
        persist()
    }

    /// Mirrors the filesystem into `localStorage`.
    ///
    /// Bytes are stored as an array of integers rather than base64: it is
    /// bulkier, but it needs no encoder, and correctness matters more than size
    /// for documents a person typed by hand. A quota failure is swallowed —
    /// the in-memory copy is still good for this session, and there is nothing
    /// useful to tell the user mid-keystroke.
    private func persist() {
        guard let storage = localStorage(),
              let json = JSObject.global.JSON.object else {
            return
        }

        // Built as a JS object so `JSON.stringify` does the encoding, rather
        // than assembling the text by hand and having to escape paths.
        let payload = JSObject.global.Object.function!.new()
        for (path, bytes) in files {
            payload[path] = JSArray(bytes.map { JSValue.number(Double($0)) }).jsValue
        }

        guard let serialized = json.stringify?(JSValue.object(payload)).string else {
            return
        }
        _ = storage.setItem?(Self.storageKey, serialized)
    }

    /// Reads the filesystem back out of `localStorage`.
    private func restore() {
        guard let storage = localStorage(),
              let serialized = storage.getItem!(Self.storageKey).string,
              let parsed = JSObject.global.JSON.object!.parse!(serialized).object else {
            return
        }

        let keys = JSObject.global.Object.function!.keys!(JSValue.object(parsed))
        guard let list = keys.object, let count = list.length.number else {
            return
        }

        var restored: [String: [UInt8]] = [:]
        for index in 0..<Int(count) {
            guard let path = list[index].string,
                  let array = parsed[path].object,
                  let length = array.length.number else {
                continue
            }
            var bytes: [UInt8] = []
            bytes.reserveCapacity(Int(length))
            for byteIndex in 0..<Int(length) {
                bytes.append(UInt8(array[byteIndex].number ?? 0))
            }
            restored[path] = bytes
        }
        files = restored
    }

    /// The page's `localStorage`, when it has one.
    ///
    /// A private window, or a browser configured to block site data, has none —
    /// and reading it throws rather than returning null, which is why this is
    /// optional rather than assumed.
    private func localStorage() -> JSObject? {
        JSObject.global.localStorage.object
    }
}

/// A JavaScript array built from Swift values.
private struct JSArray {
    /// The underlying JS array.
    let jsValue: JSValue

    /// Creates a JS array holding the given values.
    init(_ values: [JSValue]) {
        let array = JSObject.global.Array.function!.new()
        for (index, value) in values.enumerated() {
            array[index] = value
        }
        jsValue = .object(array)
    }
}

extension WASMNativeControlBackend {
    /// Opens or saves a file the way a browser actually can.
    ///
    /// **Open** shows an `<input type=file>`. The choice arrives through an
    /// event, and a wasm call cannot block waiting for it, so the first call
    /// opens the picker and reports no selection; the file is delivered on the
    /// next call, once the user has chosen. `NSDocumentController` then opens it
    /// normally. The alternative — pretending to block — is not available in a
    /// single-threaded page.
    ///
    /// **Save** writes into the virtual filesystem straight away, so the
    /// document is really saved as far as the app is concerned, and *offers*
    /// the bytes as a download. Whether that reaches the user's disk is the
    /// browser's business.
    /// The browser's answer to `runFileDialog`, called from the class body.
    ///
    /// It has to be reached through a forwarding override rather than being one
    /// itself: Swift will not let a method declared in a superclass be
    /// overridden from an extension.
    internal func winRunBrowserFileDialog(_ options: NativeFileDialogOptions) -> [String]? {
        switch options.kind {
        case .open:
            return takePendingOpenSelection(options)
        case .save:
            return saveDestination(options)
        }
    }

    /// Returns a file the user already picked, or opens the picker and waits.
    private func takePendingOpenSelection(_ options: NativeFileDialogOptions) -> [String]? {
        if let ready = pendingOpenedFilePath {
            pendingOpenedFilePath = nil
            return [ready]
        }
        presentFilePicker()
        return nil
    }

    /// Shows the browser's file picker and stores whatever comes back.
    private func presentFilePicker() {
        guard let document = JSObject.global.document.object else {
            return
        }

        let input = document.createElement!("input")
        guard let element = input.object else {
            return
        }
        element.type = .string("file")
        element.style = .string("display:none")

        let handler = JSClosure { [weak self] _ in
            guard let self,
                  let files = element.files.object,
                  let first = files[0].object else {
                return .undefined
            }

            let name = first.name.string ?? "Untitled"
            // FileReader is asynchronous too, so the bytes land here later and
            // are parked for the next runFileDialog call.
            let reader = JSObject.global.FileReader.function!.new()
            let onLoad = JSClosure { _ in
                guard let buffer = reader.result.object else {
                    return .undefined
                }
                let bytes = JSObject.global.Uint8Array.function!.new(buffer)
                var contents: [UInt8] = []
                if let length = bytes.length.number {
                    contents.reserveCapacity(Int(length))
                    for index in 0..<Int(length) {
                        contents.append(UInt8(bytes[index].number ?? 0))
                    }
                }
                let path = "/\(name)"
                WASMVirtualFileSystem.shared.write(contents, toPath: path)
                self.pendingOpenedFilePath = path
                self.announceFileReady(named: name)
                return .undefined
            }
            reader.onload = .object(onLoad)
            _ = reader.readAsArrayBuffer!(JSValue.object(first))
            return .undefined
        }

        element.onchange = .object(handler)
        _ = document.body.object?.appendChild!(JSValue.object(element))
        _ = element.click!()
    }

    /// Tells the page a picked file is ready to open.
    ///
    /// The open is deferred by a turn of the browser's event loop, so without
    /// this the user picks a file and nothing visibly happens. Dispatching a
    /// DOM event lets the page's own script re-issue Open — and, failing that,
    /// leaves a trace in the console rather than silence.
    private func announceFileReady(named name: String) {
        guard let document = JSObject.global.document.object,
              let eventClass = JSObject.global.CustomEvent.function else {
            return
        }
        let detail = JSObject.global.Object.function!.new()
        detail.name = .string(name)
        let options = JSObject.global.Object.function!.new()
        options.detail = .object(detail)
        let event = eventClass.new("chocolate:documentPicked", options)
        _ = document.dispatchEvent?(JSValue.object(event))
    }

    /// Chooses where a save writes, and offers the bytes as a download.
    private func saveDestination(_ options: NativeFileDialogOptions) -> [String]? {
        let name = options.fileName.isEmpty ? "Untitled" : options.fileName
        let path = "/\(name)"
        // The download is offered after the document has written, so the bytes
        // exist to hand over — see `offerDownload(forPath:)`, which the window
        // chrome calls once the write lands.
        pendingDownloadPath = path
        return [path]
    }

    /// Offers a file in the virtual filesystem to the user as a download.
    ///
    /// Called after a write, because only then are there bytes to give.
    internal func offerDownload(forPath path: String) {
        guard let bytes = WASMVirtualFileSystem.shared.contents(atPath: path),
              let document = JSObject.global.document.object,
              let blobClass = JSObject.global.Blob.function,
              let urlClass = JSObject.global.URL.function else {
            return
        }

        let array = JSObject.global.Uint8Array.function!.new(bytes.count)
        for (index, byte) in bytes.enumerated() {
            array[index] = .number(Double(byte))
        }
        let parts = JSObject.global.Array.function!.new()
        parts[0] = .object(array)

        let blob = blobClass.new(parts)
        guard let objectURL = urlClass.createObjectURL?(JSValue.object(blob)).string else {
            return
        }

        let anchor = document.createElement!("a")
        guard let element = anchor.object else {
            return
        }
        element.href = .string(objectURL)
        element.download = .string(String(path.dropFirst()))
        element.style = .string("display:none")
        _ = document.body.object?.appendChild!(JSValue.object(element))
        _ = element.click!()
        _ = document.body.object?.removeChild!(JSValue.object(element))
        _ = urlClass.revokeObjectURL?(JSValue.string(objectURL))
    }

    /// Reflects a window's document state in the synthesized title bar.
    ///
    /// A browser tab has no close-button dot and no OS title bar, so the
    /// asterisk convention is used here as it is on Windows and GTK — applied
    /// to the title element the backend draws itself.
    /// The browser's answer to `setWindowDocumentEdited`, called from the class
    /// body for the same reason as the file dialog above.
    internal func winApplyBrowserDocumentChrome(_ handle: NativeHandle,
                                                edited: Bool,
                                                representedPath: String?) {
        guard let label = windowTitleLabels[handle] else {
            return
        }
        let current = label.textContent ?? ""
        let bare = current.hasPrefix("*") ? String(current.dropFirst()) : current
        label.textContent = edited ? "*\(bare)" : bare

        // A save just happened if the document went clean while a download was
        // waiting on a path — this is the moment the bytes exist.
        if !edited, let path = pendingDownloadPath {
            pendingDownloadPath = nil
            offerDownload(forPath: path)
        }
    }
}

#endif
