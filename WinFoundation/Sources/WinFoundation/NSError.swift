/// User-info dictionary key for an error's primary description.
public let NSLocalizedDescriptionKey = "NSLocalizedDescription"

/// User-info dictionary key for an error's failure reason.
public let NSLocalizedFailureReasonErrorKey = "NSLocalizedFailureReason"

/// User-info dictionary key for an error's recovery suggestion.
public let NSLocalizedRecoverySuggestionErrorKey = "NSLocalizedRecoverySuggestion"

/// A domain/code/user-info error value, matching Foundation's `NSError`.
///
/// Real Foundation cannot build on the ARM64 Windows toolchain, so WinFoundation
/// provides a self-contained `NSError` that conforms to Swift's `Error`. It
/// carries the common localized strings from its `userInfo`, which is enough for
/// AppKit patterns such as `NSAlert(error:)` and `FileManager` error reporting.
open class NSError: Error, CustomStringConvertible, @unchecked Sendable {
    /// The error domain.
    public let domain: String

    /// The error code, unique within the domain.
    public let code: Int

    /// Supplementary information, keyed by the `NSLocalized*` constants.
    public let userInfo: [String: Any]

    /// Creates an error with a domain, code, and optional user info.
    public init(domain: String, code: Int, userInfo: [String: Any]? = nil) {
        self.domain = domain
        self.code = code
        self.userInfo = userInfo ?? [:]
    }

    /// A human-readable description of the error.
    open var localizedDescription: String {
        if let description = userInfo[NSLocalizedDescriptionKey] as? String, !description.isEmpty {
            return description
        }
        return "The operation couldn’t be completed. (\(domain) error \(code).)"
    }

    /// A description of the reason for the failure, when supplied.
    open var localizedFailureReason: String? {
        userInfo[NSLocalizedFailureReasonErrorKey] as? String
    }

    /// A suggestion for recovering from the failure, when supplied.
    open var localizedRecoverySuggestion: String? {
        userInfo[NSLocalizedRecoverySuggestionErrorKey] as? String
    }

    public var description: String {
        "Error Domain=\(domain) Code=\(code) \"\(localizedDescription)\""
    }
}

/// A specialized error that provides localized messages describing the error and
/// how to recover, matching Foundation's `LocalizedError`.
public protocol LocalizedError: Error {
    /// A localized message describing what error occurred.
    var errorDescription: String? { get }

    /// A localized message describing the reason for the failure.
    var failureReason: String? { get }

    /// A localized message describing how to recover from the failure.
    var recoverySuggestion: String? { get }

    /// A localized message providing help-anchor context.
    var helpAnchor: String? { get }
}

extension LocalizedError {
    public var errorDescription: String? { nil }
    public var failureReason: String? { nil }
    public var recoverySuggestion: String? { nil }
    public var helpAnchor: String? { nil }
}
