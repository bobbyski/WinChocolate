// NSAccessibilityRole.swift
// AppKit-shaped accessibility role/subrole vocabulary.
//
// AppKit models roles and subroles as string-backed newtypes exposed under the
// `NSAccessibility` namespace (`NSAccessibility.Role`, `NSAccessibility.Subrole`)
// and as the older global `NSAccessibilityRole` constants. We provide both so
// source written against either spelling compiles unchanged.

/// A string-backed accessibility role, matching `NSAccessibility.Role`.
public struct NSAccessibilityRole: RawRepresentable, Hashable, Sendable {
    /// The `rawValue` value.
    public let rawValue: String
    /// Creates a value with the supplied arguments.
    public init(rawValue: String) { self.rawValue = rawValue }
    /// Creates a value with the supplied arguments.
    public init(_ rawValue: String) { self.rawValue = rawValue }

    /// The `` type-level value.
    public static let unknown = NSAccessibilityRole("AXUnknown")
    /// The `` type-level value.
    public static let group = NSAccessibilityRole("AXGroup")
    /// The `` type-level value.
    public static let button = NSAccessibilityRole("AXButton")
    /// The `` type-level value.
    public static let radioButton = NSAccessibilityRole("AXRadioButton")
    /// The `` type-level value.
    public static let checkBox = NSAccessibilityRole("AXCheckBox")
    /// The `` type-level value.
    public static let staticText = NSAccessibilityRole("AXStaticText")
    /// The `` type-level value.
    public static let textField = NSAccessibilityRole("AXTextField")
    /// The `` type-level value.
    public static let textArea = NSAccessibilityRole("AXTextArea")
    /// The `` type-level value.
    public static let slider = NSAccessibilityRole("AXSlider")
    /// The `` type-level value.
    public static let incrementor = NSAccessibilityRole("AXIncrementor")
    /// The `` type-level value.
    public static let image = NSAccessibilityRole("AXImage")
    /// The `` type-level value.
    public static let popUpButton = NSAccessibilityRole("AXPopUpButton")
    /// The `` type-level value.
    public static let menuButton = NSAccessibilityRole("AXMenuButton")
    /// The `` type-level value.
    public static let comboBox = NSAccessibilityRole("AXComboBox")
    /// The `` type-level value.
    public static let progressIndicator = NSAccessibilityRole("AXProgressIndicator")
    /// The `` type-level value.
    public static let levelIndicator = NSAccessibilityRole("AXLevelIndicator")
    /// The `` type-level value.
    public static let colorWell = NSAccessibilityRole("AXColorWell")
    /// The `` type-level value.
    public static let scrollBar = NSAccessibilityRole("AXScrollBar")
    /// The `` type-level value.
    public static let scrollArea = NSAccessibilityRole("AXScrollArea")
    /// The `` type-level value.
    public static let table = NSAccessibilityRole("AXTable")
    /// The `` type-level value.
    public static let outline = NSAccessibilityRole("AXOutline")
    /// The `` type-level value.
    public static let browser = NSAccessibilityRole("AXBrowser")
    /// The `` type-level value.
    public static let list = NSAccessibilityRole("AXList")
    /// The `` type-level value.
    public static let row = NSAccessibilityRole("AXRow")
    /// The `` type-level value.
    public static let column = NSAccessibilityRole("AXColumn")
    /// The `` type-level value.
    public static let cell = NSAccessibilityRole("AXCell")
    /// The `` type-level value.
    public static let disclosureTriangle = NSAccessibilityRole("AXDisclosureTriangle")
    /// The `` type-level value.
    public static let toolbar = NSAccessibilityRole("AXToolbar")
    /// The `` type-level value.
    public static let tabGroup = NSAccessibilityRole("AXTabGroup")
    /// The `` type-level value.
    public static let splitGroup = NSAccessibilityRole("AXSplitGroup")
    /// The `` type-level value.
    public static let splitter = NSAccessibilityRole("AXSplitter")
    /// The `` type-level value.
    public static let menu = NSAccessibilityRole("AXMenu")
    /// The `` type-level value.
    public static let menuItem = NSAccessibilityRole("AXMenuItem")
    /// The `` type-level value.
    public static let menuBar = NSAccessibilityRole("AXMenuBar")
    /// The `` type-level value.
    public static let link = NSAccessibilityRole("AXLink")
    /// The `` type-level value.
    public static let window = NSAccessibilityRole("AXWindow")
    /// The `` type-level value.
    public static let sheet = NSAccessibilityRole("AXSheet")
    /// The `` type-level value.
    public static let application = NSAccessibilityRole("AXApplication")
    /// The `` type-level value.
    public static let busyIndicator = NSAccessibilityRole("AXBusyIndicator")
    /// The `` type-level value.
    public static let ruler = NSAccessibilityRole("AXRuler")
}

/// A string-backed accessibility subrole, matching `NSAccessibility.Subrole`.
public struct NSAccessibilitySubrole: RawRepresentable, Hashable, Sendable {
    /// The `rawValue` value.
    public let rawValue: String
    /// Creates a value with the supplied arguments.
    public init(rawValue: String) { self.rawValue = rawValue }
    /// Creates a value with the supplied arguments.
    public init(_ rawValue: String) { self.rawValue = rawValue }

    /// The `` type-level value.
    public static let standardWindow = NSAccessibilitySubrole("AXStandardWindow")
    /// The `` type-level value.
    public static let dialog = NSAccessibilitySubrole("AXDialog")
    /// The `` type-level value.
    public static let systemDialog = NSAccessibilitySubrole("AXSystemDialog")
    /// The `` type-level value.
    public static let closeButton = NSAccessibilitySubrole("AXCloseButton")
    /// The `` type-level value.
    public static let minimizeButton = NSAccessibilitySubrole("AXMinimizeButton")
    /// The `` type-level value.
    public static let zoomButton = NSAccessibilitySubrole("AXZoomButton")
    /// The `` type-level value.
    public static let toolbarButton = NSAccessibilitySubrole("AXToolbarButton")
    /// The `` type-level value.
    public static let secureTextField = NSAccessibilitySubrole("AXSecureTextField")
    /// The `` type-level value.
    public static let searchField = NSAccessibilitySubrole("AXSearchField")
    /// The `` type-level value.
    public static let textLink = NSAccessibilitySubrole("AXTextLink")
    /// The `` type-level value.
    public static let tableRow = NSAccessibilitySubrole("AXTableRow")
    /// The `` type-level value.
    public static let outlineRow = NSAccessibilitySubrole("AXOutlineRow")
    /// The `` type-level value.
    public static let sortButton = NSAccessibilitySubrole("AXSortButton")
    /// The `` type-level value.
    public static let switchSubrole = NSAccessibilitySubrole("AXSwitch")
    /// The `` type-level value.
    public static let toggle = NSAccessibilitySubrole("AXToggle")
}

/// The `NSAccessibility` namespace, mirroring AppKit's nested `Role`/`Subrole`.
public enum NSAccessibility {
    /// The public `Role` type alias.
    public typealias Role = NSAccessibilityRole
    /// The public `Subrole` type alias.
    public typealias Subrole = NSAccessibilitySubrole
}

extension NSAccessibilityRole {
    /// A human-readable description AppKit derives from the role when the
    /// element does not supply its own. Matches the strings VoiceOver speaks.
    public var winDefaultRoleDescription: String {
        switch self {
        case .button: return "button"
        case .radioButton: return "radio button"
        case .checkBox: return "checkbox"
        case .staticText: return "text"
        case .textField: return "text field"
        case .textArea: return "text area"
        case .slider: return "slider"
        case .incrementor: return "stepper"
        case .image: return "image"
        case .popUpButton: return "pop up button"
        case .menuButton: return "menu button"
        case .comboBox: return "combo box"
        case .progressIndicator: return "progress indicator"
        case .levelIndicator: return "level indicator"
        case .colorWell: return "color well"
        case .table: return "table"
        case .outline: return "outline"
        case .browser: return "browser"
        case .list: return "list"
        case .row: return "row"
        case .cell: return "cell"
        case .disclosureTriangle: return "disclosure triangle"
        case .toolbar: return "toolbar"
        case .group: return "group"
        case .window: return "window"
        case .sheet: return "sheet"
        case .link: return "link"
        case .menu: return "menu"
        case .menuItem: return "menu item"
        default: return rawValue.hasPrefix("AX") ? String(rawValue.dropFirst(2)).lowercased() : rawValue
        }
    }
}
