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
3. **"New Preset" starts empty.** User picks an AU after creating. Future: "Duplicate" via row context menu.
4. **Empty-slot persistence.** A freshly-created slot is written to disk **with no content** (an empty `RawPreset`). That way the filesystem is the canonical list — no in-memory ghost slots, no merge logic between "exists on disk" and "exists in memory". The user picks an AU; the file gets filled in.
5. **Name validation.** Trim whitespace; reject empty after trim; reject `/`, `:`, and a leading `.`; reject duplicates (case-insensitive compare so `"Default"` and `"default"` don't collide on case-insensitive filesystems). All enforced in the provider; the dialog disables Create when the name doesn't pass.

## Resolved details

- **Deleting the active preset.** Provider clears `activeName` atomically; the VM falls back to `presets.first?.name` (the new first after deletion) and calls `setActive` so the next launch matches what's on screen.
- **AU selection with zero presets.** Auto-create an `"Untitled"` preset on the first AU pick: `provider.create(uniqueUntitledName())` → `setActive` → `save(...)`. The unique-name helper picks `"Untitled"` if available, else `"Untitled 2"`, `"Untitled 3"`, etc. — like TextEdit. Users can rename via the row context menu.
- **Name validation.** `PresetNameValidatorType` (a protocol in PresetKit with an `internal` struct impl, wired in `PresetKit.Dependencies.live`) is the single source of truth. Injected into `PresetProvider` (used by `create` / `rename`) **and** into the HostViewModel (for live keystroke validation in the New Preset dialog). Mocked in `PresetKitTestSupport` so consumer tests drive validation results without re-testing the rules.
- **Sidebar tab.** View-local `@State` (already shipped). Resets to Audio Units on view recreation; no persistence.

## Architecture

### Persistence (`StorageKit`)

Path scheme:
- `presets/<name>.json` — one `RawPreset` per slot. An empty preset has all content fields nil.

`RawPreset` schema gains optional content (was all-required):

```swift
public struct RawPreset: Sendable, Equatable, Codable {
    public var componentType: UInt32?
    public var componentSubType: UInt32?
    public var componentManufacturer: UInt32?
    public var state: Data?
}
```

Old `default.json` files already on disk decode fine — `Optional<UInt32>` accepts the existing concrete values. No data migration needed.

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

Two value types:

```swift
public struct Preset: Sendable, Equatable {
    public let name: String
    public let content: PresetContent
}

public enum PresetContent: Sendable, Equatable {
    case empty
    case loaded(component: AudioUnitComponent, state: Data)
}
```

`Preset` is the single domain type — used for listing (the sidebar reads `.name`) and for loading into the engine (where `.content` determines what to do). No separate `PresetSlot`.

**`PresetProviderType` surface:**

```swift
public protocol PresetProviderType: Sendable {
    func presets() async -> [Preset]                                       // sorted, content included
    func activeName() async -> String?
    func setActive(_ name: String?) async
    func load(name: String) async -> Preset?
    func create(name: String) async -> Result<Preset, PresetNameError>     // empty slot
    func save(_ preset: Preset) async                                      // overwrite
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
- `presets()` returns full `Preset` values, including content. Cheap enough — preset files are small (state Data is the only non-trivial field; not loaded into the engine until selected). If we ever store large state blobs and listing becomes hot, we can split into `names()` + `load(name:)`.
- `create` enforces name rules; returns the new empty `Preset`.
- `save` overwrites the file at `presets/<preset.name>.json`. Used by the VM on AU selection and on explicit Save.
- `rename` moves the file and is a no-op if `from == to`.

**File-by-file changes in `PresetKit/Sources/`:**
- `Models/Preset.swift` — add `name`, replace `(component, state)` with `content: PresetContent`.
- `Models/PresetContent.swift` — new.
- `Models/PresetNameError.swift` — new.
- `Services/PresetProvider.swift` — rewrite around the new surface; takes `validator: PresetNameValidatorType` in init.
- `Services/PresetNameValidator.swift` — new (protocol + internal struct).
- `Sources/Dependencies.swift` — add `presetNameValidator: PresetNameValidatorType`; `live` wires it once and passes the same instance into `PresetProvider`'s init.

**Test support:**
- `Preset+Fake.swift` — `name: String = "Test"`, `content: PresetContent = .empty` by default; convenience `.loaded(...)` factory.
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
- `task`: read `provider.presets()` and `provider.activeName()`; set `activeName` to that value if it still names a known preset, otherwise to `presets.first?.name` (and call `provider.setActive` to repair stale state). Load the active preset into the engine.
- `selectedPreset(name)`: set local `activeName`; `await provider.setActive(name)`; load its content into the engine (engine empty if `.empty`).
- `selected(component)`: load into engine. Then:
  - If `activeName` is set: write back `Preset(name: activeName, content: .loaded(component, state))` via `provider.save`.
  - If `activeName` is nil (i.e., `presets` is empty): auto-create a slot to hold the AU — compute `uniqueUntitledName(against: presets.map(\.name))` (`"Untitled"`, `"Untitled 2"`, …), `provider.create(name)`, set local `activeName` + `provider.setActive(name)`, then `provider.save(...)` with the loaded content.
- `saveCurrentPreset`: same write-back, using the engine's current `fullState`.
- `restorePreset`: re-load the active preset from disk.
- `newPresetDialogAction(.commit(name))`: `provider.create(name)` → on success, refresh `presets`, `provider.setActive(name)`, engine to `.empty`.
- `renamePreset(from:to:)`: provider keeps `presets_state.json` consistent; VM refreshes `presets` and re-reads `provider.activeName()`.
- `deletePreset(name)`: provider clears active if it matched; VM refreshes; if `activeName` came back nil, fall back to `presets.first?.name` and call `provider.setActive`.

#### Sidebar

Already prototyped: segmented `Picker` at the top of the `NavigationSplitView` sidebar; the AU list lives under the Audio Units tab; the Presets tab gets a real list.

`PresetsSidebar` — header row "Presets" + trailing `+` button; below it a `List(selection: $activeName)` over `viewModel.presets`. Row context menu: Rename, Delete. Subview pattern: state struct + `onAction: (PresetsSidebarAction) -> Void`. The VM wraps actions as `.presetsSidebarAction(...)`.

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
