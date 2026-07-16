import Foundation

// AppKit style/mode enums the shared demo sets. Presentational hints today
// (native controls pick their own look); here for source compatibility.

public enum NSUserInterfaceLayoutOrientation: Sendable { case horizontal, vertical }

public enum NSStackViewDistribution: Sendable {
    case fill, fillEqually, fillProportionally, equalSpacing, equalCentering, gravityAreas
}
public enum NSStackViewGravity: Sendable { case top, leading, center, bottom, trailing }

public enum NSLevelIndicatorStyle: Sendable {
    case relevancy, continuousCapacity, discreteCapacity, rating
}

public enum NSProgressIndicatorStyle: Sendable { case bar, spinning }

public enum NSColorWellStyle: Sendable { case `default`, minimal, expanded }

// AppKit modal responses. LinChocolate's `runModal()` returns `Int`
// (`NSModalResponseOK` etc.), so these live as `Int` statics — the demo's
// `runModal() == .OK` and `switch { case .alertFirstButtonReturn }` then work.
// (When the frameworks promote the return type to a real `ModalResponse`, this
// bridging goes away — tracked with the other AppKit divergences.)
public extension Int {
    static var OK: Int { 1 }
    static var cancel: Int { 0 }
    static var stop: Int { -1000 }
    static var abort: Int { -1001 }
    static var alertFirstButtonReturn: Int { 1000 }
    static var alertSecondButtonReturn: Int { 1001 }
    static var alertThirdButtonReturn: Int { 1002 }
}

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
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let hourMinute = NSDatePickerElementFlags(rawValue: 0x000c)
    public static let hourMinuteSecond = NSDatePickerElementFlags(rawValue: 0x000e)
    public static let timeZone = NSDatePickerElementFlags(rawValue: 0x0010)
    public static let yearMonth = NSDatePickerElementFlags(rawValue: 0x00c0)
    public static let yearMonthDay = NSDatePickerElementFlags(rawValue: 0x00e0)
    public static let era = NSDatePickerElementFlags(rawValue: 0x0100)
}

public struct NSTableViewGridLineStyle: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let gridNone = NSTableViewGridLineStyle([])
    public static let solidVerticalGridLineMask = NSTableViewGridLineStyle(rawValue: 1 << 0)
    public static let solidHorizontalGridLineMask = NSTableViewGridLineStyle(rawValue: 1 << 1)
    public static let dashedHorizontalGridLineMask = NSTableViewGridLineStyle(rawValue: 1 << 3)
}

public extension NSFont {
    /// AppKit-shaped font weight (subset). `.bold`/`.regular`/…
    struct Weight: Equatable, Sendable {
        public let rawValue: CGFloat
        public init(_ rawValue: CGFloat) { self.rawValue = rawValue }
        public static let ultraLight = Weight(-0.8)
        public static let thin = Weight(-0.6)
        public static let light = Weight(-0.4)
        public static let regular = Weight(0)
        public static let medium = Weight(0.23)
        public static let semibold = Weight(0.3)
        public static let bold = Weight(0.4)
        public static let heavy = Weight(0.56)
        public static let black = Weight(0.62)
    }
    /// The font's weight (accepted for parity; native controls set their own).
    var weight: Weight { .regular }
}
