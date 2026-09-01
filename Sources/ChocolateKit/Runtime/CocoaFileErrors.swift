// The Cocoa error domain and file-error codes the document architecture
// reports, as the core's own internal constants.
//
// Why the core carries its own rather than reading Foundation's: the four
// Foundations underneath this module do not agree about these names. Real
// Foundation on macOS exports `NSFileReadNoSuchFileError` as a global; the
// wasm SDK's Foundation and swift-corelibs do not export the same set;
// WinFoundation declares its own. Referring to any of them from shared code
// would need a platform conditional at every call site — a fifth conditional
// the framework does not want (see Runtime/FoundationBridge.swift for the four
// that are sanctioned).
//
// The numbers are not a convention we invented. They are Apple's, measured on
// the macOS 26.4 SDK by `Tools/DocumentGroundTruthProbe.swift` and recorded in
// `Docs/NSDOCUMENT_PLAN.md` § Ground Truth. A document that fails to open must
// report the same domain and code on Windows, Linux, and in a browser as it
// does on a Mac, because application code branches on them.

/// Cocoa's error domain and the file-error codes AppKit reports through it.
///
/// Internal: applications spell these Foundation's way. This is the core's
/// single source for building the errors it hands back.
internal enum CocoaFileError {
    /// The domain every error below belongs to.
    static let domain = "NSCocoaErrorDomain"

    // MARK: Read

    /// A file could not be read for an unidentified reason.
    static let readUnknown = 256

    /// A file could not be read because permission was denied.
    static let readNoPermission = 257

    /// A file could not be read because its name is invalid.
    static let readInvalidFileName = 258

    /// A file could not be read because its contents are corrupt.
    static let readCorruptFile = 259

    /// A file could not be read because it does not exist.
    static let readNoSuchFile = 260

    // MARK: Write

    /// A file could not be written for an unidentified reason.
    static let writeUnknown = 512

    /// A file could not be written because permission was denied.
    static let writeNoPermission = 513

    /// A file could not be written because its name is invalid.
    static let writeInvalidFileName = 514

    /// A file could not be written because one already exists there.
    static let writeFileExists = 516

    /// A file could not be written because the volume is out of space.
    static let writeOutOfSpace = 640

    /// A file could not be written because the volume is read only.
    static let writeVolumeReadOnly = 642

    // MARK: Other

    /// The user cancelled the operation — what a dismissed save panel reports.
    static let userCancelled = 3072

    /// The operation is not supported on this platform or configuration.
    static let featureUnsupported = 3328

    /// Builds a Cocoa-domain file error carrying the item it concerns.
    ///
    /// The sentences follow Apple's, because applications surface them
    /// verbatim through `NSAlert(error:)` — a document that cannot be opened
    /// should read the same way on every backend.
    ///
    /// - Parameters:
    ///   - code: One of the codes above.
    ///   - url: The file the operation concerned.
    ///   - reason: An optional sentence used as the error's failure reason.
    /// - Returns: An `NSError` in `NSCocoaErrorDomain`.
    static func error(_ code: Int, url: URL, reason: String? = nil) -> NSError {
        var info: [String: Any] = [
            "NSFilePath": url.path,
            "NSURL": url,
            NSLocalizedDescriptionKey: describe(code, name: url.lastPathComponent)
        ]
        if let reason {
            info[NSLocalizedFailureReasonErrorKey] = reason
        }
        return NSError(domain: domain, code: code, userInfo: info)
    }

    /// The sentence Apple shows for a file error code.
    private static func describe(_ code: Int, name: String) -> String {
        switch code {
        case readNoSuchFile:
            return "The file “\(name)” couldn’t be opened because there is no such file."
        case readNoPermission:
            return "The file “\(name)” couldn’t be opened because you don’t have permission to view it."
        case readCorruptFile:
            return "The file “\(name)” couldn’t be opened because it isn’t in the correct format."
        case readInvalidFileName:
            return "The file “\(name)” couldn’t be opened because its name is invalid."
        case readUnknown:
            return "The file “\(name)” couldn’t be opened."
        case writeNoPermission:
            return "The file “\(name)” couldn’t be saved because you don’t have permission."
        case writeInvalidFileName:
            return "The file “\(name)” couldn’t be saved because its name is invalid."
        case writeFileExists:
            return "The file “\(name)” couldn’t be saved because a file with that name already exists."
        case writeOutOfSpace:
            return "The file “\(name)” couldn’t be saved because the volume is out of space."
        case writeVolumeReadOnly:
            return "The file “\(name)” couldn’t be saved because the volume is read only."
        case featureUnsupported:
            return "The operation on “\(name)” isn’t supported on this platform."
        default:
            return "The file “\(name)” couldn’t be saved."
        }
    }
}
