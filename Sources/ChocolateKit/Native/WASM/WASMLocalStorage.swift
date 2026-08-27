// The browser's answer to "remember this until next time".
//
// A WASI filesystem lives in the module's memory. Everything written to it is
// gone the moment the tab reloads — which is exactly when a desktop app would
// be reading its preferences back. So on this backend the small persisted
// values do not go to a file at all: they go to `localStorage`, which is the
// only thing on a page that outlives the page.

#if canImport(JavaScriptKit)

import JavaScriptKit

extension WASMNativeControlBackend {
    /// The store, or nil where the page cannot have one.
    ///
    /// **A browser can refuse.** Private-browsing modes, third-party-storage
    /// restrictions and blocked site data all make `localStorage` either absent
    /// or a property that *throws on access*. Every entry point goes through
    /// here and treats nil as "nothing was remembered", which is the same
    /// answer a first launch gives — so the app degrades to a clean start
    /// rather than to a crash.
    private var store: JSObject? {
        let value = JSObject.global.localStorage
        guard !value.isNull, !value.isUndefined else { return nil }
        return value.object
    }

    public override func persistentValue(forKey key: String) -> String? {
        guard let store, let getItem = store.getItem.function else { return nil }
        let value = getItem(this: store, key)
        // `getItem` returns null for a key that was never written, and JS null
        // converts to the *string* "null" if you ask for `.string` first.
        guard !value.isNull, !value.isUndefined else { return nil }
        return value.string
    }

    public override func setPersistentValue(_ value: String?, forKey key: String) {
        guard let store else { return }
        if let value {
            // Writing past the quota throws rather than returning a failure.
            // Losing one autosaved value is a smaller problem than taking the
            // app down, so the write is allowed to fail quietly — and the
            // caller finds out the honest way, by reading nothing back.
            _ = store.setItem.function?(this: store, key, value)
        } else {
            _ = store.removeItem.function?(this: store, key)
        }
    }

    public override func persistentKeys() -> [String] {
        guard let store,
              let length = store.length.number,
              let keyAt = store.key.function else { return [] }

        var keys: [String] = []
        keys.reserveCapacity(Int(length))
        for index in 0..<Int(length) {
            if let key = keyAt(this: store, index).string {
                keys.append(key)
            }
        }
        return keys
    }
}

#endif
