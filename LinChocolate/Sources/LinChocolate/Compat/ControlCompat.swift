import Foundation

// AppKit control enums + convenience the shared demo uses. Presentational
// hints today (GTK styles controls natively); here for source compatibility.

/// AppKit text alignment.
public enum NSTextAlignment: Sendable {
    case left, right, center, justified, natural
}

/// AppKit control state (`NSControl.StateValue` shape).
public struct NSControlStateValue: Equatable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let off = NSControlStateValue(rawValue: 0)
    public static let on = NSControlStateValue(rawValue: 1)
    public static let mixed = NSControlStateValue(rawValue: -1)
}

/// Bezel styles (accepted, not yet distinctly rendered).
public enum NSButtonBezelStyle: Sendable {
    case rounded, regularSquare, disclosure, shadowlessSquare, circular
    case texturedRounded, recessed, roundRect, inline, smallSquare
}

/// Button types (accepted for API parity).
public enum NSButtonType: Sendable {
    case momentaryLight, pushOnPushOff, toggle, `switch`, radio
    case momentaryChange, onOff, momentaryPushIn
}

/// Segmented-control styles.
public enum NSSegmentedControlStyle: Sendable {
    case automatic, rounded, roundRect, texturedSquare, smallSquare, separated, capsule
}

public extension NSButton {
    /// On/off state mapped to `isOn` (checkboxes/radios).
    var state: NSControlStateValue {
        get { isOn ? .on : .off }
        set { isOn = (newValue == .on) }
    }
    /// Accepted for API parity; the native control picks its own look.
    func setButtonType(_ type: NSButtonType) {}
}

public extension NSTextField {
    /// WinChocolate spells the change hook `onTextChanged`; alias to ours.
    var onTextChanged: ((NSTextField) -> Void)? {
        get { onTextChange }
        set { onTextChange = newValue }
    }
}
