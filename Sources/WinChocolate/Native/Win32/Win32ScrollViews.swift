#if os(Windows)
extension Win32NativeControlBackend {
    /// Creates a native scroll-view child.
    public func createScrollView(frame: NSRect, parent: NativeHandle?, hasVerticalScroller: Bool, hasHorizontalScroller: Bool) -> NativeHandle {
        registerViewClassIfNeeded()
        // A programmatically created AppKit `NSScrollView` has `borderType ==
        // .noBorder`; match that (a bordered type is opt-in via `borderType`).
        var style = wsChild | wsVisible | wsClipChildren
        if hasVerticalScroller {
            style |= wsVScroll
        }
        if hasHorizontalScroller {
            style |= wsHScroll
        }

        return createChildWindow(
            className: winChocolateViewClassName,
            text: "",
            frame: frame,
            parent: parent,
            commandIdentifier: nil,
            style: style
        )
    }

    /// Updates native scroll-view document and viewport geometry.
    public func setScrollViewContentSize(_ contentSize: NSSize, viewportSize: NSSize, hasVerticalScroller: Bool, hasHorizontalScroller: Bool, for handle: NativeHandle) {
        scrollViewMetrics[handle.rawValue] = (
            contentSize,
            viewportSize,
            hasVerticalScroller,
            hasHorizontalScroller,
            scrollViewMetrics[handle.rawValue]?.offset ?? NSZeroPoint
        )
        updateScrollViewBars(for: handle)
    }

    /// Updates the native scroll-view visible document origin.
    public func setScrollViewContentOffset(_ offset: NSPoint, for handle: NativeHandle) {
        guard var metrics = scrollViewMetrics[handle.rawValue] else {
            return
        }

        let maxX = max(0, metrics.contentSize.width - metrics.viewportSize.width)
        let maxY = max(0, metrics.contentSize.height - metrics.viewportSize.height)
        metrics.offset = NSPoint(
            x: min(max(offset.x, 0), maxX),
            y: min(max(offset.y, 0), maxY)
        )
        scrollViewMetrics[handle.rawValue] = metrics
        updateScrollViewBars(for: handle)
    }

    /// Reads the native scroll-view visible document origin.
    public func scrollViewContentOffset(for handle: NativeHandle) -> NSPoint {
        scrollViewMetrics[handle.rawValue]?.offset ?? NSZeroPoint
    }

    func updateScrollViewBars(for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle), let metrics = scrollViewMetrics[handle.rawValue] else {
            return
        }

        if metrics.hasHorizontalScroller {
            setWindowScrollInfo(
                hwnd: hwnd,
                bar: sbHorz,
                contentLength: metrics.contentSize.width,
                viewportLength: metrics.viewportSize.width,
                position: metrics.offset.x
            )
        }

        if metrics.hasVerticalScroller {
            setWindowScrollInfo(
                hwnd: hwnd,
                bar: sbVert,
                contentLength: metrics.contentSize.height,
                viewportLength: metrics.viewportSize.height,
                position: metrics.offset.y
            )
        }
    }

    private func setWindowScrollInfo(hwnd: HWND?, bar: Int32, contentLength: Double, viewportLength: Double, position: Double) {
        let content = max(0, Int32(contentLength.rounded()))
        let viewport = max(1, Int32(viewportLength.rounded()))
        let maximum = max(0, content - 1)
        let maxPosition = max(0, content - viewport)
        var scrollInfo = SCROLLINFO(
            cbSize: UINT(MemoryLayout<SCROLLINFO>.size),
            fMask: sifRange | sifPage | sifPos,
            nMin: 0,
            nMax: maximum,
            nPage: UINT(viewport),
            nPos: min(max(Int32(position.rounded()), 0), maxPosition),
            nTrackPos: 0
        )
        withUnsafePointer(to: &scrollInfo) { pointer in
            _ = winSetScrollInfo(hwnd, bar, pointer, 1)
        }
    }
}
#endif
