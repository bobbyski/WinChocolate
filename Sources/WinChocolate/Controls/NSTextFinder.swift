/// Find-and-replace actions and shared find state for text views.
///
/// This slice models AppKit's menu-driven find workflow: Edit-menu items
/// carry `NSTextFinder.Action` raw values in their `tag` and dispatch
/// through `NSTextView.performTextFinderAction(_:)`. The classic backend
/// presents a composed app-modal Find panel standing in for the macOS find
/// bar; the search and replacement strings are shared application-wide like
/// the find pasteboard.
open class NSTextFinder: NSObject {
    /// Find actions dispatched through menu item tags, matching AppKit raw values.
    public enum Action: Int {
        /// Shows the find interface.
        case showFindInterface = 1

        /// Selects the next match.
        case nextMatch = 2

        /// Selects the previous match.
        case previousMatch = 3

        /// Replaces every match.
        case replaceAll = 4

        /// Replaces the current match.
        case replace = 5

        /// Replaces the current match and selects the next one.
        case replaceAndFind = 6

        /// Makes the selection the shared search string.
        case setSearchString = 7

        /// Hides the find interface.
        case hideFindInterface = 11

        /// Shows the find interface with replacement controls.
        case showReplaceInterface = 12
    }

    /// The application-wide search string, like AppKit's find pasteboard.
    ///
    /// `win`-prefixed because AppKit shares this state through the pasteboard
    /// rather than an API; programmatic find flows set it directly.
    nonisolated(unsafe) public static var winSharedSearchString = ""

    /// The application-wide replacement string.
    nonisolated(unsafe) public static var winSharedReplacementString = ""
}

extension NSTextView {
    /// Performs the find action carried by a menu item's tag.
    public func performTextFinderAction(_ sender: Any?) {
        guard let tag = (sender as? NSMenuItem)?.tag,
              let action = NSTextFinder.Action(rawValue: tag) else {
            return
        }

        performTextFinderAction(action)
    }

    /// Performs a find action directly.
    public func performTextFinderAction(_ action: NSTextFinder.Action) {
        switch action {
        case .showFindInterface, .showReplaceInterface:
            runFindPanel()
        case .nextMatch:
            findAndSelectMatch(forward: true)
        case .previousMatch:
            findAndSelectMatch(forward: false)
        case .setSearchString:
            let selection = selectedRange
            if selection.length > 0 {
                NSTextFinder.winSharedSearchString = substringForFinding(selection)
            }
        case .replace:
            replaceCurrentMatch()
        case .replaceAndFind:
            replaceCurrentMatch()
            findAndSelectMatch(forward: true)
        case .replaceAll:
            replaceAllMatches()
        case .hideFindInterface:
            break
        }
    }

    // MARK: - Find engine

    /// ASCII case folding per UTF-16 unit keeps indexes stable, which a
    /// `lowercased()` round trip cannot guarantee.
    private func foldedUnits(_ text: String) -> [UInt16] {
        Array(text.utf16).map { unit in
            unit >= 65 && unit <= 90 ? unit + 32 : unit
        }
    }

    private func substringForFinding(_ range: NSRange) -> String {
        let units = Array(string.utf16)
        let location = min(max(0, range.location), units.count)
        let length = min(max(0, range.length), units.count - location)
        return String(decoding: units[location..<(location + length)], as: UTF16.self)
    }

    /// All non-overlapping match locations of the shared search string.
    private func matchLocations() -> (locations: [Int], patternLength: Int) {
        let pattern = foldedUnits(NSTextFinder.winSharedSearchString)
        let haystack = foldedUnits(string)
        guard !pattern.isEmpty, pattern.count <= haystack.count else {
            return ([], pattern.count)
        }

        var locations: [Int] = []
        var index = 0
        while index <= haystack.count - pattern.count {
            if Array(haystack[index..<(index + pattern.count)]) == pattern {
                locations.append(index)
                index += pattern.count
            } else {
                index += 1
            }
        }
        return (locations, pattern.count)
    }

    /// Selects the next or previous match, wrapping around the text.
    private func findAndSelectMatch(forward: Bool) {
        let (locations, patternLength) = matchLocations()
        guard !locations.isEmpty else {
            return
        }

        let selection = selectedRange
        let match: Int
        if forward {
            let start = selection.location + selection.length
            match = locations.first { $0 >= start } ?? locations[0]
        } else {
            match = locations.last { $0 < selection.location } ?? locations[locations.count - 1]
        }

        selectedRange = NSMakeRange(match, patternLength)
    }

    /// Replaces the selection when it matches the search string.
    private func replaceCurrentMatch() {
        let selection = selectedRange
        guard selection.length > 0,
              foldedUnits(substringForFinding(selection)) == foldedUnits(NSTextFinder.winSharedSearchString) else {
            return
        }

        insertText(NSTextFinder.winSharedReplacementString, replacementRange: selection)
    }

    /// Replaces every match, back to front so locations stay valid.
    private func replaceAllMatches() {
        let (locations, patternLength) = matchLocations()
        for location in locations.reversed() {
            insertText(NSTextFinder.winSharedReplacementString, replacementRange: NSMakeRange(location, patternLength))
        }
    }

    // MARK: - Find panel

    /// Runs the composed Find panel as an app-modal session.
    ///
    /// Find Next/Previous and Replace act on this text view while the panel
    /// is up; Done dismisses it. The panel stands in for the macOS find bar
    /// under the classic presentation compromise.
    private func runFindPanel() {
        let application = NSApplication.shared
        let width: CGFloat = 480
        let content = NSView(frame: NSMakeRect(0, 0, width, 152))
        content.backgroundColor = .windowBackgroundColor

        func label(_ text: String, y: CGFloat) -> NSTextField {
            let field = NSTextField(string: text, frame: NSMakeRect(20, y, 82, 24))
            field.isBordered = false
            field.drawsBackground = false
            return field
        }

        let findField = NSTextField(string: NSTextFinder.winSharedSearchString, frame: NSMakeRect(110, 20, 350, 28))
        findField.isEditable = true
        findField.isSelectable = true
        let replaceField = NSTextField(string: NSTextFinder.winSharedReplacementString, frame: NSMakeRect(110, 58, 350, 28))
        replaceField.isEditable = true
        replaceField.isSelectable = true
        content.addSubview(label("Find:", y: 22))
        content.addSubview(findField)
        content.addSubview(label("Replace:", y: 60))
        content.addSubview(replaceField)

        func syncSharedStrings() {
            NSTextFinder.winSharedSearchString = findField.stringValue
            NSTextFinder.winSharedReplacementString = replaceField.stringValue
        }

        func addButton(_ title: String, x: CGFloat, width buttonWidth: CGFloat, action: @escaping () -> Void) {
            let button = NSButton(title: title, frame: NSMakeRect(x, 104, buttonWidth, 28))
            button.onAction = { _ in
                syncSharedStrings()
                action()
            }
            content.addSubview(button)
        }

        addButton("Replace All", x: 20, width: 104) { [weak self] in
            self?.replaceAllMatches()
        }
        addButton("Replace", x: 132, width: 88) { [weak self] in
            self?.replaceCurrentMatch()
        }
        addButton("Previous", x: 228, width: 88) { [weak self] in
            self?.findAndSelectMatch(forward: false)
        }
        addButton("Next", x: 324, width: 60) { [weak self] in
            self?.findAndSelectMatch(forward: true)
        }
        addButton("Done", x: 392, width: 68) {
            application.stopModal(withCode: .OK)
        }

        // Sheet-style placement under the owning window's title area.
        var origin = NSMakePoint(360, 280)
        if let parent = window {
            origin = NSMakePoint(
                parent.frame.origin.x + max((parent.frame.size.width - width) / 2, 0),
                parent.frame.origin.y + 56
            )
        }
        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: NSMakeSize(width, 152)),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        panel.title = "Find"
        panel.contentView = content

        _ = application.runModal(for: panel)
        syncSharedStrings()
        panel.close()
    }
}
