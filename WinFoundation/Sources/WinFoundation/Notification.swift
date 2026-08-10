/// Foundation-compatible notification value.
public struct Notification {
    /// Foundation-compatible notification name.
    public struct Name: RawRepresentable, Equatable, Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
        /// The `rawValue` value.
        public var rawValue: String

        /// Creates a value with the supplied arguments.
        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }

        /// Creates a value with the supplied arguments.
        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// Creates a value with the supplied arguments.
        public init(stringLiteral value: String) {
            self.rawValue = value
        }

        /// The `description` value.
        public var description: String {
            rawValue
        }
    }

    /// The notification name.
    public let name: Name

    /// The sender object.
    public let object: Any?

    /// Extra notification data.
    public let userInfo: [AnyHashable: Any]?

    /// Creates a notification.
    public init(name: Name, object: Any? = nil, userInfo: [AnyHashable: Any]? = nil) {
        self.name = name
        self.object = object
        self.userInfo = userInfo
    }
}

/// `NSObjectProtocol`, matching Foundation's core requirements so that â€” as
/// on Apple platforms â€” conforming to it (directly or through a delegate
/// protocol that refines it) effectively requires inheriting `NSObject`,
/// which provides these members.
public protocol NSObjectProtocol: AnyObject {
    /// Identity/equality, matching `NSObjectProtocol.isEqual(_:)`.
    func isEqual(_ object: Any?) -> Bool

    /// The object's hash, matching `NSObjectProtocol.hash`.
    var hash: Int { get }

    /// A textual description, matching `NSObjectProtocol.description`.
    var description: String { get }
}

/// A Foundation-compatible operation queue with block execution support.
/// NotificationCenter observers remain synchronous, matching the shim's
/// documented delivery behavior; scheduler clients use `addOperation(_:)`.
public final class OperationQueue: @unchecked Sendable {
    /// The `` type-level value.
    public static let main = OperationQueue(isMain: true)

    private let isMain: Bool

    private init(isMain: Bool) {
        self.isMain = isMain
    }

    /// Creates a value with the supplied arguments.
    public init() {
        self.isMain = false
    }

    /// Adds a block for asynchronous execution on the receiver.
    public func addOperation(_ block: @escaping () -> Void) {
        if isMain {
            RunLoop.main.perform(block)
            return
        }

        #if os(Windows)
        let context = Unmanaged.passRetained(
            WinFoundationOperationBlock(block)
        ).toOpaque()
        guard let thread = WinFoundationCreateThread(
            nil,
            0,
            WinFoundationOperationThreadStart,
            context,
            0,
            nil
        ) else {
            Unmanaged<WinFoundationOperationBlock>.fromOpaque(context).release()
            block()
            return
        }
        _ = WinFoundationOperationCloseHandle(thread)
        #else
        block()
        #endif
    }
}

#if os(Windows)
private final class WinFoundationOperationBlock {
    let block: () -> Void

    init(_ block: @escaping () -> Void) {
        self.block = block
    }
}

private typealias WinFoundationThreadStart =
    @convention(c) (UnsafeMutableRawPointer?) -> UInt32

private func WinFoundationOperationThreadStart(
    _ context: UnsafeMutableRawPointer?
) -> UInt32 {
    guard let context else { return 0 }
    let box = Unmanaged<WinFoundationOperationBlock>
        .fromOpaque(context)
        .takeRetainedValue()
    box.block()
    return 0
}

@_silgen_name("CreateThread")
private func WinFoundationCreateThread(
    _ attributes: UnsafeMutableRawPointer?,
    _ stackSize: UInt,
    _ startAddress: WinFoundationThreadStart?,
    _ parameter: UnsafeMutableRawPointer?,
    _ creationFlags: UInt32,
    _ threadID: UnsafeMutablePointer<UInt32>?
) -> UnsafeMutableRawPointer?

@_silgen_name("CloseHandle")
private func WinFoundationOperationCloseHandle(
    _ object: UnsafeMutableRawPointer?
) -> Int32
#endif

/// A small synchronous NotificationCenter subset.
public final class NotificationCenter: @unchecked Sendable {
    private final class Observer: NSObjectProtocol {
        let name: Notification.Name?
        let object: Any?
        let block: (Notification) -> Void

        init(name: Notification.Name?, object: Any?, block: @escaping (Notification) -> Void) {
            self.name = name
            self.object = object
            self.block = block
        }

        // NSObjectProtocol requirements (identity semantics).
        func isEqual(_ object: Any?) -> Bool {
            (object as? Observer) === self
        }

        var hash: Int {
            ObjectIdentifier(self).hashValue
        }

        var description: String {
            "NotificationCenter.Observer"
        }

        func matches(_ notification: Notification) -> Bool {
            if let name, name != notification.name {
                return false
            }

            guard let object else {
                return true
            }

            guard let observedObject = object as AnyObject?, let postedObject = notification.object as AnyObject? else {
                return false
            }
            return observedObject === postedObject
        }
    }

    /// The default notification center.
    public static let `default` = NotificationCenter()

    private var observers: [Observer] = []

    /// Creates a value with the supplied arguments.
    public init() {}

    /// Adds a synchronous block observer.
    @discardableResult
    public func addObserver(forName name: Notification.Name?, object: Any?, queue: OperationQueue?, using block: @escaping (Notification) -> Void) -> NSObjectProtocol {
        let observer = Observer(name: name, object: object, block: block)
        observers.append(observer)
        return observer
    }

    /// Removes a previously returned observer token.
    public func removeObserver(_ observer: Any) {
        guard let observerObject = observer as AnyObject? else {
            return
        }
        observers.removeAll { $0 === observerObject }
    }

    /// Removes matching observer registrations.
    public func removeObserver(_ observer: Any, name: Notification.Name?, object: Any?) {
        guard let observerObject = observer as AnyObject? else {
            return
        }
        observers.removeAll { candidate in
            guard candidate === observerObject else {
                return false
            }
            if let name, candidate.name != name {
                return false
            }
            if let object {
                guard let candidateObject = candidate.object as AnyObject?, let requestedObject = object as AnyObject? else {
                    return false
                }
                return candidateObject === requestedObject
            }
            return true
        }
    }

    /// Posts a notification value.
    public func post(_ notification: Notification) {
        let snapshot = observers
        for observer in snapshot where observer.matches(notification) {
            observer.block(notification)
        }
    }

    /// Posts a notification by name.
    public func post(name: Notification.Name, object: Any? = nil, userInfo: [AnyHashable: Any]? = nil) {
        post(Notification(name: name, object: object, userInfo: userInfo))
    }
}
