# Human Review Checklist

| Item | Reason | Reviewed | Human Accepted |
|---|---|---:|---:|
| Win32 native backend FFI | The backend now uses manual User32/Gdi32 declarations because this ARM64 Swift toolchain cannot import `WinSDK`; the declarations should be reviewed before broadening the API surface. | [ ] | [ ] |
| Keyboard modifiers on real hardware | VM and remote keyboard layers can remap Command/Windows/Alt into Control or system shortcuts before WinChocolate sees them; modifier behavior should be checked on a real Windows PC. | [ ] | [ ] |
| Alert focus recovery after native MessageBoxW | After dismissing the demo `NSAlert`, keyboard focus can stop moving until the user clicks back in the window. `NSAlert.runModal()` now restores AppKit-side key/main window and first responder, but the classic Win32 `MessageBoxW` path still appears to need a native activation/focus-message fix or a custom alert dialog backend. | [ ] | [ ] |
| Foundation toolchain canary | The current Windows ARM64 Swift toolchain cannot compile real `import Foundation`; Windows builds use `WinFoundation` through `USE_WIN_FOUNDATION`. When a new Swift toolchain is installed, run the canary in `FOUNDATION_SHIMS.md` and migrate shims back to real Foundation if it passes. | [ ] | [ ] |
| WinFoundation URL compatibility | `URL` is now the first bridge type exposed through `NSPathControl` and likely future panels/resources/document APIs. Its API should be reviewed against common Foundation `URL` usage before deeper file-related AppKit surfaces are added. | [ ] | [ ] |
