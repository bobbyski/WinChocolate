/// A minimal AppKit-compatible sound.
///
/// Backs `NSButton.sound` and app code that plays short sounds. File-backed
/// sounds play through the Windows `PlaySoundW` API (asynchronously); a named
/// sound is treated as a system sound alias. Full asset-catalog/named-sound
/// lookup and playback state are future work.
open class NSSound: NSObject {
    /// The sound's name, when created by name.
    open var name: String?

    private let filePath: String?

    /// Creates a sound by name (treated as a system sound alias on Windows).
    public init?(named name: String) {
        guard !name.isEmpty else {
            return nil
        }
        self.name = name
        self.filePath = nil
        super.init()
    }

    /// Creates a sound from a file path.
    public init?(contentsOfFile path: String, byReference: Bool) {
        guard !path.isEmpty else {
            return nil
        }
        self.filePath = path
        self.name = nil
        super.init()
    }

    /// Creates a sound from a file URL.
    public init?(contentsOf url: URL, byReference: Bool) {
        guard url.isFileURL else {
            return nil
        }
        self.filePath = url.path
        self.name = nil
        super.init()
    }

    /// Whether the sound was started and not stopped.
    ///
    /// `PlaySoundW` gives no completion signal, so this reflects the last
    /// play/stop request rather than live playback state — a sound that
    /// finished on its own still reads as playing until `stop()`.
    open private(set) var isPlaying = false

    /// The playback volume, 0–1. Stored for AppKit shape; `PlaySoundW`
    /// has no per-sound volume control, so the value does not attenuate
    /// playback (a waveform backend would honor it).
    open var volume: Float = 1

    /// Starts playing the sound asynchronously; returns whether it started.
    @discardableResult
    open func play() -> Bool {
        let started = winPlayNSSound(filePath: filePath, alias: filePath == nil ? name : nil)
        isPlaying = started
        return started
    }

    /// Stops asynchronous playback.
    @discardableResult
    open func stop() -> Bool {
        winStopNSSound()
        isPlaying = false
        return true
    }

    /// Plays the system alert sound.
    open class func beep() {
        winMessageBeep()
    }
}

#if os(Windows)
@_silgen_name("PlaySoundW")
private func winPlaySoundW(_ sound: UnsafePointer<UInt16>?, _ module: UnsafeRawPointer?, _ flags: UInt32) -> Int32

private let sndAsync: UInt32 = 0x0000_0001
private let sndNoDefault: UInt32 = 0x0000_0002
private let sndAlias: UInt32 = 0x0001_0000
private let sndFilename: UInt32 = 0x0002_0000

private func winPlayNSSound(filePath: String?, alias: String?) -> Bool {
    if let filePath {
        return withWideSound(filePath) { winPlaySoundW($0, nil, sndAsync | sndFilename | sndNoDefault) != 0 }
    }
    if let alias {
        return withWideSound(alias) { winPlaySoundW($0, nil, sndAsync | sndAlias | sndNoDefault) != 0 }
    }
    return false
}

private func winStopNSSound() {
    _ = winPlaySoundW(nil, nil, 0)
}

private func withWideSound<Result>(_ string: String, _ body: (UnsafePointer<UInt16>?) -> Result) -> Result {
    var units = Array(string.utf16)
    units.append(0)
    return units.withUnsafeBufferPointer { body($0.baseAddress) }
}
@_silgen_name("MessageBeep")
private func winMessageBeepW(_ uType: UInt32) -> Int32

private func winMessageBeep() {
    // MB_OK: the default system beep.
    _ = winMessageBeepW(0)
}
#else
private func winPlayNSSound(filePath: String?, alias: String?) -> Bool { false }
private func winStopNSSound() {}
private func winMessageBeep() {}
#endif
