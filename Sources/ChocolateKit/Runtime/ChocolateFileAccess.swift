// The seam every document read and write goes through.
//
// ---------------------------------------------------------------------------
// Why this exists.
//
// `NSDocument` is written in terms of URLs, and on Windows, Linux and macOS the
// obvious implementation is the right one: ask `FileManager`, call
// `Data(contentsOf:)`, call `Data.write(to:)`.
//
// A browser tab has no filesystem at all. Those calls compile under WASI and
// then fail at runtime, which is why `Docs/WASM_CHOCOLATE_PLAN.md` recorded
// document round-trips as "windows open, saving no-ops".
//
// The seam is deliberately NOT a platform switch. `os(WASI)` is the wrong
// question: the same wasm binary has a real filesystem under Node (the contract
// suite runs there, with a preopened directory) and none in a browser. Asking
// the platform would break the headless case to fix the browser one.
//
// So the rule is capability, not platform: **use the real filesystem, unless
// something has installed a substitute.** The browser backend installs one
// because it genuinely has nowhere else to go; everything else, including a
// headless wasm test run, keeps using the disk it actually has.
// ---------------------------------------------------------------------------

/// A stand-in filesystem, for a platform that has none.
///
/// Deliberately tiny — exists, read, write, remove, list — because that is all
/// `FileWrapper` and `NSDocument` need. Anything larger would be a second
/// `FileManager`, and platforms with a real one should keep using it.
///
/// `package` rather than `public`: this is framework plumbing a backend
/// installs, not API an application writes against — but the contract suite is
/// a separate module in the same package and has to be able to install one.
package protocol ChocolateFileStore: AnyObject {
    /// Whether a file exists at a path.
    func fileExists(atPath path: String) -> Bool

    /// The bytes at a path, or nil when there is no such file.
    func contents(atPath path: String) -> [UInt8]?

    /// Writes bytes to a path.
    func write(_ bytes: [UInt8], toPath path: String)

    /// Removes a file, if it is there.
    func removeFile(atPath path: String)

    /// Every stored path, sorted.
    var allPaths: [String] { get }
}

/// Where the framework's document reads and writes actually go.
package enum ChocolateFileAccess {
    /// The stand-in filesystem, when a backend has installed one.
    ///
    /// Nil everywhere with a real filesystem, which is everywhere but a
    /// browser tab.
    nonisolated(unsafe) package static var substitute: (any ChocolateFileStore)?

    /// Whether a file exists.
    package static func fileExists(atPath path: String) -> Bool {
        if let substitute {
            return substitute.fileExists(atPath: path)
        }
        return FileManager.default.fileExists(atPath: path)
    }

    /// Reads a file's bytes, or nil when it cannot be read.
    package static func contents(atPath path: String) -> [UInt8]? {
        if let substitute {
            return substitute.contents(atPath: path)
        }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }
        return [UInt8](data)
    }

    /// Writes a file's bytes.
    package static func write(_ bytes: [UInt8], toPath path: String) {
        if let substitute {
            substitute.write(bytes, toPath: path)
            return
        }
        try? Data(bytes).write(to: URL(fileURLWithPath: path))
    }

    /// Removes a file, if it is there.
    package static func removeFile(atPath path: String) {
        if let substitute {
            substitute.removeFile(atPath: path)
            return
        }
        try? FileManager.default.removeItem(atPath: path)
    }

    /// Every stored path, when a substitute is installed.
    ///
    /// Empty with a real filesystem: enumerating a whole disk is not something
    /// this seam is for, and nothing asks it to.
    package static var allPaths: [String] {
        substitute?.allPaths ?? []
    }

    /// Whether reads and writes are going somewhere other than a real disk.
    ///
    /// Callers use this to skip filesystem-only ceremony — atomic staging has
    /// nothing to protect against in a dictionary.
    package static var usesSubstitute: Bool {
        substitute != nil
    }
}
