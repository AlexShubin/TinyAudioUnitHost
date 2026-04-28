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

## Naming Conventions

- `*Type` suffix for protocols (`AudioUnitHostEngineType`)
- `*Action` for view model action enums
- Features organized as `Features/FeatureName/` with View, ViewModel, and optional `Subviews/`

## Subview communication

Subviews don't own a view model. They take a single state struct + an `onAction` closure and bubble user intent up to the parent feature's VM:

```swift
struct DevicePickerState: Sendable, Equatable {
    var devices: [AudioDevice]
    var selectedDevice: AudioDevice?
    var selectedChannel: SelectedChannel?
}

enum DevicePickerViewAction { case selectDevice(AudioDevice), setChannel(...) }

struct DevicePickerView: View {
    let kind: DevicePickerKind
    let state: DevicePickerState
    let onAction: (DevicePickerViewAction) -> Void
}
```

The parent VM owns one state struct per subview instance (e.g. `inputState`, `outputState`) and wraps each subview action in its own case (`.inputDevicePickerAction(...)`, `.outputDevicePickerAction(...)`). When the parent dispatches multiple instances of the same subview, route writes through a kind-keyed inout helper instead of duplicating per-slice setters:

```swift
private func mutatePickerState(kind: DevicePickerKind, _ mutate: (inout DevicePickerState) -> Void) {
    switch kind {
    case .input: mutate(&inputState)
    case .output: mutate(&outputState)
    }
}
```

Call sites then touch only the field they care about (`state.selectedDevice = device`) instead of rebuilding the whole struct.

## Project Structure

- Each Tuist project follows the naming convention: `Feature`, `FeatureTests`, `FeatureTestSupport` (when needed).
- Each Tuist project lives in its own sibling folder at the repo root, named after the project, with its `Project.swift` and a `Sources/` (and `Resources/` when needed) inside:
  ```
  /
  ├── <ProjectA>/
  │   ├── Project.swift
  │   └── Sources/
  ├── <ProjectB>/
  │   ├── Project.swift
  │   ├── Sources/
  │   └── Resources/
  ├── Tuist.swift
  └── Workspace.swift
  ```
- The repo root has a single `Workspace.swift` listing every project; there is no root `Project.swift`. When adding a new project, create the sibling folder, drop in its `Project.swift`, and add it to `Workspace.swift`'s `projects` array.
- Cross-project dependencies use `.project(target: "<Other>", path: .relativeToManifest("../<Other>"))`.
- Library projects expose their API as `public` types. Keep concrete types `internal` whenever a `public` protocol covers the API surface — only the protocol(s) and the module's `Dependencies` factory should leak to consumers. App-only projects keep types `internal`.
- Every `Project.swift` enables Swift 6.2's approachable concurrency: `"SWIFT_APPROACHABLE_CONCURRENCY": "YES"` in the project's base settings (alongside `SWIFT_VERSION`).

## Dependencies pattern

Each library module owns a `Sources/Dependencies.swift` with a `public struct Dependencies: Sendable` that exposes only the module's protocol-typed services. Concrete implementations stay `internal`. Don't add a `public init` — let the synthesized memberwise init stay internal so external code can only construct a module's `Dependencies` through the `live` factory.

The factory is **always** a parameterless `public static let live: Dependencies`, never a function. When a module needs services from an upstream module, reach into that module's own factory directly inside the closure (e.g. `StorageKit.Dependencies.live.audioSettingsStore`) — don't accept upstream services as parameters. This keeps every consumer's call site uniform: `<Module>.Dependencies.live` is always a property access.

The app's `TinyAudioUnitHost/Sources/Dependencies.swift` is the composition root. It holds each module's `Dependencies` as a nested field (`let storage: StorageKit.Dependencies`, `let engine: EngineKit.Dependencies`) — don't fan individual services out into a flat list. View-model factories then reach through the nested struct (e.g. `engine.audioUnitEngineManager`). Adding a new service to a module becomes zero-touch in the app.
