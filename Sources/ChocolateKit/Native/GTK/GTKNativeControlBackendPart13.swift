#if canImport(CGTK)
import CGTK
import CGTKCompat
import Foundation

extension GTKNativeControlBackend {
    public func setSelectionChangeAction(for handle: NativeHandle, action: @escaping (Int) -> Void) {
        if collectionFlows[handle.rawValue] != nil {
            collectionSelectionActions[handle.rawValue] = action
            return
        }
        guard let w = widget(handle) else { return }
        let box = IntActionBox(action)
        if [.table, .outline, .collection].contains(kinds[handle.rawValue]) {
            guard let selection = tableSelections[handle.rawValue] else { return }
            g_signal_connect_data(
                UnsafeMutableRawPointer(selection), "notify::selected",
                unsafeBitCast(gtkTableSelectionChangedTrampoline, to: GCallback.self),
                Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
            )
            return
        }
        if kinds[handle.rawValue] == .segmented {
            // One "toggled" hookup per segment; each box carries its index and
            // only fires on activation (the deactivating peer stays quiet).
            for (index, button) in (segmentButtons[handle.rawValue] ?? []).enumerated() {
                let segmentBox = SegmentBox(index: index, action: action)
                g_signal_connect_data(
                    UnsafeMutableRawPointer(button), "toggled",
                    unsafeBitCast(gtkSegmentToggledTrampoline, to: GCallback.self),
                    Unmanaged.passRetained(segmentBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
                )
            }
            return
        }
        if kinds[handle.rawValue] == .tabView {
            // GtkNotebook reports tab changes via "switch-page" (page index arg).
            g_signal_connect_data(
                UnsafeMutableRawPointer(w), "switch-page",
                unsafeBitCast(gtkSwitchPageTrampoline, to: GCallback.self),
                Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
            )
            return
        }
        // GtkDropDown exposes its selection as the "selected" property.
        g_signal_connect_data(
            UnsafeMutableRawPointer(w), "notify::selected",
            unsafeBitCast(gtkSelectionChangedTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
    }
    /// Records and installs the date-change action; the actual signal binding depends on picker style.
    public func setDateChangeAction(for handle: NativeHandle, action: @escaping (Date) -> Void) {
        dateChangeActions[handle.rawValue] = action
        attachDateChangeAction(action, to: handle)
    }

    /// Binds `action` to the widget currently backing the picker. The graphical
    /// style emits `day-selected`; the compact style reports through its
    /// stepper (`stepDate`), which reads `dateChangeActions` directly.
    internal func attachDateChangeAction(_ action: @escaping (Date) -> Void, to handle: NativeHandle) {
        let raw = handle.rawValue
        guard graphicalDatePickers.contains(raw), let calendar = graphicalCalendars[raw] else { return }
        // Wrap so our own select_day calls (setDateValue) don't report as user edits.
        let wrapped: (Date) -> Void = { [weak self] date in
            guard self?.suppressCalendarReport.contains(raw) != true else { return }
            action(date)
        }
        let box = DateActionBox(wrapped)
        g_signal_connect_data(
            UnsafeMutableRawPointer(calendar), "day-selected",
            unsafeBitCast(gtkDaySelectedTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
    }
    /// Wires a color button's `color-set` signal to `action`.
    public func setColorChangeAction(for handle: NativeHandle, action: @escaping (NSColor) -> Void) {
        guard let w = widget(handle) else { return }
        let box = ColorActionBox(action)
        g_signal_connect_data(
            UnsafeMutableRawPointer(w), "color-set",
            unsafeBitCast(gtkColorSetTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
    }
}

#endif
