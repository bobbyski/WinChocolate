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
import SwiftDOM

/// Renders the AppKit surface into the browser DOM.
public final class WASMNativeControlBackend: InMemoryNativeControlBackend {
    /// The element mounted into `document.body` that every window sits in.
    ///
    /// A browser has no window server, so the backend supplies one: this is the
    /// desktop, and each `NSWindow` is a positioned child of it.
    private var desktop: Element?

    /// The DOM element behind each native handle.
    internal var elements: [NativeHandle: Element] = [:]

    /// The caption inside each "under construction" placeholder.
    ///
    /// Keyed by handle so `setDebugClassName` can correct the name and
    /// `setText` can append the control's own text. See `WASMPlaceholders`.
    internal var placeholderCaptions: [NativeHandle: Element] = [:]

    /// The element a window's content is added to — its client area, below the
    /// synthesized title bar.
    private var windowContent: [NativeHandle: Element] = [:]

    /// The label inside a window's synthesized title bar.
    ///
    /// A window's title arrives through `setText(_:for:)` — the same call a
    /// button or a label gets — so text aimed at a window has to be steered
    /// here. Writing it to the window element itself would replace the title
    /// bar and the content area with a text node, which is exactly what the
    /// first run of this backend did.
    private var windowTitleLabels: [NativeHandle: Element] = [:]

    /// Listener tokens, kept so `destroyControl` can actually release them.
    private var listeners: [NativeHandle: [EventListener]] = [:]

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
    private var measuringContext: JSObject?

    /// Creates the backend.
    public override init() {
        super.init()
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
            .setStyle("top", "\(frame.origin.y + 24)px")   // below the menu bar
            .setStyle("width", "\(frame.size.width)px")
            .setStyle("background", "#f0f0f0")
            .setStyle("border", "1px solid #a0a0a0")
            .setStyle("box-shadow", "0 4px 16px rgba(0,0,0,0.25)")
            .setStyle("font", "13px system-ui, sans-serif")
            .setStyle("display", "none")

        if styleMask.contains(.titled) {
            _ = window.appendChild(makeTitleBar(title: title, handle: handle,
                                                closable: styleMask.contains(.closable)))
        }

        let content = Element.div()
            .setStyle("position", "relative")
            .setStyle("width", "\(frame.size.width)px")
            .setStyle("height", "\(frame.size.height)px")
            .setStyle("overflow", "hidden")
        _ = window.appendChild(content)

        elements[handle] = window
        windowContent[handle] = content
        desktop.map { _ = $0.appendChild(window) }
        return handle
    }

    private func makeTitleBar(title: String, handle: NativeHandle, closable: Bool) -> Element {
        let bar = Element.div()
            .setStyle("display", "flex")
            .setStyle("align-items", "center")
            .setStyle("height", "26px")
            .setStyle("padding", "0 8px")
            .setStyle("background", "linear-gradient(#fdfdfd, #e4e4e4)")
            .setStyle("border-bottom", "1px solid #b8b8b8")
            .setStyle("user-select", "none")

        let label = Element.div().setStyle("flex", "1").setStyle("font-weight", "500")
        label.textContent = title
        windowTitleLabels[handle] = label
        _ = bar.appendChild(label)

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
                guard let self else { return }
                if self.windowShouldCloseHandlers[handle]?() ?? true {
                    self.windowCloseActions[handle]?()
                }
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

    /// Hides and discards a window.
    public override func closeWindow(_ handle: NativeHandle) {
        super.closeWindow(handle)
        _ = elements[handle]?.setStyle("display", "none")
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

    /// Creates a checkbox placeholder.
    public override func createCheckbox(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = super.createCheckbox(title: title, frame: frame, parent: parent)
        makePlaceholder(handle, kind: "checkbox", frame: frame, parent: parent)
        return handle
    }

    /// Creates a radio-button placeholder.
    public override func createRadioButton(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = super.createRadioButton(title: title, frame: frame, parent: parent)
        makePlaceholder(handle, kind: "radioButton", frame: frame, parent: parent)
        return handle
    }

    /// Creates a box placeholder. Its children are real and still render.
    public override func createBox(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = super.createBox(title: title, frame: frame, parent: parent)
        makePlaceholder(handle, kind: "box", frame: frame, parent: parent)
        return handle
    }

    /// Creates a secure-field placeholder.
    public override func createSecureTextField(text: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = super.createSecureTextField(text: text, frame: frame, parent: parent)
        makePlaceholder(handle, kind: "secureTextField", frame: frame, parent: parent)
        return handle
    }

    /// Creates a text-view placeholder.
    public override func createTextView(text: String, frame: NSRect, parent: NativeHandle?,
                                        isEditable: Bool, isRichText: Bool) -> NativeHandle {
        let handle = super.createTextView(text: text, frame: frame, parent: parent,
                                          isEditable: isEditable, isRichText: isRichText)
        makePlaceholder(handle, kind: isEditable ? "editableTextView" : "textView",
                        frame: frame, parent: parent)
        return handle
    }

    /// Creates a pop-up button placeholder.
    public override func createPopUpButton(items: [String], selectedIndex: Int,
                                           frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = super.createPopUpButton(items: items, selectedIndex: selectedIndex,
                                             frame: frame, parent: parent)
        makePlaceholder(handle, kind: "popUpButton", frame: frame, parent: parent)
        return handle
    }

    /// Creates a combo-box placeholder.
    public override func createComboBox(items: [String], text: String,
                                        frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = super.createComboBox(items: items, text: text, frame: frame, parent: parent)
        makePlaceholder(handle, kind: "comboBox", frame: frame, parent: parent)
        return handle
    }

    /// Creates an image-view placeholder.
    public override func createImageView(description: String, imagePath: String?,
                                         frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = super.createImageView(description: description, imagePath: imagePath,
                                           frame: frame, parent: parent)
        makePlaceholder(handle, kind: "imageView", frame: frame, parent: parent)
        return handle
    }

    /// Creates a tab-view placeholder. Tab content is parented into it.
    public override func createTabView(items: [String], selectedIndex: Int,
                                       frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = super.createTabView(items: items, selectedIndex: selectedIndex,
                                         frame: frame, parent: parent)
        makePlaceholder(handle, kind: "tabView", frame: frame, parent: parent)
        return handle
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

    /// Creates a slider placeholder.
    public override func createSlider(value: Double, minValue: Double, maxValue: Double,
                                      frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = super.createSlider(value: value, minValue: minValue, maxValue: maxValue,
                                        frame: frame, parent: parent)
        makePlaceholder(handle, kind: "slider", frame: frame, parent: parent)
        return handle
    }

    /// Creates a progress-indicator placeholder.
    public override func createProgressIndicator(value: Double, minValue: Double, maxValue: Double,
                                                 frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = super.createProgressIndicator(value: value, minValue: minValue,
                                                   maxValue: maxValue, frame: frame, parent: parent)
        makePlaceholder(handle, kind: "progressIndicator", frame: frame, parent: parent)
        return handle
    }

    /// Creates a scroller placeholder.
    public override func createScroller(value: Double, knobProportion: Double, isVertical: Bool,
                                        frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = super.createScroller(value: value, knobProportion: knobProportion,
                                          isVertical: isVertical, frame: frame, parent: parent)
        makePlaceholder(handle, kind: "scroller", frame: frame, parent: parent)
        return handle
    }

    /// Creates a stepper placeholder.
    public override func createStepper(configuration: NativeStepperConfiguration,
                                       frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = super.createStepper(configuration: configuration, frame: frame, parent: parent)
        makePlaceholder(handle, kind: "stepper", frame: frame, parent: parent)
        return handle
    }

    /// Creates a date-picker placeholder.
    public override func createDatePicker(configuration: NativeDatePickerConfiguration,
                                          frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = super.createDatePicker(configuration: configuration, frame: frame, parent: parent)
        makePlaceholder(handle, kind: configuration.style == .clockAndCalendar
                            ? "calendarDatePicker" : "datePicker",
                        frame: frame, parent: parent)
        return handle
    }

    /// Creates a table-view placeholder.
    public override func createTableView(columns: [String], columnWidths: [CGFloat],
                                         content: NativeTableContent,
                                         frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = super.createTableView(columns: columns, columnWidths: columnWidths,
                                           content: content, frame: frame, parent: parent)
        makePlaceholder(handle, kind: "tableView", frame: frame, parent: parent)
        return handle
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
        _ = view.setAttribute("data-cx-partial", "NSScrollView")
        register(handle, element: view, parent: parent)
        return handle
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
        // Then placeholders, for the same reason: their child is the caption,
        // and writing text to the box itself would replace it.
        if setPlaceholderText(text, for: handle) {
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
    public override func setFrame(_ frame: NSRect, for handle: NativeHandle) {
        super.setFrame(frame, for: handle)
        _ = elements[handle]?
            .setStyle("left", "\(frame.origin.x)px")
            .setStyle("top", "\(frame.origin.y)px")
            .setStyle("width", "\(frame.size.width)px")
            .setStyle("height", "\(frame.size.height)px")
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
        actionListeners[handle] = element.addEventListener(.click) { _ in action() }
    }

    // MARK: - Text measurement

    /// Measures text with a canvas 2D context.
    ///
    /// SwiftDOM has no `measureText` wrapper yet (WASMChocolatePlan row S1), so
    /// this reaches through the raw-JS escape hatch. That is sanctioned only
    /// while the row is open.
    public override func measureText(_ text: String, font: NativeFontSpec) -> NSSize {
        // SPIKE: replace with SwiftDOM's canvas measureText when S1 lands.
        guard let context = measuringContextIfAvailable() else {
            return super.measureText(text, font: font)
        }
        let family = font.family ?? "system-ui, sans-serif"
        let weight = font.bold ? "bold " : ""
        let slant = font.italic ? "italic " : ""
        context.font = .string("\(slant)\(weight)\(font.size)px \(family)")
        guard let metrics = context.measureText?(text).object,
              let width = metrics.width.number else {
            return super.measureText(text, font: font)
        }
        // Height is the font's em box: canvas metrics carry ascent and descent
        // only for the glyphs supplied, which is not a line height.
        return NSSize(width: width, height: font.size * 1.2)
    }

    private func measuringContextIfAvailable() -> JSObject? {
        if let measuringContext { return measuringContext }
        guard DOM.isBrowser else { return nil }
        let canvas = Element.canvas()
        guard let context = canvas.rawValue.getContext?("2d").object else { return nil }
        measuringContext = context
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
    internal func register(_ handle: NativeHandle, element: Element, parent: NativeHandle?) {
        elements[handle] = element
        guard let parent else { return }
        // A window's children belong to its content area, not its chrome.
        let container = windowContent[parent] ?? elements[parent]
        _ = container?.appendChild(element)
    }
}

#endif
