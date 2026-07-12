/// A minimal Foundation-compatible `NumberFormatter`.
///
/// Real Foundation cannot build on the current Windows toolchain, so this shim
/// formats and parses numbers for AppKit-facing code (formatted text fields,
/// `objectValue` display). It covers the common `numberStyle` presets — plain,
/// decimal, currency, and percent — with locale-derived separators and currency
/// symbol (US formatting on a US machine, matching the `DateFormatter` shim's
/// approach), configurable fraction digits, and grouping. Scientific/spell-out
/// styles and the full option surface are future parity work; it is a drop-in
/// for real Foundation once it builds.
public final class NumberFormatter: Formatter {
    /// The presentation style presets, matching Foundation's raw values.
    public enum Style: Int, Sendable {
        case none = 0
        case decimal = 1
        case currency = 2
        case percent = 3
        case scientific = 4
        case spellOut = 5
    }

    /// The active style. Assigning it applies that style's grouping and
    /// fraction-digit defaults, which callers may then override.
    public var numberStyle: Style = .none {
        didSet {
            applyStyleDefaults()
        }
    }

    /// The locale used for separators and the currency symbol.
    public var locale: Locale = .current

    /// Smallest number of fraction digits shown.
    public var minimumFractionDigits: Int = 0

    /// Largest number of fraction digits shown (trailing zeros are trimmed to
    /// the minimum).
    public var maximumFractionDigits: Int = 0

    /// Smallest number of integer digits shown (zero-padded when shorter).
    public var minimumIntegerDigits: Int = 1

    /// Whether digit grouping (thousands separators) is applied.
    public var usesGroupingSeparator: Bool = false

    /// An explicit grouping separator, or `nil` to use the locale's.
    public var groupingSeparator: String?

    /// An explicit decimal separator, or `nil` to use the locale's.
    public var decimalSeparator: String?

    /// An explicit currency symbol, or `nil` to use the locale's.
    public var currencySymbol: String?

    /// An ISO 4217 currency code (for example `"USD"`), or `nil` to use the
    /// locale's currency. Rendered as the symbol when set; an explicit
    /// `currencySymbol` wins.
    public var currencyCode: String?

    /// The symbol appended for percent style.
    public var percentSymbol: String = "%"

    /// Creates a number formatter.
    public override init() {
        super.init()
    }

    // MARK: - Formatting

    /// Returns the formatted string for a number, or `nil` when out of range.
    public func string(from number: NSNumber) -> String? {
        let value = number.doubleValue
        guard value.isFinite else {
            return nil
        }

        switch numberStyle {
        case .none, .decimal:
            return formatMagnitudeSigned(value)
        case .percent:
            return formatMagnitudeSigned(value * 100) + percentSymbol
        case .currency:
            let symbol = currencySymbol ?? currencyCode.map { winSymbol(forCurrencyCode: $0) } ?? locale.currencySymbol
            let body = formatMagnitude(abs(value))
            return (value < 0 ? "-" : "") + symbol + body
        case .scientific, .spellOut:
            return number.stringValue
        }
    }

    /// The display symbol for an ISO currency code — the common sign where
    /// one exists, otherwise the code itself with a separating space, which
    /// is how Foundation renders less-common codes.
    private func winSymbol(forCurrencyCode code: String) -> String {
        switch code.uppercased() {
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY": return "¥"
        default: return code + "\u{00A0}"
        }
    }

    /// Parses a number from a formatted string, or `nil` when it has no digits.
    public func number(from string: String) -> NSNumber? {
        let decimal = (decimalSeparator ?? locale.decimalSeparator).first ?? "."
        let grouping = (groupingSeparator ?? locale.groupingSeparator).first
        var cleaned = ""
        var sawDigit = false

        for character in string {
            if character.isNumber {
                cleaned.append(character)
                sawDigit = true
            } else if character == "-" && cleaned.isEmpty {
                cleaned.append("-")
            } else if character == decimal {
                cleaned.append(".")
            } else if let grouping, character == grouping {
                continue
            }
            // Currency symbols, percent signs, spaces, and letters are ignored.
        }

        guard sawDigit, let value = Double(cleaned) else {
            return nil
        }

        return NSNumber(value: numberStyle == .percent ? value / 100 : value)
    }

    /// Formats any supported value for display via the base `Formatter` API.
    public override func string(for obj: Any?) -> String? {
        if let number = obj as? NSNumber {
            return string(from: number)
        }
        if let value = obj as? Double {
            return string(from: NSNumber(value: value))
        }
        if let value = obj as? Int {
            return string(from: NSNumber(value: value))
        }
        if let value = obj as? Float {
            return string(from: NSNumber(value: value))
        }
        return nil
    }

    // MARK: - Internals

    private func applyStyleDefaults() {
        switch numberStyle {
        case .none:
            usesGroupingSeparator = false
            minimumFractionDigits = 0
            maximumFractionDigits = 0
        case .decimal:
            usesGroupingSeparator = true
            minimumFractionDigits = 0
            maximumFractionDigits = 3
        case .currency:
            usesGroupingSeparator = true
            minimumFractionDigits = 2
            maximumFractionDigits = 2
        case .percent:
            usesGroupingSeparator = true
            minimumFractionDigits = 0
            maximumFractionDigits = 0
        case .scientific, .spellOut:
            break
        }
    }

    /// Formats a value, carrying its sign, using the current digit settings.
    private func formatMagnitudeSigned(_ value: Double) -> String {
        (value < 0 ? "-" : "") + formatMagnitude(abs(value))
    }

    /// Formats a non-negative magnitude with grouping and fraction digits.
    private func formatMagnitude(_ magnitude: Double) -> String {
        // Very large magnitudes exceed the integer path; fall back to plain text.
        guard magnitude < 1e15 else {
            return NSNumber(value: magnitude).stringValue
        }

        let fractionMax = min(max(0, maximumFractionDigits), 15)
        let fractionMin = max(0, min(minimumFractionDigits, fractionMax))

        var scale = 1.0
        for _ in 0..<fractionMax {
            scale *= 10
        }

        let totalRounded = (magnitude * scale).rounded()
        var allDigits = String(Int64(totalRounded))
        if fractionMax > 0 && allDigits.count <= fractionMax {
            allDigits = String(repeating: "0", count: fractionMax - allDigits.count + 1) + allDigits
        }

        let digitArray = Array(allDigits)
        let splitIndex = digitArray.count - fractionMax
        var integerDigits = fractionMax == 0 ? allDigits : String(digitArray[..<splitIndex])
        var fractionDigits = fractionMax == 0 ? "" : String(digitArray[splitIndex...])

        // Trim trailing zeros down to the minimum fraction count.
        if fractionMax > fractionMin {
            var fractionArray = Array(fractionDigits)
            while fractionArray.count > fractionMin && fractionArray.last == "0" {
                fractionArray.removeLast()
            }
            fractionDigits = String(fractionArray)
        }

        // Pad to the minimum integer-digit count.
        if integerDigits.count < minimumIntegerDigits {
            integerDigits = String(repeating: "0", count: minimumIntegerDigits - integerDigits.count) + integerDigits
        }

        if usesGroupingSeparator && integerDigits.count > 3 {
            integerDigits = applyGrouping(integerDigits, separator: groupingSeparator ?? locale.groupingSeparator)
        }

        guard !fractionDigits.isEmpty else {
            return integerDigits
        }

        return integerDigits + (decimalSeparator ?? locale.decimalSeparator) + fractionDigits
    }

    /// Inserts a grouping separator every three digits from the right.
    private func applyGrouping(_ digits: String, separator: String) -> String {
        let characters = Array(digits)
        var groups: [String] = []
        var index = characters.count
        while index > 0 {
            let start = max(0, index - 3)
            groups.insert(String(characters[start..<index]), at: 0)
            index = start
        }
        return groups.joined(separator: separator)
    }
}
