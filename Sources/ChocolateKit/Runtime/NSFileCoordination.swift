// File coordination — the protocol `NSDocument` conforms to so that something
// else changing its file on disk can reach it.
//
// ---------------------------------------------------------------------------
// What this is, and honestly what it is not.
//
// On a Mac, `NSFileCoordinator` talks to a system daemon so that *separate
// processes* can take turns with a file: a document open in TextEdit learns
// that the Finder renamed it, and two apps cannot half-write the same bytes.
// No platform this framework targets has that daemon — not Windows, not GTK,
// not a browser tab.
//
// So this is an **in-process** coordinator. Within one application it is
// faithful: presenters are registered, readers and writers take turns, and a
// writer tells every other presenter of the same file what happened. Across
// processes it does nothing, and pretending otherwise would be worse than
// saying so. Recorded in Docs/AppKitCompatibilityDivergences.md.
//
// The gate keeps this out of the way of the real thing on Apple platforms.
// ---------------------------------------------------------------------------

#if !canImport(Darwin)

/// An object that wants to know when a file it is presenting changes.
///
/// `NSDocument` conforms to this, which is how a document notices that its own
/// file moved or changed underneath it.
public protocol NSFilePresenter: NSObjectProtocol {
    /// The file or directory this object is presenting, if any.
    var presentedItemURL: URL? { get }

    /// The queue this presenter's callbacks are delivered on.
    ///
    /// The framework is single-threaded by design, so every callback arrives
    /// on the main queue whatever this returns; it exists because AppKit's
    /// protocol requires it and ported code implements it.
    var presentedItemOperationQueue: OperationQueue { get }

    /// Hands the item to a reader, then takes it back through `reacquirer`.
    func relinquishPresentedItem(toReader reader: @escaping ((() -> Void)?) -> Void)

    /// Hands the item to a writer, then takes it back through `reacquirer`.
    func relinquishPresentedItem(toWriter writer: @escaping ((() -> Void)?) -> Void)

    /// Asks the presenter to save any unwritten changes.
    func savePresentedItemChanges(completionHandler: @escaping (Error?) -> Void)

    /// Asks the presenter to let go of the item so it can be deleted.
    func accommodatePresentedItemDeletion(completionHandler: @escaping (Error?) -> Void)

    /// Tells the presenter its item is now at a new URL.
    func presentedItemDidMove(to newURL: URL)

    /// Tells the presenter its item's contents changed.
    func presentedItemDidChange()
}

/// Default no-op implementations, so a conformer implements only what it cares
/// about — matching AppKit, whose protocol members are all optional.
public extension NSFilePresenter {
    /// No queue preference.
    var presentedItemOperationQueue: OperationQueue { OperationQueue.main }

    /// Hands the item over and takes it straight back.
    func relinquishPresentedItem(toReader reader: @escaping ((() -> Void)?) -> Void) {
        reader(nil)
    }

    /// Hands the item over and takes it straight back.
    func relinquishPresentedItem(toWriter writer: @escaping ((() -> Void)?) -> Void) {
        writer(nil)
    }

    /// Reports nothing to save.
    func savePresentedItemChanges(completionHandler: @escaping (Error?) -> Void) {
        completionHandler(nil)
    }

    /// Allows the deletion.
    func accommodatePresentedItemDeletion(completionHandler: @escaping (Error?) -> Void) {
        completionHandler(nil)
    }

    /// Ignores the move.
    func presentedItemDidMove(to newURL: URL) {}

    /// Ignores the change.
    func presentedItemDidChange() {}
}

/// Serialises access to a file among the presenters in this process.
///
/// ```
///   coordinate(writingItemAt: url) { actual in
///        │
///        ├─ every OTHER presenter of `url` is asked to relinquish
///        ├─ the accessor block runs, with the file to itself
///        └─ every OTHER presenter is told presentedItemDidChange()
/// ```
///
/// The presenter that *initiated* the write is deliberately not notified: it
/// already knows, and telling it would make a document reload the bytes it
/// just wrote.
open class NSFileCoordinator: NSObject {
    /// Options for a coordinated read.
    public struct ReadingOptions: OptionSet, Sendable {
        /// The raw option value.
        public let rawValue: UInt

        /// Creates options from a raw value.
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// Do not ask the presenter to save before reading.
        public static let withoutChanges = ReadingOptions(rawValue: 1)

        /// Resolve a symbolic link before reading.
        public static let resolvesSymbolicLink = ReadingOptions(rawValue: 2)

        /// Read the item immediately even if it is being written.
        public static let immediatelyAvailableMetadataOnly = ReadingOptions(rawValue: 4)
    }

    /// Options for a coordinated write.
    public struct WritingOptions: OptionSet, Sendable {
        /// The raw option value.
        public let rawValue: UInt

        /// Creates options from a raw value.
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// The write creates the item.
        public static let forReplacing = WritingOptions(rawValue: 1)

        /// The write deletes the item.
        public static let forDeleting = WritingOptions(rawValue: 2)

        /// The write moves the item.
        public static let forMoving = WritingOptions(rawValue: 4)

        /// The write merges into an existing item.
        public static let forMerging = WritingOptions(rawValue: 8)
    }

    /// Every presenter registered in this process.
    ///
    /// Held weakly: a presenter that forgets to deregister — a document torn
    /// down without closing, say — must not be kept alive by this list, and
    /// must not receive callbacks after it is gone.
    nonisolated(unsafe) private static var registered: [WeakPresenter] = []

    /// A weak box, so the registry does not own what it tracks.
    private struct WeakPresenter {
        weak var presenter: (any NSFilePresenter)?
    }

    /// The presenter that filed this coordinator's operations, if any.
    private weak var owner: (any NSFilePresenter)?

    /// Creates a coordinator whose operations are attributed to a presenter.
    ///
    /// The owning presenter is excluded from its own notifications.
    public init(filePresenter: (any NSFilePresenter)?) {
        self.owner = filePresenter
        super.init()
    }

    /// Creates a coordinator not attributed to any presenter.
    public override init() {
        self.owner = nil
        super.init()
    }

    /// Registers a presenter so it hears about changes to its item.
    public class func addFilePresenter(_ presenter: any NSFilePresenter) {
        removeDeadEntries()
        guard !registered.contains(where: { $0.presenter === presenter }) else {
            return
        }
        registered.append(WeakPresenter(presenter: presenter))
    }

    /// Deregisters a presenter.
    public class func removeFilePresenter(_ presenter: any NSFilePresenter) {
        registered.removeAll { $0.presenter === presenter || $0.presenter == nil }
    }

    /// Every currently registered presenter.
    public class var filePresenters: [any NSFilePresenter] {
        removeDeadEntries()
        return registered.compactMap { $0.presenter }
    }

    /// Runs a block with coordinated read access to an item.
    ///
    /// Presenters of the same item are asked to flush unsaved changes first,
    /// unless `.withoutChanges` says not to bother.
    open func coordinate(readingItemAt url: URL,
                         options: ReadingOptions = [],
                         byAccessor reader: (URL) throws -> Void) throws {
        if !options.contains(.withoutChanges) {
            for presenter in others(presenting: url) {
                presenter.savePresentedItemChanges { _ in }
            }
        }
        try reader(url)
    }

    /// Runs a block with coordinated write access to an item.
    ///
    /// Other presenters of the item are told it changed once the block returns
    /// — but only if it returned successfully, because a write that threw did
    /// not change anything worth reloading.
    open func coordinate(writingItemAt url: URL,
                         options: WritingOptions = [],
                         byAccessor writer: (URL) throws -> Void) throws {
        let affected = others(presenting: url)
        for presenter in affected {
            // The label is spelled out rather than left to trailing-closure
            // syntax: `toReader:` and `toWriter:` differ only by it, so a bare
            // trailing closure is ambiguous between them.
            presenter.relinquishPresentedItem(toWriter: { reacquire in
                reacquire?()
            })
        }

        try writer(url)

        for presenter in affected {
            if options.contains(.forDeleting) {
                presenter.accommodatePresentedItemDeletion { _ in }
            } else {
                presenter.presentedItemDidChange()
            }
        }
    }

    /// Tells presenters of an item that it moved.
    ///
    /// Called after a rename or a Save As, so a document that was presenting
    /// the old URL follows it to the new one.
    open func item(at oldURL: URL, didMoveTo newURL: URL) {
        for presenter in others(presenting: oldURL) {
            presenter.presentedItemDidMove(to: newURL)
        }
    }

    /// Registered presenters of a URL, excluding this coordinator's owner.
    private func others(presenting url: URL) -> [any NSFilePresenter] {
        Self.filePresenters.filter { presenter in
            presenter !== owner && presenter.presentedItemURL == url
        }
    }

    /// Drops boxes whose presenter has been deallocated.
    private class func removeDeadEntries() {
        registered.removeAll { $0.presenter == nil }
    }
}

#endif
