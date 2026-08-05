/// A named appearance (AppKit's light/dark theme descriptor).
///
/// WinChocolate maps AppKit's appearance model onto Windows themes: `.aqua`
/// is the light theme and `.darkAqua` the Windows dark theme. The *effective*
/// appearance resolves through the AppKit inheritance chain — view → window →
/// application → system — where the system leg asks the backend whether
/// Windows "dark mode for applications" is on.
///
/// This is the 8.5 API scaffold: names, resolution, and inheritance are real
/// and contract-tested; rendering the dark palette through the controls is the
/// remainder of Phase 8.5.
public final class NSAppearance: Sendable {
    /// The name of a standard appearance.
    public struct Name: Hashable, RawRepresentable, Sendable {
        public let rawValue: String
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }

        /// The standard light system appearance.
        public static let aqua = Name("NSAppearanceNameAqua")

        /// The standard dark system appearance.
        public static let darkAqua = Name("NSAppearanceNameDarkAqua")
    }

    /// The appearance's name.
    public let name: Name

    /// Returns the standard appearance with the given name, or `nil` for a
    /// name the framework does not provide.
    public init?(named name: Name) {
        guard name == .aqua || name == .darkAqua else {
            return nil
        }
        self.name = name
    }

    private init(_ name: Name) {
        self.name = name
    }

    /// The shared standard appearances (AppKit vends one object per name).
    static let aqua = NSAppearance(.aqua)
    static let darkAqua = NSAppearance(.darkAqua)

    /// Returns the appearance object for a standard name.
    static func standard(_ name: Name) -> NSAppearance {
        name == .darkAqua ? .darkAqua : .aqua
    }

    /// Returns the name in `appearances` that best matches this appearance:
    /// an exact match, else the light base (dark falls back to light, as in
    /// AppKit), else `nil` when nothing fits.
    public func bestMatch(from appearances: [Name]) -> Name? {
        if appearances.contains(name) {
            return name
        }
        return appearances.contains(.aqua) ? .aqua : nil
    }

    /// Whether this appearance is a dark theme. Not API (18.8): application
    /// code uses AppKit's `bestMatch(from: [.aqua, .darkAqua]) == .darkAqua`.
    package var winIsDark: Bool {
        name == .darkAqua
    }

    /// The appearance in effect for the current draw pass.
    nonisolated(unsafe) private static var winCurrentDrawing: NSAppearance?

    /// Returns the appearance active for the drawing code currently running:
    /// inside `draw(_:)` this is the view's effective appearance; elsewhere it
    /// falls back to the application's.
    public static func currentDrawing() -> NSAppearance {
        winCurrentDrawing ?? NSApplication.shared.effectiveAppearance
    }

    /// Runs `body` with `appearance` as the current-drawing appearance,
    /// restoring the previous one afterward (draw passes can nest when a
    /// hosted child paints during its parent's pass).
    static func winWithCurrentDrawing(_ appearance: NSAppearance, _ body: () -> Void) {
        let previous = winCurrentDrawing
        winCurrentDrawing = appearance
        defer { winCurrentDrawing = previous }
        body()
    }
}

// MARK: - Effective-appearance inheritance (view → window → app → system)

extension NSApplication {
    /// The application's appearance override; `nil` follows the system theme.
    public var appearance: NSAppearance? {
        get { winAppearanceOverride }
        set { winAppearanceOverride = newValue }
    }

    /// The appearance the application resolves to: the override when set,
    /// otherwise the system theme (the backend's dark-mode preference).
    public var effectiveAppearance: NSAppearance {
        if let winAppearanceOverride {
            return winAppearanceOverride
        }
        return NSAppearance.standard(nativeBackend.systemPrefersDarkAppearance() ? .darkAqua : .aqua)
    }
}

extension NSWindow {
    /// The appearance the window resolves to: its own override when set,
    /// otherwise the application's effective appearance.
    public var effectiveAppearance: NSAppearance {
        appearance ?? NSApplication.shared.effectiveAppearance
    }
}

extension NSView {
    /// The appearance the view resolves to, following AppKit's inheritance:
    /// the view's own override, else the nearest ancestor's, else the
    /// window's, else the application's.
    public var effectiveAppearance: NSAppearance {
        appearance
            ?? superview?.effectiveAppearance
            ?? window?.effectiveAppearance
            ?? NSApplication.shared.effectiveAppearance
    }
}
