/// A Foundation-compatible subset of `ProcessInfo`.
///
/// This slice covers process identity — the executable-derived process name
/// and the raw argument list — which application chrome (window titles,
/// "Quit <name>" menu items) reads at startup, plus the process environment,
/// which backend selection reads (`CHOCOLATE_BACKEND`).
public final class ProcessInfo: @unchecked Sendable {
    /// The shared process information object.
    public static let processInfo = ProcessInfo()

    /// The command-line arguments, matching Foundation's shape.
    public var arguments: [String] {
        CommandLine.arguments
    }

    /// The process environment, matching Foundation's shape.
    ///
    /// Read from `GetEnvironmentStringsW`, which hands back one block of
    /// double-null-terminated UTF-16 `NAME=VALUE` pairs. The block must be
    /// released with `FreeEnvironmentStringsW`, so it is copied out eagerly
    /// rather than kept.
    public var environment: [String: String] {
        guard let block = WinFoundationGetEnvironmentStringsW() else { return [:] }
        defer { _ = WinFoundationFreeEnvironmentStringsW(block) }

        var variables: [String: String] = [:]
        var cursor = block
        while cursor.pointee != 0 {
            var length = 0
            while cursor[length] != 0 { length += 1 }
            let entry = String(decoding: UnsafeBufferPointer(start: cursor, count: length),
                               as: UTF16.self)
            // Entries whose name is empty are the shell's per-drive working
            // directories (`=C:`), not real variables. Foundation omits them.
            if let separator = entry.firstIndex(of: "="), separator != entry.startIndex {
                variables[String(entry[entry.startIndex..<separator])] =
                    String(entry[entry.index(after: separator)...])
            }
            cursor += length + 1
        }
        return variables
    }

    /// The process name, derived from the executable filename without its
    /// directory or `.exe` suffix.
    public var processName: String {
        guard let executable = arguments.first, !executable.isEmpty else {
            return ""
        }
        let filename = executable
            .split(whereSeparator: { $0 == "\\" || $0 == "/" })
            .last.map(String.init) ?? executable
        if filename.lowercased().hasSuffix(".exe") {
            return String(filename.dropLast(4))
        }
        return filename
    }
}

@_silgen_name("GetEnvironmentStringsW")
private func WinFoundationGetEnvironmentStringsW() -> UnsafeMutablePointer<UInt16>?

@_silgen_name("FreeEnvironmentStringsW")
private func WinFoundationFreeEnvironmentStringsW(_ block: UnsafeMutablePointer<UInt16>?) -> Int32

@_silgen_name("ExitProcess")
private func WinFoundationExitProcess(_ uExitCode: UInt32) -> Never

/// Terminates the process with a status code, matching the C library's
/// `exit` that Foundation re-exports on other platforms.
public func exit(_ status: Int32) -> Never {
    WinFoundationExitProcess(UInt32(bitPattern: status))
}
