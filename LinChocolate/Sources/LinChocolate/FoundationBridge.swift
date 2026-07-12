// Re-export Foundation so `import LinChocolate` brings the Foundation surface
// (NSRect/NSMakeRect/CGFloat/Date/URL/Data/NSNumber/…) into client code — the
// mirror of WinChocolate's FoundationBridge (which re-exports WinFoundation on
// Windows). This lets the same demo/app source compile against either library
// with a single conditional `import`.
@_exported import Foundation
