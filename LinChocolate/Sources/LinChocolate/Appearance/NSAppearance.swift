import Foundation

/// AppKit-shaped appearance (light / dark). Assign one to `NSApp.appearance`
/// to switch the whole app between Aqua and Dark Aqua; every native control
/// re-themes at once through GTK's theme system.
///
/// Per-view appearance overrides are a later parity item — appearance is
/// application-scoped here because GTK's dark-theme preference is display-wide.
public final class NSAppearance: Equatable, Sendable {

    /// The named appearances LinChocolate maps onto GTK's light/dark themes.
    public struct Name: RawRepresentable, Equatable, Sendable {
        /// The AppKit-style raw name (e.g. `"NSAppearanceNameAqua"`).
        public let rawValue: String
        /// Wraps an arbitrary raw name; unrecognised values are treated as light.
        public init(rawValue: String) { self.rawValue = rawValue }
        /// The standard light appearance.
        public static let aqua = Name(rawValue: "NSAppearanceNameAqua")
        /// The standard dark appearance.
        public static let darkAqua = Name(rawValue: "NSAppearanceNameDarkAqua")
        /// The vibrant light variant (mapped onto the same GTK light theme as `aqua`).
        public static let vibrantLight = Name(rawValue: "NSAppearanceNameVibrantLight")
        /// The vibrant dark variant (mapped onto the same GTK dark theme as `darkAqua`).
        public static let vibrantDark = Name(rawValue: "NSAppearanceNameVibrantDark")
    }

    /// The appearance's canonical name.
    public let name: Name

    /// Creates an appearance for the given named theme.
    public init(named name: Name) {
        self.name = name
    }

    /// Whether this appearance is one of the dark variants.
    public var isDark: Bool {
        name == .darkAqua || name == .vibrantDark
    }

    /// Shared instance of the light appearance.
    public static let aqua = NSAppearance(named: .aqua)
    /// Shared instance of the dark appearance.
    public static let darkAqua = NSAppearance(named: .darkAqua)

    /// The best-matching name among `appearances` (AppKit's matching hook —
    /// the demo's standard `bestMatch(from: [.aqua, .darkAqua])` idiom).
    /// Dark appearances match the dark names first, light ones the light.
    public func bestMatch(from appearances: [Name]) -> Name? {
        if appearances.contains(name) {
            return name
        }
        if isDark {
            return appearances.first { Self(named: $0).isDark } ?? appearances.first
        }
        return appearances.first { !Self(named: $0).isDark } ?? appearances.first
    }

    /// The appearance active for the drawing pass currently underway
    /// (AppKit's `currentDrawing()`). LinChocolate's appearance is
    /// application-scoped, so this resolves to the app's effective appearance.
    public static func currentDrawing() -> NSAppearance {
        NSApplication.shared.effectiveAppearance
    }

    /// Two appearances are equal when they share the same `name`.
    public static func == (lhs: NSAppearance, rhs: NSAppearance) -> Bool {
        lhs.name == rhs.name
    }
}
