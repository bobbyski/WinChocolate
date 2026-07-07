/// Selects the Windows presentation style for native controls (plan 8.2).
///
/// The appearance strategy (plan 8.1) is a hybrid: the **modern** presentation
/// binds ComCtl32 **v6** for the process via a runtime activation context, so
/// every native control renders with the current Windows visual styles
/// (Windows 11 theming); **classic** leaves the process on unthemed v5 — the
/// original 3D look. Framework-drawn surfaces (tables, indicators, toolbar
/// looks) render identically under both, and Fluent-specific accents (plan
/// 8.3) layer on top of the modern foundation later.
///
/// Set `selected` **before** `NSApplication.shared` (or any backend) is
/// created; the choice binds at backend startup and cannot change for the
/// life of the process (ComCtl32 is bound once). Application code needs no
/// other changes when switching presentations.
public enum WinPresentation: Sendable {
    /// The unthemed classic Win32 look (ComCtl32 v5). The default until the
    /// modern look reaches parity (plan 8.4).
    case classic

    /// The themed modern Windows look (ComCtl32 v6 visual styles).
    case modern

    /// The presentation the next-created backend applies.
    nonisolated(unsafe) public static var selected: WinPresentation = .classic
}
