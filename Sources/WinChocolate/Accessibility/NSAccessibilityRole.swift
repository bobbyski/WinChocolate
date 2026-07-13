// NSAccessibilityRole.swift
// AppKit-shaped accessibility role/subrole vocabulary.
//
// AppKit models roles and subroles as string-backed newtypes exposed under the
// `NSAccessibility` namespace (`NSAccessibility.Role`, `NSAccessibility.Subrole`)
// and as the older global `NSAccessibilityRole` constants. We provide both so
// source written against either spelling compiles unchanged.

/// A string-backed accessibility role, matching `NSAccessibility.Role`.
public struct NSAccessibilityRole: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }

    public static let unknown = NSAccessibilityRole("AXUnknown")
    public static let group = NSAccessibilityRole("AXGroup")
    public static let button = NSAccessibilityRole("AXButton")
    public static let radioButton = NSAccessibilityRole("AXRadioButton")
    public static let checkBox = NSAccessibilityRole("AXCheckBox")
    public static let staticText = NSAccessibilityRole("AXStaticText")
    public static let textField = NSAccessibilityRole("AXTextField")
    public static let textArea = NSAccessibilityRole("AXTextArea")
    public static let slider = NSAccessibilityRole("AXSlider")
    public static let incrementor = NSAccessibilityRole("AXIncrementor")
    public static let image = NSAccessibilityRole("AXImage")
    public static let popUpButton = NSAccessibilityRole("AXPopUpButton")
    public static let menuButton = NSAccessibilityRole("AXMenuButton")
    public static let comboBox = NSAccessibilityRole("AXComboBox")
    public static let progressIndicator = NSAccessibilityRole("AXProgressIndicator")
    public static let levelIndicator = NSAccessibilityRole("AXLevelIndicator")
    public static let colorWell = NSAccessibilityRole("AXColorWell")
    public static let scrollBar = NSAccessibilityRole("AXScrollBar")
    public static let scrollArea = NSAccessibilityRole("AXScrollArea")
    public static let table = NSAccessibilityRole("AXTable")
    public static let outline = NSAccessibilityRole("AXOutline")
    public static let browser = NSAccessibilityRole("AXBrowser")
    public static let list = NSAccessibilityRole("AXList")
    public static let row = NSAccessibilityRole("AXRow")
    public static let column = NSAccessibilityRole("AXColumn")
    public static let cell = NSAccessibilityRole("AXCell")
    public static let disclosureTriangle = NSAccessibilityRole("AXDisclosureTriangle")
    public static let toolbar = NSAccessibilityRole("AXToolbar")
    public static let tabGroup = NSAccessibilityRole("AXTabGroup")
    public static let splitGroup = NSAccessibilityRole("AXSplitGroup")
    public static let splitter = NSAccessibilityRole("AXSplitter")
    public static let menu = NSAccessibilityRole("AXMenu")
    public static let menuItem = NSAccessibilityRole("AXMenuItem")
    public static let menuBar = NSAccessibilityRole("AXMenuBar")
    public static let link = NSAccessibilityRole("AXLink")
    public static let window = NSAccessibilityRole("AXWindow")
    public static let sheet = NSAccessibilityRole("AXSheet")
    public static let application = NSAccessibilityRole("AXApplication")
    public static let busyIndicator = NSAccessibilityRole("AXBusyIndicator")
    public static let ruler = NSAccessibilityRole("AXRuler")
}

/// A string-backed accessibility subrole, matching `NSAccessibility.Subrole`.
public struct NSAccessibilitySubrole: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }

    public static let standardWindow = NSAccessibilitySubrole("AXStandardWindow")
    public static let dialog = NSAccessibilitySubrole("AXDialog")
    public static let systemDialog = NSAccessibilitySubrole("AXSystemDialog")
    public static let closeButton = NSAccessibilitySubrole("AXCloseButton")
    public static let minimizeButton = NSAccessibilitySubrole("AXMinimizeButton")
    public static let zoomButton = NSAccessibilitySubrole("AXZoomButton")
    public static let toolbarButton = NSAccessibilitySubrole("AXToolbarButton")
    public static let secureTextField = NSAccessibilitySubrole("AXSecureTextField")
    public static let searchField = NSAccessibilitySubrole("AXSearchField")
    public static let textLink = NSAccessibilitySubrole("AXTextLink")
    public static let tableRow = NSAccessibilitySubrole("AXTableRow")
    public static let outlineRow = NSAccessibilitySubrole("AXOutlineRow")
    public static let sortButton = NSAccessibilitySubrole("AXSortButton")
    public static let switchSubrole = NSAccessibilitySubrole("AXSwitch")
    public static let toggle = NSAccessibilitySubrole("AXToggle")
}

/// The `NSAccessibility` namespace, mirroring AppKit's nested `Role`/`Subrole`.
public enum NSAccessibility {
    public typealias Role = NSAccessibilityRole
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
