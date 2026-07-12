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

// Make the demo's collection data source (AppKit method shape) conform.
public extension NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, representedObjectForItemAt index: Int) -> Any? { nil }
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        NSCollectionViewItem()
    }
    func collectionView(_ collectionView: NSCollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> NSView? { nil }
}

public enum NSDatePickerStyle: Sendable { case textFieldAndStepper, clockAndCalendar, textField }

public struct NSDatePickerElementFlags: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let yearMonthDay = NSDatePickerElementFlags(rawValue: 1 << 0)
    public static let yearMonthDayEra = NSDatePickerElementFlags(rawValue: 1 << 1)
    public static let hourMinute = NSDatePickerElementFlags(rawValue: 1 << 2)
    public static let hourMinuteSecond = NSDatePickerElementFlags(rawValue: 1 << 3)
    public static let timeZone = NSDatePickerElementFlags(rawValue: 1 << 4)
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
