#if os(Windows)
/// OLE drag and drop over hand-built COM objects.
///
/// Swift on Windows has no COM interop, so the three interfaces involved are
/// laid out manually: each COM object is a raw allocation whose first pointer
/// is a vtable of `@convention(c)` functions, followed by a reference count
/// and a context pointer to a retained Swift box. `IDropTarget` receives drops
/// (registered per HWND with `RegisterDragDrop`); `IDataObject` and
/// `IDropSource` feed `DoDragDrop` for outbound drags. Content is limited to
/// the platform's two lingua-franca formats — `CF_UNICODETEXT` and `CF_HDROP`
/// file lists — which covers text drags and Explorer file drops both ways.
///
/// Object layout (all offsets in bytes):
///   0: vtable pointer
///   8: reference count (Int32)
///  16: Unmanaged context pointer (DropTargetBox / DragContentBox)
private let comObjectSize = 24
private let comVTableOffset = 0
private let comRefCountOffset = 8
private let comContextOffset = 16

/// Context for a registered drop target: which handle it serves and the drag
/// content captured at enter time.
private final class DropTargetBox {
    let handleRawValue: UInt
    var content = NativeDropContent(text: nil, filePaths: [])
    var accepts = false

    init(handleRawValue: UInt) {
        self.handleRawValue = handleRawValue
    }
}

/// Context for an outbound drag's data object.
private final class DragContentBox {
    let content: NativeDropContent

    init(content: NativeDropContent) {
        self.content = content
    }
}

// MARK: - COM plumbing shared by the three interfaces

/// Reads the retained context box of a COM object.
private func comContext<Box: AnyObject>(_ this: UnsafeMutableRawPointer?, as type: Box.Type) -> Box? {
    guard let this else {
        return nil
    }
    guard let raw = this.load(fromByteOffset: comContextOffset, as: UnsafeMutableRawPointer?.self) else {
        return nil
    }
    return Unmanaged<Box>.fromOpaque(raw).takeUnretainedValue()
}

/// Standard AddRef over the inline reference count.
private func comAddRef(_ this: UnsafeMutableRawPointer?) -> UInt32 {
    guard let this else {
        return 0
    }
    let count = this.load(fromByteOffset: comRefCountOffset, as: Int32.self) + 1
    this.storeBytes(of: count, toByteOffset: comRefCountOffset, as: Int32.self)
    return UInt32(max(count, 0))
}

/// Standard Release; frees the object and its context on the last reference.
private func comRelease<Box: AnyObject>(_ this: UnsafeMutableRawPointer?, boxType: Box.Type) -> UInt32 {
    guard let this else {
        return 0
    }
    let count = this.load(fromByteOffset: comRefCountOffset, as: Int32.self) - 1
    this.storeBytes(of: count, toByteOffset: comRefCountOffset, as: Int32.self)
    if count <= 0 {
        if let raw = this.load(fromByteOffset: comContextOffset, as: UnsafeMutableRawPointer?.self) {
            Unmanaged<Box>.fromOpaque(raw).release()
        }
        this.deallocate()
        return 0
    }
    return UInt32(count)
}

/// QueryInterface supporting IUnknown plus one interface IID.
private func comQueryInterface(
    _ this: UnsafeMutableRawPointer?,
    _ iid: UnsafeMutableRawPointer?,
    _ object: UnsafeMutableRawPointer?,
    interfaceIID: COMGUID
) -> Int32 {
    guard let this, let iid, let object else {
        return comENoInterface
    }
    let requested = iid.load(as: COMGUID.self)
    if requested == iidIUnknown || requested == interfaceIID {
        object.storeBytes(of: this, as: UnsafeMutableRawPointer?.self)
        _ = comAddRef(this)
        return comSOk
    }
    object.storeBytes(of: nil, as: UnsafeMutableRawPointer?.self)
    return comENoInterface
}

/// Allocates a COM object with a vtable, refcount 1, and a retained box.
private func comAllocate(vtable: UnsafeMutableRawPointer, context: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer {
    let object = UnsafeMutableRawPointer.allocate(byteCount: comObjectSize, alignment: 8)
    object.storeBytes(of: vtable, toByteOffset: comVTableOffset, as: UnsafeMutableRawPointer.self)
    object.storeBytes(of: Int32(1), toByteOffset: comRefCountOffset, as: Int32.self)
    object.storeBytes(of: context, toByteOffset: comContextOffset, as: UnsafeMutableRawPointer?.self)
    return object
}

/// Builds a vtable allocation from function-pointer slots.
private func comBuildVTable(_ slots: [UnsafeMutableRawPointer?]) -> UnsafeMutableRawPointer {
    let table = UnsafeMutablePointer<UnsafeMutableRawPointer?>.allocate(capacity: slots.count)
    for (index, slot) in slots.enumerated() {
        table[index] = slot
    }
    return UnsafeMutableRawPointer(table)
}

/// C-function slot types (raw pointers only — Swift structs are not
/// representable in `@convention(c)` signatures).
private typealias COMQueryInterfaceFn = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Int32
private typealias COMRefFn = @convention(c) (UnsafeMutableRawPointer?) -> UInt32
private typealias COMThisOnlyFn = @convention(c) (UnsafeMutableRawPointer?) -> Int32
private typealias COMDragEnterFn = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, DWORD, Int64, UnsafeMutableRawPointer?) -> Int32
private typealias COMDragOverFn = @convention(c) (UnsafeMutableRawPointer?, DWORD, Int64, UnsafeMutableRawPointer?) -> Int32
private typealias COMGetDataFn = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Int32
private typealias COMQueryGetDataFn = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Int32
private typealias COMEnumFormatEtcFn = @convention(c) (UnsafeMutableRawPointer?, DWORD, UnsafeMutableRawPointer?) -> Int32
private typealias COMAdviseFn = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, DWORD, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Int32
private typealias COMDwordFn = @convention(c) (UnsafeMutableRawPointer?, DWORD) -> Int32
private typealias COMQueryContinueFn = @convention(c) (UnsafeMutableRawPointer?, Int32, DWORD) -> Int32

private func slot<Fn>(_ function: Fn) -> UnsafeMutableRawPointer? {
    unsafeBitCast(function, to: UnsafeMutableRawPointer?.self)
}

// MARK: - Reading a foreign IDataObject

/// Reads one HGLOBAL-backed format from a drag's data object, when offered.
private func dataObjectBytes(_ dataObject: UnsafeMutableRawPointer, format: UINT) -> [UInt8]? {
    // Slot 3 of IDataObject's vtable is GetData.
    let vtable = dataObject.load(as: UnsafeMutablePointer<UnsafeMutableRawPointer?>.self)
    guard let getDataRaw = vtable[3] else {
        return nil
    }
    let getData = unsafeBitCast(getDataRaw, to: COMGetDataFn.self)

    var request = FORMATETC()
    request.cfFormat = UInt16(format)
    request.dwAspect = dvAspectContent
    request.lindex = -1
    request.tymed = tymedHGlobal
    var medium = STGMEDIUM()

    let status = withUnsafeMutablePointer(to: &request) { requestPointer in
        withUnsafeMutablePointer(to: &medium) { mediumPointer in
            getData(dataObject, UnsafeMutableRawPointer(requestPointer), UnsafeMutableRawPointer(mediumPointer))
        }
    }
    guard status == comSOk, medium.tymed == tymedHGlobal, let handle = medium.handle else {
        return nil
    }
    defer {
        withUnsafeMutablePointer(to: &medium) { mediumPointer in
            winReleaseStgMedium(UnsafeMutableRawPointer(mediumPointer))
        }
    }

    guard let memory = winGlobalLock(handle) else {
        return nil
    }
    defer {
        _ = winGlobalUnlock(handle)
    }
    let byteCount = Int(winGlobalSize(handle))
    guard byteCount > 0 else {
        return nil
    }
    return Array(UnsafeBufferPointer(start: memory.assumingMemoryBound(to: UInt8.self), count: byteCount))
}

/// Captures the text and file-list content of a drag's data object.
private func captureDropContent(_ dataObject: UnsafeMutableRawPointer?) -> NativeDropContent {
    guard let dataObject else {
        return NativeDropContent(text: nil, filePaths: [])
    }

    var text: String?
    if let bytes = dataObjectBytes(dataObject, format: cfUnicodeText) {
        var units: [UInt16] = []
        var index = 0
        while index + 1 < bytes.count {
            let unit = UInt16(bytes[index]) | (UInt16(bytes[index + 1]) << 8)
            if unit == 0 {
                break
            }
            units.append(unit)
            index += 2
        }
        text = String(decoding: units, as: UTF16.self)
    }

    var filePaths: [String] = []
    if let bytes = dataObjectBytes(dataObject, format: cfHDrop), bytes.count > 20 {
        let offset = Int(bytes[0]) | (Int(bytes[1]) << 8) | (Int(bytes[2]) << 16) | (Int(bytes[3]) << 24)
        let wide = bytes[16] != 0
        if wide, offset >= 20, offset < bytes.count {
            var units: [UInt16] = []
            var position = offset
            while position + 1 < bytes.count {
                let unit = UInt16(bytes[position]) | (UInt16(bytes[position + 1]) << 8)
                position += 2
                if unit == 0 {
                    if units.isEmpty {
                        break
                    }
                    filePaths.append(String(decoding: units, as: UTF16.self))
                    units.removeAll()
                } else {
                    units.append(unit)
                }
            }
        }
    }
    return NativeDropContent(text: text, filePaths: filePaths)
}

/// Converts a `POINTL` packed into an Int64 into control-local coordinates.
private func dropLocation(_ packedPoint: Int64, handleRawValue: UInt) -> NSPoint {
    var point = POINT()
    point.x = Int32(truncatingIfNeeded: packedPoint)
    point.y = Int32(truncatingIfNeeded: packedPoint >> 32)
    if let backend = Win32NativeControlBackend.activeBackend,
       let hwnd = backend.hwnd(from: NativeHandle(rawValue: handleRawValue)) {
        _ = winScreenToClient(hwnd, &point)
    }
    return NSPoint(x: CGFloat(point.x), y: CGFloat(point.y))
}

private func storeEffect(_ effect: UnsafeMutableRawPointer?, accepted: Bool) {
    effect?.storeBytes(of: accepted ? dropEffectCopy : dropEffectNone, as: DWORD.self)
}

// MARK: - IDropTarget

/// The one IDropTarget vtable shared by every registered target.
private nonisolated(unsafe) let dropTargetVTable: UnsafeMutableRawPointer = comBuildVTable([
    slot({ this, iid, object in
        comQueryInterface(this, iid, object, interfaceIID: iidIDropTarget)
    } as COMQueryInterfaceFn),
    slot({ this in comAddRef(this) } as COMRefFn),
    slot({ this in comRelease(this, boxType: DropTargetBox.self) } as COMRefFn),
    // DragEnter
    slot({ this, dataObject, _, packedPoint, effect in
        guard let box = comContext(this, as: DropTargetBox.self),
              let backend = Win32NativeControlBackend.activeBackend,
              let handler = backend.dropHandlers[box.handleRawValue] else {
            storeEffect(effect, accepted: false)
            return comSOk
        }
        box.content = captureDropContent(dataObject)
        box.accepts = handler.entered(box.content, dropLocation(packedPoint, handleRawValue: box.handleRawValue))
        storeEffect(effect, accepted: box.accepts)
        return comSOk
    } as COMDragEnterFn),
    // DragOver
    slot({ this, _, packedPoint, effect in
        guard let box = comContext(this, as: DropTargetBox.self),
              let backend = Win32NativeControlBackend.activeBackend,
              let handler = backend.dropHandlers[box.handleRawValue] else {
            storeEffect(effect, accepted: false)
            return comSOk
        }
        box.accepts = handler.moved(dropLocation(packedPoint, handleRawValue: box.handleRawValue))
        storeEffect(effect, accepted: box.accepts)
        return comSOk
    } as COMDragOverFn),
    // DragLeave
    slot({ this in
        if let box = comContext(this, as: DropTargetBox.self),
           let backend = Win32NativeControlBackend.activeBackend,
           let handler = backend.dropHandlers[box.handleRawValue] {
            handler.exited()
        }
        return comSOk
    } as COMThisOnlyFn),
    // Drop
    slot({ this, dataObject, _, packedPoint, effect in
        guard let box = comContext(this, as: DropTargetBox.self),
              let backend = Win32NativeControlBackend.activeBackend,
              let handler = backend.dropHandlers[box.handleRawValue] else {
            storeEffect(effect, accepted: false)
            return comSOk
        }
        let content = captureDropContent(dataObject)
        let performed = handler.performed(content, dropLocation(packedPoint, handleRawValue: box.handleRawValue))
        storeEffect(effect, accepted: performed)
        return comSOk
    } as COMDragEnterFn),
])

// MARK: - IDropSource

private nonisolated(unsafe) let dropSourceVTable: UnsafeMutableRawPointer = comBuildVTable([
    slot({ this, iid, object in
        comQueryInterface(this, iid, object, interfaceIID: iidIDropSource)
    } as COMQueryInterfaceFn),
    slot({ this in comAddRef(this) } as COMRefFn),
    slot({ this in comRelease(this, boxType: DragContentBox.self) } as COMRefFn),
    // QueryContinueDrag: Escape cancels, releasing the mouse drops.
    slot({ _, escapePressed, keyState in
        if escapePressed != 0 {
            return comDragDropSCancel
        }
        if keyState & DWORD(mkLButton) == 0 {
            return comDragDropSDrop
        }
        return comSOk
    } as COMQueryContinueFn),
    // GiveFeedback: keep the standard drag cursors.
    slot({ _, _ in comDragDropSUseDefaultCursors } as COMDwordFn),
])

// MARK: - IDataObject (outbound)

/// Whether an outbound data object can serve a requested format.
private func outboundSupports(_ box: DragContentBox, formatEtc: UnsafeMutableRawPointer?) -> Bool {
    guard let formatEtc else {
        return false
    }
    let format = UINT(formatEtc.load(as: UInt16.self))
    let tymed = formatEtc.load(fromByteOffset: 24, as: DWORD.self)
    guard tymed & tymedHGlobal != 0 else {
        return false
    }
    if format == cfUnicodeText {
        return box.content.text != nil
    }
    if format == cfHDrop {
        return !box.content.filePaths.isEmpty
    }
    return false
}

/// Copies bytes into a movable HGLOBAL for a data-object medium.
private func hGlobalBytes(_ bytes: [UInt8]) -> UnsafeMutableRawPointer? {
    guard !bytes.isEmpty, let memory = winGlobalAlloc(gmemMoveable, UInt(bytes.count)), let target = winGlobalLock(memory) else {
        return nil
    }
    bytes.withUnsafeBytes { source in
        target.copyMemory(from: source.baseAddress!, byteCount: bytes.count)
    }
    _ = winGlobalUnlock(memory)
    return memory
}

private nonisolated(unsafe) let dataObjectVTable: UnsafeMutableRawPointer = comBuildVTable([
    slot({ this, iid, object in
        comQueryInterface(this, iid, object, interfaceIID: iidIDataObject)
    } as COMQueryInterfaceFn),
    slot({ this in comAddRef(this) } as COMRefFn),
    slot({ this in comRelease(this, boxType: DragContentBox.self) } as COMRefFn),
    // GetData
    slot({ this, formatEtc, medium in
        guard let box = comContext(this, as: DragContentBox.self), let formatEtc, let medium,
              outboundSupports(box, formatEtc: formatEtc) else {
            return comDVEFormatEtc
        }
        let format = UINT(formatEtc.load(as: UInt16.self))
        let bytes: [UInt8]
        if format == cfUnicodeText, let text = box.content.text {
            var encoded: [UInt8] = []
            for unit in Array(text.utf16) + [0] {
                encoded.append(UInt8(unit & 0xff))
                encoded.append(UInt8(unit >> 8))
            }
            bytes = encoded
        } else {
            bytes = Win32NativeControlBackend.dropFilesBytes(for: box.content.filePaths)
        }
        guard let handle = hGlobalBytes(bytes) else {
            return comDVEFormatEtc
        }
        medium.storeBytes(of: tymedHGlobal, toByteOffset: 0, as: DWORD.self)
        medium.storeBytes(of: handle, toByteOffset: 8, as: UnsafeMutableRawPointer?.self)
        medium.storeBytes(of: nil, toByteOffset: 16, as: UnsafeMutableRawPointer?.self)
        return comSOk
    } as COMGetDataFn),
    // GetDataHere
    slot({ _, _, _ in comENotImpl } as COMGetDataFn),
    // QueryGetData
    slot({ this, formatEtc in
        guard let box = comContext(this, as: DragContentBox.self), outboundSupports(box, formatEtc: formatEtc) else {
            return comDVEFormatEtc
        }
        return comSOk
    } as COMQueryGetDataFn),
    // GetCanonicalFormatEtc
    slot({ _, _, _ in comENotImpl } as COMGetDataFn),
    // SetData
    slot({ _, _, _ in comENotImpl } as COMGetDataFn),
    // EnumFormatEtc
    slot({ this, direction, enumerator in
        guard direction == 1, let box = comContext(this, as: DragContentBox.self), let enumerator else {
            return comENotImpl
        }
        var formats: [FORMATETC] = []
        if box.content.text != nil {
            var format = FORMATETC()
            format.cfFormat = UInt16(cfUnicodeText)
            format.dwAspect = dvAspectContent
            format.lindex = -1
            format.tymed = tymedHGlobal
            formats.append(format)
        }
        if !box.content.filePaths.isEmpty {
            var format = FORMATETC()
            format.cfFormat = UInt16(cfHDrop)
            format.dwAspect = dvAspectContent
            format.lindex = -1
            format.tymed = tymedHGlobal
            formats.append(format)
        }
        return formats.withUnsafeMutableBufferPointer { buffer in
            winSHCreateStdEnumFmtEtc(UINT(buffer.count), UnsafeMutableRawPointer(buffer.baseAddress), enumerator.assumingMemoryBound(to: UnsafeMutableRawPointer?.self))
        }
    } as COMEnumFormatEtcFn),
    // DAdvise
    slot({ _, _, _, _, _ in comOleEAdviseNotSupported } as COMAdviseFn),
    // DUnadvise
    slot({ _, _ in comOleEAdviseNotSupported } as COMDwordFn),
    // EnumDAdvise
    slot({ _, _ in comOleEAdviseNotSupported } as COMDwordFn),
])

// MARK: - Backend surface

extension Win32NativeControlBackend {
    /// Starts OLE once per process; drag and drop requires `OleInitialize`
    /// (plain `CoInitializeEx` is not enough).
    private static func ensureOleStarted() {
        struct OnceToken {
            nonisolated(unsafe) static var started = false
        }
        if !OnceToken.started {
            OnceToken.started = true
            _ = winOleInitialize(nil)
        }
    }

    /// Makes a control a drop target for native text and file-list drags.
    public func registerDropTarget(for handle: NativeHandle, handler: NativeDropHandler) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }
        Self.ensureOleStarted()

        dropHandlers[handle.rawValue] = handler
        guard dropTargetObjects[handle.rawValue] == nil else {
            return
        }

        let box = DropTargetBox(handleRawValue: handle.rawValue)
        let object = comAllocate(vtable: dropTargetVTable, context: Unmanaged.passRetained(box).toOpaque())
        if winRegisterDragDrop(hwnd, object) == comSOk {
            dropTargetObjects[handle.rawValue] = object
        } else {
            _ = comRelease(object, boxType: DropTargetBox.self)
        }
    }

    /// Removes a control's drop-target registration.
    public func unregisterDropTarget(for handle: NativeHandle) {
        dropHandlers.removeValue(forKey: handle.rawValue)
        guard let object = dropTargetObjects.removeValue(forKey: handle.rawValue) else {
            return
        }
        if let hwnd = hwnd(from: handle) {
            _ = winRevokeDragDrop(hwnd)
        }
        _ = comRelease(object, boxType: DropTargetBox.self)
    }

    /// Runs a blocking OLE drag with the given content from a control.
    public func performDrag(content: NativeDropContent, from handle: NativeHandle) -> Bool {
        Self.ensureOleStarted()

        let box = DragContentBox(content: content)
        let dataObject = comAllocate(vtable: dataObjectVTable, context: Unmanaged.passRetained(box).toOpaque())
        let sourceBox = DragContentBox(content: content)
        let dropSource = comAllocate(vtable: dropSourceVTable, context: Unmanaged.passRetained(sourceBox).toOpaque())
        defer {
            _ = comRelease(dataObject, boxType: DragContentBox.self)
            _ = comRelease(dropSource, boxType: DragContentBox.self)
        }

        var effect: DWORD = dropEffectNone
        let status = winDoDragDrop(dataObject, dropSource, dropEffectCopy | dropEffectMove | dropEffectLink, &effect)
        return status == comDragDropSDrop && effect != dropEffectNone
    }
}
#endif
