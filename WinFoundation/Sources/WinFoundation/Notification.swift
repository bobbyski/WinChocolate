/// Foundation-compatible notification value.
public struct Notification {
    /// Foundation-compatible notification name.
    public struct Name: RawRepresentable, Equatable, Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
        public var rawValue: String

        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(stringLiteral value: String) {
            self.rawValue = value
        }

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

/// Minimal NSObjectProtocol stand-in for Foundation observer tokens.
public protocol NSObjectProtocol: AnyObject {}

/// Minimal operation queue stand-in. The current NotificationCenter shim invokes observers synchronously.
public final class OperationQueue: @unchecked Sendable {
    public static let main = OperationQueue()

    public init() {}
}

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
