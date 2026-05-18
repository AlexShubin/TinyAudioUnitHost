# Multi-Preset Support — Plan

## Goal

Replace the single-default-preset model with a multi-slot model. The host's left sidebar gains a tab switcher: **Audio Units** (today's component list) and **Presets** (list of preset slots with a `+` to create a new one). Selecting a slot loads it; the Save/Restore buttons in the toolbar operate on the *active* slot.

Inspiration: the "Journals" sidebar — a section header with a trailing `+`, and a centered modal dialog with a circular icon, a "Preset Name" placeholder, and Cancel / Create buttons.

## Scope

In:
- Two-tab sidebar (AUs / Presets) with the existing AU list moved under the AUs tab.
- Preset slot list view (rows = name + glyph; selection drives load).
- `+` button → "New Preset" sheet that asks for a name.
- Slot context menu (rename, delete).
- Filesystem layout for multiple presets keyed by name.

Out (future):
- Drag-to-reorder slots (alphabetical for now), duplicate-slot, export/import.
- Per-slot AU-internal preset library hooks.
- Persisted "last active preset" across launches (we pick the first alphabetically on launch — simple and predictable).

## Identity model

**Each preset is identified by its name.** No UUIDs, no separate index file, no explicit migration:

- A preset's name is its filename: `presets/<name>.json`.
- Listing slots = enumerating the `presets/` directory.
- Renaming = moving the file.
- The existing `presets/default.json` is already a preset named `"default"` under this scheme — nothing to migrate; it just shows up in the list and loads on first launch.

Trade-offs we accept:
- **Renames are I/O**, not just a metadata update. Cheap enough.
- **Order is alphabetical**, fixed. Reordering would require an index file; deferred.

**Active preset persists across launches** in a tiny dedicated file `presets_state.json` (`{ "activeName": "B" }`), managed by `RawPresetStore` alongside the preset files. On launch the VM reads it; if it's missing or names a preset that no longer exists, the VM falls back to `presets.first?.name` — so an existing single-preset user still sees `"default"` load automatically. `RawPresetStore` keeps the state file consistent on its own: renaming the active preset rewrites `activeName`; deleting it clears the field.

## Decisions (with recommendations)

1. **Sidebar tab style.** Recommend segmented `Picker` at the top of the sidebar (matches Mail/Calendar). Vertical icon rail is the other option; more chrome and harder to size inside `NavigationSplitView`. **Confirmed and shipped** as a placeholder.
2. **AU selection writes back to the active slot** (recommended). Picking an AU replaces the slot's `component` + state immediately and persists. Save persists in-flight tweaks; Restore reloads from disk. Alternative is "stage until Save", but that splits engine state from disk state and surprises users.
3. **`+` is Save As.** The button on the Presets sidebar is enabled only when the engine is `.loaded` (same gating as the toolbar Save). Clicking it opens the name dialog; on commit, the current AU + state is written under the new name and becomes the active preset. No empty presets ever exist on disk. `+` and Save are siblings — both write the engine state to a file; Save targets the active preset's file, Save As writes to a new one.
4. **`RawPreset` stays as-is.** All four content fields remain required. Since no empty preset ever reaches disk, we don't need to weaken the type.
5. **Name validation.** Trim whitespace; reject empty after trim; reject `/`, `:`, and a leading `.`; reject duplicates (case-insensitive compare so `"Default"` and `"default"` don't collide on case-insensitive filesystems). All enforced in the provider; the dialog disables Create when the name doesn't pass.

## Resolved details

- **Deleting the active preset.** Provider clears `activeName` atomically; the VM falls back to `presets.first?.name` (the new first after deletion) and calls `setActive` so the next launch matches what's on screen.
- **AU selection with no active preset.** The engine enters "preview" — AU loads, nothing persists. `+` becomes enabled the moment content reaches `.loaded`, giving the user a clear way to save what's playing under a name. This covers both "zero presets exist" and "active was just deleted and there's no successor". No auto-create; nothing on disk until the user names it.
- **Name validation.** `PresetNameValidatorType` (a protocol in PresetKit with an `internal` struct impl, wired in `PresetKit.Dependencies.live`) is the single source of truth. Injected into `PresetProvider` (used by `create` / `rename`) **and** into the HostViewModel (for live keystroke validation in the New Preset dialog). Mocked in `PresetKitTestSupport` so consumer tests drive validation results without re-testing the rules.
- **Sidebar tab.** View-local `@State` (already shipped). Resets to Audio Units on view recreation; no persistence.

## Architecture

### Persistence (`StorageKit`)

Path scheme:
- `presets/<name>.json` — one `RawPreset` per slot. An empty preset has all content fields nil.

`RawPreset` is unchanged — all four content fields stay required. Every file on disk represents a fully-formed preset (no empty marker case).

**`FileStorageType` gains two methods** to support listing and renaming:

```swift
func list(directory relativePath: String) -> [String]   // basenames, no extension
func move(from: String, to: String)                     // file rename
```

**`RawPresetStoreType` surface** (replaces today's `load(name:) / save(_:name:) / delete(name:)`):

```swift
public protocol RawPresetStoreType: Sendable {
    func names() async -> [String]
    func load(name: String) async -> RawPreset?
    func save(_ preset: RawPreset, name: String) async
    func rename(from: String, to: String) async
    func delete(name: String) async
    func activeName() async -> String?
    func setActive(_ name: String?) async
}
```

`names()` returns whatever's in the `presets/` directory, sorted by `localizedCaseInsensitiveCompare`. The active name is persisted in `presets_state.json` (`{ "activeName": String? }`) and accessed via `activeName / setActive`. `rename(from:to:)` and `delete(name:)` keep that file in sync atomically — renaming the active preset rewrites `activeName`, deleting it clears the field. Callers don't need to call `setActive` themselves on rename/delete.

Test-support updates: `RawPresetStoreMock` gains `rename` + `names` in its `Calls` enum; its internal map becomes `[String: RawPreset]` — already keyed by name.

### Domain (`PresetKit`)

One value type:

```swift
public struct Preset: Sendable, Equatable {
    public let name: String
    public let component: AudioUnitComponent
    public let state: Data
}
```

Used for listing (the sidebar reads `.name`) and for loading into the engine. No separate `PresetSlot`, no `PresetContent` enum — a `Preset` is always a fully-formed AU + state pair.

**`PresetProviderType` surface:**

```swift
public protocol PresetProviderType: Sendable {
    func presets() async -> [Preset]                                       // sorted by name
    func activeName() async -> String?
    func setActive(_ name: String?) async
    func load(name: String) async -> Preset?
    func save(_ preset: Preset) async                                      // overwrite existing
    func saveAs(name: String, component: AudioUnitComponent, state: Data)
        async -> Result<Preset, PresetNameError>                           // new file, validated
    func rename(from: String, to: String) async -> Result<Void, PresetNameError>
    func delete(name: String) async
}

public enum PresetNameError: Error, Sendable, Equatable {
    case empty
    case invalidCharacter
    case duplicate
}

public protocol PresetNameValidatorType: Sendable {
    /// Returns nil when the name passes all rules, otherwise the first failing rule.
    /// Trims whitespace; rejects empty, `/`, `:`, leading `.`; existing names are
    /// compared case-insensitively (so `"Default"` and `"default"` collide).
    func validate(name: String, against existing: [String]) -> PresetNameError?
}

struct PresetNameValidator: PresetNameValidatorType { ... }
```

Wired through `PresetKit.Dependencies.live` and injected into both `PresetProvider` (so `create` / `rename` validate before writing) and the HostViewModel (so the New Preset dialog can disable Create live as the user types). One shared seam, one set of rules, two consumers — and tests for either can swap in a `PresetNameValidatorMock` to drive specific outcomes without re-deriving the rules.

Notes:
- `presets()` returns full `Preset` values. Cheap enough — preset files are small. If listing ever becomes hot we can split into `names()` + `load(name:)`.
- `save(_:)` overwrites the file at `presets/<preset.name>.json`. Used on every AU selection (write-back to the active preset) and on toolbar Save. No validation — the name is the active preset's, already on disk.
- `saveAs(name:component:state:)` runs name validation and writes a brand-new file. Used by the `+` dialog. Returns the resulting `Preset` so the VM can update `presets` and active state without a separate refresh.
- `rename` moves the file and is a no-op if `from == to`. Validates the new name.

**File-by-file changes in `PresetKit/Sources/`:**
- `Models/Preset.swift` — add `name` field. Stays a plain `(name, component, state)` value.
- `Models/PresetNameError.swift` — new.
- `Services/PresetProvider.swift` — rewrite around the new surface; takes `validator: PresetNameValidatorType` in init.
- `Services/PresetNameValidator.swift` — new (protocol + internal struct).
- `Sources/Dependencies.swift` — add `presetNameValidator: PresetNameValidatorType`; `live` wires it once and passes the same instance into `PresetProvider`'s init.

**Test support:**
- `Preset+Fake.swift` — `name: String = "Test"`, `component: AudioUnitComponent = .fake()`, `state: Data = Data()`.
- `PresetProviderMock.swift` — `Calls` covers each method; backing map is `[String: Preset]`.
- `PresetNameValidatorMock.swift` — `final class` (the protocol isn't actor-bound); configurable `result: PresetNameError?`; records each `validate(...)` call.

### App layer (`TinyAudioUnitHost`)

#### `HostViewModel`

State additions:
- `presets: [Preset]`
- `activeName: String?` — view-model state, not persisted. On `task`, defaults to `presets.first?.name`.
- `sidebarTab: SidebarTab` — could live in the View as `@State` (it has no business-logic impact). Keep in VM only if a test cares.
- `newPresetDialog: NewPresetDialogState?` — drives the sheet.

Actions:
- Keep `selected(AudioUnitComponent)`, `saveCurrentPreset`, `restorePreset` — now operate via `activeName`.
- New: `case selectedPreset(String)`, `case newPresetTapped`, `case newPresetDialogAction(NewPresetDialogAction)`, `case renamePreset(String, to: String)`, `case deletePreset(String)`.

Behavior:
- `task`: read `provider.presets()` and `provider.activeName()`; set `activeName` to that value if it still names a known preset, otherwise to `presets.first?.name` (and call `provider.setActive` to repair stale state). Load the active preset into the engine. With zero presets, `activeName` stays nil and content is `.empty`.
- `selectedPreset(name)`: set local `activeName`; `await provider.setActive(name)`; load its content into the engine.
- `selected(component)`: load into engine. If `activeName` is set, write back `Preset(name: activeName, component, state)` via `provider.save`. Otherwise the engine is in "preview" — no persistence; `+` becomes the way out.
- `saveCurrentPreset`: write the engine's current `fullState` to the active preset via `provider.save`. Disabled (gated in the toolbar) when no active preset.
- `restorePreset`: re-load the active preset from disk. Disabled when no active preset.
- `newPresetDialogAction(.commit(name))`: gated on `content.isLoaded`. Calls `provider.saveAs(name:, component:, state:)` with the engine's current values. On `.success(preset)`: refresh `presets`, set `activeName = preset.name`, `provider.setActive`. On `.failure(error)`: surface in the dialog.
- `renamePreset(from:to:)`: provider keeps `presets_state.json` consistent; VM refreshes `presets` and re-reads `provider.activeName()`.
- `deletePreset(name)`: provider clears active if it matched; VM refreshes; if `activeName` came back nil, fall back to `presets.first?.name` and call `provider.setActive` (nil if no presets remain — engine drops to preview-style empty).

#### Sidebar

Already prototyped: segmented `Picker` at the top of the `NavigationSplitView` sidebar; the AU list lives under the Audio Units tab; the Presets tab gets a real list.

`PresetsSidebar` — header row "Presets" + trailing `+` button (disabled when `content.isLoaded == false`, same as toolbar Save); below it a `List(selection: $activeName)` over `viewModel.presets`. Row context menu: Rename, Delete. Subview pattern: state struct + `onAction: (PresetsSidebarAction) -> Void`. The VM wraps actions as `.presetsSidebarAction(...)`.

We don't necessarily need to extract `AudioUnitsSidebar` as a subview to ship presets — the existing inline `List` works fine. Worth doing only if/when we want symmetry or the inline block grows unwieldy.

#### "New Preset" dialog

`NewPresetDialogView` presented as a `.sheet`. Layout per the reference: rounded card, centered circular icon (`Image(systemName: "rectangle.stack")` on an accent disc), `TextField` with placeholder "Preset Name", Cancel / Create at the bottom. Create disabled when validation fails (empty after trim, or duplicate of an existing name).

```swift
struct NewPresetDialogState: Sendable, Equatable {
    var name: String
    var error: PresetNameError?
}

enum NewPresetDialogAction {
    case nameChanged(String)
    case cancel
    case commit
}
```

The text field's `Binding` is the binding-shaped subview-API exception mentioned in CLAUDE.md.

#### Toolbar

Replace the hardcoded `"Preset: Default"` with `activeName ?? "—"`. Save / Restore behavior unchanged for the user; routing goes through the active preset.

### Dependency graph

No new modules, no new edges.

## Implementation order

1. **StorageKit**: `RawPreset` field optionality, `FileStorageType.list` + `move`, new `RawPresetStoreType` surface (incl. `activeName` / `setActive` via `presets_state.json` and the rename/delete consistency rules), mock + tests.
2. **PresetKit**: `Preset` / `PresetContent`, `PresetNameError`, `PresetNameValidatorType` + impl wired through `Dependencies.live`, new `PresetProviderType` surface (taking the validator in init), mocks + tests.
3. **HostVM**: `presets`, `activeName`, new actions, save-back-on-AU-selection. Update existing tests; add tests for active-preset routing, create / rename / delete.
4. **HostView**: replace the Presets placeholder with `PresetsSidebar`; add the `+` button.
5. **New-preset dialog**: `NewPresetDialogView`, sheet wiring.
6. **Toolbar text** + active-name binding.
7. **Manual QA**: launch with existing `presets/default.json` → it loads as `"default"`; create, switch, rename, delete; verify Save/Restore route to the active preset.

No step needs `mise run generate` (Sources-only changes).

## Notes on conventions

- New types in PresetKit are `public`; concrete impls stay `internal` behind their `Type` protocols.
- New sidebar subviews follow the dedicated-action-enum + single `onAction` closure pattern; the VM wraps each subview's enum in its own case.
- File-backed storage keys stay snake_case; preset filenames are user-controlled strings, validated by the provider.
- One init per type; live wiring stays in `PresetKit.Dependencies.live`; no convenience inits.
- `Type+Fake.swift` updates ship in the same commit as the type changes.
