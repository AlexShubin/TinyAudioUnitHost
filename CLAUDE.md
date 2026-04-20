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

- MVVM with `@Observable` ViewModels
- DI via `Dependencies` structs with `static let live` factory + SwiftUI `EnvironmentKey`

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
- `*ViewState` for UI state structs, `*Action` for view model action enums
- Features organized as `Features/FeatureName/` with View, ViewModel, and optional `Subviews/`

## Project Structure

- Each Tuist project follows the naming convention: `Feature`, `FeatureTests`, `FeatureTestSupport` (when needed).
