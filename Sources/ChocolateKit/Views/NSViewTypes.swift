extension NSView {
    /// Autoresizing behavior flags matching AppKit names.
    public struct AutoresizingMask: OptionSet, Sendable {
        /// Raw option value.
        public let rawValue: UInt

        /// Creates an autoresizing mask from a raw value.
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// Left margin can change.
        public static let minXMargin = AutoresizingMask(rawValue: 1 << 0)

        /// Width can change.
        public static let width = AutoresizingMask(rawValue: 1 << 1)

        /// Right margin can change.
        public static let maxXMargin = AutoresizingMask(rawValue: 1 << 2)

        /// Bottom margin can change.
        public static let minYMargin = AutoresizingMask(rawValue: 1 << 3)

        /// Height can change.
        public static let height = AutoresizingMask(rawValue: 1 << 4)

        /// Top margin can change.
        public static let maxYMargin = AutoresizingMask(rawValue: 1 << 5)
    }
}
