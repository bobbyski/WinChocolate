// The Foundation seam — conditional C1 of the four sanctioned platform switches
// (see Docs/UnifiedChocolatePlan.md §"The four sanctioned conditionals").
//
// The shared AppKit core is written against one Foundation surface; only the
// implementation supplying it varies:
//
//   Windows  →  WinFoundation, because this Swift toolchain cannot compile real
//               `import Foundation` (see FOUNDATION_SHIMS.md and the toolchain
//               canary in NEEDS_HUMAN.md).
//   Linux    →  real corelibs-foundation, which is present and preferred.
//   macOS    →  real Foundation (the cross-check build).
//
// `USE_WIN_FOUNDATION` is defined by the manifest with
// `.when(platforms: [.windows])`, so this resolves without an `os()` test.
//
// Everything downstream — every control, view, and window in the core — sees the
// same spellings (`Date`, `URL`, `Data`, `Timer`, `NSRect`, …). Where the two
// implementations genuinely differ in behavior, the fix belongs in WinFoundation
// (the deliberately-compatible one), NOT in a second conditional up here. That
// reconciliation is the Foundation parity ledger, Phase 2 of the plan.

#if USE_WIN_FOUNDATION
@_exported import WinFoundation
#else
@_exported import Foundation

/// The platform message pump a run loop drives.
///
/// WinFoundation declares this next to its own `RunLoop`, because on Windows
/// the run loop and the pump are one mechanism: `RunLoop.run` blocks in
/// `MsgWaitForMultipleObjects` and the Win32 backend supplies the conformance.
/// Real Foundation has no such seam — on Linux the GLib main loop owns the
/// dispatching — so the bridge declares the type here to keep the core's one
/// Foundation surface complete. `NativeControlBackend.makeRunLoopPump()`
/// returns nil on every backend that doesn't drive its own loop.
public protocol RunLoopPlatformPump: AnyObject {
    /// Blocks until a native event arrives or `limit` passes (nil = no timer
    /// pending, wait indefinitely for input), servicing platform messages
    /// before returning. Returns `false` when the platform has asked the loop
    /// to stop (Windows `WM_QUIT`), so `run` can exit.
    func waitForEvents(until limit: Date?) -> Bool
    /// Wakes a blocked `waitForEvents` early — e.g. when a timer or `perform`
    /// block is added from elsewhere.
    func wake()
}

// MARK: - Surface real Foundation doesn't carry
//
// WinFoundation is not merely a subset of Foundation — it grew a handful of
// members the core relies on that corelibs-foundation has no equivalent for.
// Levelling them here is what keeps the core itself free of a second
// conditional: every control above this line sees one Foundation, whichever
// implementation is underneath.

/// Identity and description, matching the slice of `NSObjectProtocol` the
/// framework's delegate protocols actually refine.
///
/// The core already brings its own Swift-native `NSObject` (Runtime/NSObject.swift),
/// which shadows Foundation's inside this module — there is no Objective-C
/// runtime to inherit from on Windows, and on Linux the GTK backend doesn't
/// want one. The root class and its protocol have to shadow *together*:
/// Foundation's `NSObjectProtocol` is the Objective-C runtime's protocol, and
/// demands `self()`, `isProxy()`, `superclass`, `isKind(of:)` and a
/// `perform(_:)` returning `Unmanaged<AnyObject>!`. Answering those on a
/// Swift-native root would mean inventing Objective-C semantics that aren't
/// there. WinFoundation declares exactly these three members, so this is the
/// same protocol the Windows build compiles against.
public protocol NSObjectProtocol: AnyObject {
    /// Identity/equality, matching `NSObjectProtocol.isEqual(_:)`.
    func isEqual(_ object: Any?) -> Bool

    /// The object's hash, matching `NSObjectProtocol.hash`.
    var hash: Int { get }

    /// A textual description, matching `NSObjectProtocol.description`.
    var description: String { get }
}

extension Data {
    /// The bytes as an array (WinFoundation's `Data.array`).
    public var array: [UInt8] { [UInt8](self) }
}

extension NSString: NSPasteboardWriting {
    /// `NSString` writes the string flavor, as on Apple.
    ///
    /// `Application/NSPasteboard.swift` conforms `String` and notes that
    /// `NSString` is a typealias for it — true under WinFoundation, but real
    /// Foundation's `NSString` is a separate class, so the demo's
    /// `"…" as NSString` needs its own conformance here.
    public func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        [.string]
    }

    /// The string itself.
    public func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        self as String
    }
}

extension IndexPath {
    /// Creates a two-element path addressing `item` within `section`.
    ///
    /// On Apple platforms this pair ships with Foundation; corelibs-foundation
    /// has only the general `indexes` form, so the collection-view code —
    /// which is written against Apple's spelling — needs it supplied here.
    public init(item: Int, section: Int) {
        self.init(indexes: [section, item])
    }

    /// The second index — the item within its section.
    public var item: Int { self[1] }

    /// The first index — the section.
    public var section: Int { self[0] }
}

extension Locale {
    /// The locale's short date pattern (for example `M/d/yy`).
    ///
    /// WinFoundation reads these three from the Windows locale tables; here
    /// they come from the same ICU data the rest of Foundation uses, so the
    /// pattern syntax matches the `DateFormatter` that will consume it on this
    /// platform (Unicode `a` for the meridiem, where Windows writes `tt`).
    public var shortDatePattern: String {
        Self.pattern(for: self, date: .short, time: .none) ?? "M/d/yyyy"
    }

    /// The locale's time pattern including seconds (for example `h:mm:ss a`).
    public var timePattern: String {
        Self.pattern(for: self, date: .none, time: .medium) ?? "h:mm:ss a"
    }

    /// The locale's time pattern without seconds (for example `h:mm a`).
    ///
    /// The locale owns which fields a short time drops; deriving it by cutting
    /// `:ss` out of `timePattern` would only guess at the separator.
    public var shortTimePattern: String {
        Self.pattern(for: self, date: .none, time: .short) ?? "h:mm a"
    }

    private static func pattern(for locale: Locale,
                                date: DateFormatter.Style,
                                time: DateFormatter.Style) -> String? {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = date
        formatter.timeStyle = time
        let pattern = formatter.dateFormat
        return (pattern?.isEmpty ?? true) ? nil : pattern
    }
}

extension RunLoop {
    /// Installs the platform message pump.
    ///
    /// Real Foundation's run loop has no pump seam — on Linux the GLib main
    /// loop does the dispatching and `NSApplication.run` takes the
    /// `runApplication()` path instead. Reaching here means a backend returned
    /// a pump from `makeRunLoopPump()` that this run loop cannot drive, which
    /// would silently cost the app every timer and `perform` block. Fail
    /// loudly rather than accept-and-ignore it.
    public func installPlatformPump(_ pump: RunLoopPlatformPump) {
        preconditionFailure(
            "\(type(of: pump)) cannot drive this RunLoop: real Foundation has no "
            + "platform-pump seam. A backend that owns its own event loop must "
            + "return nil from makeRunLoopPump() and implement runApplication().")
    }
}
#endif


// AppKit defines two run-loop modes Foundation does not: the mode a drag or a
// menu tracks in, and the mode a modal panel runs in. Off Apple, Foundation
// supplies `RunLoop.Mode` and AppKit supplies nothing, so the framework adds
// the two names its own API takes — under AppKit's spellings, because the whole
// point is that one source compiles against either.
//
// WASI is excluded because there `RunLoop` is the framework's own shim
// (`WASIFoundationShims.swift`), which declares these modes itself.
#if !os(WASI) && !USE_WIN_FOUNDATION
extension RunLoop.Mode {
    /// The mode AppKit runs in while tracking a drag or a menu.
    public static let eventTracking = RunLoop.Mode("NSEventTrackingRunLoopMode")

    /// The mode AppKit runs in while a modal panel is up.
    public static let modalPanel = RunLoop.Mode("NSModalPanelRunLoopMode")
}
#endif
