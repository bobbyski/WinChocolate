/// A Foundation-compatible subset of `ProcessInfo`.
///
/// This slice covers process identity — the executable-derived process name
/// and the raw argument list — which application chrome (window titles,
/// "Quit <name>" menu items) reads at startup.
public final class ProcessInfo: @unchecked Sendable {
    /// The shared process information object.
    public static let processInfo = ProcessInfo()

    /// The command-line arguments, matching Foundation's shape.
    public var arguments: [String] {
        CommandLine.arguments
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

@_silgen_name("ExitProcess")
private func WinFoundationExitProcess(_ uExitCode: UInt32) -> Never

/// Terminates the process with a status code, matching the C library's
/// `exit` that Foundation re-exports on other platforms.
public func exit(_ status: Int32) -> Never {
    WinFoundationExitProcess(UInt32(bitPattern: status))
}
