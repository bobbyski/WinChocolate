import Foundation

/// AppKit-shaped segmented control, composed from linked native toggle buttons
/// (GTK's segmented-switcher idiom). Select-one tracking; the selected segment
/// index flows both ways.
public final class NSSegmentedControl: NSView {

    /// The segment labels, in order.
    public let segmentLabels: [String]

    /// Number of segments.
    public var segmentCount: Int { segmentLabels.count }

    private var backingSelection = -1

    /// The selected segment index (−1 when nothing is selected yet).
    public var selectedSegment: Int {
        get { backingSelection }
        set {
            backingSelection = newValue
            backend.setSelectedIndex(newValue, for: handle)
        }
    }

    /// Called when the user selects a segment.
    public var onAction: ((NSSegmentedControl) -> Void)?

    /// Segment style (accepted for API parity; GTK styles natively).
    public var segmentStyle: NSSegmentedControlStyle = .automatic
    public var trackingMode: Int = 0

    /// Creates a segmented control with one segment per label.
    public init(labels: [String], frame: NSRect) {
        self.segmentLabels = labels
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createSegmentedControl(labels: labels, frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
        backend.setSelectionChangeAction(for: handle) { [weak self] index in
            guard let self else { return }
            self.backingSelection = index      // sync silently
            self.onAction?(self)
        }
    }

    /// The label of segment `index`.
    public func label(forSegment index: Int) -> String? {
        (index >= 0 && index < segmentLabels.count) ? segmentLabels[index] : nil
    }
}
