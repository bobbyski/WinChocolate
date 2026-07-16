import WinFoundation

#if os(Windows)
@_silgen_name("GetEnvironmentVariableW")
private func WinDiagGetEnvironmentVariableW(
    _ name: UnsafePointer<UInt16>?,
    _ buffer: UnsafeMutablePointer<UInt16>?,
    _ size: UInt32
) -> UInt32
#endif

/// Opt-in framework diagnostics: set `WINCHOCOLATE_DIAG` to a file path and
/// instrumented framework paths append one line per event. Costs nothing when
/// the variable is unset. Framework-internal — never part of the AppKit
/// surface; exists so interactive event chains (clicks → panels → actions)
/// can be verified on the real backend from a script.
enum WinDiagnostics {
    nonisolated(unsafe) private static let path: String? = {
        #if os(Windows)
        let name = Array("WINCHOCOLATE_DIAG".utf16) + [0]
        var buffer = [UInt16](repeating: 0, count: 1024)
        let length = name.withUnsafeBufferPointer { namePointer in
            buffer.withUnsafeMutableBufferPointer { bufferPointer in
                WinDiagGetEnvironmentVariableW(namePointer.baseAddress, bufferPointer.baseAddress, 1024)
            }
        }
        guard length > 0, length < 1024 else {
            return nil
        }
        return String(decoding: buffer[0..<Int(length)], as: UTF16.self)
        #else
        return nil
        #endif
    }()

    nonisolated(unsafe) private static var lines: [String] = []

    static var isEnabled: Bool {
        path != nil
    }

    /// Appends one line to the diagnostics file (rewritten per event; the log
    /// is tiny and this keeps the writer dependency-free).
    static func log(_ message: @autoclosure () -> String) {
        guard let path else {
            return
        }

        lines.append(message())
        try? (lines.joined(separator: "\n") + "\n")
            .write(to: URL(fileURLWithPath: path), atomically: false, encoding: .utf8)
    }
}
