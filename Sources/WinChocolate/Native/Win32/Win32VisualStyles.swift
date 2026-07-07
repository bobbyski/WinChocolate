#if os(Windows)
/// Binds ComCtl32 v6 (themed visual styles) for the process — the modern
/// presentation's foundation (plan 8.1/8.2).
///
/// The process has no embedded manifest, so without this it binds unthemed
/// ComCtl32 v5 (the classic 3D look). A runtime **activation context** built
/// from a common-controls v6 manifest rebinds the process before any window
/// class or common control is created, so every native control renders with
/// the current Windows theme. The context stays active for the process
/// lifetime — the binding is one-way by design (`WinPresentation` documents
/// the set-before-startup contract).
extension Win32NativeControlBackend {
    nonisolated(unsafe) private static var modernVisualStylesEnabled = false

    /// The common-controls v6 dependency manifest the activation context loads.
    private static let commonControlsV6Manifest = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
      <dependency>
        <dependentAssembly>
          <assemblyIdentity type="win32" name="Microsoft.Windows.Common-Controls" version="6.0.0.0" processorArchitecture="*" publicKeyToken="6595b64144ccf1df" language="*"/>
        </dependentAssembly>
      </dependency>
    </assembly>
    """

    /// Activates the v6 activation context (idempotent). Called from backend
    /// startup when `WinPresentation.selected == .modern`.
    static func enableModernVisualStyles() {
        guard !modernVisualStylesEnabled else {
            return
        }
        modernVisualStylesEnabled = true

        // The activation context needs the manifest as a file on disk; stage
        // it under the local caches directory.
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            print("WinChocolate: no caches directory; staying on classic visual styles.")
            return
        }
        let directory = caches.appendingPathComponent("WinChocolate")
        try? FileManager.default.createDirectory(atPath: directory.path, withIntermediateDirectories: true)
        let manifestURL = directory.appendingPathComponent("comctl32-v6.manifest")
        do {
            try Data(Array(commonControlsV6Manifest.utf8)).write(to: manifestURL)
        } catch {
            print("WinChocolate: could not stage the v6 manifest; staying on classic visual styles.")
            return
        }

        let activated = withWideString(manifestURL.path) { manifestPath -> Bool in
            var context = ACTCTXW()
            context.cbSize = DWORD(MemoryLayout<ACTCTXW>.size)
            context.lpSource = manifestPath
            let handle = withUnsafePointer(to: context) { pointer in
                winCreateActCtxW(pointer)
            }
            guard let handle, handle != UnsafeMutableRawPointer(bitPattern: -1) else {
                return false
            }
            var cookie: UInt = 0
            // Left active for the process lifetime; never deactivated.
            return winActivateActCtx(handle, &cookie) != 0
        }
        if !activated {
            print("WinChocolate: v6 activation context failed (error \(winGetLastError())); staying on classic visual styles.")
        }
    }
}
#endif
