/// Base cell object used by legacy AppKit controls.
///
/// WinChocolate keeps this small for now so table columns can expose familiar
/// `headerCell` and `dataCell` properties while newer view-based table work is
/// layered in later.
open class NSCell: NSObject {
    /// Generic cell value.
    open var objectValue: Any?

    /// String representation of the cell value.
    open var stringValue: String {
        get {
            objectValue.map { String(describing: $0) } ?? ""
        }
        set {
            objectValue = newValue
        }
    }

    /// Whether the cell can be edited.
    open var isEditable: Bool

    /// Whether the cell can be selected.
    open var isSelectable: Bool

    /// Whether the cell is enabled.
    open var isEnabled: Bool

    /// Creates an empty cell.
    public override init() {
        self.objectValue = nil
        self.isEditable = false
        self.isSelectable = false
        self.isEnabled = true
        super.init()
    }

    /// Creates a cell with text.
    public init(textCell string: String) {
        self.objectValue = string
        self.isEditable = false
        self.isSelectable = false
        self.isEnabled = true
        super.init()
    }

    // MARK: The control this cell draws for
    //
    // AppKit's cells are not property bags: a cell belongs to a control, and
    // setting a property on the cell changes the control on screen. The
    // subclasses below forward to `controlView` for exactly that reason —
    // `field.cell?.placeholderString = "Name"` has to move the placeholder,
    // not store a string nobody reads.

    /// The view this cell draws inside, set when a control adopts the cell.
    open weak var controlView: NSView?

    /// Whether the cell draws a bezel.
    open var isBezeled: Bool = false

    /// Whether the cell draws a plain border.
    open var isBordered: Bool = true

    /// Whether text wraps to more lines rather than being clipped.
    open var wraps: Bool = false

    /// Whether the cell scrolls its text horizontally instead of wrapping.
    open var isScrollable: Bool = true

    /// Whether ending editing sends the action, as well as Return doing so.
    open var sendsActionOnEndEditing: Bool = false

    /// The focus-ring style, or `.none` to suppress the ring.
    ///
    /// Advisory: the Chocolate backends draw the focus indicator their own
    /// platform draws. Stored so a themed control can ask for no ring and have
    /// the request survive, rather than silently doing nothing *and* losing it.
    open var focusRingType: NSFocusRingType = .default
}

/// Focus-ring styles, matching AppKit's names.
public enum NSFocusRingType: Sendable {
    case `default`
    case none
    case exterior
}

/// Text cell used by table columns and by `NSTextField` itself.
///
/// Every property here forwards to the field when the cell has one, so the two
/// spellings AppKit code uses — `field.placeholderString = x` and
/// `field.cell?.placeholderString = x` — do the same thing. Detached cells (a
/// table column's `dataCell`, say) fall back to their own storage.
open class NSTextFieldCell: NSCell {
    /// Creates a text cell.
    public override init() {
        super.init()
    }

    /// Creates a text cell with initial text.
    public override init(textCell string: String) {
        super.init(textCell: string)
    }

    // The field this cell draws for, when it has one.
    private var field: NSTextField? { controlView as? NSTextField }

    // Storage used only while the cell is detached from a field.
    private var detachedPlaceholder: String?
    private var detachedFont: NSFont?
    private var detachedAlignment: NSTextAlignment = .natural
    private var detachedBezelStyle: NSTextField.BezelStyle = .squareBezel

    /// Grey text shown while the field is empty.
    open var placeholderString: String? {
        get { field?.placeholderString ?? detachedPlaceholder }
        set {
            if let field { field.placeholderString = newValue } else { detachedPlaceholder = newValue }
        }
    }

    /// The font the text is drawn in.
    open var font: NSFont? {
        get { field?.font ?? detachedFont }
        set {
            if let field { field.font = newValue } else { detachedFont = newValue }
        }
    }

    /// How the text is aligned in the cell.
    open var alignment: NSTextAlignment {
        get { field?.alignment ?? detachedAlignment }
        set {
            if let field { field.alignment = newValue } else { detachedAlignment = newValue }
        }
    }

    /// The bezel shape drawn around the text.
    open var bezelStyle: NSTextField.BezelStyle {
        get { field?.bezelStyle ?? detachedBezelStyle }
        set {
            if let field { field.bezelStyle = newValue } else { detachedBezelStyle = newValue }
        }
    }

    /// Whether the field draws a bezel.
    open override var isBezeled: Bool {
        get { field?.isBezeled ?? super.isBezeled }
        set {
            if let field { field.isBezeled = newValue } else { super.isBezeled = newValue }
        }
    }

    /// The object the action is sent to.
    open var target: AnyObject? {
        get { field?.target }
        set { field?.target = newValue }
    }

    /// The selector sent when the cell's value is committed.
    open var action: Selector? {
        get { field?.action }
        set { field?.action = newValue }
    }
}

/// The cell a secure text field draws with.
open class NSSecureTextFieldCell: NSTextFieldCell {
    /// Whether the substituted characters are drawn, as against nothing at all.
    open var echosBullets: Bool = true
}

/// The base class for AppKit's text-editing views.
///
/// AppKit uses `NSText` for the shared field editor, and ported code reaches it
/// through `NSControl.currentEditor()` — almost always to ask whether a control
/// is being edited, occasionally to read or replace the text mid-edit. There is
/// no shared editor off Apple: each native control owns its text. So this is a
/// thin view over whichever control vended it, which is the honest shape of the
/// thing here.
open class NSText: NSView {
    /// The text being edited.
    open var string: String = ""

    /// Whether the text can be edited.
    open var isEditable: Bool = true

    /// Whether the text can be selected.
    open var isSelectable: Bool = true
}

/// The cell a pop-up button draws with.
open class NSPopUpButtonCell: NSCell {
    /// Where the pull-down arrow sits.
    public enum ArrowPosition: Sendable {
        /// No arrow.
        case noArrow
        /// Beside the title.
        case arrowAtCenter
        /// At the trailing edge.
        case arrowAtBottom
    }

    /// Where the arrow is drawn.
    ///
    /// Stored: the native pop-up draws its own arrow in its own place, and no
    /// backend here can be asked to move it. Kept so a themed control's request
    /// survives rather than being silently dropped *and* forgotten.
    open var arrowPosition: ArrowPosition = .arrowAtCenter

    /// Whether the button pulls down from its title rather than showing the
    /// selected item.
    open var pullsDown: Bool = false
}

/// The cell a segmented control draws with.
open class NSSegmentedCell: NSCell {
    /// How segment images are scaled.
    open var imageScaling: NSImageScaling = .scaleProportionallyDown

    /// The number of segments the cell tracks.
    open var segmentCount: Int = 0
}

/// The cell a token field draws with.
open class NSTokenFieldCell: NSTextFieldCell {
    /// The characters that end a token as they are typed.
    open var tokenizingCharacterSet: CharacterSet = CharacterSet(charactersIn: ",")

    /// How long the completion list waits before appearing.
    open var completionDelay: TimeInterval = 0

    /// How tokens are drawn.
    open var tokenStyle: NSTokenField.TokenStyle = .rounded
}
