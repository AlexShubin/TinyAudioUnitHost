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
- Inside `Tests/`, two top-level folders: `Tests/Suites/` for `@Suite` test files and `Tests/Mocks/` for mocks. Under `Suites/`, mirror `Sources/`'s subfolder layout — a test for `Sources/<SubFolder>/<File>.swift` lives at `Tests/Suites/<SubFolder>/<File>Tests.swift` (e.g. `Sources/Engine/Engine.swift` → `Tests/Suites/Engine/EngineTests.swift`). `Tests/Mocks/` stays flat.

## Dependencies pattern

Each library module owns a `Sources/Dependencies.swift` with a `public struct Dependencies: Sendable` that exposes only the module's protocol-typed services. Concrete implementations stay `internal`. Don't add a `public init` — let the synthesized memberwise init stay internal so external code can only construct a module's `Dependencies` through the `live` factory.

The factory is **always** a parameterless `public static let live: Dependencies`, never a function. When a module needs services from an upstream module, reach into that module's own factory directly inside the closure (e.g. `StorageKit.Dependencies.live.audioSettingsStore`) — don't accept upstream services as parameters. This keeps every consumer's call site uniform: `<Module>.Dependencies.live` is always a property access.

The app's `TinyAudioUnitHost/Sources/Dependencies.swift` is the composition root. It holds each module's `Dependencies` as a nested field (`let storage: StorageKit.Dependencies`, `let engine: EngineKit.Dependencies`) — don't fan individual services out into a flat list. View-model factories then reach through the nested struct (e.g. `engine.engine`). Adding a new service to a module becomes zero-touch in the app.

## Mock pattern

Mocks for `*Type` protocols live in one of two places depending on scope:
- `<Feature>/TestSupport/Mocks/<Type>Mock.swift` (target `<Feature>TestSupport`, `public`) — when the protocol is `public` and *other* modules' tests need it.
- `<Feature>/Tests/Mocks/<Type>Mock.swift` (target `<Feature>Tests`, internal) — when the protocol is module-internal. The test target uses `@testable import <Feature>` to reach internal types, so the mock stays internal too.

Default shape:

```swift
public actor AudioSettingsStoreMock: AudioSettingsStoreType {
    public enum Calls: Equatable {
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

- One `Calls` case per protocol method; add associated values when arguments matter. `Calls: Equatable` so tests can assert sequences with `==`.
- Append to `calls` *after* the real effect runs.
- Configure stub state and return-value overrides via init params with defaults.
- Actor mocks may add one `set<Field>(_:)` method per init parameter, alongside the protocol surface. These setters mirror what `init` already accepts, do **not** append to `calls`, and are reserved for test setup — they let a test adjust starting state mid-fixture without recording a sut-driven call. Use them to (a) reach an actor whose protocol has no in-place setter, or (b) keep the `calls` log clean when the protocol *does* have a setter (`update`, etc.) but the test is using it for setup rather than to exercise the sut. Protocol methods always record; setters never do.
- No `clearCalls()`. No fields beyond what `init` accepts. No mutators that don't correspond to a config-time concept.
- For class-bound protocols (`: AnyObject`), use `final class` instead of `actor`. Visibility follows location: `public` in `TestSupport`, internal in `Tests`.

## Fake pattern

Fakes are zero-arg-friendly factory methods on value types, kept in `<Feature>/TestSupport/Fakes/<Type>+Fake.swift` (target `<Feature>TestSupport`, `public`). The file is an extension on the type; the method is `static func fake(...) -> Self`.

```swift
public extension AudioDevice {
    static func fake(
        id: UInt32 = 1,
        uid: String = "uid",
        name: String = "Test Device",
        inputChannels: [AudioChannel] = [],
        outputChannels: [AudioChannel] = [],
        availableBufferSizes: [UInt32] = []
    ) -> AudioDevice {
        AudioDevice(id: id, uid: uid, name: name, inputChannels: inputChannels, outputChannels: outputChannels, availableBufferSizes: availableBufferSizes)
    }
}
```

- Every parameter is defaulted. `Type.fake()` must work with no arguments — that's the whole point. Overrides happen at the call site.
- Compose fakes by defaulting one to another (`device: AudioDevice = .fake()`). Tests can override at any layer (e.g. `TargetAudioDevice.fake(inputOffset: 2)`).
- A type's fake lives in the same module's `TestSupport` as the type (`AudioDevice` → `CommonTestSupport`, `TargetAudioDevice` → `EngineKitTestSupport`). Cross-module composition flows through `import CommonTestSupport` etc.
- Fakes are for value types (data shapes); mocks are for protocols. Different folders (`Fakes/` vs `Mocks/`), different naming. Don't conflate.
- Don't put `make<Type>(...)` helpers in test files. If a test needs a fixture, the type's `fake(...)` is the only home — discoverable via autocomplete on the type itself.
- Keep fakes dumb: just construction with defaults, no logic, no pattern-matching factories. If you need shaped data, override at the call site.

## Test fixture pattern

Each `@Suite` is a struct that holds its mocks and the sut as IUO `var` properties. `init()` builds every mock from its no-arg default and does nothing else — it never constructs the sut. Each `@Test` is `mutating`, configures the mocks it needs, then calls `createSut()` once. `createSut()` is the only place that constructs the sut.

```swift
@Suite
struct FooTests {
    var someMock: SomeMock!
    var sut: FooType!  // protocol type, not the concrete

    init() {
        someMock = SomeMock()
        // ... only mock construction goes here
    }

    mutating func createSut() {
        sut = Foo(some: someMock, ...)
    }

    @Test
    mutating func someTest() async {
        someMock.result = .success(...)
        createSut()
        // exercise sut...
    }
}
```

- Type the sut as the protocol (`FooType`), never the concrete (`Foo`). Tests should exercise only the protocol surface.
- No parameterized `makeSut(...)` factory. Each test configures mocks in its body and then calls `createSut()`.
- Don't build the sut in `init()`. Calling `createSut()` again later would double up any side effects the constructor records (e.g. an `attach` call), and forcing every test to do its setup before sut construction keeps the recorded call sequence clean.
- Mutate class mocks' properties directly in tests (`someMock.result = .success(...)`).
- For actor mocks, mutate through the protocol's own methods (e.g. `await mock.update { ... }`). When the protocol has no setter, replace the mock var (`someActorMock = SomeActorMock(field: ...)`) before calling `createSut()`.
- Read the test's name to identify which mock(s) it commits to — those are **primary**; the rest are **incidental**. Assert primary mocks with full-array equality (`#expect(mock.calls == [.foo, .bar])`), not `.count == N` or piecewise `.contains` — that's the whole point of `Calls: Equatable`. For incidental mocks, prefer a targeted `.contains(...)` (or skip them) so an unrelated wiring change in the sut doesn't cascade across the suite. Other tests, named after those mocks, will cover them fully. When the primary claim is "nothing else happened", `.isEmpty` is the right form. The exception: tests whose name commits to multi-mock orchestration (e.g. "detachesOldAndTearsDownMIDI") legitimately need full `==` on every named mock.
