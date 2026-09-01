// Cocoa's error domain and the file-error codes AppKit's document architecture
// reports through it.
//
// Real Foundation supplies these everywhere else; on Windows this file is the
// only source of them, so the values below are not a convention we invented —
// they are Apple's, measured from the macOS 26.4 SDK by
// `Tools/DocumentGroundTruthProbe.swift` and recorded in
// `Docs/NSDOCUMENT_PLAN.md` § Ground Truth. A document that fails to open must
// report the same domain and code on Windows as it does on a Mac, because
// application code branches on them.
//
// Constants only, deliberately. A convenience for *building* these errors would
// be surface Foundation does not have, and WinFoundation's job is to be the
// Foundation that is missing — not a better one. The core builds its document
// errors through its own internal factory instead
// (`Sources/ChocolateKit/Runtime/CocoaFileErrors.swift`).

/// The error domain Cocoa uses for Foundation and AppKit failures.
public let NSCocoaErrorDomain = "NSCocoaErrorDomain"

// MARK: - User-info keys

/// User-info dictionary key for an error nested inside another.
public let NSUnderlyingErrorKey = "NSUnderlyingError"

/// User-info dictionary key for the file path an error concerns.
public let NSFilePathErrorKey = "NSFilePath"

/// User-info dictionary key for the URL an error concerns.
public let NSURLErrorKey = "NSURL"

// MARK: - Read errors

/// A file could not be read for an unidentified reason.
public let NSFileReadUnknownError = 256

/// A file could not be read because permission was denied.
public let NSFileReadNoPermissionError = 257

/// A file could not be read because its name is invalid.
public let NSFileReadInvalidFileNameError = 258

/// A file could not be read because its contents are corrupt.
public let NSFileReadCorruptFileError = 259

/// A file could not be read because it does not exist.
public let NSFileReadNoSuchFileError = 260

/// A file could not be read because it is in an unsupported format.
public let NSFileReadUnsupportedSchemeError = 262

/// A file could not be read because it is too large.
public let NSFileReadTooLargeError = 263

/// A file could not be read because its text encoding could not be determined.
public let NSFileReadUnknownStringEncodingError = 264

// MARK: - Write errors

/// A file could not be written for an unidentified reason.
public let NSFileWriteUnknownError = 512

/// A file could not be written because permission was denied.
public let NSFileWriteNoPermissionError = 513

/// A file could not be written because its name is invalid.
public let NSFileWriteInvalidFileNameError = 514

/// A file could not be written because one already exists at the destination.
public let NSFileWriteFileExistsError = 516

/// A file could not be written because its text encoding is unsupported.
public let NSFileWriteInapplicableStringEncodingError = 517

/// A file could not be written because the volume is out of space.
public let NSFileWriteOutOfSpaceError = 640

/// A file could not be written because the volume is read only.
public let NSFileWriteVolumeReadOnlyError = 642

// MARK: - Other

/// No error occurred.
public let NSFileNoSuchFileError = 4

/// The user cancelled the operation.
public let NSUserCancelledError = 3072

/// A feature is unsupported on this platform or configuration.
public let NSFeatureUnsupportedError = 3328
