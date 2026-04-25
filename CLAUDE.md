# Project Notes

## Tuist

- To regenerate the Xcode project, run: `mise run generate`
- Always run `mise run generate` after structural changes to the project (adding/removing targets, files, dependencies in Project.swift)

## Tech Stack

- Swift 6.0 strict concurrency, macOS 26.0
- SwiftUI only (NSViewControllerRepresentable for AU views)
- Zero external dependencies — only Apple frameworks
- Swift Testing framework (`@Suite`, `@Test`, `#expect`) — not XCTest

## Architecture

- MVVM with `@Observable` ViewModels that expose state as observed properties directly
- DI via `Dependencies` structs with `static let live` factory + SwiftUI `EnvironmentKey`
- Keep framework types (CoreAudio, CoreMIDI, AudioToolbox, etc.) out of the view layer. Framework imports belong in `Engine/` and model definitions.

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
- Library projects expose their API as `public` types (with explicit `public init`s — synthesized memberwise inits are internal). App-only projects keep types `internal`.
