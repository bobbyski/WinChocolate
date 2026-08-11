/// A drawing context that records commands for deterministic tests.
public final class RecordingDrawingContext: NativeDrawingContext {
    /// A recorded fill command.
    public struct Fill: Equatable {
        /// The filled path segments.
        public let segments: [NativePathSegment]

        /// The fill color.
        public let color: NSColor
    }

    /// A recorded stroke command.
    public struct Stroke: Equatable {
        /// The stroked path segments.
        public let segments: [NativePathSegment]

        /// The stroke color.
        public let color: NSColor

        /// The stroke line width.
        public let lineWidth: CGFloat
    }

    /// A recorded text command.
    public struct Text: Equatable {
        /// The drawn string.
        public let text: String

        /// The top-left origin of the text run.
        public let point: NSPoint

        /// The text color.
        public let color: NSColor

        /// The requested font family name.
        public let fontName: String

        /// The requested font point size.
        public let fontSize: CGFloat

        /// The requested font weight (Windows `LOGFONT` scale).
        public let weight: Int

        /// Whether the text was drawn italic.
        public let italic: Bool

        /// Whether the text was drawn bold (weight of semibold or heavier).
        public var bold: Bool {
            weight >= NSFont.Weight.semibold.rawValue
        }
    }

    /// A recorded image command.
    public struct Image: Equatable {
        /// The source image file path.
        public let path: String

        /// The destination rectangle.
        public let rect: NSRect

        /// The template tint color, when the image was drawn tinted.
        public let tint: NSColor?

        /// Creates a recorded image command.
        public init(path: String, rect: NSRect, tint: NSColor? = nil) {
            self.path = path
            self.rect = rect
            self.tint = tint
        }
    }

    /// A recorded in-memory (data-backed) bitmap draw.
    public struct BitmapImage: Equatable {
        /// The `width` value.
        public let width: Int
        /// The `height` value.
        public let height: Int
        /// The `rect` value.
        public let rect: NSRect
        /// The `tint` value.
        public let tint: NSColor?
        /// The RGBA byte count supplied (width*height*4), for assertions.
        public let byteCount: Int

        /// Creates a value with the supplied arguments.
        public init(width: Int, height: Int, rect: NSRect, tint: NSColor?, byteCount: Int) {
            self.width = width
            self.height = height
            self.rect = rect
            self.tint = tint
            self.byteCount = byteCount
        }
    }

    /// A recorded linear-gradient command.
    public struct Gradient: Equatable {
        /// The gradient color stops in order.
        public let stops: [NativeGradientStop]

        /// The filled rectangle.
        public let rect: NSRect

        /// The gradient angle in AppKit degrees.
        public let angle: CGFloat
    }

    /// A recorded clip command.
    public struct Clip: Equatable {
        /// The clip path segments.
        public let segments: [NativePathSegment]
    }

    /// A recorded graphics-state operation.
    public enum StateOperation: Equatable {
        /// A state save.
        case save

        /// A state restore.
        case restore
    }

    /// Fill commands in draw order.
    public internal(set) var fills: [Fill] = []

    /// Stroke commands in draw order.
    public internal(set) var strokes: [Stroke] = []

    /// Text commands in draw order.
    public internal(set) var texts: [Text] = []

    /// Image commands in draw order.
    public internal(set) var images: [Image] = []

    /// In-memory bitmap draws in order (data-backed images).
    public internal(set) var bitmapImages: [BitmapImage] = []

    /// Linear-gradient commands in draw order.
    public internal(set) var gradients: [Gradient] = []

    /// Clip commands in draw order.
    public internal(set) var clips: [Clip] = []

    /// Graphics-state saves and restores in order.
    public internal(set) var stateOperations: [StateOperation] = []

    /// Creates an empty recording context.
    public init() {
    }

    /// Records a fill command.
    public func fillPath(_ segments: [NativePathSegment], color: NSColor) {
        fills.append(Fill(segments: segments, color: color))
    }

    /// Records a stroke command.
    public func strokePath(_ segments: [NativePathSegment], color: NSColor, lineWidth: CGFloat) {
        strokes.append(Stroke(segments: segments, color: color, lineWidth: lineWidth))
    }

    /// Records a text command.
    public func drawText(_ text: String, at point: NSPoint, color: NSColor, font: NativeFontSpec) {
        texts.append(Text(
            text: text,
            point: point,
            color: color,
            fontName: font.family ?? "",
            fontSize: font.size,
            weight: font.bold ? 700 : 400,
            italic: font.italic
        ))
    }

    /// Records an image command.
    public func drawImage(atPath path: String, in rect: NSRect, tint: NSColor?) {
        images.append(Image(path: path, rect: rect, tint: tint))
    }

    /// Records an in-memory bitmap draw.
    public func drawImage(rgbaPixels: [UInt8], width: Int, height: Int, in rect: NSRect, tint: NSColor?) {
        bitmapImages.append(BitmapImage(width: width, height: height, rect: rect, tint: tint, byteCount: rgbaPixels.count))
    }

    /// Records a linear-gradient command.
    public func drawLinearGradient(_ stops: [NativeGradientStop], in rect: NSRect, angle: CGFloat) {
        gradients.append(Gradient(stops: stops, rect: rect, angle: angle))
    }

    /// Records a clip command.
    public func clip(to segments: [NativePathSegment]) {
        clips.append(Clip(segments: segments))
    }

    /// Records a state save.
    public func saveState() {
        stateOperations.append(.save)
    }

    /// Records a state restore.
    public func restoreState() {
        stateOperations.append(.restore)
    }
}

/// In-memory backend used before controls are realized and by tests.
///
/// This backend records requested controls without touching the operating
/// system. It keeps framework behavior deterministic in unit tests while the
/// Win32 backend owns real HWND creation for application runs.

/// A recorded native object request.
// Not `Sendable`: these records carry AppKit values (`NSFont`, `NSColor`)
// which are not Sendable on Apple either. The backend is single-threaded
// (everything runs on the UI/test thread), so nothing needs to cross an
// isolation boundary.
/// Describes the public `Record` struct.
public struct InMemoryNativeRecord: Equatable {
    /// The kind of native object requested.
    public var kind: String

    /// The visible title or text.
    public var text: String

    /// The requested frame.
    public var frame: NSRect

    /// The parent native handle, when any.
    public var parent: NativeHandle?

    /// Whether the native object is hidden.
    public var isHidden = false

    /// Whether the native object accepts input.
    public var isEnabled = true

    /// Native button check state.
    public var buttonState: NSControl.StateValue = .off

    /// Native pop-up button items.
    public var popUpItems: [String] = []

    /// Native pop-up button selected index.
    public var popUpSelectedIndex = -1

    /// Native combo-box items.
    public var comboBoxItems: [String] = []

    /// Native image-view file path.
    public var imagePath: String?

    /// Native image-view template tint color, when tinted.
    public var imageTint: NSColor?

    /// Native tab-view items.
    public var tabViewItems: [String] = []

    /// Native tab-view selected index.
    public var tabViewSelectedIndex = -1

    /// Native toolbar items.
    public var toolbarItems: [NativeToolbarItem] = []

    /// Native slider minimum value.
    public var sliderMinValue = 0.0

    /// Native slider maximum value.
    public var sliderMaxValue = 1.0

    /// Native slider value.
    public var sliderValue = 0.0

    /// Native progress minimum value.
    public var progressMinValue = 0.0

    /// Native progress maximum value.
    public var progressMaxValue = 1.0

    /// Native progress value.
    public var progressValue = 0.0

    /// Native scroller knob proportion.
    public var scrollerKnobProportion = 0.0

    /// Whether the native scroller is vertical.
    public var scrollerIsVertical = false
    /// Native scroll-view document size.
    public var scrollViewContentSize = NSZeroSize
    /// Native scroll-view viewport size.
    public var scrollViewViewportSize = NSZeroSize
    /// Native scroll-view visible origin.
    public var scrollViewContentOffset = NSZeroPoint

    /// Native stepper minimum value.
    public var stepperMinValue = 0.0

    /// Native stepper maximum value.
    public var stepperMaxValue = 1.0

    /// Native stepper increment.
    public var stepperIncrement = 1.0

    /// Native stepper value.
    public var stepperValue = 0.0

    /// Native date picker value.
    public var datePickerDate: Date?

    /// Native date picker minimum date.
    public var datePickerMinDate: Date?

    /// Native date picker maximum date.
    public var datePickerMaxDate: Date?

    /// Native table column titles.
    public var tableColumns: [String] = []

    /// Native table column widths.
    public var tableColumnWidths: [CGFloat] = []

    /// Native table row values.
    public var tableRows: [[String]] = []

    /// Native table selected row.
    public var tableSelectedRow = -1

    /// Last native table row requested visible.
    public var tableVisibleRow = -1

    /// Native table clicked row.
    public var tableClickedRow = -1

    /// Native table clicked column.
    public var tableClickedColumn = -1

    /// Recorded text selection start, in UTF-16 units.
    public var textSelectionLocation = 0

    /// Recorded text selection length, in UTF-16 units.
    public var textSelectionLength = 0

    /// Whether the recorded edit control accepts keyboard editing.
    public var isTextEditable = true

    /// Recorded text color.
    public var textColor: NSColor?

    /// Recorded background color.
    public var backgroundColor: NSColor?

    /// Whether the native control should paint its own background.
    public var drawsBackground = true

    /// Recorded tooltip text.
    public var toolTip: String?

    /// Recorded explicit accessibility name (from `accessibilityLabel`).
    public var accessibilityName: String?

    /// Recorded font.
    public var font: NSFont?

    /// Whether a top-level window requested the application menu bar.
    public var usesMainMenu = false

    /// Recorded top-level window z-ordering level raw value.
    public var windowLevel: Int = 0

    /// Whether the recorded window hides while the application is inactive.
    public var hidesOnDeactivate: Bool = false

    /// Recorded placeholder (cue banner) text.
    public var placeholder: String?

    /// Recorded text alignment.
    public var textAlignment: NSTextAlignment = .natural

    /// Recorded slider tick-mark count.
    public var sliderTickMarkCount: Int = 0

    /// Whether the recorded slider is vertical.
    public var sliderIsVertical: Bool = false

    /// Recorded combo-box visible item count.
    public var comboBoxVisibleItems: Int = 0

    /// Recorded progress/level bar color.
    public var progressBarColor: NSColor?

    /// Recorded minimum content size limit.
    public var minContentSize: NSSize?

    /// Recorded maximum content size limit.
    public var maxContentSize: NSSize?

    /// Recorded content scale for custom-drawn views.
    public var contentScale: CGFloat = 1

    /// Recorded date-picker display format.
    public var datePickerFormat: String?
    /// Whether the peer was asked for a stepper (`.textFieldAndStepper`).
    public var datePickerShowsStepper = false
    /// The zone the peer renders its wall clock in.
    public var datePickerTimeZone: TimeZone?

    /// Recorded button image file path.
    public var buttonImagePath: String?

    /// Whether the recorded text view is rich text.
    public var isRichText: Bool = false

    /// Recorded rich-text range formatting requests, oldest first.
    public var textRangeFormats: [InMemoryTextRangeFormat] = []
}

/// One recorded rich-text range formatting request.
public struct InMemoryTextRangeFormat: Equatable {
    /// The applied font, when any.
    public var font: NSFont?

    /// The applied color, when any.
    public var color: NSColor?

    /// The applied underline state, when any.
    public var underline: Bool?

    /// The applied strikethrough state, when any.
    public var strikethrough: Bool?

    /// The formatted range start, in UTF-16 units.
    public var location: Int

    /// The formatted range length, in UTF-16 units.
    public var length: Int
}
