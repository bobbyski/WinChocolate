# ViewInfo

Dumps the views a Swift source file builds — every property set, every action,
and what each action touches — as markdown on stdout.

It exists to answer one question quickly: **does implementation B do everything
implementation A does?** Point it at the same demo source compiled two ways (or
at an AppKit reference and a WinChocolate port), redirect both to files, and
diff them. A control that never gets a property, a `levelIndicatorStyle` that is
never set, an action that forgets to update a label — all of it shows up as a
plain text difference.

## Usage

```sh
cd Demo/ViewInfo
swift run ViewInfo ../DemoApplication/main.swift > appkit.md
swift run ViewInfo ../DemoApplication/main.swift ../DemoApplication/DemoConveniences.swift | less
```

Pass one or more `.swift` files; markdown goes to stdout so it pipes and
redirects cleanly.

```sh
# What does one side miss?
diff appkit.md winchocolate.md
```

## What it reports

- **Summary** — counts of views, properties, actions.
- **View hierarchy** — parent/child from `addSubview` / `addArrangedSubview` /
  `addItem`, so grouped controls are visible as a group.
- **Views & controls** — one section per view:
  - declaration site, initializer (frames live here), and what it was added to
  - a table of **every property set** on it, with values and line numbers
  - a table of configuration calls (`setX…`, `addX…`)
  - each **action** as a fenced `swift` code block, followed by
    **Accesses:** — the other views/controls that action reads or mutates
- **`@objc` action methods** — target/action selectors, their bodies, what they
  access, and which control wired them up.
- **Other declared objects** — non-view declarations, for reference.

## How it reads the source

It parses with [swift-syntax](https://github.com/swiftlang/swift-syntax) — a
real Swift parse, not regex — and folds operators so `slider.minValue = 0` is
recognized as an assignment. It is a *static* read of the source: it reports
what the code says, so it finds missing/extra calls, not runtime behavior.

Recognized shapes:

| Source | Reported as |
|---|---|
| `let stepper = NSStepper(frame: …)` | a view (type + initializer) |
| `stepper.minValue = 0` | a property assignment |
| `stepper.onAction = { … }` | an action (code + accesses) |
| `button.action = #selector(foo)` | an action, linked to the `@objc func` |
| `contentView.addSubview(stepper)` | a hierarchy edge |

A declaration counts as a *view* when its type starts with `NS` or ends in a UI
suffix (`View`, `Control`, `Button`, `Field`, `Indicator`, …) — see
`ViewTypeHeuristic`. Everything else is listed under "Other declared objects".

ViewInfo is a **standalone package** on purpose: it depends on swift-syntax, and
the root `WinChocolate` package stays dependency-light for Windows builds.

