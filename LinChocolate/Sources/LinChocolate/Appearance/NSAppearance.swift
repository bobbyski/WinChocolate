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
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let aqua = Name(rawValue: "NSAppearanceNameAqua")
        public static let darkAqua = Name(rawValue: "NSAppearanceNameDarkAqua")
        public static let vibrantLight = Name(rawValue: "NSAppearanceNameVibrantLight")
        public static let vibrantDark = Name(rawValue: "NSAppearanceNameVibrantDark")
    }

    public let name: Name

    public init(named name: Name) {
        self.name = name
    }

    /// Whether this appearance is one of the dark variants.
    public var isDark: Bool {
        name == .darkAqua || name == .vibrantDark
    }

    public static let aqua = NSAppearance(named: .aqua)
    public static let darkAqua = NSAppearance(named: .darkAqua)

    public static func == (lhs: NSAppearance, rhs: NSAppearance) -> Bool {
        lhs.name == rhs.name
    }
}
