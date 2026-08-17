// Part of the shared demo, split out of main.swift by topic.
//
// Only DECLARATIONS live here. main.swift is Swift's top-level-code file:
// its statements run in written order, and moving one here would turn it
// into a lazily-initialized global that never runs. Declarations have no
// such ordering, so they move freely.

#if canImport(WASMChocolate)
import WASMChocolate
#elseif canImport(LinChocolate)
import LinChocolate
#elseif canImport(WinChocolate)
import WinChocolate
#else
import AppKit
#endif

func modifierText(for event: NSEvent) -> String {
    var names: [String] = []
    if event.modifierFlags.contains(.shift) {
        names.append("shift")
    }
    if event.modifierFlags.contains(.control) {
        names.append("control")
    }
    if event.modifierFlags.contains(.option) {
        names.append("option")
    }
    if event.modifierFlags.contains(.command) {
        names.append("command")
    }
    return names.isEmpty ? "" : " [" + names.joined(separator: "+") + "]"
}

func keyName(for keyCode: UInt16) -> String? {
    switch keyCode {
    case 0x08:
        return "Backspace"
    case 0x09:
        return "Tab"
    case 0x0d:
        return "Enter"
    case 0x10:
        return "Shift"
    case 0x11:
        return "Control"
    case 0x12:
        return "Alt"
    case 0x1b:
        return "Escape"
    case 0x20:
        return "Space"
    case 0x21:
        return "Page Up"
    case 0x22:
        return "Page Down"
    case 0x23:
        return "End"
    case 0x24:
        return "Home"
    case 0x26:
        return "Up"
    case 0x28:
        return "Down"
    case 0x5b:
        return "Left Windows"
    case 0x5c:
        return "Right Windows"
    case 0xa0:
        return "Left Shift"
    case 0xa1:
        return "Right Shift"
    case 0xa2:
        return "Left Control"
    case 0xa3:
        return "Right Control"
    case 0xa4:
        return "Left Alt"
    case 0xa5:
        return "Right Alt"
    default:
        return nil
    }
}

func printableCharacterText(for event: NSEvent) -> String {
    guard let characters = event.characters, !characters.isEmpty else {
        return ""
    }

    switch characters {
    case "\t":
        return " <tab>"
    case "\n":
        return " <enter>"
    case "\u{1b}":
        return " <escape>"
    case "\u{8}":
        return " <backspace>"
    default:
        return " '\(characters)'"
    }
}

func keyText(for event: NSEvent) -> String {
    let code = event.keyCode
    let name = keyName(for: code).map { " \($0)" } ?? ""
    return "\(code)\(name)\(printableCharacterText(for: event))\(modifierText(for: event))"
}

@MainActor
func focusName() -> String {
    guard let responder = window.firstResponder else {
        return "none"
    }

    if responder === contentView {
        return "content"
    }
    if responder === editableTextField {
        return "text field"
    }
    if responder === secureTextField {
        return "secure text field"
    }
    if responder === button {
        return "click button"
    }
    if responder === enableButton {
        return "disable button"
    }
    if responder === hideButton {
        return "hide button"
    }
    if responder === moveButton {
        return "move button"
    }
    if responder === panelButton {
        return "panel button"
    }
    if responder === popoverButton {
        return "popover button"
    }
    if responder === alertButton {
        return "alert button"
    }
    if responder === titleCheckbox {
        return "title checkbox"
    }
    if responder === alertStylePopup {
        return "alert style popup"
    }
    if responder === infoRadio {
        return "info radio"
    }
    if responder === warningRadio {
        return "warning radio"
    }
    if responder === criticalRadio {
        return "critical radio"
    }
    if responder === notesTextView {
        return "notes"
    }
    if responder === tokenField {
        return "token field"
    }
    // NSForm and NSMatrix are cell-based on Apple — focus inside them is
    // identified by containment, not by child-view identity.
    if let view = responder as? NSView, view.isDescendant(of: form) {
        return "form"
    }
    if let view = responder as? NSView, view.isDescendant(of: matrix) {
        return "matrix"
    }
    if responder === slider {
        return "slider"
    }
    if responder === stepper {
        return "stepper"
    }
    if responder === comboBox {
        return "combo box"
    }
    if responder === searchField {
        return "search field"
    }
    if responder === toolbarSearchField {
        return "toolbar search"
    }
    if responder === levelIndicator {
        return "level indicator"
    }
    if responder === colorWell {
        return "color well"
    }
    if responder === segmentedControl {
        return "segments"
    }
    if responder === scroller {
        return "scroller"
    }
    if responder === datePicker {
        return "date picker"
    }
    if responder === clipHomeButton {
        return "clip home"
    }
    if responder === clipCenterButton {
        return "clip center"
    }
    if responder === clipCornerButton {
        return "clip corner"
    }
    if responder === pathControl {
        return "path control"
    }
    if responder === collectionView {
        return "collection view"
    }
    if responder === visualEffectButton {
        return "visual effect button"
    }
    if responder === scrollSelectedButton {
        return "scroll selected"
    }
    if responder === pageSelector {
        return "page selector"
    }
    if responder === tableView {
        return "table view"
    }
    if responder === outlineView {
        return "outline view"
    }
    return "view"
}

@MainActor
func updateFocusDisplay() {
    let name = focusName()
    focusLabel.stringValue = "Focus: \(name)"
    // The content view is the container for every page, so tinting its whole
    // background on focus turns the entire app blue (and shows through/around the
    // pages on resize and tab switches, reading as a repaint bug). Keep the
    // container at its normal color and show content focus only via the label
    // above; the small input controls below still demo their own focus tint.
    // Resolve the surface from the live appearance (windowBackgroundColor is
    // dynamic) — a cached launch value would clobber the content background back
    // to the old shade after a system switch.
    contentView.backgroundColor = NSColor.windowBackgroundColor
    // Resolve the focus tint from the live appearance so a system switch while a
    // field is focused rebuilds its brush at the new shade.
    let controlFocusColor = NSApplication.shared.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        ? NSColor(calibratedRed: 0.35, green: 0.32, blue: 0.12, alpha: 1.0)
        : NSColor(calibratedRed: 1.0, green: 0.96, blue: 0.72, alpha: 1.0)
    editableTextField.backgroundColor = name == "text field"
        ? controlFocusColor
        : normalTextFieldColor
    secureTextField.backgroundColor = name == "secure text field"
        ? controlFocusColor
        : normalTextFieldColor
    searchField.backgroundColor = name == "search field"
        ? controlFocusColor
        : normalTextFieldColor
    tokenField.backgroundColor = name == "token field"
        ? controlFocusColor
        : normalTextFieldColor
    pathControl.backgroundColor = name == "path control"
        ? controlFocusColor
        : normalTextFieldColor
}

@MainActor
func configureToolbarKeyLoop() {
    popoverButton.nextKeyView = editableTextField
}
