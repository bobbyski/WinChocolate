# AI Coding guidelines

Goal is readability and maintainability.

Prefer small classes organized by function. If things belong together but the class contains more than 500 lines call it out for me to review and offer suggestions on how to break it up.

All public classes, functions, properties etc, should have documentation comments.
Other classes, functions should have standard comments.

Classes should have good summaries of their intended use case including ASCII art diagrams when appropriate.

Performance should be considered but weighed against readability. 

Short code does not mean good code. A three line block that is very readable is usually more desirable than than a clever one line implementation.

Include an architecture markdown document

---

# Project plans

Any plan that we elect to pursue should include a summary and progress information at the top similar to this:

# PollingKit — Build Plan

---

## Dashboard
```
Overall Progress  ████████████████████████░░░░░░░░  77%   (47 / 61 items)

Phase 1 · Core Data Layer        ██████████████████████████  100%  ✅ Complete
Phase 2 · Historical Importers   ██████████████████████████  100%  ✅ Complete
Phase 3 · Accuracy Engine        ██████████████████████████  100%  ✅ Complete
Phase 4 · SimCore Export         ██████████████████████████  100%  ✅ Complete
Phase 5 · App Shell & Xcode      █████████████████████░░░░░   78%  🔄 In Progress
Phase 6 · Live Data Fetchers     ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ Pending
Phase 7 · SwiftUI Views          ██████████████████████████  100%  ✅ Complete
Phase 8 · Think Tank / Intel     ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ Pending
Phase 9 · Tests                  ██████████████████████████  100%  ✅ Complete
Phase 10 · Polish & Ship         ░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ⏳ Pending
```

**Status key:** ✅ Done &nbsp;|&nbsp; 🔄 In Progress &nbsp;|&nbsp; ⏳ Pending &nbsp;|&nbsp; 🚫 Blocked

---

## Phase 1 — Core Data Layer ✅ 100%

Foundation models and actor-based persistence. Zero external dependencies.

| # | File | Status | Notes |
|---|------|--------|-------|
| 1.1 | `Models/Poll.swift` | ✅ Done | Poll, PollResult, PollMethodology, PollSource |
| 1.2 | `Models/Pollster.swift` | ✅ Done | 16 known pollsters seeded; NAIP badges |
| 1.3 | `Models/ElectionResult.swift` | ✅ Done | ElectionContest, ElectionResult, battleground detection |
| 1.4 | `Models/AccuracyModels.swift` | ✅ Done | PollAccuracyRecord, AccuracyMetrics, PollsterAccuracyProfile, dynamic weight |
| 1.5 | `Models/EconomicContext.swift` | ✅ Done | EconomicSnapshot, ElectionEconomicContext, EconomicAccuracyCorrelation |
| 1.6 | `Models/SimulationParameters.swift` | ✅ Done | SimulationParameters, NationParameters, DataQualityReport, CoverageLevel |
| 1.7 | `Database/PollingDatabase.swift` | ✅ Done | Actor-based JSON store; Application Support; seeds pollsters on first load |

---

## Phase 2 — Historical Data Import ✅ 100%

Seed the database with ground-truth election results and archived poll data.

| # | File | Status | Notes |
|---|------|--------|-------|
| 2.1 | `DataSources/MITElectionLabImporter.swift` | ✅ Done | President, Senate, Governor, House; 1976–2024 |
| 2.2 | `DataSources/FiveThirtyEightImporter.swift` | ✅ Done | Historical polls CSV; multiple URL fallbacks post-closure |
| 2.3 | `DataSources/FREDEconomicImporter.swift` | ✅ Done | FRED API; GDP, unemployment, CPI, gas, debt, tax rates |
| 2.4 | `Sources/PollingKitCLI/main.swift` | ✅ Done | CLI: seed-mit, seed-538, seed-fred, score, profiles, correlations, export, pipeline |


# END OF PLAN SAMPLE
---

# Keys To Good Coding Design

This document is a draft source list and rule set for future AI coding instructions. The goal is not merely "make it work." The goal is code that is easy to use, easy to reason about, and shaped like a real framework instead of a pile of demo-specific fixes.

## Sources Reviewed

- User-provided UI component architecture article: https://medium.com/@patelava/mastering-ui-component-architecture-principles-patterns-and-practical-tips-b44cc667daad
- User-provided SOLID article: https://www.educative.io/blog/solid-principles-oop-c-sharp
- Swift API Design Guidelines: https://www.swift.org/documentation/api-design-guidelines/
- React Thinking in React: https://react.dev/learn/thinking-in-react
- React sharing state guidance: https://react.dev/learn/sharing-state-between-components
- WAI-ARIA Authoring Practices Guide: https://www.w3.org/WAI/ARIA/apg/
- WAI-ARIA keyboard interface guidance: https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- Web Components custom element best practices: https://web.dev/custom-elements-best-practices/
- Material Design interaction guidance: https://m3.material.io/foundations/interaction/overview
- Material Design accessible design guidance: https://m3.material.io/foundations/accessible-design/overview
- Fluent 2 accessibility guidance: https://fluent2.microsoft.design/accessibility

## Design North Star

Code should be clear and concise, complexity should be managed with code structure so any segment of code should be very easy to understand even with limited context. Interior comments should make the code more understandable, not less.

Good framework code gives the application a vocabulary of intentions. Bad framework code forces the application to describe mechanics.

## OpenAI recomendations

- Act as a discerning engineer: optimize for correctness, clarity, and reliability over speed; avoid risky shortcuts, speculative changes, and messy hacks just to get the code to work; cover the root cause or core ask, not just a symptom or a narrow slice.
- Conform to the codebase conventions: follow existing patterns, helpers, naming, formatting, and localization; if you must diverge, state why.
- Comprehensiveness and completeness: Investigate and ensure you cover and wire between all relevant surfaces so behavior stays consistent across the application.
- Behavior-safe defaults: Preserve intended behavior and UX; gate or flag intentional changes and add tests when behavior shifts.
- Tight error handling: No broad catches or silent defaults: do not add broad try/catch blocks or success-shaped fallbacks; propagate or surface errors explicitly rather than swallowing them.
  - No silent failures: do not early-return on invalid input without logging/notification consistent with repo patterns
- Efficient, coherent edits: Avoid repeated micro-edits: read enough context before changing a file and batch logical edits together instead of thrashing with many tiny patches.
- Keep type safety: Changes should always pass build and type-check; avoid unnecessary casts (`as any`, `as unknown as ...`); prefer proper types and guards, and reuse existing helpers (e.g., normalizing identifiers) instead of type-asserting.
- Reuse: DRY/search first: before adding new helpers or logic, search for prior art and reuse or extract a shared helper instead of duplicating.
- Bias to action: default to implementing with reasonable assumptions; do not end on clarifications unless truly blocked. Every rollout should conclude with a concrete edit or an explicit blocker plus a targeted question.

## Bobby's Golden Rules For Frameworks

- **Boilerplate is bad.** If users always have to do something, it should probably become built-in behavior.
- **Complex components are bad components.** A component can solve a complex problem, but its public use should still feel simple.
- **Big is suspicious.** This is not absolute, but if a class is more than 500 lines, assume it is probably poorly organized and review it for smaller responsibilities.
- **Line count is a symptom, not the disease.** Splitting one complex class into many files can make the code worse if the same class still owns the same concepts. Reduce the number of responsibilities the type understands.
- **Repeating something three times is a design signal.** If the same pattern appears three times, start thinking about how to generalize it. This is art, not arithmetic, so do not force abstraction too early.
- **Rules need judgment.** These are strong defaults, not laws of physics. Human intuition still matters when deciding whether code is simpler left alone or better generalized.
- **Do not abstract past usefulness.** Composition is good when it hides real complexity, but ceremony is still bad. Do not turn simple values into elaborate object systems just to look architected.
- Maintain a NEEDS_HUMAN.md review checklist with a reviewed check box, and a human accepted check box. alert the user when ever you add to it. You should add long files (>500 code lines), Overly complicated functions, Overly complicated functions (to many different responsibilities)

## Key Concepts

1. **Applications express intent; components own mechanics.** App code chooses what should happen. Framework controls decide how input, focus, rendering, state transitions, and validation happen.

2. **A component owns its interaction state.** Hover, pressed, selected, focused, dragging, resizing, expanded, checked, editing, cursor blink, scroll offset, and modal state belong inside the component unless there is a strong reason to expose them.

3. **Expose semantic events, not raw device events.** Prefer callbacks such as `onOpen(path)`, `onClose()`, `onThemeChanged(theme)`, and `onSelectionChanged(items)` over handing every app a stream of keys and mouse cells.

4. **Raw input belongs at framework edges.** Terminal escape sequences, key decoding, mouse protocol decoding, focus routing, and coordinate translation should be centralized behind protocols and dispatchers.

5. **A demo is a consumer, not a framework extension.** If the demo needs helper code to make a control behave correctly, that helper probably belongs in the framework.

6. **Design public APIs around the common case.** A simple, readable call should cover the normal path. Advanced hooks can exist, but they should not be required for basic use.

7. **Clarity at the point of use matters.** Swift APIs should read naturally where they are called. Argument labels, names, and defaults should make misuse feel awkward.

8. **Use narrow protocols for substitution.** A terminal backend, renderer, file system provider, or style source should be swappable through focused protocols rather than global state or concrete types.

9. **Prefer composition over inheritance.** Build behavior from small capabilities such as renderable, focusable, scrollable, selectable, styleable, and command-handling protocols.

10. **Separate model, layout, rendering, and input.** A component should not blur data ownership, geometry calculation, painting, and event handling into one giant method.

11. **Make impossible states impossible.** Use enums, typed values, and constrained initializers so invalid combinations cannot be represented casually.

12. **State transitions should be explicit.** Window states, dialog results, selection modes, and validation outcomes should be named transitions, not incidental booleans scattered through app code.

13. **Controlled and uncontrolled modes should be deliberate.** A component may own its state, or the app may provide external state, but the API should make that contract obvious.

14. **Default behavior should be useful.** A control should work correctly with minimal configuration, including keyboard, mouse, focus, rendering, and reasonable styles.

15. **Good components require minimal configuration for normal use.** Configuration should be needed to do less-normal things, not to make the component usable. A text editor component should need little more than load/save hooks or a document binding for ordinary editing; keyboard handling, cursor behavior, scrolling, selection, dirty state, and rendering should already work.

16. **Customization should be additive.** Styling and behavior overrides should refine the default, not force the caller to reimplement the control.

17. **Do not leak internal coordinates.** Window children should see local coordinates; parent screens should see parent coordinates. Translation should be handled by the container.

18. **Clipping is a component contract.** A child that is too large or misplaced must not draw outside its parent viewport or window inner frame.

19. **Focus is owned by scopes.** Windows, dialogs, menus, and composite controls should maintain their own tab order and focus rules, then expose only high-level focus outcomes to the parent.

20. **Keyboard behavior is part of the component.** Menus, trees, tables, dialogs, lists, file choosers, and editors should know their standard keys. Apps should not repeat those maps.

21. **Mouse behavior is part of the component.** Hit testing, double-click behavior, drag gestures, resize handles, and click target expansion belong inside the component or shared framework services.

22. **Accessibility patterns improve architecture.** Even in a terminal UI, ARIA-style thinking helps: every component should have a role, state, keyboard model, and predictable focus behavior.

23. **Layout should be declarative and testable.** Containers should accept child preferences and produce frames. Tests should assert geometry without rendering the entire app.

24. **Styles should not become business logic.** TCSS can alter appearance and layout preferences, but core behavior should remain available through pure Swift APIs.

25. **Style application should be reset-safe.** Switching themes must not leave stale values behind. The framework needs clear defaults, cascaded values, and fallback behavior.

26. **Rendering should be deterministic.** Given state, style, and frame, a component should render the same cells. Avoid hidden side effects during drawing.

27. **Use adapter boundaries for unstable technology.** Terminal I/O, ANSI/VT100 support, future vector rendering, file system access, and platform-specific behavior should sit behind protocols.

28. **Keep public APIs smaller than implementations.** A powerful component may have internal complexity, but its public surface should stay compact and intention-revealing.

29. **Prefer one strong abstraction to many one-off flags.** Repeated flags such as `allowFiles`, `allowDirectories`, `allowMultiple`, and `mode` are fine when they form a coherent options type.

30. **Name extension points explicitly.** Hooks such as `FileSystemProvider`, `TerminalDriver`, `StyleResolver`, `WindowChrome`, and `CommandHandler` are easier to understand than arbitrary closures everywhere.

31. **SOLID is a diagnostic tool, not a religion.** Single responsibility, open/closed extension, substitutability, narrow interfaces, and dependency inversion are useful ways to find design stress.

32. **Single responsibility means one reason to change.** A file chooser should not also be a terminal decoder, renderer, theme parser, and app-specific command router.

33. **Open for extension means new cases should not require surgery.** Adding a new terminal backend, border style, window chrome, or chooser mode should usually add a type or strategy, not edit every caller.

34. **Substitutability means contracts matter.** If a custom terminal driver, renderer, or file provider conforms to a protocol, it should be safe to use anywhere the protocol is expected.

35. **Interface segregation means callers see only what they need.** A render-only component should not be forced to implement input handling. A selectable component should not need file-system APIs.

36. **Dependency inversion means framework code depends on abstractions.** High-level controls should depend on `TerminalProtocol`, `FileSystemProvider`, or `StyleResolving`, not concrete global services.

37. **Prefer boring data models and rich behavior at boundaries.** Models should be plain and testable. Behavior becomes complex only where it translates input, layout, rendering, or external effects.

38. **Document behavior, not just parameters.** Public docs should explain ownership, state, focus rules, input behavior, and rendering/clipping guarantees.

39. **Tests should guard contracts, not implementation trivia.** Test that a window clips children, a file chooser opens directories on double-click, and menu navigation consumes Space correctly.

40. **Demos should be readable tutorials.** Demo code should show the desired public API. If a learner cannot understand the demo quickly, the API may be too low-level.

41. **When dogfooding hurts, fix the framework.** Do not patch around pain in the demo. Treat the pain as a design signal and move the capability down into framework.

42. **Elegance means fewer concepts for the caller.** A good text editor API might look like: create a text view, place it in a scrolling window, load text with a syntax mode, and ask for the edited buffer. The caller should think about documents and layout, not cursor blinking, mouse hit tests, resize gestures, or text insertion rules.

43. **A smaller file is not automatically a smaller class.** If the same type is split across extensions but still owns menu routing, file choosing, mouse handling, resize math, window focus, document state, and rendering, the refactor is cosmetic. A real refactor moves responsibilities into independent components with small APIs.

44. **Components should be built from smaller components.** Treat each lower-level component as if it has its own app author who deserves a simple interface. Compose complex behavior from understandable pieces until no single piece is complex on its own. The whole system may solve a complex problem, but each layer should hide its internal mechanics behind a small, humane API.

45. **Avoid ceremony masquerading as design.** Good abstraction makes code easier to read and use. If a design turns every small value, flag, or operation into a class-shaped ceremony, it has probably confused architecture with indirection.

## Framework Folder Structure

When asked to create a framework assume this file structure will be used

```text
Code/GitUI
|
|-- Package.swift
|   `-- SwiftPM manifest for the FrameworkName framework package.
|
|-- Sources
|   `-- FrameworkName
|       |-- FrameworkName.swift
|       |   `-- Package entry source file.
|       |
|       `-- Views
|
|-- Tests
|   `-- GitUITests
|       `-- GitRepositoryOrganizerViewModelTests.swift
|           `-- Tests for framework organizer behavior.
|
|-- Demo
|   |
|   |-- project.yml
|   |   `-- XcodeGen project definition for the FrameworkName app and FrameworkName target.
|   |
|   |-- GitKeeper.xcodeproj
|   |   `-- Generated Xcode project for opening and running the demo app.
|   |
|   `-- DemoApplication
|
`-- Docs
    `-- Architecture.md
        `-- Architecture and progress document.

```

