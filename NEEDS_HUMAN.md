# Human Review Checklist

| Item | Reason | Reviewed | Human Accepted |
|---|---|---:|---:|
| Win32 native backend FFI | The backend now uses manual User32/Gdi32 declarations because this ARM64 Swift toolchain cannot import `WinSDK`; the declarations should be reviewed before broadening the API surface. | [ ] | [ ] |
| Keyboard modifiers on real hardware | VM and remote keyboard layers can remap Command/Windows/Alt into Control or system shortcuts before WinChocolate sees them; modifier behavior should be checked on a real Windows PC. | [ ] | [ ] |
