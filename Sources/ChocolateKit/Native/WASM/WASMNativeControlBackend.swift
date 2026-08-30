// The browser backend (Docs/WASMChocolatePlan.md, phases W1–W5).
//
// One `NativeControlBackend` over SwiftDOM. It starts from the in-memory
// recorder, so the ~160 requirements this spike has not built yet keep their
// honest recording behaviour instead of crashing, and only the slice the click
// counter actually exercises is overridden here: application lifecycle, the
// main menu, windows, views, buttons, labels, geometry, text, and the click
// path. Everything overridden calls `super` first, so the recorded state the
// contract tests inspect stays true of the DOM as well.
//
// Two rules from the plan are load-bearing in this file:
//
//   * The page owns the event loop. `runApplication()` mounts and RETURNS; it
//     never blocks. The wasm instance stays alive because JavaScript holds it
//     and the listeners below hold Swift.
//   * Listener lifetime is token-based. `addEventListener` hands back a
//     removable `EventListener`; those tokens are kept per handle here rather
//     than using SwiftDOM's `.on(...)`, which retains its closure forever in a
//     global store with no per-listener release.

#if canImport(JavaScriptKit)

import JavaScriptKit
import JavaScriptEventLoop
import SwiftDOM

/// Renders the AppKit surface into the browser DOM.
public final class WASMNativeControlBackend: InMemoryNativeControlBackend {
    /// The element mounted into `document.body` that every window sits in.
    ///
    /// A browser has no window server, so the backend supplies one: this is the
    /// desktop, and each `NSWindow` is a positioned child of it.
    internal var desktop: Element?

    /// The DOM element behind each native handle.
    internal var elements: [NativeHandle: Element] = [:]

    /// The caption inside each "under construction" placeholder.
    ///
    /// Keyed by handle so `setDebugClassName` can correct the name and
    /// `setText` can append the control's own text. See `WASMPlaceholders`.
    internal var placeholderCaptions: [NativeHandle: Element] = [:]

    /// The element a window's content is added to — its client area, below the
    /// synthesized title bar.
    internal var windowContent: [NativeHandle: Element] = [:]

    /// The label inside a window's synthesized title bar.
    ///
    /// A window's title arrives through `setText(_:for:)` — the same call a
    /// button or a label gets — so text aimed at a window has to be steered
    /// here. Writing it to the window element itself would replace the title
    /// bar and the content area with a text node, which is exactly what the
    /// first run of this backend did.
    internal var windowTitleLabels: [NativeHandle: Element] = [:]

    /// Listener tokens, kept so `destroyControl` can actually release them.
    internal var listeners: [NativeHandle: [EventListener]] = [:]

    /// Page-level closures kept alive for the backend's lifetime — the
    /// clipboard watcher, and anything else attached to `document` rather than
    /// to one control. A `JSClosure` that goes out of scope stops being called.
    internal var clipboardListeners: [JSClosure] = []

    /// The event-tracking session in flight, if any (`WASMEventTracking.swift`).
    internal var eventTracking: EventTrackingSession?

    /// The click listener carrying a control's primary action.
    ///
    /// Held separately from `listeners` because it is *replaced*, not added to:
    /// the core registers a control's action more than once over its life (peer
    /// realization and every later target/action change), and appending a
    /// second listener makes one click fire the action twice — which is exactly
    /// what a counter shows immediately, and a less honest demo would hide.
    private var actionListeners: [NativeHandle: EventListener] = [:]

    /// Listener tokens belonging to the menu bar.
    ///
    /// These must be held. `addEventListener` hands back a token whose `deinit`
    /// removes the listener, so discarding it with `_ =` unregisters the
    /// handler the instant the statement ends — the menu renders perfectly and
    /// then does nothing at all when clicked. The menu bar lives as long as the
    /// page, so these are simply never released.
    private var menuListeners: [EventListener] = []

    /// The main menu, held until there is a desktop to attach it to.
    ///
    /// `NSApplication.mainMenu`'s `didSet` fires before any window exists, so a
    /// backend that renders the menu bar into its own chrome has to hold the
    /// menu and replay it once mounted. The GTK backend hit this first and
    /// solved it the same way.
    private var pendingMainMenu: NSMenu?

    /// A canvas kept solely for text measurement.
    private var measuringCanvas: Element?

    /// Views awaiting the next paint pass. See `WASMPaintScheduler`.
    internal var dirtyHandles: Set<NativeHandle> = []

    /// Whether a paint pass is already queued for the next animation frame.
    internal var isPaintScheduled = false

    /// Views proved to paint themselves, and already captioned as such.
    internal var drawnHandles: Set<NativeHandle> = []

    /// The caption added to a framework-drawn view's own element.
    internal var drawnCaptions: [NativeHandle: Element] = [:]

    /// The interactive element inside a control, when it is not the box itself.
    ///
    /// A checkbox is a `<label>` wrapping an `<input>`; a combo box is a `<div>`
    /// wrapping an `<input>` and its `<datalist>`. The box is what gets
    /// positioned and what `elements[handle]` holds; this is what gets read,
    /// written and listened to.
    internal var inputElements: [NativeHandle: Element] = [:]

    /// The title text beside a checkbox or radio button.
    internal var titleSpans: [NativeHandle: Element] = [:]

    /// The `<datalist>` backing a combo box.
    internal var comboLists: [NativeHandle: Element] = [:]

    /// A stepper's up and down arrows.
    internal var stepperArrows: [NativeHandle: (up: Element, down: Element)] = [:]

    /// The `<canvas>` a framework-drawn view paints into.
    internal var drawingCanvases: [NativeHandle: Element] = [:]

    /// Decoded images, shared across paints so a repaint is not a reload.
    internal let imageCache = WASMImageCache()

    /// Views whose children are measured from the bottom edge.
    internal var unflippedViews: Set<NativeHandle> = []

    /// Live repeating timers, by the identifier handed to the framework.
    internal var nativeTimers: [UInt: DOMTimer] = [:]

    /// The next timer identifier to hand out.
    internal var nextWASMTimerIdentifier: UInt = 1

    /// A scroll view's document element — the thing that is actually sized.
    internal var scrollDocuments: [NativeHandle: Element] = [:]

    /// A tab view's content area, below its tab strip.
    internal var tabContents: [NativeHandle: Element] = [:]

    /// A tab view's strip buttons, so selection can restyle them.
    internal var tabButtons: [NativeHandle: [Element]] = [:]

    /// A tab view's strip, rebuilt when its tabs change.
    internal var tabStrips: [NativeHandle: Element] = [:]

    /// A table's `<tbody>`, `<thead>`, rows and header cells.
    internal var tableBodies: [NativeHandle: Element] = [:]
    internal var tableHeads: [NativeHandle: Element] = [:]
    internal var tableRows: [NativeHandle: [Element]] = [:]
    internal var tableHeaderCells: [NativeHandle: [Element]] = [:]

    /// The listener watching for a click outside a transient popover.
    internal var outsideClickListener: EventListener?

    /// The open context menu, if any.
    internal var contextMenuElement: Element?

    /// Listeners belonging to the open context menu.
    internal var contextMenuListeners: [EventListener] = []

    /// The dock along the bottom of the desktop, holding minimized windows.
    internal var dock: Element?

    /// One dock tile per minimized window.
    internal var dockTiles: [NativeHandle: Element] = [:]

    /// Listeners live only for the duration of a drag.
    internal var gestureListeners: [EventListener] = []

    /// Kinds whose text the user is meant to be able to select and edit.
    internal static let editableKinds: Set<String> = [
        "editableTextField", "secureTextField", "editableTextView", "textView", "comboBox"
    ]

    /// Height of the synthesized menu bar; windows sit below it.
    internal static var menuBarHeight: CGFloat { 24 }

    /// Creates the backend.
    public override init() {
        super.init()
        // Must happen before any `Task` is created, and creating the backend is
        // the earliest point this backend controls. Without it Swift concurrency
        // has no executor on the browser loop and a `Task { @MainActor … }`
        // never runs — the same class of silent death as a dropped animation
        // frame, and just as hard to see afterwards.
        JavaScriptEventLoop.installGlobalExecutor()
    }

    // MARK: - Application lifecycle

    /// Mounts the desktop and hands control back to the browser.
    ///
    /// This is the single largest divergence from every other backend, and it
    /// is not a shortcut: a page that blocks here freezes the tab. See
    /// `WASIFoundationShims.RunLoop`.
    public override func runApplication() {
        super.runApplication()
        mountDesktopIfNeeded()
        beginWatchingSystemClipboard()
        // The tree was built before this call, so its first paint cannot wait
        // on an animation frame that was requested mid-`main`. See flushPaint.
        flushPaint()
    }

    /// Ends the app as far as a page can.
    ///
    /// A page cannot exit. Rather than pretend otherwise, the desktop is made
    /// inert and says what happened — ground rule 4, degrade visibly.
    public override func terminateApplication() {
        super.terminateApplication()
        guard let desktop else { return }
        _ = desktop.removeAllChildren()
        let banner = Element.div()
            .setStyle("padding", "24px")
            .setStyle("font", "14px system-ui, sans-serif")
            .setStyle("color", "#444")
        banner.textContent = "Application terminated. Reload the page to run it again."
        _ = desktop.appendChild(banner)
    }

    /// Runs a block on the next turn of the browser's event loop.
    public override func dispatchAsync(_ action: @escaping () -> Void) {
        _ = DOM.window.setTimeout(milliseconds: 0) { action() }
    }

    // MARK: - Menus

    /// Renders the main menu bar, or holds it until there is a desktop.
    public override func installMainMenu(_ menu: NSMenu?) {
        super.installMainMenu(menu)
        pendingMainMenu = menu
        renderMainMenuIfPossible()
    }

    private func renderMainMenuIfPossible() {
        guard let desktop, let menu = pendingMainMenu else { return }

        let bar = Element.div()
            .setStyle("position", "absolute")
            .setStyle("top", "0").setStyle("left", "0").setStyle("right", "0")
            .setStyle("height", "24px")
            .setStyle("display", "flex")
            .setStyle("align-items", "stretch")
            .setStyle("background", "#e8e8e8")
            .setStyle("border-bottom", "1px solid #c0c0c0")
            .setStyle("font", "13px system-ui, sans-serif")
            .setStyle("user-select", "none")
            .setStyle("z-index", "1000")

        for item in menu.items where !item.isHidden {
            _ = bar.appendChild(makeMenuTitle(for: item))
        }
        _ = desktop.appendChild(bar)
    }

    /// Builds one top-level menu title and the dropdown it opens.
    private func makeMenuTitle(for item: NSMenuItem) -> Element {
        let title = Element.div()
            .setStyle("position", "relative")
            .setStyle("padding", "0 10px")
            .setStyle("display", "flex")
            .setStyle("align-items", "center")
            .setStyle("cursor", "default")
        title.textContent = item.title

        guard let submenu = item.submenu else { return title }

        let dropdown = Element.div()
            .setStyle("position", "absolute")
            .setStyle("top", "24px").setStyle("left", "0")
            .setStyle("min-width", "180px")
            .setStyle("padding", "4px 0")
            .setStyle("background", "#f6f6f6")
            .setStyle("border", "1px solid #c0c0c0")
            .setStyle("box-shadow", "0 2px 6px rgba(0,0,0,0.2)")
            .setStyle("display", "none")

        for entry in submenu.items where !entry.isHidden {
            _ = dropdown.appendChild(makeMenuRow(for: entry, dropdown: dropdown))
        }
        _ = title.appendChild(dropdown)

        menuListeners.append(title.addEventListener(.click) { event in
            event.stopPropagation()
            let isOpen = dropdown.getStyle("display") == "block"
            _ = dropdown.setStyle("display", isOpen ? "none" : "block")
        })
        // Clicking anywhere else dismisses the menu, as every menu bar does.
        menuListeners.append(DOM.document.body.addEventListener(.click) { _ in
            _ = dropdown.setStyle("display", "none")
        })
        return title
    }

    /// Builds one dropdown row.
    ///
    /// Activation goes straight to `performAction()`: the backend renders the
    /// menu, the core decides what an item means. That is how `"terminate:"`
    /// reaches the application through the responder chain with no browser
    /// knowledge anywhere in the path.
    private func makeMenuRow(for item: NSMenuItem, dropdown: Element) -> Element {
        if item.isSeparatorItem {
            return Element.div()
                .setStyle("height", "1px")
                .setStyle("margin", "4px 0")
                .setStyle("background", "#d0d0d0")
        }

        let row = Element.div()
            .setStyle("padding", "4px 14px")
            .setStyle("cursor", "default")
            .setStyle("color", item.isEnabled ? "#111" : "#999")
        row.textContent = item.keyEquivalent.isEmpty
            ? item.title
            : "\(item.title)\t⌘\(item.keyEquivalent.uppercased())"

        guard item.isEnabled else { return row }
        menuListeners.append(row.addEventListener(.click) { event in
            event.stopPropagation()
            _ = dropdown.setStyle("display", "none")
            _ = item.performAction()
        })
        return row
    }

    // MARK: - Windows

    /// Creates a window as a positioned element on the desktop.
    public override func createWindow(title: String, frame: NSRect,
                                      styleMask: NSWindow.StyleMask,
                                      usesMainMenu: Bool) -> NativeHandle {
        let handle = super.createWindow(title: title, frame: frame,
                                        styleMask: styleMask, usesMainMenu: usesMainMenu)
        mountDesktopIfNeeded()

        let window = Element.div()
            .setStyle("position", "absolute")
            .setStyle("left", "\(frame.origin.x)px")
            .setStyle("top", "\(frame.origin.y + Self.menuBarHeight)px")   // below the menu bar
            .setStyle("width", "\(frame.size.width)px")
            .setStyle("background", "#f0f0f0")
            .setStyle("border", "1px solid #a0a0a0")
            .setStyle("box-shadow", "0 4px 16px rgba(0,0,0,0.25)")
            .setStyle("font", "13px system-ui, sans-serif")
            .setStyle("display", "none")

        if styleMask.contains(.titled) {
            _ = window.appendChild(makeTitleBar(
                title: title, handle: handle,
                closable: styleMask.contains(.closable),
                miniaturizable: styleMask.contains(.miniaturizable)))
        }

        let content = Element.div()
            .setStyle("position", "relative")
            .setStyle("width", "\(frame.size.width)px")
            .setStyle("height", "\(frame.size.height)px")
            .setStyle("overflow", "hidden")
        _ = window.appendChild(content)

        elements[handle] = window
        windowContent[handle] = content

        // Resizable is a styleMask fact, so honour it rather than always
        // drawing a grip: a fixed-size panel that looks resizable is a lie the
        // user only discovers by dragging it.
        if styleMask.contains(.resizable) {
            _ = window.appendChild(makeResizeGrip(handle: handle))
        }
        desktop.map { _ = $0.appendChild(window) }
        return handle
    }

    private func makeTitleBar(title: String, handle: NativeHandle,
                             closable: Bool, miniaturizable: Bool) -> Element {
        let bar = Element.div()
            .setStyle("display", "flex")
            .setStyle("align-items", "center")
            .setStyle("height", "26px")
            .setStyle("padding", "0 8px")
            .setStyle("background", "linear-gradient(#fdfdfd, #e4e4e4)")
            .setStyle("border-bottom", "1px solid #b8b8b8")
            .setStyle("user-select", "none")

            .setStyle("cursor", "default")

        let label = Element.div().setStyle("flex", "1").setStyle("font-weight", "500")
        label.textContent = title
        windowTitleLabels[handle] = label
        _ = bar.appendChild(label)
        installWindowDrag(on: bar, handle: handle)

        if miniaturizable {
            let minimize = Element.div()
                .setStyle("width", "14px").setStyle("height", "14px")
                .setStyle("border-radius", "7px")
                .setStyle("margin-right", "6px")
                .setStyle("background", "#febc2e")
                .setStyle("cursor", "default")
            let token = minimize.addEventListener(.click) { [weak self] event in
                event.stopPropagation()
                self?.setWindowMinimized(true, for: handle)
            }
            listeners[handle, default: []].append(token)
            _ = bar.appendChild(minimize)
        }

        if closable {
            let close = Element.div()
                .setStyle("width", "14px").setStyle("height", "14px")
                .setStyle("border-radius", "7px")
                .setStyle("background", "#ff5f57")
                .setStyle("cursor", "default")
            // The close box asks the core, which consults the delegate's
            // shouldClose and then closes — the same path the other backends
            // drive from a real title bar.
            let token = close.addEventListener(.click) { [weak self] _ in
                self?.dismissWindow(handle)
            }
            listeners[handle, default: []].append(token)
            _ = bar.appendChild(close)
        }
        return bar
    }

    /// Shows a window.
    public override func showWindow(_ handle: NativeHandle) {
        super.showWindow(handle)
        mountDesktopIfNeeded()
        _ = elements[handle]?.setStyle("display", "block")
    }

    /// Fades a window in or out.
    ///
    /// Not decoration — this is how a popover is shown at all. `NSPopover.show`
    /// branches on `animates`, which defaults to `true`, so the ordinary path
    /// never reaches `orderFrontRegardless`/`showWindow`; it calls here
    /// instead. Leaving it to the recorder meant the popover was built,
    /// positioned, told to appear, and never displayed.
    public override func fadeWindow(_ handle: NativeHandle, visible: Bool) {
        super.fadeWindow(handle, visible: visible)
        guard let element = elements[handle] else { return }
        _ = element
            .setStyle("transition", "opacity 120ms ease")
            .setStyle("opacity", visible ? "1" : "0")
            .setStyle("display", visible ? "block" : "none")
    }

    /// Watches for a click outside a window and dismisses it.
    ///
    /// A transient popover is borderless — no title bar, no close box — so this
    /// is the only way it can be closed. Registered a turn later so the click
    /// that opened the popover does not immediately dismiss it, and tested for
    /// containment so a click *inside* it does not either.
    public override func beginOutsideClickDismiss(for handle: NativeHandle,
                                                  onDismiss: @escaping () -> Void) {
        super.beginOutsideClickDismiss(for: handle, onDismiss: onDismiss)
        endOutsideClickDismissListener()
        _ = DOM.window.setTimeout(milliseconds: 0) { [weak self] in
            guard let self, DOM.isBrowser else { return }
            // Capture phase: a press inside a view stops bubbling (see
            // `onPointer`), so a bubble-phase listener would never see the
            // presses that are supposed to dismiss.
            self.outsideClickListener = DOM.document.body.addEventListener(
                .pointerdown, options: EventListenerOptions(capture: true, once: false, passive: false)
            ) { event in
                guard let element = self.elements[handle] else { return }
                if let target = event.target, element.contains(target) { return }
                onDismiss()
            }
        }
    }

    /// Stops watching for the outside click.
    public override func endOutsideClickDismiss() {
        super.endOutsideClickDismiss()
        endOutsideClickDismissListener()
    }

    /// Drops the outside-click listener, if any.
    internal func endOutsideClickDismissListener() {
        outsideClickListener?.remove()
        outsideClickListener = nil
    }

    /// Hides and discards a window.
    public override func closeWindow(_ handle: NativeHandle) {
        super.closeWindow(handle)
        discardWindowElement(handle)
    }

    /// Runs the title-bar close: ask, tell the core, then destroy the frame.
    ///
    /// The last step is this backend's job alone. `nativeWindowDidClose()`
    /// deliberately does *not* call `closeWindow` — on Win32 and GTK the window
    /// server is already tearing the window down when the title bar is clicked,
    /// so closing it again would be wrong. Here there is no window server but
    /// this backend, so nothing destroys the frame unless it does: the core
    /// tore out the content view and nil'd its handle, and what stayed on
    /// screen was an empty box with a working close button and nothing inside.
    internal func dismissWindow(_ handle: NativeHandle) {
        guard windowShouldCloseHandlers[handle]?() ?? true else { return }
        windowCloseActions[handle]?()
        discardWindowElement(handle)
    }

    /// Removes a window's element and everything filed against it.
    ///
    /// Idempotent: a programmatic `close()` reaches `closeWindow` *and* fires
    /// the close action, so this runs twice for one close.
    internal func discardWindowElement(_ handle: NativeHandle) {
        _ = elements.removeValue(forKey: handle)?.remove()
        windowContent.removeValue(forKey: handle)
        windowTitleLabels.removeValue(forKey: handle)
        listeners.removeValue(forKey: handle)?.forEach { $0.remove() }
        setDockTile(false, for: handle)
    }

    // MARK: - Views and controls

    /// Creates a plain container view.
    public override func createView(frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = super.createView(frame: frame, parent: parent)
        let view = Element.div()
            .setStyle("position", "absolute")
            .setStyle("left", "\(frame.origin.x)px")
            .setStyle("top", "\(frame.origin.y)px")
            .setStyle("width", "\(frame.size.width)px")
            .setStyle("height", "\(frame.size.height)px")
        register(handle, element: view, parent: parent)
        return handle
    }

    /// Creates a push button.
    public override func createButton(title: String, frame: NSRect,
                                      parent: NativeHandle?, isBordered: Bool) -> NativeHandle {
        let handle = super.createButton(title: title, frame: frame,
                                        parent: parent, isBordered: isBordered)
        let button = Element.button()
            .setStyle("position", "absolute")
            .setStyle("left", "\(frame.origin.x)px")
            .setStyle("top", "\(frame.origin.y)px")
            .setStyle("width", "\(frame.size.width)px")
            .setStyle("height", "\(frame.size.height)px")
            .setStyle("font", "13px system-ui, sans-serif")
        button.textContent = title
        register(handle, element: button, parent: parent)
        return handle
    }

    /// Creates a text field, or a label when the options say so.
    ///
    /// A label is exactly a non-editable, non-bordered field that draws no
    /// background — the same distinction every other backend makes.
    public override func createTextField(text: String, frame: NSRect,
                                         parent: NativeHandle?,
                                         options: NativeTextFieldOptions) -> NativeHandle {
        let handle = super.createTextField(text: text, frame: frame,
                                           parent: parent, options: options)
        let element: Element
        if options.isEditable {
            element = Element.input()
            _ = element.setAttribute("value", text)
        } else {
            element = Element.div()
            element.textContent = text
            _ = element.setStyle("display", "flex").setStyle("align-items", "center")
            // **The DOM must wrap exactly where the measurement says it will.**
            // A single-line label is measured as one line and given a one-line
            // box; left to itself the browser wraps the text anyway, it
            // overflows the box, and in a table it lands on top of the row
            // below. Telling the DOM not to wrap is what makes the measurement
            // true. A multiline label wraps in both places, and the wrapping
            // measurement now uses the browser's own metrics so the two agree.
            if options.isMultiline {
                _ = element
                    .setStyle("white-space", "pre-wrap")
                    .setStyle("align-items", "flex-start")
            } else {
                _ = element
                    .setStyle("white-space", "nowrap")
                    .setStyle("overflow", "hidden")
                    .setStyle("text-overflow", "ellipsis")
            }
        }
        _ = element
            .setStyle("position", "absolute")
            .setStyle("left", "\(frame.origin.x)px")
            .setStyle("top", "\(frame.origin.y)px")
            .setStyle("width", "\(frame.size.width)px")
            .setStyle("height", "\(frame.size.height)px")
            .setStyle("font", "13px system-ui, sans-serif")
        if !options.isBordered {
            _ = element.setStyle("border", "none").setStyle("background", "transparent")
        }
        register(handle, element: element, parent: parent)
        return handle
    }

    // MARK: - Controls not built yet
    //
    // Every one of these produces a visible, captioned box rather than nothing,
    // for the reason given at the top of `WASMPlaceholders.swift`: a create call
    // that files no element orphans the whole subtree under it. Each is one line
    // away from being a real control — swap `makePlaceholder` for the DOM
    // builder and delete the row from `WASM_PARITY.md`.
    //
    // `createView`, `createWindow`, `createButton` and `createTextField` are
    // absent on purpose: they are implemented, and striping the universal
    // container would cover the page in hazard tape.

    /// Creates a checkbox as a real `<input type=checkbox>`.
    public override func createCheckbox(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = super.createCheckbox(title: title, frame: frame, parent: parent)
        makeToggle(handle, title: title, frame: frame, parent: parent, isRadio: false)
        return handle
    }

    /// Creates a radio button as a real `<input type=radio>`.
    public override func createRadioButton(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = super.createRadioButton(title: title, frame: frame, parent: parent)
        makeToggle(handle, title: title, frame: frame, parent: parent, isRadio: true)
        return handle
    }

    /// Creates a group box as a real `<fieldset>`.
    public override func createBox(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = super.createBox(title: title, frame: frame, parent: parent)
        makeBox(handle, title: title, frame: frame, parent: parent)
        return handle
    }

    /// Creates a secure field as `<input type=password>`.
    public override func createSecureTextField(text: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = super.createSecureTextField(text: text, frame: frame, parent: parent)
        makeSecureField(handle, text: text, frame: frame, parent: parent)
        return handle
    }

    /// Creates a text view as a real `<textarea>`.
    public override func createTextView(text: String, frame: NSRect, parent: NativeHandle?,
                                        isEditable: Bool, isRichText: Bool) -> NativeHandle {
        let handle = super.createTextView(text: text, frame: frame, parent: parent,
                                          isEditable: isEditable, isRichText: isRichText)
        makeTextView(handle, text: text, isEditable: isEditable, frame: frame, parent: parent)
        return handle
    }

    /// Creates a pop-up button as a real `<select>`.
    ///
    /// Implemented ahead of the other value controls because the demo's page
    /// selector is one, so this is what makes all eleven pages reachable from
    /// inside the app rather than only through `?page=N`.
    public override func createPopUpButton(items: [String], selectedIndex: Int,
                                           frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = super.createPopUpButton(items: items, selectedIndex: selectedIndex,
                                             frame: frame, parent: parent)
        let select = Element.select()
            .setStyle("position", "absolute")
            .setStyle("box-sizing", "border-box")
            .setStyle("left", "\(frame.origin.x)px")
            .setStyle("top", "\(frame.origin.y)px")
            .setStyle("width", "\(frame.size.width)px")
            .setStyle("height", "\(frame.size.height)px")
            .setStyle("font", "13px system-ui, sans-serif")
        fillPopUpOptions(select, items: items, selectedIndex: selectedIndex)
        register(handle, element: select, parent: parent)
        return handle
    }

    /// Replaces a pop-up button's items.
    public override func setPopUpButtonItems(_ items: [String], selectedIndex: Int,
                                             for handle: NativeHandle) {
        super.setPopUpButtonItems(items, selectedIndex: selectedIndex, for: handle)
        guard let select = elements[handle], records[handle]?.kind == "popUpButton" else {
            return
        }

        _ = select.removeAllChildren()
        fillPopUpOptions(select, items: items, selectedIndex: selectedIndex)
    }

    /// Moves a pop-up button's selection.
    public override func setPopUpButtonSelectedIndex(_ selectedIndex: Int, for handle: NativeHandle) {
        super.setPopUpButtonSelectedIndex(selectedIndex, for: handle)
        guard let select = elements[handle], records[handle]?.kind == "popUpButton" else {
            return
        }

        select.value = records[handle]?.popUpItems.indices.contains(selectedIndex) == true
            ? records[handle]!.popUpItems[selectedIndex]
            : ""
    }

    /// Creates a combo box as an editable `<input>` with a `<datalist>`.
    public override func createComboBox(items: [String], text: String,
                                        frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = super.createComboBox(items: items, text: text, frame: frame, parent: parent)
        makeComboBox(handle, items: items, text: text, frame: frame, parent: parent)
        return handle
    }

    /// Replaces a combo box's completions.
    public override func setComboBoxItems(_ items: [String], text: String, for handle: NativeHandle) {
        super.setComboBoxItems(items, text: text, for: handle)
        if let list = comboLists[handle] {
            fillComboOptions(handle, list, items: items)
        }
        inputElements[handle]?.value = text
    }

    /// Creates an image view as a real `<img>`.
    public override func createImageView(description: String, imagePath: String?,
                                         frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = super.createImageView(description: description, imagePath: imagePath,
                                           frame: frame, parent: parent)
        makeImageView(handle, imagePath: imagePath, description: description,
                      frame: frame, parent: parent)
        return handle
    }

    /// Repoints an image view at a new file.
    public override func setImagePath(_ imagePath: String?, description: String,
                                      tint: NSColor?, for handle: NativeHandle) {
        super.setImagePath(imagePath, description: description, tint: tint, for: handle)
        guard let image = inputElements[handle], records[handle]?.kind == "imageView" else { return }
        _ = image.setAttribute("alt", description)
        applyImagePath(image, path: imagePath, description: description)
    }

    /// Creates a tab view: a strip of tab buttons over a content area.
    public override func createTabView(items: [String], selectedIndex: Int,
                                       frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = super.createTabView(items: items, selectedIndex: selectedIndex,
                                         frame: frame, parent: parent)
        makeTabView(handle, items: items, selectedIndex: selectedIndex,
                    frame: frame, parent: parent)
        return handle
    }

    /// Replaces a tab view's tabs.
    public override func setTabViewItems(_ items: [String], selectedIndex: Int,
                                         for handle: NativeHandle) {
        super.setTabViewItems(items, selectedIndex: selectedIndex, for: handle)
        rebuildTabStrip(handle, items: items, selectedIndex: selectedIndex)
    }

    /// Moves a tab view's selection.
    public override func setTabViewSelectedIndex(_ selectedIndex: Int, for handle: NativeHandle) {
        super.setTabViewSelectedIndex(selectedIndex, for: handle)
        highlightTab(selectedIndex, for: handle)
    }

    /// Creates a toolbar placeholder.
    ///
    /// Custom-view toolbar items are real subviews, so they are parented into
    /// this box and render for real — which is why the demo's page selector is
    /// reachable long before toolbar chrome is drawn.
    public override func createToolbar(items: [NativeToolbarItem],
                                       frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = super.createToolbar(items: items, frame: frame, parent: parent)
        makePlaceholder(handle, kind: "toolbar", frame: frame, parent: parent)
        return handle
    }

    /// Creates a slider as a real `<input type=range>`.
    public override func createSlider(value: Double, minValue: Double, maxValue: Double,
                                      frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = super.createSlider(value: value, minValue: minValue, maxValue: maxValue,
                                        frame: frame, parent: parent)
        makeSlider(handle, value: value, minValue: minValue, maxValue: maxValue,
                   frame: frame, parent: parent)
        return handle
    }

    /// Moves a slider's knob.
    public override func setSliderValue(_ value: Double, for handle: NativeHandle) {
        super.setSliderValue(value, for: handle)
        inputElements[handle]?.value = "\(value)"
    }

    /// Changes a slider's range.
    public override func setSliderRange(minValue: Double, maxValue: Double, for handle: NativeHandle) {
        super.setSliderRange(minValue: minValue, maxValue: maxValue, for: handle)
        guard let input = inputElements[handle] else { return }
        applySliderRange(input, minValue: minValue, maxValue: maxValue)
        input.value = "\(sliderValue(for: handle))"
    }

    /// Checks or clears a checkbox or radio button.
    public override func setButtonState(_ state: NSControl.StateValue, for handle: NativeHandle) {
        super.setButtonState(state, for: handle)
        inputElements[handle]?.checked = state != .off
    }

    /// Creates a progress indicator as a real `<progress>`.
    public override func createProgressIndicator(value: Double, minValue: Double, maxValue: Double,
                                                 frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = super.createProgressIndicator(value: value, minValue: minValue,
                                                   maxValue: maxValue, frame: frame, parent: parent)
        makeProgressIndicator(handle, value: value, minValue: minValue, maxValue: maxValue,
                              frame: frame, parent: parent)
        return handle
    }

    /// Moves a progress bar.
    public override func setProgressIndicatorValue(_ value: Double, for handle: NativeHandle) {
        super.setProgressIndicatorValue(value, for: handle)
        guard let bar = inputElements[handle], let record = records[handle] else { return }
        applyProgress(bar, value: value, minValue: record.progressMinValue, maxValue: record.progressMaxValue)
    }

    /// Changes a progress bar's range.
    public override func setProgressIndicatorRange(minValue: Double, maxValue: Double,
                                                   for handle: NativeHandle) {
        super.setProgressIndicatorRange(minValue: minValue, maxValue: maxValue, for: handle)
        guard let bar = inputElements[handle], let record = records[handle] else { return }
        applyProgress(bar, value: record.progressValue, minValue: minValue, maxValue: maxValue)
    }

    /// Switches a progress bar between determinate and busy.
    public override func setProgressIndicatorIndeterminate(_ isIndeterminate: Bool, animating: Bool,
                                                           for handle: NativeHandle) {
        super.setProgressIndicatorIndeterminate(isIndeterminate, animating: animating, for: handle)
        guard let bar = inputElements[handle], let record = records[handle] else { return }
        if isIndeterminate {
            // A <progress> with no value is HTML's "busy, length unknown".
            _ = bar.removeAttribute("value")
        } else {
            applyProgress(bar, value: record.progressValue,
                          minValue: record.progressMinValue, maxValue: record.progressMaxValue)
        }
    }

    /// Creates a scroller as a range input.
    public override func createScroller(value: Double, knobProportion: Double, isVertical: Bool,
                                        frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = super.createScroller(value: value, knobProportion: knobProportion,
                                          isVertical: isVertical, frame: frame, parent: parent)
        makeScroller(handle, value: value, isVertical: isVertical, frame: frame, parent: parent)
        return handle
    }

    /// Moves a scroller's knob.
    public override func setScrollerValue(_ value: Double, knobProportion: Double,
                                          for handle: NativeHandle) {
        super.setScrollerValue(value, knobProportion: knobProportion, for: handle)
        inputElements[handle]?.value = "\(value)"
    }

    /// Creates a stepper as its up/down arrow pair.
    public override func createStepper(configuration: NativeStepperConfiguration,
                                       frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = super.createStepper(configuration: configuration, frame: frame, parent: parent)
        makeStepper(handle, configuration: configuration, frame: frame, parent: parent)
        return handle
    }

    /// Creates a date picker as `<input type=datetime-local>`.
    public override func createDatePicker(configuration: NativeDatePickerConfiguration,
                                          frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = super.createDatePicker(configuration: configuration, frame: frame, parent: parent)
        makeDatePicker(handle, configuration: configuration, frame: frame, parent: parent)
        return handle
    }

    /// Moves a date picker's value.
    public override func setDatePickerDate(_ date: Date, minDate: Date?, maxDate: Date?,
                                           for handle: NativeHandle) {
        super.setDatePickerDate(date, minDate: minDate, maxDate: maxDate, for: handle)
        inputElements[handle]?.value = Self.localDateTimeString(date)
    }

    /// Creates a table view as a real scrolling `<table>`.
    public override func createTableView(columns: [String], columnWidths: [CGFloat],
                                         content: NativeTableContent,
                                         frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = super.createTableView(columns: columns, columnWidths: columnWidths,
                                           content: content, frame: frame, parent: parent)
        makeTableView(handle, columns: columns, columnWidths: columnWidths,
                      content: content, frame: frame, parent: parent)
        return handle
    }

    /// Replaces every row.
    public override func setTableRows(_ rows: [[String]], selectedRow: Int,
                                      for handle: NativeHandle) {
        super.setTableRows(rows, selectedRow: selectedRow, for: handle)
        rebuildTableRows(handle, rows: rows, selectedRow: selectedRow)
    }

    /// Updates one cell in place.
    public override func setTableCellText(_ text: String, row: Int, column: Int,
                                          for handle: NativeHandle) {
        super.setTableCellText(text, row: row, column: column, for: handle)
        setTableCell(text, row: row, column: column, for: handle)
    }

    /// Moves the single-row selection.
    public override func setTableSelectedRow(_ selectedRow: Int, for handle: NativeHandle) {
        super.setTableSelectedRow(selectedRow, for: handle)
        highlightTableSelection(handle)
    }

    /// Moves a multi-row selection.
    public override func setTableSelectedRows(_ rows: Set<Int>, for handle: NativeHandle) {
        super.setTableSelectedRows(rows, for: handle)
        highlightTableSelection(handle)
    }

    /// Draws the sort arrow on a column header.
    public override func setTableSortIndicator(column: Int, ascending: Bool,
                                               for handle: NativeHandle) {
        super.setTableSortIndicator(column: column, ascending: ascending, for: handle)
        applySortIndicator(column: column, ascending: ascending, for: handle)
    }

    /// Scrolls a row into view.
    public override func scrollTableRowToVisible(_ row: Int, for handle: NativeHandle) {
        super.scrollTableRowToVisible(row, for: handle)
        scrollTableRow(row, for: handle)
    }

    /// Creates a scroll view.
    ///
    /// Not a placeholder: a scroll view is structure, and hazard-striping the
    /// container of the tables, the collection views and the stress page would
    /// bury the very content this backend is trying to show. The clipping and
    /// the scrollbars are real; the scroll *geometry* the framework pushes
    /// through `setScrollViewContentSize` is not honoured yet, so the box
    /// carries `data-cx-partial` and shows up in the census as incomplete
    /// rather than passing itself off as finished.
    public override func createScrollView(frame: NSRect, parent: NativeHandle?,
                                          hasVerticalScroller: Bool,
                                          hasHorizontalScroller: Bool) -> NativeHandle {
        let handle = super.createScrollView(frame: frame, parent: parent,
                                            hasVerticalScroller: hasVerticalScroller,
                                            hasHorizontalScroller: hasHorizontalScroller)
        let view = Element.div()
            .setStyle("position", "absolute")
            .setStyle("box-sizing", "border-box")
            .setStyle("left", "\(frame.origin.x)px")
            .setStyle("top", "\(frame.origin.y)px")
            .setStyle("width", "\(frame.size.width)px")
            .setStyle("height", "\(frame.size.height)px")
            .setStyle("overflow-x", hasHorizontalScroller ? "auto" : "hidden")
            .setStyle("overflow-y", hasVerticalScroller ? "auto" : "hidden")
        let document = Element.div()
            .setStyle("position", "relative")
            .setStyle("width", "100%")
            .setStyle("height", "100%")
        _ = view.appendChild(document)
        scrollDocuments[handle] = document
        register(handle, element: view, parent: parent)
        return handle
    }

    // MARK: - Painting

    /// Records a view's draw action and queues it for the next paint pass.
    public override func registerDrawAction(for handle: NativeHandle,
                                            action: @escaping (NativeDrawingContext, NSRect) -> Void) {
        super.registerDrawAction(for: handle, action: action)
        markNeedsPaint(handle)
    }

    /// Queues a repaint.
    public override func invalidateControl(_ handle: NativeHandle) {
        super.invalidateControl(handle)
        markNeedsPaint(handle)
    }

    /// Queues a repaint of a view and its descendants.
    public override func invalidateControlTree(_ handle: NativeHandle) {
        super.invalidateControlTree(handle)
        markNeedsPaint(handle)
    }

    /// Repaints now rather than on the next frame.
    public override func redrawControlImmediately(_ handle: NativeHandle) {
        super.redrawControlImmediately(handle)
        paintOnce(handle)
    }

    /// Hides a window into the dock, or brings it back.
    ///
    /// `setWindowMinimized` is a seam every backend already had; on this one it
    /// was an honest no-op, so a miniaturized window vanished with nowhere to
    /// go. The dock is the missing half.
    public override func setWindowMinimized(_ minimized: Bool, for handle: NativeHandle) {
        super.setWindowMinimized(minimized, for: handle)
        _ = elements[handle]?.setStyle("display", minimized ? "none" : "block")
        setDockTile(minimized, for: handle)
    }

    /// Confines a view's children to its box.
    ///
    /// The one place a DOM backend has to act where Win32 and GTK do not: their
    /// child widgets are already confined by the platform, while an absolutely
    /// positioned `div` paints wherever it likes. Without this a clip view
    /// shows its entire document instead of the part scrolled into view.
    public override func setClipsToBounds(_ clips: Bool, for handle: NativeHandle) {
        super.setClipsToBounds(clips, for: handle)
        _ = elements[handle]?.setStyle("overflow", clips ? "hidden" : "")
    }

    /// Records which edge a view's children are measured from.
    public override func setViewFlipped(_ flipped: Bool, for handle: NativeHandle) {
        super.setViewFlipped(flipped, for: handle)
        applyViewFlipped(flipped, for: handle)
    }

    /// Schedules a repeating timer on the browser's clock.
    public override func scheduleNativeTimer(intervalMilliseconds: Int,
                                             action: @escaping () -> Void) -> UInt {
        _ = super.scheduleNativeTimer(intervalMilliseconds: intervalMilliseconds, action: action)
        return startNativeTimer(intervalMilliseconds: intervalMilliseconds, action: action)
    }

    /// Cancels a repeating timer.
    public override func cancelNativeTimer(_ identifier: UInt) {
        super.cancelNativeTimer(identifier)
        stopNativeTimer(identifier)
    }

    /// Sizes a scroll view's document.
    public override func setScrollViewContentSize(_ contentSize: NSSize, viewportSize: NSSize,
                                                  hasVerticalScroller: Bool,
                                                  hasHorizontalScroller: Bool,
                                                  for handle: NativeHandle) {
        super.setScrollViewContentSize(contentSize, viewportSize: viewportSize,
                                       hasVerticalScroller: hasVerticalScroller,
                                       hasHorizontalScroller: hasHorizontalScroller, for: handle)
        applyScrollContentSize(contentSize, for: handle)
    }

    /// Moves a scroll view's visible origin.
    public override func setScrollViewContentOffset(_ offset: NSPoint, for handle: NativeHandle) {
        super.setScrollViewContentOffset(offset, for: handle)
        applyScrollContentOffset(offset, for: handle)
    }

    // MARK: - Input

    /// Delivers mouse-down through the responder chain, and captures the pointer.
    ///
    /// The capture is what makes dragging work at all. AppKit delivers every
    /// `mouseDragged` and the final `mouseUp` to the view the drag *started*
    /// on; the DOM delivers them to whatever is under the cursor. So a
    /// framework drag — the toolbar customization tiles, a drawn slider knob,
    /// any custom view that tracks the mouse — stalled the instant the pointer
    /// left the element, and its `mouseUp` was delivered somewhere else
    /// entirely, so the drop never ran. Capturing on press restores AppKit's
    /// rule and costs one call.
    public override func registerMouseDownAction(for handle: NativeHandle,
                                                 action: @escaping (NSEvent) -> Void) {
        super.registerMouseDownAction(for: handle, action: action)
        onPointer(.pointerdown, handle) { [weak self] event in
            guard let self, event.rawValue.button.number ?? 0 == 0 else { return }
            // Suppress the browser's own press gesture (text selection, image
            // dragging) for everything except editable fields, which need the
            // default to place a caret.
            if !Self.editableKinds.contains(self.records[handle]?.kind ?? "") {
                event.preventDefault()
            }
            if let pointerId = event.pointerId {
                self.elements[handle]?.setPointerCapture(pointerId)
            }
            action(self.mouseEvent(.leftMouseDown, event, for: handle))
        }
    }

    /// Delivers mouse-up and releases the pointer capture taken on press.
    public override func registerMouseUpAction(for handle: NativeHandle,
                                               action: @escaping (NSEvent) -> Void) {
        super.registerMouseUpAction(for: handle, action: action)
        onPointer(.pointerup, handle) { [weak self] event in
            guard let self, event.rawValue.button.number ?? 0 == 0 else { return }
            if let pointerId = event.pointerId {
                self.elements[handle]?.releasePointerCapture(pointerId)
            }
            action(self.mouseEvent(.leftMouseUp, event, for: handle))
        }
    }

    /// Delivers mouse-moved, and drags as moves with a button held.
    public override func registerMouseMovedAction(for handle: NativeHandle,
                                                  action: @escaping (NSEvent) -> Void) {
        super.registerMouseMovedAction(for: handle, action: action)
        onPointer(.pointermove, handle) { [weak self] event in
            guard let self, event.rawValue.buttons.number ?? 0 == 0 else { return }
            action(self.mouseEvent(.mouseMoved, event, for: handle))
        }
    }

    /// Delivers mouse-dragged — a move with a button down, as AppKit defines it.
    public override func registerMouseDraggedAction(for handle: NativeHandle,
                                                    action: @escaping (NSEvent) -> Void) {
        super.registerMouseDraggedAction(for: handle, action: action)
        onPointer(.pointermove, handle) { [weak self] event in
            guard let self, (event.rawValue.buttons.number ?? 0) != 0 else { return }
            action(self.mouseEvent(.leftMouseDragged, event, for: handle))
        }
    }

    /// Delivers mouse-exited.
    public override func registerMouseLeftAction(for handle: NativeHandle,
                                                 action: @escaping () -> Void) {
        super.registerMouseLeftAction(for: handle, action: action)
        onPointer(.pointerleave, handle) { _ in action() }
    }

    /// Delivers right mouse-down, suppressing the browser context menu.
    public override func registerRightMouseDownAction(for handle: NativeHandle,
                                                      action: @escaping (NSEvent) -> Void) {
        super.registerRightMouseDownAction(for: handle, action: action)
        guard let element = elements[handle] else { return }
        listeners[handle, default: []].append(
            element.addEventListener(.contextmenu) { [weak self] event in
                guard let self else { return }
                // The app is handling this click, so the browser's own menu
                // would be a second, competing menu over the top of it.
                event.preventDefault()
                action(self.mouseEvent(.rightMouseDown, event, for: handle))
            })
    }

    /// Delivers right mouse-up.
    public override func registerRightMouseUpAction(for handle: NativeHandle,
                                                    action: @escaping (NSEvent) -> Void) {
        super.registerRightMouseUpAction(for: handle, action: action)
        onPointer(.pointerup, handle) { [weak self] event in
            guard let self, event.rawValue.button.number ?? 0 == 2 else { return }
            action(self.mouseEvent(.rightMouseUp, event, for: handle))
        }
    }

    /// Delivers scroll-wheel deltas.
    public override func registerScrollWheelAction(for handle: NativeHandle,
                                                   action: @escaping (NSEvent) -> Void) {
        super.registerScrollWheelAction(for: handle, action: action)
        guard let element = elements[handle] else { return }
        listeners[handle, default: []].append(element.addEventListener(.wheel) { event in
            // Browser wheel deltas grow downward; AppKit's grow upward.
            action(NSEvent(type: .mouseMoved, locationInWindow: .zero,
                           scrollingDeltaX: CGFloat(-(event.rawValue.deltaX.number ?? 0)),
                           scrollingDeltaY: CGFloat(-(event.rawValue.deltaY.number ?? 0))))
        })
    }

    /// Delivers key-down.
    public override func registerKeyDownAction(for handle: NativeHandle,
                                               action: @escaping (NSEvent) -> Void) {
        super.registerKeyDownAction(for: handle, action: action)
        guard let element = elements[handle] else { return }
        // `tabindex` is what makes a plain div focusable at all — without it a
        // custom view can never receive a key event, however correct the
        // responder chain is.
        if records[handle]?.kind == "view" {
            _ = element.setAttribute("tabindex", "0")
            _ = element.setStyle("outline", "none")
        }
        listeners[handle, default: []].append(element.addEventListener(.keydown) { event in
            action(Self.keyEvent(.keyDown, event))
        })
    }

    /// Delivers key-up.
    public override func registerKeyUpAction(for handle: NativeHandle,
                                             action: @escaping (NSEvent) -> Void) {
        super.registerKeyUpAction(for: handle, action: action)
        guard let element = elements[handle] else { return }
        listeners[handle, default: []].append(element.addEventListener(.keyup) { event in
            action(Self.keyEvent(.keyUp, event))
        })
    }

    /// Reports focus gained and lost.
    public override func registerFocusChangeAction(for handle: NativeHandle,
                                                   action: @escaping (Bool) -> Void) {
        super.registerFocusChangeAction(for: handle, action: action)
        guard let element = inputElements[handle] ?? elements[handle] else { return }
        listeners[handle, default: []].append(element.addEventListener(.focus) { _ in action(true) })
        listeners[handle, default: []].append(element.addEventListener(.blur) { _ in action(false) })
    }

    /// Reports every keystroke in an editable control.
    public override func registerTextChangeAction(for handle: NativeHandle,
                                                  action: @escaping (String) -> Void) {
        super.registerTextChangeAction(for: handle, action: action)
        guard let element = inputElements[handle] ?? elements[handle] else { return }
        // `input`, not `change`: AppKit's text-change notifications fire per
        // keystroke, while `change` waits for the field to lose focus.
        listeners[handle, default: []].append(element.addEventListener(.input) { [weak self] _ in
            self?.records[handle]?.text = element.value
            action(element.value)
        })
    }

    /// Moves keyboard focus to a control.
    public override func focusControl(_ handle: NativeHandle) {
        super.focusControl(handle)
        _ = (inputElements[handle] ?? elements[handle])?.rawValue.focus?()
    }

    /// Matches a key equivalent before the browser acts on it.
    public override func registerKeyEquivalentHandler(_ handler: @escaping (NSEvent) -> Bool) {
        super.registerKeyEquivalentHandler(handler)
        guard DOM.isBrowser else { return }
        // Document-level, because a menu shortcut belongs to the app rather
        // than to whatever happens to hold focus. The default is suppressed
        // *only* when the handler claims the key, so Cmd-R and Cmd-L keep
        // working as the browser's own.
        menuListeners.append(DOM.document.body.addEventListener(.keydown) { event in
            if handler(Self.keyEvent(.keyDown, event)) {
                event.preventDefault()
            }
        })
    }

    /// Pops a context menu — right-click, `NSView.menu`, toolbar options.
    public override func runContextMenu(_ menu: NSMenu, atScreenPoint point: NSPoint) -> NSMenuItem? {
        _ = super.runContextMenu(menu, atScreenPoint: point)
        return presentContextMenu(menu, at: NSMakePoint(point.x, point.y + Self.menuBarHeight))
    }

    // MARK: - Modals

    /// Shows an alert using the browser's own blocking dialogs.
    ///
    /// This is the one place a page can honour AppKit's synchronous modal
    /// contract: `window.alert` and `window.confirm` genuinely block the event
    /// loop and return a value, which no other browser dialog does. That is
    /// why alerts work here while file, colour and font panels cannot (plan
    /// row W-H2) — those have async-only APIs and stay honest no-ops.
    ///
    /// A browser dialog offers at most two answers, so an alert with three
    /// buttons loses its third. That is a visible degrade, not a silent one:
    /// the third button's title is appended to the message so the choice is
    /// still legible even though it cannot be clicked.
    public override func runAlert(_ alert: NSAlert) -> NSApplication.ModalResponse {
        guard DOM.isBrowser else {
            return super.runAlert(alert)
        }

        var message = alert.messageText
        if !alert.informativeText.isEmpty {
            message += "\n\n" + alert.informativeText
        }
        let titles = alert.buttons.map { $0.title }
        if titles.count > 2 {
            message += "\n\n(" + titles.dropFirst(2).joined(separator: ", ")
                + " unavailable in a browser dialog)"
        }

        // One button is a statement, not a question — `confirm` would offer a
        // Cancel the app never asked for.
        guard titles.count > 1 else {
            DOM.window.alert(message)
            return .alertFirstButtonReturn
        }

        return DOM.window.confirm(message) ? .alertFirstButtonReturn : .alertSecondButtonReturn
    }

    // MARK: - Diagnostics

    /// This backend labels what it cannot draw, so it wants the real names.
    public override var wantsDebugClassNames: Bool { true }

    /// Corrects a placeholder's caption to the actual AppKit class.
    public override func setDebugClassName(_ name: String, for handle: NativeHandle) {
        super.setDebugClassName(name, for: handle)
        applyDebugClassName(name, to: handle)
    }

    /// Removes a control's element and everything filed against its handle.
    public override func destroyControl(_ handle: NativeHandle) {
        super.destroyControl(handle)
        actionListeners.removeValue(forKey: handle)?.remove()
        listeners.removeValue(forKey: handle)?.forEach { $0.remove() }
        placeholderCaptions.removeValue(forKey: handle)
        drawnCaptions.removeValue(forKey: handle)
        inputElements.removeValue(forKey: handle)
        titleSpans.removeValue(forKey: handle)
        comboLists.removeValue(forKey: handle)
        stepperArrows.removeValue(forKey: handle)
        scrollDocuments.removeValue(forKey: handle)
        tabContents.removeValue(forKey: handle)
        tabButtons.removeValue(forKey: handle)
        tabStrips.removeValue(forKey: handle)
        tableBodies.removeValue(forKey: handle)
        tableHeads.removeValue(forKey: handle)
        tableRows.removeValue(forKey: handle)
        tableHeaderCells.removeValue(forKey: handle)
        unflippedViews.remove(handle)
        drawingCanvases.removeValue(forKey: handle)
        _ = dockTiles.removeValue(forKey: handle)?.remove()
        drawnHandles.remove(handle)
        dirtyHandles.remove(handle)
        _ = elements.removeValue(forKey: handle)?.remove()
    }

    // MARK: - Properties

    /// Sets a control's text — or a window's title.
    public override func setText(_ text: String, for handle: NativeHandle) {
        super.setText(text, for: handle)
        // Windows first: their text is the title, and it belongs to the label
        // in the chrome, not to the window element (whose children are the
        // chrome and the content area).
        if let titleLabel = windowTitleLabels[handle] {
            titleLabel.textContent = text
            return
        }
        // A toolbar item's "text" is a descriptor, not a caption — parse it
        // into real chrome rather than printing it. The customization palette's
        // tiles use a second, simpler descriptor of the same kind.
        if applyToolbarItemText(text, for: handle) || applyToolbarTileText(text, for: handle) {
            return
        }
        // Then placeholders, for the same reason: their child is the caption,
        // and writing text to the box itself would replace it.
        if setPlaceholderText(text, for: handle) {
            return
        }
        // Then toggles: a checkbox's box is a <label> whose children are the
        // input and the title. Writing text to it would delete the checkbox.
        if let span = titleSpans[handle] {
            span.textContent = text
            return
        }
        // Then anything with a distinct input: its text is a value, not content.
        if let input = inputElements[handle] {
            input.value = text
            return
        }
        guard let element = elements[handle] else { return }
        if records[handle]?.kind == "editableTextField" {
            element.value = text
        } else {
            element.textContent = text
        }
    }

    /// Moves and resizes a control.
    /// The modifier state carried by the most recent DOM event.
    ///
    /// Static because `modifiers(from:)` is: it is called from event plumbing
    /// that does not always have the backend instance to hand, and a page has
    /// exactly one backend anyway.
    nonisolated(unsafe) internal static var lastReportedModifiers: NSEvent.ModifierFlags = []

    public override func currentModifierFlags() -> NSEvent.ModifierFlags {
        Self.lastReportedModifiers
    }

    /// Swaps a text field between a label and an editable input.
    ///
    /// **A label and a field are different elements, not one element with a
    /// flag.** `createTextField` builds a `<div>` for a label and an `<input>`
    /// for a field, so a control that becomes editable after it was realized
    /// has the wrong element — and a `<div>` with no text is invisible, which
    /// is how a text field went missing from a catalog page entirely.
    ///
    /// The replacement keeps the frame, the parent and the position in the
    /// sibling order, so nothing above it has to be told.
    public override func setTextEditable(_ isEditable: Bool, for handle: NativeHandle) {
        super.setTextEditable(isEditable, for: handle)
        guard records[handle]?.kind == "textField", let old = elements[handle] else { return }

        let isInput = old.rawValue.tagName.string?.lowercased() == "input"
        guard isInput != isEditable else { return }

        let text = isInput
            ? (old.rawValue.value.string ?? "")
            : (old.textContent ?? "")
        let replacement: Element
        if isEditable {
            replacement = Element.input()
            _ = replacement.setAttribute("value", text)
        } else {
            replacement = Element.div()
            replacement.textContent = text
            _ = replacement.setStyle("display", "flex").setStyle("align-items", "center")
        }
        _ = replacement
            .setStyle("position", "absolute")
            .setStyle("left", old.getStyle("left") ?? "0px")
            .setStyle("top", old.getStyle("top") ?? "0px")
            .setStyle("width", old.getStyle("width") ?? "0px")
            .setStyle("height", old.getStyle("height") ?? "0px")
            .setStyle("font", old.getStyle("font") ?? "13px system-ui, sans-serif")

        _ = old.rawValue.replaceWith?(replacement.rawValue)
        elements[handle] = replacement
        inputElements[handle] = replacement
    }

    // MARK: - Clipboard
    //
    // See `WASMClipboard.swift` for why a page can write through but not read
    // through. These two are here rather than there because Swift cannot
    // override a class method from an extension.

    /// Writes through to the system clipboard as well as the in-process one.
    public override func setClipboardString(_ string: String) {
        super.setClipboardString(string)
        writeSystemClipboard(string)
    }

    /// Writes through to the system clipboard as well as the in-process one.
    ///
    /// Only the text representation crosses over. `navigator.clipboard.write`
    /// can carry more, but every extra format needs a `Blob` and a permission
    /// the page may not have; text is what every other application can read,
    /// and the richer representations stay in-process, where the app itself is
    /// the only consumer.
    public override func setClipboardContents(text: String?,
                                              dataRepresentations: [String: [UInt8]],
                                              filePaths: [String]) {
        super.setClipboardContents(text: text, dataRepresentations: dataRepresentations,
                                   filePaths: filePaths)
        if let text, !text.isEmpty {
            writeSystemClipboard(text)
        }
    }

    /// Records text arriving from a `paste` event.
    ///
    /// Goes to `super` on purpose: this text came *from* the system clipboard,
    /// and writing it back would be a needless round trip and a second
    /// permission prompt.
    internal func recordPastedText(_ text: String) {
        super.setClipboardString(text)
    }

    // MARK: - Small persistent values
    //
    // A WASI filesystem lives in the module's memory: everything written to it
    // is gone the moment the tab reloads, which is exactly when a desktop app
    // would be reading its preferences back. `localStorage` is the only store
    // on a page that outlives the page, so that is where the small persisted
    // values go.
    //
    // In the class body rather than an extension because Swift cannot override
    // a class method from one — and these must override
    // `InMemoryNativeControlBackend`'s `UserDefaults` versions.

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

    public override func setFrame(_ frame: NSRect, for handle: NativeHandle) {
        // Read the old size before `super` overwrites it: only a size change
        // invalidates a canvas, and only a *change* may schedule a repaint.
        // Marking unconditionally deadlocks the page — a view's `draw(_:)` can
        // lay out its subviews, each `setFrame` re-marks, and the next animation
        // frame repaints and re-marks again, forever. The tab pegs at 100% and
        // renders nothing, which reads as "the canvas seam broke" rather than
        // "the canvas seam never stops".
        let sizeChanged = records[handle]?.frame.size != frame.size
        // **A window that lands outside the viewport is gone.** On a desktop a
        // stray window can be dragged back from the edge, or recovered from the
        // Window menu; a page has neither, so an off-screen window is simply an
        // app that did not appear. Windows are nudged back far enough that
        // their title bar — the part you grab — is always reachable.
        //
        // Only windows: a *view* is positioned in its parent's coordinates and
        // is meant to be clipped when it overflows.
        let frame = records[handle]?.kind == "window" ? clampedToViewport(frame) : frame
        super.setFrame(frame, for: handle)
        _ = elements[handle]?
            .setStyle("left", "\(frame.origin.x)px")
            .setStyle("top", "\(domTop(of: frame, in: records[handle]?.parent))px")
            .setStyle("width", "\(frame.size.width)px")
            .setStyle("height", "\(frame.size.height)px")

        // An unflipped view measures its children from its bottom edge, so its
        // own height changing moves every child even though no child's frame
        // did. GTK hit this first and re-places the same way.
        if sizeChanged, unflippedViews.contains(handle) {
            replaceChildren(of: handle)
        }

        // A view that paints itself has a canvas sized to its old frame, and
        // nothing else would ever tell it otherwise: the framework relays out,
        // pushes new frames down here, and never calls `invalidateControl`
        // because on Win32 and GTK a resized child repaints on its own. Without
        // this, resizing the window reflows every constrained box correctly and
        // the artwork stays exactly where it was — which looks precisely like a
        // layout engine that did not run.
        if sizeChanged, drawActions[handle] != nil {
            markNeedsPaint(handle)
        }
    }

    /// Shows or hides a control.
    ///
    /// Showing *clears* `visibility` rather than setting it to `visible`, and
    /// the difference is the whole demo. `visibility` inherits, so a hidden
    /// page view hides its subtree — but only until some descendant states its
    /// own visibility, and the framework calls this method on every control
    /// during realization. Writing `visible` on each one made all eleven demo
    /// pages draw on top of each other while the page views themselves were
    /// correctly hidden. Clearing the property lets the parent's state cascade,
    /// which is also what AppKit means: a subview of a hidden view is not
    /// drawn, whatever the subview thinks.
    public override func setHidden(_ isHidden: Bool, for handle: NativeHandle) {
        super.setHidden(isHidden, for: handle)
        _ = elements[handle]?.setStyle("visibility", isHidden ? "hidden" : "")
    }

    // MARK: - Screen

    /// The viewport, standing in for the screen.
    ///
    /// Without this the inherited 1024×768 test frame decides window placement,
    /// and the demo's 1120×760 window is positioned off the edge of a viewport
    /// that is usually a different size again.
    public override func primaryScreenFrame() -> NSRect {
        guard DOM.isBrowser else {
            return super.primaryScreenFrame()
        }

        return NSMakeRect(0, 0, CGFloat(DOM.window.innerWidth), CGFloat(DOM.window.innerHeight))
    }

    /// Keeps a window's frame reachable inside the viewport.
    ///
    /// The title bar is the handle, so that is what has to stay visible: the
    /// origin is pulled back far enough to leave a grab strip on screen, and a
    /// window wider than the viewport is pinned to the top-left rather than
    /// centred out of reach.
    private func clampedToViewport(_ frame: NSRect) -> NSRect {
        let viewport = primaryScreenFrame()
        guard !viewport.isEmpty else { return frame }

        // Enough of the window to see and grab, even when it is much larger
        // than the page.
        let grab: CGFloat = 80

        // **A window bigger than the page is a page that scrolls.** The viewport
        // is the whole screen here, and a window taller than it pushes the
        // document itself into scrolling — so the title bar leaves the top of
        // the screen, and a click near the bottom scrolls the desktop instead
        // of the app. AppKit constrains a window to the screen for the same
        // reason (`constrainFrameRect(_:to:)`); nothing is lost, because the
        // part that would have hung off was unreachable either way.
        let width = min(frame.size.width, viewport.width)
        let height = min(frame.size.height, viewport.height)

        let maxX = max(0, viewport.width - min(grab, width))
        let maxY = max(0, viewport.height - min(grab, height))
        return NSRect(
            x: min(max(frame.origin.x, 0), maxX),
            y: min(max(frame.origin.y, 0), maxY),
            width: width,
            height: height
        )
    }

    /// One synthetic screen: a page cannot see the real display arrangement.
    public override func screenDescriptions() -> [NativeScreenDescription] {
        let frame = primaryScreenFrame()
        return [NativeScreenDescription(frame: frame, visibleFrame: frame)]
    }

    /// Enables or disables a control.
    public override func setEnabled(_ isEnabled: Bool, for handle: NativeHandle) {
        super.setEnabled(isEnabled, for: handle)
        guard let element = elements[handle] else { return }
        if isEnabled {
            _ = element.removeAttribute("disabled")
        } else {
            _ = element.setAttribute("disabled", "disabled")
        }
    }

    // MARK: - Input

    /// Wires a control's primary action.
    ///
    /// This one method is the whole click path: the core's closure calls
    /// `makeFirstResponder` and `sendAction`, which reaches the demo's button
    /// handler. Nothing else in the framework needs to know about the DOM.
    public override func registerAction(for handle: NativeHandle,
                                        action: @escaping () -> Void) {
        super.registerAction(for: handle, action: action)
        guard let element = elements[handle] else { return }
        actionListeners[handle]?.remove()

        // Which DOM event *is* this control's action, and what does the user's
        // choice mean, both depend on the kind. In every case the DOM is the
        // source of truth and is written back into `records` BEFORE the action
        // runs — that is what lets the inherited getters
        // (`buttonState(for:)`, `sliderValue(for:)`, `comboBoxText(for:)`,
        // `popUpButtonSelectedIndex(for:)`) stay correct without this backend
        // overriding a single one of them. Skip the write-back and the screen
        // looks right while the framework reads stale values.
        let kind = records[handle]?.kind ?? ""
        let source = inputElements[handle] ?? element

        switch kind {
        case "popUpButton":
            actionListeners[handle] = source.addEventListener(.change) { [weak self] _ in
                if let self, let index = self.records[handle]?.popUpItems.firstIndex(of: source.value) {
                    self.records[handle]?.popUpSelectedIndex = index
                    self.records[handle]?.text = source.value
                }
                action()
            }

        case "checkbox", "radioButton":
            actionListeners[handle] = source.addEventListener(.change) { [weak self] _ in
                self?.records[handle]?.buttonState = source.checked ? .on : .off
                action()
            }

        case "slider", "scroller":
            // `input`, not `change`: AppKit sends a continuous slider's action
            // while the knob is dragged, and `change` only fires on release.
            actionListeners[handle] = source.addEventListener(.input) { [weak self] _ in
                if let value = Double(source.value) {
                    self?.records[handle]?.sliderValue = value
                }
                action()
            }

        case "stepper":
            // A stepper has no display of its own — the field beside it in the
            // demo is a separate NSTextField that redraws from the action. So
            // the arrows do the arithmetic, clamp, write back, and fire.
            guard let arrows = stepperArrows[handle] else {
                actionListeners[handle] = element.addEventListener(.click) { _ in action() }
                return
            }
            let step: (Double) -> Void = { [weak self] direction in
                guard let self, let record = self.records[handle] else { return }
                let stepped = record.stepperValue + direction * record.stepperIncrement
                self.records[handle]?.stepperValue =
                    min(max(stepped, record.stepperMinValue), record.stepperMaxValue)
                action()
            }
            // Both arrows go in `listeners`, not `actionListeners`, because that
            // table holds one token per handle and a stepper needs two.
            listeners[handle, default: []].forEach { $0.remove() }
            listeners[handle] = [
                arrows.up.addEventListener(.click) { _ in step(1) },
                arrows.down.addEventListener(.click) { _ in step(-1) }
            ]

        case "comboBox":
            actionListeners[handle] = source.addEventListener(.change) { [weak self] _ in
                self?.records[handle]?.text = source.value
                action()
            }

        default:
            actionListeners[handle] = element.addEventListener(.click) { _ in action() }
        }
    }

    // MARK: - Shared control chrome

    /// Paints a control's background.
    public override func setBackgroundColor(_ color: NSColor?, for handle: NativeHandle) {
        super.setBackgroundColor(color, for: handle)
        // A placeholder's background is its hazard stripes; overwriting it with
        // the view's own colour would hide that it is unfinished.
        guard placeholderCaptions[handle] == nil, let element = elements[handle] else { return }
        _ = element.setStyle("background-color", color.map(Self.cssColor) ?? "")
    }

    /// Sets a control's font.
    public override func setFont(_ font: NSFont?, for handle: NativeHandle) {
        super.setFont(font, for: handle)
        guard let font, let element = elements[handle] else { return }
        _ = element.setStyle("font", Self.cssFont(font))
    }

    /// Sets a control's text colour.
    public override func setTextColor(_ color: NSColor?, for handle: NativeHandle) {
        super.setTextColor(color, for: handle)
        guard let element = elements[handle] else { return }
        _ = element.setStyle("color", color.map(Self.cssColor) ?? "")
    }

    /// Sets a control's text alignment.
    public override func setTextAlignment(_ alignment: NSTextAlignment, for handle: NativeHandle) {
        super.setTextAlignment(alignment, for: handle)
        guard let element = elements[handle] else { return }
        _ = element.setStyle("text-align", Self.cssTextAlign(alignment))
        // Labels are laid out as flex rows so their text centres vertically the
        // way a native field's does; `text-align` alone would not move them.
        if records[handle]?.kind == "textField" {
            _ = element.setStyle("justify-content", Self.cssJustify(alignment))
        }
    }

    /// Sets a control's tooltip.
    public override func setToolTip(_ toolTip: String?, for handle: NativeHandle) {
        super.setToolTip(toolTip, for: handle)
        guard let element = elements[handle] else { return }
        if let toolTip, !toolTip.isEmpty {
            _ = element.setAttribute("title", toolTip)
        } else if placeholderCaptions[handle] == nil {
            // Placeholders keep their own explanatory title.
            _ = element.removeAttribute("title")
        }
    }

    // MARK: - Text measurement

    /// Measures text with a canvas 2D context.
    ///
    /// Canvas `measureText` is the standard answer, and SwiftDOM now wraps it
    /// (plan row S1). This used to reach through `rawValue.getContext` behind a
    /// spike marker; the wrapper landed upstream and the escape hatch is gone.
    public override func measureText(_ text: String, font: NativeFontSpec) -> NSSize {
        guard let context = measuringContext(for: font) else {
            return super.measureText(text, font: font)
        }

        // Ascent + descent is the font's own line box where the browser
        // reports it, which is what a layout wants; the glyph-specific
        // bounding box would make "x" shorter than "X". Older engines omit it,
        // hence the em-box fallback.
        let probe = context.measureText(text.isEmpty ? "Mg" : text)
        let reported = probe.map { $0.fontBoundingBoxAscent + $0.fontBoundingBoxDescent } ?? 0
        let lineHeight = reported > 0 ? CGFloat(reported) : CGFloat(font.size) * 1.2

        // **Newlines are not wrapping, and this is not the wrapping call.**
        // `canvas.measureText` lays a string out on one line and reports the
        // width it would take there — a `\n` contributes nothing. AppKit's
        // `size(withAttributes:)` returns the multi-line size, so a code
        // snippet or any pre-formatted block measures one line tall here and
        // draws four: the box is sized for the first line and the rest spills
        // over whatever is below it.
        //
        // Splitting on newlines costs one `measureText` per line and is the
        // difference between a laid-out block and a pile.
        guard text.contains("\n") else {
            return NSMakeSize(CGFloat(probe?.width ?? 0), lineHeight)
        }

        var widest: CGFloat = 0
        var lines = 0
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            lines += 1
            if let metrics = context.measureText(String(line)) {
                widest = max(widest, CGFloat(metrics.width))
            }
        }
        return NSMakeSize(widest, CGFloat(max(lines, 1)) * lineHeight)
    }

    /// Measures text word-wrapped at a width, using the browser's own metrics.
    ///
    /// **The base class estimates, and an estimate is not good enough here.**
    /// It assumes every character is `font.size * 0.55` wide, which for a
    /// proportional font is wrong in both directions and wrong by different
    /// amounts per string. The consequence is not a slightly-off box: a label
    /// measured as one line and drawn as three overflows whatever was sized to
    /// hold it, and in a table it lands on top of the row below. Every sidebar
    /// row in the catalog looked like that.
    ///
    /// The browser already knows the answer — it is the thing that will do the
    /// wrapping — so each word is measured for real and the greedy line-break
    /// is the same one the DOM performs.
    public override func measureText(_ text: String, font: NativeFontSpec,
                                     wrappingAt maxWidth: CGFloat) -> NSSize {
        guard maxWidth > 0, let context = measuringContext(for: font) else {
            return super.measureText(text, font: font, wrappingAt: maxWidth)
        }

        // The line box, not the glyph box: "x" and "X" must measure the same
        // height or a line's position depends on which letters are in it.
        let probe = context.measureText("Mg")
        let lineHeight = probe.map { CGFloat($0.fontBoundingBoxAscent + $0.fontBoundingBoxDescent) } ?? 0
        let resolvedLineHeight = lineHeight > 0 ? lineHeight : CGFloat(font.size) * 1.2

        func width(of run: String) -> CGFloat {
            guard let metrics = context.measureText(run) else { return 0 }
            return CGFloat(metrics.width)
        }

        var lineCount = 0
        var widest: CGFloat = 0
        // Explicit newlines break unconditionally; the wrap only applies within
        // each paragraph, exactly as the DOM treats a `\n` in pre-wrap text.
        for paragraph in text.split(separator: "\n", omittingEmptySubsequences: false) {
            var current = ""
            for word in paragraph.split(separator: " ", omittingEmptySubsequences: false) {
                let candidate = current.isEmpty ? String(word) : current + " " + word
                if !current.isEmpty, width(of: candidate) > maxWidth {
                    lineCount += 1
                    widest = max(widest, width(of: current))
                    current = String(word)
                } else {
                    current = candidate
                }
            }
            lineCount += 1
            widest = max(widest, width(of: current))
        }

        return NSMakeSize(min(widest, maxWidth),
                          CGFloat(max(lineCount, 1)) * resolvedLineHeight)
    }

    /// A canvas context kept solely for measurement, with the font applied.
    private func measuringContext(for font: NativeFontSpec) -> CanvasRenderingContext2D? {
        guard DOM.isBrowser else { return nil }
        if measuringCanvas == nil {
            measuringCanvas = Element.canvas()
        }
        guard var context = measuringCanvas?.asCanvas.getContext2D() else { return nil }
        context.font = WASMCanvasDrawingContext.cssFont(font)
        return context
    }

    // MARK: - Plumbing

    /// Mounts the desktop element, once, and replays a menu set before it.
    private func mountDesktopIfNeeded() {
        guard desktop == nil, DOM.isBrowser else { return }
        let element = Element.div()
            .setStyle("position", "absolute")
            .setStyle("inset", "0")
            .setStyle("background", "#ffffff")
            // Scrollable, not clipped: the catalog's window is larger than most
            // viewports, and a clipped desktop makes the bottom of the demo
            // unreachable rather than merely off-screen.
            .setStyle("overflow", "auto")
        _ = DOM.document.body.appendChild(element)
        desktop = element
        renderMainMenuIfPossible()
    }

    /// Files a new element under its handle and adds it to its parent.
    ///
    /// Every control passes through here, which makes it the one place to state
    /// the rule the whole backend depends on: **the frame is the frame**. An
    /// `<input>` or `<button>` defaults to `content-box`, so a 24-point field
    /// renders as 24 points *plus* its padding and border — about 36 — and a
    /// toolbar sized to hold a 24-point field then has a field hanging out of
    /// the bottom of it. `border-box` makes the element exactly the size the
    /// framework asked for, which is what every other backend already gives it.
    internal func register(_ handle: NativeHandle, element: Element, parent: NativeHandle?) {
        _ = element.setStyle("box-sizing", "border-box")
        // Anything that is not an editable field must not be selectable text.
        // A press-and-drag on a view starts a *text selection* in a browser,
        // which wins over the framework's own drag: the toolbar customization
        // tiles simply refused to move while every label on the panel turned
        // blue. Editable kinds are excluded — a text field the user cannot
        // select inside is worse than the problem.
        if !Self.editableKinds.contains(records[handle]?.kind ?? "") {
            _ = element.setStyle("user-select", "none")
        }
        elements[handle] = element
        guard let parent else { return }
        // Composite controls own a content area distinct from their chrome —
        // a window has its client area below the title bar, a tab view has the
        // pane below its strip, a scroll view has the document that scrolls.
        // Children belong in that, never beside it.
        let container = windowContent[parent] ?? tabContents[parent]
            ?? scrollDocuments[parent] ?? elements[parent]
        _ = container?.appendChild(element)
    }
}

#endif
