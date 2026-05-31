#if USE_REAL_FOUNDATION
@_exported import Foundation
#elseif USE_WIN_FOUNDATION
@_exported import WinFoundation
#else
@_exported import Foundation
#endif
