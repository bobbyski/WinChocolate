extension NSWindow {
    /// Window style options matching AppKit names.
    public struct StyleMask: OptionSet, Sendable {
        /// Raw option value.
        public let rawValue: UInt

        /// Creates a style mask from a raw value.
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// Titled window style.
        public static let titled = StyleMask(rawValue: 1 << 0)

        /// Borderless window style.
        public static var borderless: StyleMask { [] }

        /// Closable window style.
        public static let closable = StyleMask(rawValue: 1 << 1)

        /// Miniaturizable window style.
        public static let miniaturizable = StyleMask(rawValue: 1 << 2)

        /// Resizable window style.
        public static let resizable = StyleMask(rawValue: 1 << 3)

        /// Utility-panel window style with compact tool-window chrome.
        public static let utilityWindow = StyleMask(rawValue: 1 << 4)

        /// Content view fills the whole frame, including under the title bar.
        public static let fullSizeContentView = StyleMask(rawValue: 1 << 5)

        /// A panel that does not become key/activate when shown.
        public static let nonactivatingPanel = StyleMask(rawValue: 1 << 6)

        /// A heads-up-display style panel (dark translucent chrome on
        /// AppKit; the classic backend renders a standard utility panel).
        public static let hudWindow = StyleMask(rawValue: 1 << 7)

        /// Present while the window occupies the full screen. AppKit adds this
        /// to `styleMask` for the duration of full-screen mode; WinChocolate
        /// does the same (see `toggleFullScreen`).
        public static let fullScreen = StyleMask(rawValue: 1 << 7)
    }

    /// How a window participates in spaces and full screen, matching AppKit's
    /// `NSWindow.CollectionBehavior`. WinChocolate stores the value for API
    /// fidelity; only the full-screen flags affect behavior on Windows.
    public struct CollectionBehavior: OptionSet, Sendable {
        /// The `rawValue` value.
        public let rawValue: Int
        /// Creates a value with the supplied arguments.
        public init(rawValue: Int) { self.rawValue = rawValue }

        /// The window can enter full screen as a primary full-screen window.
        public static let fullScreenPrimary = CollectionBehavior(rawValue: 1 << 7)

        /// The window can join another window's full-screen space.
        public static let fullScreenAuxiliary = CollectionBehavior(rawValue: 1 << 8)

        /// The window cannot be made full screen.
        public static let fullScreenNone = CollectionBehavior(rawValue: 1 << 9)
    }

    /// Whether the window shows its title text.
    public enum TitleVisibility: Sendable {
        /// The title is shown in the title bar (default).
        case visible

        /// The title text is hidden while the title bar remains.
        case hidden
    }

    /// The standard title-bar buttons AppKit can vend.
    public enum ButtonType: Sendable {
        case closeButton
        case miniaturizeButton
        case zoomButton
        case toolbarButton
        case documentIconButton
    }

    /// Window z-ordering levels matching AppKit names.
    public struct Level: RawRepresentable, Equatable, Hashable, Sendable {
        /// Raw level value; higher levels order above lower ones.
        public let rawValue: Int

        /// Creates a level from a raw value.
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// The default level for document windows.
        public static let normal = Level(rawValue: 0)

        /// The level for floating utility panels above document windows.
        public static let floating = Level(rawValue: 3)

        /// The level for modal panels.
        public static let modalPanel = Level(rawValue: 8)

        /// The level for status-bar items, above floating panels.
        public static let statusBar = Level(rawValue: 25)
    }

    /// Window backing store strategy.
    public enum BackingStoreType: Sendable {
        /// Buffered backing store.
        case buffered
    }

    /// Relative ordering used when inserting views.
    public enum OrderingMode: Sendable {
        /// Place above the reference object.
        case above

        /// Place below the reference object.
        case below

        /// Remove from ordering.
        case out
    }
}
