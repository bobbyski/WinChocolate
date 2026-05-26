# Human Review Checklist

| Item | Reason | Reviewed | Human Accepted |
|---|---|---:|---:|
| Win32 native backend FFI | The backend now uses manual User32/Gdi32 declarations because this ARM64 Swift toolchain cannot import `WinSDK`; the declarations should be reviewed before broadening the API surface. | [ ] | [ ] |
