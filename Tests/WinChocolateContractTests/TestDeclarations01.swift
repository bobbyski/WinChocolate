import WinChocolate

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fatalError(message)
    }
}

func requireValue<T>(_ value: T?, _ message: String) -> T {
    guard let value else {
        fatalError(message)
    }
    return value
}

func requireNoThrow<T>(_ operation: () throws -> T, _ message: String) -> T {
    do {
        return try operation()
    } catch {
        fatalError("\(message): \(error)")
    }
}

extension NSButton {
    convenience init(title: String, frame: NSRect) {
        self.init(frame: frame)
        self.title = title
    }

    convenience init(checkboxWithTitle title: String, frame: NSRect) {
        self.init(checkboxWithTitle: title, target: nil, action: nil)
        self.frame = frame
    }

    convenience init(radioButtonWithTitle title: String, frame: NSRect) {
        self.init(radioButtonWithTitle: title, target: nil, action: nil)
        self.frame = frame
    }
}

extension NSTextField {
    convenience init(string: String, frame: NSRect) {
        self.init(frame: frame)
        self.stringValue = string
    }

    convenience init(labelWithString string: String, frame: NSRect) {
        self.init(labelWithString: string)
        self.frame = frame
    }
}

extension NSSegmentedControl {
    convenience init(labels: [String], frame: NSRect) {
        self.init(labels: labels, trackingMode: .selectOne, target: nil, action: nil)
        self.frame = frame
    }
}

extension NSDatePicker {
    convenience init(date: Date, frame: NSRect) {
        self.init(frame: frame)
        self.dateValue = date
    }
}

extension NSTokenField {
    convenience init(tokens: [String], frame: NSRect) {
        self.init(frame: frame)
        self.objectValue = tokens
    }
}

extension NSPathControl {
    convenience init(url: URL?, frame: NSRect) {
        self.init(frame: frame)
        // Assign through a method: property observers are suppressed for
        // direct assignments inside an initializer, and `url`'s observer
        // builds the breadcrumb.
        applyTestURL(url)
    }

    private func applyTestURL(_ url: URL?) {
        self.url = url
    }
}

extension NSBox {
    convenience init(title: String, frame: NSRect) {
        self.init(frame: frame)
        self.title = title
    }
}

final class TestActionTarget: NSObject {
    nonisolated(unsafe) static var retained: [ObjectIdentifier: TestActionTarget] = [:]

    var handlers: [String: (Any?) -> Void] = [:]

    static func trampoline(for sender: NSObject) -> TestActionTarget {
        if let existing = retained[ObjectIdentifier(sender)] {
            return existing
        }

        let created = TestActionTarget()
        retained[ObjectIdentifier(sender)] = created
        return created
    }

    override func responds(to aSelector: Selector?) -> Bool {
        guard let aSelector else {
            return false
        }

        return handlers[aSelector.name] != nil || super.responds(to: aSelector)
    }

    @discardableResult
    override func perform(_ aSelector: Selector, with object: Any?) -> Any? {
        guard let handler = handlers[aSelector.name] else {
            return super.perform(aSelector, with: object)
        }

        handler(object)
        return nil
    }

    static let fireSelector = Selector("testFire:")
    static let doubleFireSelector = Selector("testFireDouble:")
}

extension NSControl {
    var onAction: ((NSControl) -> Void)? {
        get { nil }
        set {
            guard let newValue else {
                TestActionTarget.retained.removeValue(forKey: ObjectIdentifier(self))
                target = nil
                action = nil
                return
            }

            let trampoline = TestActionTarget.trampoline(for: self)
            trampoline.handlers["testFire:"] = { [weak self] sender in
                if let control = (sender as? NSControl) ?? self {
                    newValue(control)
                }
            }
            target = trampoline
            action = TestActionTarget.fireSelector
        }
    }
}

extension NSMenuItem {
    var onAction: ((NSMenuItem) -> Void)? {
        get { nil }
        set {
            guard let newValue else {
                TestActionTarget.retained.removeValue(forKey: ObjectIdentifier(self))
                target = nil
                action = nil
                return
            }

            let trampoline = TestActionTarget.trampoline(for: self)
            trampoline.handlers["testFire:"] = { [weak self] sender in
                if let item = (sender as? NSMenuItem) ?? self {
                    newValue(item)
                }
            }
            target = trampoline
            action = TestActionTarget.fireSelector
        }
    }
}

extension NSToolbarItem {
    var onAction: ((NSToolbarItem) -> Void)? {
        get { nil }
        set {
            guard let newValue else {
                TestActionTarget.retained.removeValue(forKey: ObjectIdentifier(self))
                target = nil
                action = nil
                return
            }

            let trampoline = TestActionTarget.trampoline(for: self)
            trampoline.handlers["testFire:"] = { [weak self] sender in
                if let item = (sender as? NSToolbarItem) ?? self {
                    newValue(item)
                }
            }
            target = trampoline
            action = TestActionTarget.fireSelector
        }
    }
}

extension NSTableView {
    var onDoubleAction: ((NSTableView) -> Void)? {
        get { nil }
        set {
            guard let newValue else {
                doubleAction = nil
                return
            }

            let trampoline = TestActionTarget.trampoline(for: self)
            trampoline.handlers["testFireDouble:"] = { [weak self] sender in
                if let table = (sender as? NSTableView) ?? self {
                    newValue(table)
                }
            }
            target = trampoline
            doubleAction = TestActionTarget.doubleFireSelector
        }
    }
}

final class TestChangeDelegate: NSObject, NSTextFieldDelegate, NSTableViewDelegate, NSOutlineViewDelegate, NSTextViewDelegate, NSTabViewDelegate {
    nonisolated(unsafe) static var retained: [ObjectIdentifier: TestChangeDelegate] = [:]

    nonisolated(unsafe) var onFieldChange: ((NSTextField) -> Void)?
    nonisolated(unsafe) var onTableSelection: ((NSTableView) -> Void)?
    nonisolated(unsafe) var onOutlineSelection: ((NSOutlineView) -> Void)?
    nonisolated(unsafe) var onTextViewChange: ((NSTextView) -> Void)?
    nonisolated(unsafe) var onTabSelection: ((NSTabView) -> Void)?

    static func trampoline(for owner: NSObject) -> TestChangeDelegate {
        if let existing = retained[ObjectIdentifier(owner)] {
            return existing
        }

        let created = TestChangeDelegate()
        retained[ObjectIdentifier(owner)] = created
        return created
    }

    nonisolated func controlTextDidChange(_ obj: Notification) {
        if let field = obj.object as? NSTextField {
            onFieldChange?(field)
        }
    }

    nonisolated func tableViewSelectionDidChange(_ notification: Notification) {
        if let table = notification.object as? NSTableView {
            onTableSelection?(table)
        }
    }

    nonisolated func outlineViewSelectionDidChange(_ notification: Notification) {
        if let outline = notification.object as? NSOutlineView {
            onOutlineSelection?(outline)
        }
    }

    nonisolated func textDidChange(_ notification: Notification) {
        if let view = notification.object as? NSTextView {
            onTextViewChange?(view)
        }
    }

    nonisolated func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        _ = tabViewItem
        onTabSelection?(tabView)
    }
}

extension NSTabView {
    @MainActor var onSelectionChanged: ((NSTabView) -> Void)? {
        get { nil }
        set {
            let trampoline = TestChangeDelegate.trampoline(for: self)
            trampoline.onTabSelection = newValue
            delegate = trampoline
        }
    }
}

extension NSTextField {
    @MainActor var onTextChanged: ((NSTextField) -> Void)? {
        get { nil }
        set {
            let trampoline = TestChangeDelegate.trampoline(for: self)
            trampoline.onFieldChange = newValue
            delegate = trampoline
        }
    }
}

extension NSComboBox {
    @MainActor var onComboBoxTextChanged: ((NSComboBox) -> Void)? {
        get { nil }
        set {
            guard let newValue else {
                onTextChanged = nil
                return
            }

            onTextChanged = { field in
                if let combo = field as? NSComboBox {
                    newValue(combo)
                }
            }
        }
    }
}

extension NSTextView {
    @MainActor var onTextChanged: ((NSTextView) -> Void)? {
        get { nil }
        set {
            let trampoline = TestChangeDelegate.trampoline(for: self)
            trampoline.onTextViewChange = newValue
            delegate = trampoline
        }
    }
}

extension NSTableView {
    @MainActor var onSelectionChanged: ((NSTableView) -> Void)? {
        get { nil }
        set {
            let trampoline = TestChangeDelegate.trampoline(for: self)
            trampoline.onTableSelection = newValue
            delegate = trampoline
        }
    }
}

@MainActor
func winClose(_ a: CGFloat, _ b: CGFloat, _ tol: CGFloat = 0.5) -> Bool {
    abs(a - b) < tol
}

@MainActor
func testAutoLayoutPinsEdgesFixedSizeAndCenter() {
    // Pinning all four edges to the superview with insets sizes and positions
    // the subview exactly.
    let container = NSView(frame: NSMakeRect(0, 0, 200, 100))
    let box = NSView(frame: .zero)
    box.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(box)
    NSLayoutConstraint.activate([
        box.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
        box.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
        box.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
        box.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
    ])
    container.layoutSubtreeIfNeeded()
    expect(winClose(box.frame.origin.x, 10) && winClose(box.frame.origin.y, 20)
        && winClose(box.frame.size.width, 180) && winClose(box.frame.size.height, 60),
        "Edge-pinned subview frame wrong: got \(box.frame).")

    // Fixed size + centering places the subview centered in the container.
    let centered = NSView(frame: .zero)
    centered.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(centered)
    NSLayoutConstraint.activate([
        centered.widthAnchor.constraint(equalToConstant: 50),
        centered.heightAnchor.constraint(equalToConstant: 30),
        centered.centerXAnchor.constraint(equalTo: container.centerXAnchor),
        centered.centerYAnchor.constraint(equalTo: container.centerYAnchor),
    ])
    container.layoutSubtreeIfNeeded()
    expect(winClose(centered.frame.origin.x, 75) && winClose(centered.frame.origin.y, 35)
        && winClose(centered.frame.size.width, 50) && winClose(centered.frame.size.height, 30),
        "Fixed-size centered subview frame wrong: got \(centered.frame).")
}

final class IntrinsicSizeView: NSView {
    var intrinsic: NSSize
    init(_ size: NSSize) {
        intrinsic = size
        super.init(frame: .zero)
    }
    required init(frame frameRect: NSRect) {
        intrinsic = .zero
        super.init(frame: frameRect)
    }
    override var intrinsicContentSize: NSSize { intrinsic }
}

@MainActor
func testAutoLayoutIntrinsicContentSize() {
    // A constraint-driven view with an intrinsic size and no size constraints
    // sizes itself to the intrinsic size (hugging + compression resistance).
    let container = NSView(frame: NSMakeRect(0, 0, 200, 100))
    let label = IntrinsicSizeView(NSSize(width: 80, height: 24))
    label.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(label)
    NSLayoutConstraint.activate([
        label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        label.topAnchor.constraint(equalTo: container.topAnchor),
    ])
    container.layoutSubtreeIfNeeded()
    expect(winClose(label.frame.size.width, 80) && winClose(label.frame.size.height, 24),
        "Intrinsic-size view should adopt its intrinsic size: got \(label.frame.size).")

    // Compression resistance (defaultHigh) beats a low-priority smaller width.
    let label2 = IntrinsicSizeView(NSSize(width: 80, height: 24))
    label2.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(label2)
    let small = label2.widthAnchor.constraint(equalToConstant: 40)
    small.priority = .defaultLow
    NSLayoutConstraint.activate([
        label2.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        label2.topAnchor.constraint(equalTo: container.topAnchor),
        small,
    ])
    container.layoutSubtreeIfNeeded()
    expect(label2.frame.size.width >= 79,
        "Compression resistance should keep width at the intrinsic 80 over a low-priority 40: got \(label2.frame.size.width).")

    // A required width overrides the intrinsic size entirely.
    let label3 = IntrinsicSizeView(NSSize(width: 80, height: 24))
    label3.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(label3)
    NSLayoutConstraint.activate([
        label3.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        label3.topAnchor.constraint(equalTo: container.topAnchor),
        label3.widthAnchor.constraint(equalToConstant: 150),
    ])
    container.layoutSubtreeIfNeeded()
    expect(winClose(label3.frame.size.width, 150),
        "A required width should override the intrinsic size: got \(label3.frame.size.width).")

    // A real NSTextField reports an intrinsic size derived from its text, so
    // Auto Layout can size labels without an explicit width.
    let shortLabel = NSTextField(string: "Hi", frame: .zero)
    let longLabel = NSTextField(string: "A considerably longer label", frame: .zero)
    expect(shortLabel.intrinsicContentSize.width > 0 && shortLabel.intrinsicContentSize.height > 0,
        "An NSTextField should report a positive intrinsic size: got \(shortLabel.intrinsicContentSize).")
    expect(longLabel.intrinsicContentSize.width > shortLabel.intrinsicContentSize.width,
        "A longer label should have a wider intrinsic width.")
}

@MainActor
func testGridViewContentSizingAndPlacement() {
    func iv(_ w: CGFloat, _ h: CGFloat) -> IntrinsicSizeView { IntrinsicSizeView(NSSize(width: w, height: h)) }

    // A 2×2 grid: columns size to the widest content, rows to the tallest.
    let c00 = iv(30, 20), c01 = iv(50, 20)
    let c10 = iv(60, 24), c11 = iv(40, 16)
    let grid = NSGridView(views: [[c00, c01], [c10, c11]])
    grid.columnSpacing = 10
    grid.rowSpacing = 8
    grid.layoutSubtreeIfNeeded()

    // Column widths: col0 = max(30,60)=60, col1 = max(50,40)=50.
    // Row heights: row0 = max(20,20)=20, row1 = max(24,16)=24.
    // Intrinsic: 60+50+10 = 120 wide, 20+24+8 = 52 tall.
    expect(winClose(grid.intrinsicContentSize.width, 120) && winClose(grid.intrinsicContentSize.height, 52),
        "Grid intrinsic size wrong: got \(grid.intrinsicContentSize).")
    // Default placement is x=.leading, y=.center.
    expect(winClose(c00.frame.origin.x, 0) && winClose(c00.frame.origin.y, 0),
        "Cell (0,0) wrong: got \(c00.frame).")
    expect(winClose(c01.frame.origin.x, 70) && winClose(c01.frame.origin.y, 0),
        "Cell (1,0) should start after col0 + spacing (70): got \(c01.frame).")
    expect(winClose(c10.frame.origin.y, 28),
        "Cell (0,1) should start after row0 + spacing (28): got \(c10.frame.origin.y).")
    // c11 (40×16) centered vertically in the 24-tall row: y = 28 + (24-16)/2 = 32.
    expect(winClose(c11.frame.origin.x, 70) && winClose(c11.frame.origin.y, 32),
        "Cell (1,1) should be x=70, y-centered at 32: got \(c11.frame).")

    // Placement within a wider (explicit) column.
    let only = iv(40, 20)
    let g2 = NSGridView(views: [[only]])
    g2.column(at: 0).width = 100
    g2.xPlacement = .trailing
    g2.layoutSubtreeIfNeeded()
    expect(winClose(only.frame.origin.x, 60), "Trailing placement should right-align (x=60): got \(only.frame.origin.x).")
    g2.xPlacement = .center
    g2.layoutSubtreeIfNeeded()
    expect(winClose(only.frame.origin.x, 30), "Center placement should center (x=30): got \(only.frame.origin.x).")
    g2.xPlacement = .fill
    g2.layoutSubtreeIfNeeded()
    expect(winClose(only.frame.origin.x, 0) && winClose(only.frame.size.width, 100),
        "Fill placement should stretch to the column width: got \(only.frame).")
}

@MainActor
func testGridViewCellMergingSpans() {
    func iv(_ w: CGFloat, _ h: CGFloat) -> IntrinsicSizeView { IntrinsicSizeView(NSSize(width: w, height: h)) }

    // Row 0 is a header that spans all three columns; row 1 has the real cells.
    let header = iv(50, 20)
    let a = iv(40, 20), b = iv(60, 20), c = iv(30, 20)
    let grid = NSGridView(views: [[header], [a, b, c]])
    grid.columnSpacing = 10
    grid.rowSpacing = 8
    grid.xPlacement = .fill
    grid.mergeCells(inHorizontalRange: NSMakeRange(0, 3), verticalRange: NSMakeRange(0, 1))
    grid.layoutSubtreeIfNeeded()

    // Columns come from row 1 (merged cells excluded): 40 / 60 / 30, spacing 10.
    // Total width = 40+60+30 + 20 = 150; the header spans all of it.
    expect(winClose(header.frame.origin.x, 0) && winClose(header.frame.size.width, 150),
        "Merged header should span the full width (150): got \(header.frame).")
    // Row 1 begins below the header row (20 + 8 = 28).
    expect(winClose(b.frame.origin.x, 50) && winClose(c.frame.origin.x, 120) && winClose(a.frame.origin.y, 28),
        "Row-1 cells wrong under the merged header: a=\(a.frame) b=\(b.frame) c=\(c.frame).")

    // Unmerging restores per-cell placement of the head content.
    grid.unmergeCells(atColumnIndex: 0, rowIndex: 0)
    grid.layoutSubtreeIfNeeded()
    // Column 0 now sizes to max(header 50, a 40) = 50; the header no longer spans.
    expect(winClose(header.frame.size.width, 50),
        "After unmerge the header should occupy just its own column (50): got \(header.frame.size.width).")
}

