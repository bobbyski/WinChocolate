# Windows setup

WinChocolate is a Swift Package Manager project that builds native Win32
executables. It requires the Windows Swift toolchain, the matching Microsoft C++
build tools, and a Windows SDK.

## 1. Install the platform prerequisites

First, check the current machine without changing it:

```bat
windowsSwiftCheck.bat
```

To install missing prerequisites automatically, run:

```bat
windowsSwiftCheck.bat --install
```

Installation mode requests administrator access and installs all missing pieces:

- Windows Package Manager (`winget`), bootstrapped through Microsoft's official
  PowerShell Gallery module when necessary
- Visual Studio 2022 C++ Build Tools and the Windows SDK
- Git for Windows
- Python 3.10
- The native Windows Swift toolchain (`Swift.Toolchain`)
- Windows Developer Mode

Swiftly is not currently the Windows installation route; the official Swift for
Windows package is `Swift.Toolchain`. The project scripts discover versioned
Swift toolchains, runtimes, the bundled Python, Windows SDK, and Visual Studio
environment automatically, including in the terminal that performed installation.

The simplest supported route is the official Swift for Windows installation
guide:

<https://www.swift.org/install/windows/>

Install Visual Studio 2022 or Visual Studio 2022 Build Tools with:

- MSVC v143 C++ x64/x86 build tools
- A Windows 11 SDK (10.0.22621 or newer is suitable)
- MSVC ARM64/ARM64EC build tools only if you intend to cross-compile for ARM64

Also install Git for Windows and Python 3.10.x, as listed by Swift's manual
Windows instructions:

<https://www.swift.org/install/windows/manual/>

If `winget` is available, Swift.org currently provides these commands from an
Administrator PowerShell prompt:

```powershell
winget install --id Microsoft.VisualStudio.2022.Community --exact --force --custom "--add Microsoft.VisualStudio.Component.Windows11SDK.22621 --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.VC.Tools.ARM64" --source winget
winget install --id Swift.Toolchain --exact --source winget
```

The automated checker bootstraps `winget` if needed. The manual installers linked
from the official Swift page remain a fallback for restricted machines that
cannot access the Microsoft Store or PowerShell Gallery.

## 2. Verify the toolchain

From a new PowerShell or Command Prompt window:

```powershell
swift --version
git --version
```

`swift --version` should report a Windows target matching the installed
toolchain, normally `x86_64-unknown-windows-msvc` on an x64 machine.

If Swift is installed in a nonstandard location, set `SWIFT_EXE` for the current
Command Prompt before running the build script:

```bat
set "SWIFT_EXE=C:\path\to\swift.exe"
buildandrun.bat
```

## 3. Build and test

From the repository root:

```powershell
swift build
swift run WinChocolateContractTests
```

Or use the project script, which builds, runs the contract tests, stages demo
resources, and launches the selected demo:

```bat
buildandrun.bat
buildandrun.bat --build
buildandrun.bat runloop
```

The script discovers `swift.exe` from `PATH` (or the standard per-user Swift
installation) and obtains the architecture-specific binary directory from
SwiftPM, so it works with both x64 and ARM64 toolchains.

## Troubleshooting

- **`Swift was not found`**: reopen the terminal after installing Swift, or set
  `SWIFT_EXE` explicitly as shown above.
- **MSVC, linker, or Windows SDK errors**: modify the Visual Studio installation
  and confirm that the C++ build tools and Windows SDK components are selected.
- **Developer Mode or symlink errors**: enable Windows Developer Mode as directed
  by Swift's manual installation guide.
- **Foundation-related compiler errors**: this project normally defines
  `USE_WIN_FOUNDATION` on Windows and uses the nested `WinFoundation` package.
  See `FOUNDATION_SHIMS.md` before forcing real Foundation.
