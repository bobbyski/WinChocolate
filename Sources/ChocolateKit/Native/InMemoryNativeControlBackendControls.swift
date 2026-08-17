// Control-related recording helpers that no backend needs to override.
//
// Everything a subclass has to intercept — the creators and the writers — lives
// in the class body in `InMemoryNativeControlBackendState.swift` instead, under
// the "Overridable core seam" MARK. Swift cannot override a method declared in
// an extension, so a method's file here is a statement that no backend will ever
// replace it: these are test simulations and derived getters.
extension InMemoryNativeControlBackend {
    /// Simulates a title-bar close request, honoring the veto handler.
    @discardableResult
    public func requestWindowClose(_ handle: NativeHandle) -> Bool {
        if windowShouldCloseHandlers[handle]?() == false {
            return false
        }

        closeWindow(handle)
        return true
    }

    /// A recorded paragraph-alignment application.
    public struct TextRangeAlignment: Equatable {
        /// The applied alignment.
        public let alignment: NSTextAlignment

        /// The range start in UTF-16 units.
        public let location: Int

        /// The range length in UTF-16 units.
        public let length: Int

        /// Creates a recorded alignment application.
        public init(alignment: NSTextAlignment, location: Int, length: Int) {
            self.alignment = alignment
            self.location = location
            self.length = length
        }
    }

    /// Returns the recorded toolbar item frame using the same simple sizing model as the in-memory toolbar.
    public func toolbarItemFrame(at index: Int, for handle: NativeHandle) -> NSRect? {
        guard let record = records[handle], record.toolbarItems.indices.contains(index) else {
            return nil
        }

        var x: CGFloat = 8
        for itemIndex in 0..<index {
            x += toolbarItemWidth(record.toolbarItems[itemIndex], toolbarWidth: record.frame.size.width)
        }

        let width = toolbarItemWidth(record.toolbarItems[index], toolbarWidth: record.frame.size.width)
        return NSMakeRect(x, 0, width, record.frame.size.height)
    }
}
