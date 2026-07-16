/// A minimal Foundation-compatible locale.
///
/// This shim exposes just enough for `DateFormatter` to format dates the way
/// the user's Windows locale does — on a US machine that means US dates. The
/// identifier follows Foundation's `en_US` style; the Windows APIs use the
/// `en-US` form, which this type bridges. Full locale data (collation,
/// number formats, etc.) is future Foundation-parity work.
public struct Locale: Equatable, Sendable {
    /// The locale identifier (Foundation style, e.g. `en_US`).
    public let identifier: String

    /// Creates a locale from an identifier.
    public init(identifier: String) {
        self.identifier = identifier
    }

    /// The user's current locale, read from the system.
    public static var current: Locale {
        Locale(identifier: WinLocale.userDefaultName())
    }

    /// The user's current locale, tracking system changes (same as `current`).
    public static var autoupdatingCurrent: Locale {
        current
    }

    /// The Windows locale name (`en-US`) used by the date-format APIs.
    var windowsName: String {
        String(identifier.map { $0 == "_" ? "-" : $0 })
    }

    /// The locale's short-date pattern in Windows date-format syntax
    /// (for example `M/d/yyyy`), suitable for a native date picker.
    public var shortDatePattern: String {
        WinLocale.info(windowsName, WinLocale.localeShortDate) ?? "M/d/yyyy"
    }

    /// The locale's time pattern in Windows date-format syntax
    /// (for example `h:mm:ss tt`).
    public var timePattern: String {
        WinLocale.info(windowsName, WinLocale.localeTimeFormat) ?? "h:mm:ss tt"
    }

    /// The locale's time pattern without seconds (for example `h:mm tt`).
    ///
    /// The OS owns which fields a short time drops; deriving it by cutting
    /// `:ss` out of `timePattern` would only guess at the separator.
    public var shortTimePattern: String {
        WinLocale.info(windowsName, WinLocale.localeShortTime) ?? "h:mm tt"
    }

    /// The decimal separator for the locale (for example `.`).
    public var decimalSeparator: String {
        WinLocale.info(windowsName, WinLocale.localeDecimalSeparator) ?? "."
    }

    /// The thousands/grouping separator for the locale (for example `,`).
    public var groupingSeparator: String {
        WinLocale.info(windowsName, WinLocale.localeThousandSeparator) ?? ","
    }

    /// The currency symbol for the locale (for example `$`).
    public var currencySymbol: String {
        WinLocale.info(windowsName, WinLocale.localeCurrencySymbol) ?? "$"
    }
}

/// Windows locale/date bridging used by `Locale` and `DateFormatter`.
enum WinLocale {
    static let localeShortDate: UInt32 = 0x0000_001F
    static let localeTimeFormat: UInt32 = 0x0000_1003
    static let localeShortTime: UInt32 = 0x0000_0079
    static let localeDecimalSeparator: UInt32 = 0x0000_000E
    static let localeThousandSeparator: UInt32 = 0x0000_000F
    static let localeCurrencySymbol: UInt32 = 0x0000_0014

    static let dateShortDate: UInt32 = 0x0000_0001
    static let dateLongDate: UInt32 = 0x0000_0002
    static let timeNoSeconds: UInt32 = 0x0000_0002

    /// The current user's locale name, or `en-US` if unavailable.
    static func userDefaultName() -> String {
        #if os(Windows)
        var buffer = [UInt16](repeating: 0, count: 85)
        let count = buffer.withUnsafeMutableBufferPointer { pointer in
            WinFoundationGetUserDefaultLocaleName(pointer.baseAddress, Int32(pointer.count))
        }
        guard count > 1 else {
            return "en-US"
        }
        return decode(buffer, upTo: Int(count) - 1)
        #else
        return "en_US"
        #endif
    }

    /// Reads a locale info string (Windows date-format syntax).
    static func info(_ localeName: String, _ type: UInt32) -> String? {
        #if os(Windows)
        var buffer = [UInt16](repeating: 0, count: 128)
        let count = withWide(localeName) { namePointer in
            buffer.withUnsafeMutableBufferPointer { pointer in
                WinFoundationGetLocaleInfoEx(namePointer, type, pointer.baseAddress, Int32(pointer.count))
            }
        }
        guard count > 1 else {
            return nil
        }
        return decode(buffer, upTo: Int(count) - 1)
        #else
        return nil
        #endif
    }

    /// Formats a date's date-part with the OS for a locale, using either a
    /// flag (short/long) or a custom Windows-syntax pattern.
    static func formatDate(_ time: WinSystemTime, localeName: String, flags: UInt32, pattern: String?) -> String? {
        #if os(Windows)
        var value = time
        var buffer = [UInt16](repeating: 0, count: 128)
        let count = withWide(localeName) { namePointer in
            withOptionalWide(pattern) { patternPointer in
                buffer.withUnsafeMutableBufferPointer { pointer in
                    WinFoundationGetDateFormatEx(namePointer, flags, &value, patternPointer, pointer.baseAddress, Int32(pointer.count), nil)
                }
            }
        }
        guard count > 1 else {
            return nil
        }
        return decode(buffer, upTo: Int(count) - 1)
        #else
        return nil
        #endif
    }

    /// Formats a date's time-part with the OS for a locale.
    static func formatTime(_ time: WinSystemTime, localeName: String, flags: UInt32) -> String? {
        #if os(Windows)
        var value = time
        var buffer = [UInt16](repeating: 0, count: 128)
        let count = withWide(localeName) { namePointer in
            buffer.withUnsafeMutableBufferPointer { pointer in
                WinFoundationGetTimeFormatEx(namePointer, flags, &value, nil, pointer.baseAddress, Int32(pointer.count))
            }
        }
        guard count > 1 else {
            return nil
        }
        return decode(buffer, upTo: Int(count) - 1)
        #else
        return nil
        #endif
    }

    private static func decode(_ buffer: [UInt16], upTo length: Int) -> String {
        String(decoding: buffer.prefix(length), as: UTF16.self)
    }

    #if os(Windows)
    private static func withWide<Result>(_ string: String, _ body: (UnsafePointer<UInt16>?) -> Result) -> Result {
        var units = Array(string.utf16)
        units.append(0)
        return units.withUnsafeBufferPointer { body($0.baseAddress) }
    }

    private static func withOptionalWide<Result>(_ string: String?, _ body: (UnsafePointer<UInt16>?) -> Result) -> Result {
        guard let string else {
            return body(nil)
        }
        return withWide(string, body)
    }
    #endif
}

/// A Windows `SYSTEMTIME` used for locale date formatting.
struct WinSystemTime {
    var year: UInt16 = 0
    var month: UInt16 = 0
    var dayOfWeek: UInt16 = 0
    var day: UInt16 = 0
    var hour: UInt16 = 0
    var minute: UInt16 = 0
    var second: UInt16 = 0
    var milliseconds: UInt16 = 0
}

#if os(Windows)
@_silgen_name("GetUserDefaultLocaleName")
private func WinFoundationGetUserDefaultLocaleName(_ name: UnsafeMutablePointer<UInt16>?, _ count: Int32) -> Int32

@_silgen_name("GetLocaleInfoEx")
private func WinFoundationGetLocaleInfoEx(_ localeName: UnsafePointer<UInt16>?, _ type: UInt32, _ data: UnsafeMutablePointer<UInt16>?, _ count: Int32) -> Int32

@_silgen_name("GetDateFormatEx")
private func WinFoundationGetDateFormatEx(_ localeName: UnsafePointer<UInt16>?, _ flags: UInt32, _ date: UnsafePointer<WinSystemTime>?, _ format: UnsafePointer<UInt16>?, _ dateString: UnsafeMutablePointer<UInt16>?, _ count: Int32, _ calendar: UnsafePointer<UInt16>?) -> Int32

@_silgen_name("GetTimeFormatEx")
private func WinFoundationGetTimeFormatEx(_ localeName: UnsafePointer<UInt16>?, _ flags: UInt32, _ time: UnsafePointer<WinSystemTime>?, _ format: UnsafePointer<UInt16>?, _ timeString: UnsafeMutablePointer<UInt16>?, _ count: Int32) -> Int32
#endif
