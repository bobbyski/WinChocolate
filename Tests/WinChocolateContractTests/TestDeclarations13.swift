import WinChocolate

@MainActor
func testWindowToolbarHeightFollowsDisplayMode() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(20, 30, 320, 220),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 320, 220))
    let toolbar = NSToolbar(identifier: "windowToolbarHeight")
    let item = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("open"))

    item.label = "Open"
    item.image = NSImage(systemSymbolName: "folder", accessibilityDescription: "Open")
    toolbar.addItem(item)
    window.toolbar = toolbar
    window.contentView = contentView

    _ = window.realizeNativePeer()

    expect(window.toolbarHeight == 40, "Default toolbar height should fit icon and label display.")
    expect(contentView.frame == NSMakeRect(0, 40, 320, 180), "Default toolbar height did not reserve icon-and-label space.")

    toolbar.displayMode = .iconOnly

    expect(window.toolbarHeight == 30, "Icon-only toolbar mode should reduce toolbar height.")
    expect(contentView.frame == NSMakeRect(0, 30, 320, 190), "Icon-only toolbar mode did not reduce reserved content space.")

    toolbar.displayMode = .labelOnly

    expect(window.toolbarHeight == 26, "Label-only toolbar mode should reduce toolbar height.")
    expect(contentView.frame == NSMakeRect(0, 26, 320, 194), "Label-only toolbar mode did not reduce reserved content space.")

    toolbar.displayMode = .iconAndLabel
    toolbar.sizeMode = .small

    expect(window.toolbarHeight == 34, "Small icon-and-label toolbar mode should use compact toolbar height.")
    expect(contentView.frame == NSMakeRect(0, 34, 320, 186), "Small toolbar mode did not update reserved content space.")
}

@MainActor
func testEditableTextFieldUsesEditableNativePeer() {
    let backend = InMemoryNativeControlBackend()
    let textField = NSTextField(string: "Seed", frame: NSMakeRect(0, 0, 120, 24))
    textField.isEditable = true

    let handle = textField.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "editableTextField", "Editable text field did not request editable native peer.")
}

@MainActor
func testSecureTextFieldUsesSecureNativePeer() {
    let backend = InMemoryNativeControlBackend()
    let secureField = NSSecureTextField(string: "Secret", frame: NSMakeRect(0, 0, 160, 24))

    expect(secureField.isEditable, "Secure text field should be editable by default.")
    expect(secureField.isSelectable, "Secure text field should be selectable by default.")

    let handle = secureField.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "secureTextField", "Secure text field did not request secure native peer.")
    expect(backend.records[handle]?.text == "Secret", "Secure text field initial string was not sent to backend.")

    secureField.stringValue = "Changed"
    expect(backend.records[handle]?.text == "Changed", "Secure text field changes did not sync to backend.")
}

@MainActor
func testTextViewUsesMultilineNativePeerAndStoresText() {
    let backend = InMemoryNativeControlBackend()
    let textView = NSTextView(frame: NSMakeRect(0, 0, 220, 80))
    textView.string = "Line one"
    textView.insertText("\nLine two")

    let handle = textView.realizeNativePeer(in: backend, parent: nil)

    expect(textView.string == "Line one\nLine two", "Text view did not store multiline text.")
    expect(textView.isEditable, "Text view should default to editable.")
    expect(textView.isSelectable, "Text view should default to selectable.")
    expect(backend.records[handle]?.kind == "editableTextView", "Text view did not request editable native peer.")
    expect(backend.records[handle]?.text == "Line one\nLine two", "Text view text was not synced to backend.")

    textView.setString("Reset")
    expect(backend.records[handle]?.text == "Reset", "Text view setString did not update backend.")
}

@MainActor
func testTextFieldFactoryConstructorsAndCompatibilityProperties() {
    let label = NSTextField.label(withString: "Label")
    let wrappingLabel = NSTextField.wrappingLabel(withString: "Wrapped")
    let textField = NSTextField.textField(withString: "Edit")
    let secureField = NSSecureTextField.secureTextField(withString: "Password")

    textField.placeholderString = "Placeholder"

    expect(label.stringValue == "Label", "Label factory did not set string.")
    expect(!label.isEditable, "Label factory created editable field.")
    expect(!label.isSelectable, "Label factory created selectable field.")
    expect(!label.isBordered, "Label factory created bordered field.")
    expect(!label.drawsBackground, "Label factory enabled background drawing.")
    expect(wrappingLabel.stringValue == "Wrapped", "Wrapping label factory did not set string.")
    expect(textField.stringValue == "Edit", "Text field factory did not set string.")
    expect(textField.isEditable, "Text field factory did not create editable field.")
    expect(textField.isSelectable, "Text field factory did not create selectable field.")
    expect(textField.isBordered, "Text field factory did not create bordered field.")
    expect(textField.drawsBackground, "Text field factory did not enable background drawing.")
    expect(textField.placeholderString == "Placeholder", "Placeholder string was not stored.")
    expect(secureField.stringValue == "Password", "Secure text field factory did not store string.")
    expect(secureField.isEditable, "Secure text field factory did not create editable field.")
    expect(secureField.isSelectable, "Secure text field factory did not create selectable field.")
    expect(secureField.isBordered, "Secure text field factory did not create bordered field.")
    expect(secureField.drawsBackground, "Secure text field factory did not draw background.")

    // Bezel and line-mode properties round-trip for AppKit source compatibility.
    expect(!textField.isBezeled, "isBezeled should default off.")
    expect(textField.bezelStyle == .squareBezel, "bezelStyle should default to square.")
    expect(textField.usesSingleLineMode, "usesSingleLineMode should default on.")
    expect(textField.maximumNumberOfLines == 1, "maximumNumberOfLines should default to 1.")

    textField.isBezeled = true
    textField.bezelStyle = .roundedBezel
    textField.usesSingleLineMode = false
    textField.maximumNumberOfLines = 0
    expect(textField.isBezeled, "isBezeled did not store.")
    expect(textField.bezelStyle == .roundedBezel, "bezelStyle did not store rounded.")
    expect(!textField.usesSingleLineMode, "usesSingleLineMode did not clear.")
    expect(textField.maximumNumberOfLines == 0, "maximumNumberOfLines did not store unlimited.")
}

@MainActor
func testTextFieldMultilineRealizesMultilineEdit() {
    let backend = InMemoryNativeControlBackend()

    // A default editable field realizes single-line.
    let single = NSTextField.textField(withString: "one line")
    let singleHandle = single.realizeNativePeer(in: backend, parent: nil)
    expect(backend.multilineTextFields[singleHandle] == false, "Default editable field should realize single-line.")

    // Clearing single-line mode with room for more than one line realizes multi-line.
    let multi = NSTextField.textField(withString: "wrap me")
    multi.usesSingleLineMode = false
    multi.maximumNumberOfLines = 0
    let multiHandle = multi.realizeNativePeer(in: backend, parent: nil)
    expect(backend.multilineTextFields[multiHandle] == true, "Field did not realize multi-line when single-line mode was cleared.")

    // A label (non-editable) is never multi-line at the edit-peer level.
    let label = NSTextField.label(withString: "label")
    label.usesSingleLineMode = false
    let labelHandle = label.realizeNativePeer(in: backend, parent: nil)
    expect(backend.multilineTextFields[labelHandle] == false, "A non-editable label should not use a multi-line edit peer.")
}

@MainActor
func testFormComposesTextFieldsAndStoresCells() {
    let backend = InMemoryNativeControlBackend()
    let form = NSForm(frame: NSMakeRect(0, 0, 260, 90))
    form.titleWidth = 80

    let name = form.addEntry("Name:")
    let status = form.insertEntry("Status:", at: 1)
    form.setStringValue("WinChocolate", at: 0)
    form.setStringValue("Native", at: 1)

    expect(form.numberOfRows == 2, "Form row count was not stored.")
    expect((form.cell(at: 0) as? NSFormCell) === name, "Form did not return first cell.")
    expect((form.cell(at: 1) as? NSFormCell) === status, "Form did not return inserted cell.")
    expect(form.index(of: status) == 1, "Form did not find cell index.")
    expect(form.textField(at: 0)?.stringValue == "WinChocolate", "Form did not sync first text field value.")
    expect(form.textField(at: 1)?.stringValue == "Native", "Form did not sync second text field value.")
    expect(form.textField(at: 0)?.frame == NSMakeRect(88, 0, 172, 28), "Form did not lay out first text field.")
    expect(!form.acceptsFirstResponder, "Form container should not accept first responder.")

    let handle = form.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[handle]?.kind == "view", "Form did not request a native container view.")
    guard form.subviews.count == 4,
          let firstLabelHandle = form.subviews[0].nativeHandle,
          let firstFieldHandle = form.subviews[1].nativeHandle else {
        expect(false, "Form subviews were not realized.")
        return
    }

    expect(backend.records[firstLabelHandle]?.kind == "textField", "Form label did not use label text field peer.")
    expect(backend.records[firstFieldHandle]?.kind == "editableTextField", "Form entry did not use editable text field peer.")

    backend.textChangeActions[firstFieldHandle]?("Updated")
    expect(name.stringValue == "Updated", "Form cell did not track native text changes.")

    form.removeEntry(at: 0)
    expect(form.numberOfRows == 1, "Form did not remove entry.")
    expect((form.cell(at: 0) as? NSFormCell) === status, "Form did not preserve remaining cell after removal.")
}

@MainActor
func testMatrixComposesButtonsAndTracksSelection() {
    let backend = InMemoryNativeControlBackend()
    let matrix = NSMatrix(
        frame: NSMakeRect(0, 0, 240, 80),
        mode: .radioModeMatrix,
        prototype: NSButtonCell(title: "Choice"),
        numberOfRows: 2,
        numberOfColumns: 2
    )
    var actionCount = 0

    matrix.cellSize = NSMakeSize(100, 28)
    matrix.intercellSpacing = NSMakeSize(8, 6)
    matrix.onAction = { control in
        expect(control === matrix, "Matrix action sender was not matrix.")
        actionCount += 1
    }

    expect(matrix.numberOfRows == 2, "Matrix row count was not stored.")
    expect(matrix.numberOfColumns == 2, "Matrix column count was not stored.")
    expect(matrix.cell(atRow: 0, column: 0)?.stringValue == "Choice 1,1", "Matrix did not create prototype-based cells.")
    expect(matrix.button(atRow: 0, column: 0)?.frame == NSMakeRect(0, 0, 100, 28), "Matrix did not lay out first button.")
    expect(matrix.button(atRow: 1, column: 1)?.frame == NSMakeRect(108, 34, 100, 28), "Matrix did not lay out last button.")
    expect(!matrix.acceptsFirstResponder, "Matrix container should not accept first responder.")

    matrix.selectCell(atRow: 1, column: 0)

    expect(matrix.selectedRow == 1, "Matrix selected row was not stored.")
    expect(matrix.selectedColumn == 0, "Matrix selected column was not stored.")
    expect(matrix.selectedCell()?.stringValue == "Choice 2,1", "Matrix selected cell was not returned.")
    expect(matrix.button(atRow: 1, column: 0)?.state == .on, "Matrix did not sync button state for selected cell.")

    let replacement = NSButtonCell(title: "Custom")
    matrix.putCell(replacement, atRow: 0, column: 1)

    expect(matrix.cell(atRow: 0, column: 1) === replacement, "Matrix did not store replacement cell.")
    expect(matrix.button(atRow: 0, column: 1)?.title == "Custom", "Matrix did not sync replacement title.")

    let handle = matrix.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "view", "Matrix did not request a native container view.")
    guard let customHandle = matrix.button(atRow: 0, column: 1)?.nativeHandle else {
        expect(false, "Matrix button was not realized.")
        return
    }

    expect(backend.records[customHandle]?.kind == "radioButton", "Radio-mode matrix did not realize radio button peers.")

    matrix.button(atRow: 0, column: 1)?.performClick(nil)

    expect(matrix.selectedRow == 0, "Matrix button click did not update selected row.")
    expect(matrix.selectedColumn == 1, "Matrix button click did not update selected column.")
    expect(actionCount == 1, "Matrix button click did not dispatch matrix action.")

    matrix.deselectSelectedCell()

    expect(matrix.selectedRow == -1, "Matrix deselect did not clear selected row.")
    expect(matrix.selectedCell() == nil, "Matrix deselect did not clear selected cell.")
}

@MainActor
func testSwitchButtonUsesCheckboxNativePeer() {
    let backend = InMemoryNativeControlBackend()
    let checkbox = NSButton(title: "Check", frame: NSMakeRect(0, 0, 120, 24))
    checkbox.setButtonType(.switch)
    checkbox.state = .on

    let handle = checkbox.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "checkbox", "Switch button did not request checkbox native peer.")
    expect(backend.records[handle]?.buttonState == .on, "Switch button state was not synced to backend.")
}

@MainActor
func testRadioButtonUsesRadioNativePeer() {
    let backend = InMemoryNativeControlBackend()
    let radioButton = NSButton(title: "Radio", frame: NSMakeRect(0, 0, 120, 24))
    radioButton.setButtonType(.radio)
    radioButton.state = .on

    let handle = radioButton.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "radioButton", "Radio button did not request radio native peer.")
    expect(backend.records[handle]?.buttonState == .on, "Radio button state was not synced to backend.")
}

@MainActor
func testPopUpButtonUsesNativePeerAndSelection() {
    let backend = InMemoryNativeControlBackend()
    let popUpButton = NSPopUpButton(frame: NSMakeRect(0, 0, 140, 80), pullsDown: false)
    popUpButton.addItems(withTitles: ["Info", "Warning", "Critical"])
    popUpButton.selectItem(withTitle: "Warning")

    let handle = popUpButton.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "popUpButton", "Pop-up button did not request native peer.")
    expect(backend.records[handle]?.popUpItems == ["Info", "Warning", "Critical"], "Pop-up button items were not synced.")
    expect(backend.records[handle]?.popUpSelectedIndex == 1, "Pop-up button selection was not synced.")
    expect(popUpButton.titleOfSelectedItem == "Warning", "Pop-up button selected title was not reported.")
}

@MainActor
func testPopUpButtonNativeActionUpdatesSelection() {
    let backend = InMemoryNativeControlBackend()
    let popUpButton = NSPopUpButton(frame: NSMakeRect(0, 0, 140, 80), pullsDown: false)
    popUpButton.addItems(withTitles: ["Info", "Warning", "Critical"])
    let handle = popUpButton.realizeNativePeer(in: backend, parent: nil)
    var actionCount = 0

    popUpButton.onAction = { control in
        expect(control === popUpButton, "Pop-up action sender was not the control.")
        actionCount += 1
    }

    backend.setPopUpButtonSelectedIndex(2, for: handle)
    backend.actions[handle]?()

    expect(popUpButton.indexOfSelectedItem == 2, "Pop-up button did not read native selection.")
    expect(popUpButton.titleOfSelectedItem == "Critical", "Pop-up button selected title did not update.")
    expect(actionCount == 1, "Pop-up button action was not sent.")
}

@MainActor
func testPopUpButtonItemLookupAndRemoval() {
    let popUpButton = NSPopUpButton(frame: NSMakeRect(0, 0, 140, 80), pullsDown: false)

    popUpButton.addItems(withTitles: ["Info", "Warning", "Critical"])
    popUpButton.selectItem(withTitle: "Critical")

    expect(popUpButton.itemTitles == ["Info", "Warning", "Critical"], "Pop-up itemTitles did not match.")
    expect(popUpButton.lastItem == "Critical", "Pop-up lastItem was wrong.")
    expect(popUpButton.indexOfItem(withTitle: "Warning") == 1, "Pop-up index lookup failed.")
    expect(popUpButton.indexOfItem(withTitle: "Missing") == -1, "Pop-up missing index should be -1.")

    popUpButton.removeItem(withTitle: "Warning")

    expect(popUpButton.itemTitles == ["Info", "Critical"], "Pop-up title removal failed.")
    expect(popUpButton.indexOfSelectedItem == 1, "Pop-up selected index was not adjusted after title removal.")

    popUpButton.removeItem(at: 1)

    expect(popUpButton.itemTitles == ["Info"], "Pop-up index removal failed.")
    expect(popUpButton.indexOfSelectedItem == 0, "Pop-up selected index was not clamped after removal.")

    popUpButton.removeItem(at: 0)

    expect(popUpButton.itemTitles.isEmpty, "Pop-up final removal failed.")
    expect(popUpButton.indexOfSelectedItem == -1, "Pop-up selected index was not cleared.")
}

@MainActor
func testComboBoxStoresItemsTextAndUsesNativePeer() {
    let backend = InMemoryNativeControlBackend()
    let comboBox = NSComboBox(frame: NSMakeRect(0, 0, 180, 28))
    comboBox.addItems(withObjectValues: ["Cocoa", "AppKit"])
    comboBox.stringValue = "WinChocolate"

    let handle = comboBox.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "comboBox", "Combo box did not request native peer.")
    expect(backend.records[handle]?.comboBoxItems == ["Cocoa", "AppKit"], "Combo box items were not synced.")
    expect(backend.records[handle]?.text == "WinChocolate", "Combo box text was not synced.")
    expect(comboBox.numberOfItems == 2, "Combo box numberOfItems was wrong.")
    expect(comboBox.indexOfItem(withObjectValue: "AppKit") == 1, "Combo box item lookup failed.")

    comboBox.selectItem(at: 0)
    expect(comboBox.stringValue == "Cocoa", "Combo box selection did not update stringValue.")
}

final class ComboSource: NSObject, NSComboBoxDataSource {
    var values: [String]
    init(_ values: [String]) { self.values = values }
    func numberOfItems(in comboBox: NSComboBox) -> Int { values.count }
    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? { values[index] }
}

@MainActor
func testComboBoxDataSourceSuppliesItems() {
    let backend = InMemoryNativeControlBackend()
    let comboBox = NSComboBox(frame: NSMakeRect(0, 0, 180, 28))
    let source = ComboSource(["One", "Two", "Three"])
    comboBox.dataSource = source
    comboBox.usesDataSource = true

    // Turning on the data source pulls its items.
    expect(comboBox.numberOfItems == 3, "Data-source combo did not pull item count.")
    expect(comboBox.objectValues == ["One", "Two", "Three"], "Data-source combo did not pull item values.")

    // The native peer is realized with the data-source items.
    let handle = comboBox.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[handle]?.comboBoxItems == ["One", "Two", "Three"], "Data-source items were not synced to the peer.")

    // reloadData picks up data-source changes and re-syncs.
    source.values = ["Alpha", "Beta"]
    comboBox.reloadData()
    expect(comboBox.numberOfItems == 2, "reloadData did not refresh the item count.")
    expect(backend.records[handle]?.comboBoxItems == ["Alpha", "Beta"], "reloadData did not re-sync the peer.")

    // hasVerticalScroller round-trips.
    comboBox.hasVerticalScroller = false
    expect(!comboBox.hasVerticalScroller, "hasVerticalScroller did not store.")
}

@MainActor
func testComboBoxNativeTextChangeAndActionUpdateState() {
    let backend = InMemoryNativeControlBackend()
    let comboBox = NSComboBox(frame: NSMakeRect(0, 0, 180, 28))
    // The real delegate surface (controlTextDidChange) observes every
    // native-edit update — the typed change and the commit's text refresh —
    // so record the sequence rather than assuming a single fire.
    var observedTexts: [String] = []
    var actionCount = 0

    comboBox.onComboBoxTextChanged = { combo in
        observedTexts.append(combo.stringValue)
    }
    comboBox.onAction = { control in
        actionCount += 1
        expect((control as? NSComboBox)?.stringValue == "Selected", "Combo box action did not read backend text.")
    }

    let handle = comboBox.realizeNativePeer(in: backend, parent: nil)
    backend.textChangeActions[handle]?("Typed")
    expect(backend.records[handle]?.text == "", "Combo box native text change should not echo text back to the native peer.")
    expect(observedTexts == ["Typed"], "Combo box text-change delegate did not observe the typed text.")
    backend.setText("Selected", for: handle)
    backend.actions[handle]?()

    expect(observedTexts.contains("Typed"), "Combo box text-change callback did not fire for typing.")
    expect(actionCount == 1, "Combo box action callback did not fire.")
}

@MainActor
func testTokenFieldStoresTokensAndTokenizesNativeText() {
    let backend = InMemoryNativeControlBackend()
    let tokenField = NSTokenField(tokens: ["Cocoa", "AppKit"], frame: NSMakeRect(0, 0, 220, 28))
    // A plain-style token field keeps the native editable text peer.
    tokenField.tokenStyle = .plain
    var changedTokens: [String] = []

    tokenField.onTextChanged = { field in
        changedTokens = (field as? NSTokenField)?.tokens ?? []
    }

    let handle = tokenField.realizeNativePeer(in: backend, parent: nil)
    backend.textChangeActions[handle]?("NSWindow, NSView, NSButton")

    expect(backend.records[handle]?.kind == "editableTextField", "Plain token field did not use editable text-field peer.")
    expect(tokenField.tokens == ["NSWindow", "NSView", "NSButton"], "Token field did not tokenize edited text.")
    expect((tokenField.objectValue as? [String]) == tokenField.tokens, "Token field objectValue did not mirror tokens.")
    expect(changedTokens == tokenField.tokens, "Token field text-change callback did not observe tokens.")

    tokenField.tokenizingCharacter = ";"
    tokenField.stringValue = "One; Two"
    tokenField.setTokens(["Cocoa", "WinChocolate"])

    expect(tokenField.tokens == ["Cocoa", "WinChocolate"], "Token field setTokens did not replace tokens.")
    expect(tokenField.stringValue == "Cocoa; WinChocolate", "Token field setTokens did not honor tokenizing character.")

    // A rounded (default) token field draws chips on a view peer.
    let chips = NSTokenField(tokens: ["A", "B"], frame: NSMakeRect(0, 0, 200, 28))
    let chipsHandle = chips.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[chipsHandle]?.kind == "view", "Rounded token field should draw chips on a view peer.")
    expect(chips.tokens == ["A", "B"], "Rounded token field did not keep its token model.")
}

@MainActor
func testTokenFieldChipColorsAreAppearanceAware() {
    // The rounded chips must not stay a fixed light island in dark mode: the
    // whole palette (fill/border/text) flips with appearance, and the chip text
    // inverts so tokens stay legible on the dark capsule.
    let light = NSTokenField.winChipColors(isDark: false)
    let dark = NSTokenField.winChipColors(isDark: true)
    expect(light.fill != dark.fill, "The chip fill must adapt to appearance.")
    expect(light.text == .black && dark.text == .white,
        "Chip text should invert: dark text on the light capsule, light text on the dark one.")
    // The dark capsule is a deep accent fill; the light capsule a pale wash — so
    // the dark fill is meaningfully darker than the light fill.
    expect(dark.fill.redComponent < light.fill.redComponent
        && dark.fill.greenComponent < light.fill.greenComponent
        && dark.fill.blueComponent < light.fill.blueComponent,
        "The dark chip fill should be darker than the light one across all channels.")
}

@MainActor
func testPathControlStoresURLAndPathComponentCells() {
    let backend = InMemoryNativeControlBackend()
    #if os(Windows)
    let packagePath = "C:\\AIResearch\\WinChocolate"
    let codePath = packagePath + "\\Code"
    #else
    let packagePath = "/AIResearch/WinChocolate"
    let codePath = packagePath + "/Code"
    #endif
    let pathControl = NSPathControl(
        url: URL(fileURLWithPath: packagePath),
        frame: NSMakeRect(0, 0, 260, 28)
    )

    let handle = pathControl.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "view", "Path control did not use a breadcrumb container peer.")
    expect(pathControl.stringValue.contains("WinChocolate"), "Path control did not display URL path.")
    expect(pathControl.pathComponentCells.contains { $0.title == "WinChocolate" }, "Path control did not build component cells.")
    expect(pathControl.subviews.compactMap { $0 as? NSButton }.count == pathControl.pathComponentCells.count, "Path control did not compose a breadcrumb button per component.")

    pathControl.setURL(URL(fileURLWithPath: codePath))

    expect(pathControl.stringValue.hasSuffix("Code"), "Path control setURL did not update visible path.")
    expect(pathControl.pathComponentCells.contains { $0.title == "Code" }, "Path control setURL did not refresh component cells.")
}

@MainActor
func testPathControlComponentURLsAndSelection() {
    #if os(Windows)
    let codePath = "C:\\AIResearch\\WinChocolate\\Code"
    #else
    let codePath = "/AIResearch/WinChocolate/Code"
    #endif
    let pathControl = NSPathControl(
        url: URL(fileURLWithPath: codePath),
        frame: NSMakeRect(0, 0, 260, 28)
    )

    // Every component cell carries a cumulative URL ending in its own title.
    expect(!pathControl.pathComponentCells.isEmpty, "Path control produced no component cells.")
    for cell in pathControl.pathComponentCells {
        guard let cellURL = cell.url else {
            expect(false, "Component cell \(cell.title) had no cumulative URL.")
            continue
        }
        expect(cellURL.lastPathComponent == cell.title, "Component cell URL did not end with its own title.")
    }

    // Selecting a component records it, exposes its URL, and fires the action.
    var actionFired = false
    pathControl.onAction = { _ in actionFired = true }
    guard let last = pathControl.pathComponentCells.last else {
        expect(false, "Path control had no last component.")
        return
    }
    let selected = pathControl.selectComponentCell(at: pathControl.pathComponentCells.count - 1)
    expect(selected, "selectComponentCell did not accept a valid index.")
    expect(actionFired, "Selecting a component did not fire the control action.")
    expect(pathControl.clickedPathComponentCell() === last, "Clicked component cell was not recorded.")
    expect(pathControl.clickedPathComponentURL == last.url, "Clicked component URL did not match the cell.")

    // Clicking the composed breadcrumb segment selects the same component.
    let buttons = pathControl.subviews.compactMap { $0 as? NSButton }
    expect(buttons.count == pathControl.pathComponentCells.count, "Breadcrumb button count did not match components.")
    actionFired = false
    buttons.last?.sendAction()
    expect(actionFired, "Clicking a breadcrumb segment did not fire the action.")
    expect(pathControl.clickedPathComponentCell() === last, "Breadcrumb click did not select its component.")

    // An out-of-range selection is rejected.
    expect(!pathControl.selectComponentCell(at: 99), "selectComponentCell should reject an out-of-range index.")

    // Changing the URL clears the recorded click.
    pathControl.setURL(URL(fileURLWithPath: "C:\\AIResearch"))
    expect(pathControl.clickedPathComponentCell() == nil, "Rebuilding components did not clear the clicked cell.")
}

