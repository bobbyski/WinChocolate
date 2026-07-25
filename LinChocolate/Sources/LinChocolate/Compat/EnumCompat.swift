import Foundation

// AppKit style/mode enums the shared demo sets. Presentational hints today
// (native controls pick their own look); here for source compatibility.

/// Axis along which a stack or similar container lays out its subviews.
public enum NSUserInterfaceLayoutOrientation: Sendable { case horizontal, vertical }

/// AppKit's `NSStackView.Distribution` — how arranged subviews share space
/// along the stack's orientation.
public enum NSStackViewDistribution: Sendable {
    case fill, fillEqually, fillProportionally, equalSpacing, equalCentering, gravityAreas
}
/// AppKit's `NSStackView.Gravity` slot for `setViews(_:in:)`.
public enum NSStackViewGravity: Sendable { case top, leading, center, bottom, trailing }

/// AppKit's `NSLevelIndicator.Style`. Raw values are Apple's, read from real
/// AppKit: relevancy 0, continuousCapacity 1, discreteCapacity 2, rating 3.
public enum NSLevelIndicatorStyle: Int, Sendable {
    case relevancy = 0, continuousCapacity = 1, discreteCapacity = 2, rating = 3
}

/// AppKit's `NSProgressIndicator.Style` — bar (linear) vs spinning (indeterminate).
public enum NSProgressIndicatorStyle: Sendable { case bar, spinning }

/// AppKit's `NSColorWell.Style` (10.15+).
public enum NSColorWellStyle: Sendable { case `default`, minimal, expanded }

// AppKit modal responses. LinChocolate's `runModal()` returns `Int`
// (`NSModalResponseOK` etc.), so these live as `Int` statics — the demo's
// `runModal() == .OK` and `switch { case .alertFirstButtonReturn }` then work.
// (When the frameworks promote the return type to a real `ModalResponse`, this
// bridging goes away — tracked with the other AppKit divergences.)
public extension Int {
    /// AppKit's `NSModalResponse.OK` (user confirmed).
    static var OK: Int { 1 }
    /// AppKit's `NSModalResponse.cancel` (user cancelled).
    static var cancel: Int { 0 }
    /// AppKit's `NSModalResponse.stop`.
    static var stop: Int { -1000 }
    /// AppKit's `NSModalResponse.abort`.
    static var abort: Int { -1001 }
    /// The alert's first (default) button was clicked.
    static var alertFirstButtonReturn: Int { 1000 }
    /// The alert's second button was clicked.
    static var alertSecondButtonReturn: Int { 1001 }
    /// The alert's third button was clicked.
    static var alertThirdButtonReturn: Int { 1002 }
}

/// AppKit's `NSDatePicker.Style`.
public enum NSDatePickerStyle: Sendable { case textFieldAndStepper, clockAndCalendar, textField }

/// AppKit's `NSDatePicker.ElementFlags`.
///
/// These are Apple's exact raw values, read out of real AppKit rather than
/// invented — the previous `1 << n` values meant any app passing a literal
/// raw value (or round-tripping through one) got a different control. Note
/// they are **cumulative**: `yearMonthDay` (0xe0) contains `yearMonth` (0xc0),
/// and `hourMinuteSecond` (0xe) contains `hourMinute` (0xc), so test for the
/// wider flag first. Apple spells the era one `.era`; there is no
/// `.yearMonthDayEra`.
public struct NSDatePickerElementFlags: OptionSet, Sendable {
    /// Raw bitmask matching Apple's exact values.
    public let rawValue: UInt
    /// Builds a flag set from its raw bitmask.
    public init(rawValue: UInt) { self.rawValue = rawValue }
    /// Show hour and minute.
    public static let hourMinute = NSDatePickerElementFlags(rawValue: 0x000c)
    /// Show hour, minute, and second (contains `.hourMinute`).
    public static let hourMinuteSecond = NSDatePickerElementFlags(rawValue: 0x000e)
    /// Show the time zone.
    public static let timeZone = NSDatePickerElementFlags(rawValue: 0x0010)
    /// Show year and month.
    public static let yearMonth = NSDatePickerElementFlags(rawValue: 0x00c0)
    /// Show year, month, and day (contains `.yearMonth`).
    public static let yearMonthDay = NSDatePickerElementFlags(rawValue: 0x00e0)
    /// Show the era.
    public static let era = NSDatePickerElementFlags(rawValue: 0x0100)
}

/// AppKit's `NSTableView.GridLineStyle` — which grid lines a table draws.
public struct NSTableViewGridLineStyle: OptionSet, Sendable {
    /// Raw bitmask matching AppKit's values.
    public let rawValue: Int
    /// Builds a style set from its raw bitmask.
    public init(rawValue: Int) { self.rawValue = rawValue }
    /// Draw no grid lines.
    public static let gridNone = NSTableViewGridLineStyle([])
    /// Draw solid vertical column separators.
    public static let solidVerticalGridLineMask = NSTableViewGridLineStyle(rawValue: 1 << 0)
    /// Draw solid horizontal row separators.
    public static let solidHorizontalGridLineMask = NSTableViewGridLineStyle(rawValue: 1 << 1)
    /// Draw dashed horizontal row separators.
    public static let dashedHorizontalGridLineMask = NSTableViewGridLineStyle(rawValue: 1 << 3)
}

public extension NSFont {
    /// AppKit-shaped font weight (subset). `.bold`/`.regular`/…
    struct Weight: Equatable, Sendable {
        /// Underlying numeric weight, matching AppKit's normalized scale.
        public let rawValue: CGFloat
        /// Builds a weight from its raw normalized value.
        public init(_ rawValue: CGFloat) { self.rawValue = rawValue }
        /// Ultra-light weight.
        public static let ultraLight = Weight(-0.8)
        /// Thin weight.
        public static let thin = Weight(-0.6)
        /// Light weight.
        public static let light = Weight(-0.4)
        /// Regular (default) weight.
        public static let regular = Weight(0)
        /// Medium weight.
        public static let medium = Weight(0.23)
        /// Semibold weight.
        public static let semibold = Weight(0.3)
        /// Bold weight.
        public static let bold = Weight(0.4)
        /// Heavy weight.
        public static let heavy = Weight(0.56)
        /// Black (heaviest) weight.
        public static let black = Weight(0.62)
    }
    /// The font's weight (accepted for parity; native controls set their own).
    var weight: Weight { .regular }
}
