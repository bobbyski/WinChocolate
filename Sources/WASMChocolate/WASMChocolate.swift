// The WebAssembly façade: `@_exported import ChocolateKit` and nothing else,
// so `import WASMChocolate` / `canImport(WASMChocolate)` work the way
// `import WinChocolate` and `import LinChocolate` do.
//
// Rule One, inherited from the other two façades: never add API here. A symbol
// declared in a façade exists on exactly one platform, which is the one thing
// this whole architecture is built to prevent — the shared surface lives in
// ChocolateKit, where every backend answers for it.
//
// Like LinChocolate, this target must not resolve on the wrong platform: the
// demos test `os(WASI)` first, and a WASMChocolate that resolved in a Windows
// or Linux build would capture it. SwiftPM targets themselves are not
// conditional, but *dependencies* are, so the manifest only ever depends on
// this target under `.when(platforms: [.wasi])`.

@_exported import ChocolateKit
