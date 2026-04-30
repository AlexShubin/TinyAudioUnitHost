# Project Notes

## Tuist

- To regenerate the Xcode project, run: `mise run generate`
- Targets use buildable folders, so adding/removing source files does **not** require regeneration — Xcode picks them up automatically.
- Only run `mise run generate` after structural changes to `Project.swift` itself (adding/removing targets, dependencies, build settings).

## Tech Stack

- Swift 6 strict concurrency, macOS 26.0
- SwiftUI only (NSViewControllerRepresentable for AU views)
- Zero external dependencies — only Apple frameworks
- Swift Testing framework (`@Suite`, `@Test`, `#expect`) — not XCTest

## Architecture

- MVVM with `@Observable` ViewModels that expose state as observed properties directly
- DI via `Dependencies` structs with `static let live` factory + SwiftUI `EnvironmentKey` (see [Dependencies pattern](#dependencies-pattern))
- Keep framework types (CoreAudio, CoreMIDI, AudioToolbox, etc.) out of the view layer. Framework imports belong in module-internal files (e.g. `EngineKit`, `StorageKit`) and shared model definitions.

## Code Style

- Always add file headers to new Swift files following the existing pattern:
  ```
  //
  //  FileName.swift
  //  TargetName
  //
  //  Created by Alex Shubin on DD.MM.YY.
  //  Copyright © YYYY Alex Shubin. All rights reserved.
  //
  ```
- Avoid using `any` with protocol types when it's not required. Prefer `let sut: HostViewModelType` over `let sut: any HostViewModelType`.
- Avoid copy-pasted logic. Extract repeated lines into a private helper function.
- Prefer a computed `var` over a `func` with no parameters. `var physicalChannelCount: Int? { ... }` instead of `func physicalChannelCount() -> Int? { ... }`.

## Naming Conventions

- `*Type` suffix for protocols (`AudioUnitHostEngineType`)
- `*Action` for view model action enums
- Features organized as `Features/FeatureName/` with View, ViewModel, and optional `Subviews/`

## Subview communication

Subviews don't own a view model and don't mutate shared state. Every user-driven event bubbles up through a single `onAction: (Action) -> Void` closure to the parent feature's VM, which is the only thing that decides what to do:

```swift
enum FooViewAction { /* every user-driven event the subview can emit */ }

struct FooView: View {
    // inputs the view renders — pass however suits the subview
    // (a state struct, individual lets, bindings, etc.)
    let onAction: (FooViewAction) -> Void
}
```

- Define a dedicated `*ViewAction` enum per subview. Don't reuse the parent VM's action type — the subview shouldn't know it exists.
- When the same subview type is used multiple times (e.g. an input and an output picker), the parent wraps each instance's actions in its own VM-action case (`.inputFooAction(...)`, `.outputFooAction(...)`) so the handler can tell instances apart.
- If multiple instances share write logic on the VM, route mutations through a small instance-keyed `inout` helper instead of duplicating per-slice setters.
- Shape of the *input* (single state struct vs. several `let`s vs. bindings) is a per-subview judgment call — what matters is that intent only flows out via `onAction`.

## Project Structure

- Each Tuist project's `Project.swift` declares one main target named after the feature, plus optional sibling targets `<Feature>Tests` and `<Feature>TestSupport` **within the same `Project.swift`** (not as separate Tuist projects). Each target gets its own buildable folder inside the project directory:
  ```
  /
  ├── <Feature>/
  │   ├── Project.swift
  │   ├── Sources/         # <Feature> target
  │   ├── TestSupport/     # <Feature>TestSupport target (when present)
  │   ├── Tests/           # <Feature>Tests target (when present)
  │   └── Resources/       # (when needed, attached to whichever target uses it)
  ├── Tuist.swift
  └── Workspace.swift
  ```
- The repo root has a single `Workspace.swift` listing every project (one entry per project, regardless of how many targets it contains); there is no root `Project.swift`. When adding a brand-new project (not just a target), create the sibling folder, drop in its `Project.swift`, and add it to `Workspace.swift`'s `projects` array. When adding a `Tests`/`TestSupport` target to an existing project, just add it to that project's `Project.swift` and create the corresponding source folder — no `Workspace.swift` change needed.
- Cross-target dependencies *within the same project* use `.target(name: "OtherTargetInSameProject")`; cross-project dependencies use `.project(target: "<Other>", path: .relativeToManifest("../<Other>"))`.
- Library projects expose their API as `public` types. Keep concrete types `internal` whenever a `public` protocol covers the API surface — only the protocol(s) and the module's `Dependencies` factory should leak to consumers. App-only projects keep types `internal`.
- Every `Project.swift` enables Swift 6.2's approachable concurrency: `"SWIFT_APPROACHABLE_CONCURRENCY": "YES"` in the project's base settings (alongside `SWIFT_VERSION`).

## Dependencies pattern

Each library module owns a `Sources/Dependencies.swift` with a `public struct Dependencies: Sendable` that exposes only the module's protocol-typed services. Concrete implementations stay `internal`. Don't add a `public init` — let the synthesized memberwise init stay internal so external code can only construct a module's `Dependencies` through the `live` factory.

The factory is **always** a parameterless `public static let live: Dependencies`, never a function. When a module needs services from an upstream module, reach into that module's own factory directly inside the closure (e.g. `StorageKit.Dependencies.live.audioSettingsStore`) — don't accept upstream services as parameters. This keeps every consumer's call site uniform: `<Module>.Dependencies.live` is always a property access.

The app's `TinyAudioUnitHost/Sources/Dependencies.swift` is the composition root. It holds each module's `Dependencies` as a nested field (`let storage: StorageKit.Dependencies`, `let engine: EngineKit.Dependencies`) — don't fan individual services out into a flat list. View-model factories then reach through the nested struct (e.g. `engine.engine`). Adding a new service to a module becomes zero-touch in the app.

## Mock pattern

Mocks for `*Type` protocols go in `<Feature>/TestSupport/<Type>Mock.swift` (target `<Feature>TestSupport`):

```swift
public actor AudioSettingsStoreMock: AudioSettingsStoreType {
    public enum Calls {
        case update
        case current
    }

    public private(set) var calls: [Calls] = []
    public var settings: AudioSettings

    public init(settings: AudioSettings = .empty) {
        self.settings = settings
    }

    public func current() -> AudioSettings {
        calls.append(.current)
        return settings
    }

    public func update(_ transform: @Sendable (inout AudioSettings) -> Void) {
        transform(&settings)
        calls.append(.update)
    }
}
```

- One `Calls` case per protocol method; add associated values when arguments matter.
- Append to `calls` *after* the real effect runs.
- Configure stub state and return-value overrides via init params with defaults — actors block cross-actor property writes, and adding setter methods tempts tests to bypass the protocol.
- No `clearCalls()`, no backdoor mutators. Only the protocol surface plus configurable starting state.
