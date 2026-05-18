# Multi-Preset Support — Plan

## Goal

Replace the single-default-preset model with a multi-slot model. The host's left sidebar gains a tab switcher: **Audio Units** (today's component list) and **Presets** (list of preset slots with a `+` to create a new one). Selecting a slot loads it; the Save/Restore buttons in the toolbar operate on the *active* slot.

Inspiration: the "Journals" sidebar from the user's reference shots — a section header with a trailing `+`, and a centered modal dialog with a circular icon, a "Preset Name" placeholder, and Cancel / Create buttons.

## Scope

In:
- Two-tab sidebar (AUs / Presets) with the existing AU list moved under the AUs tab.
- Preset slot list view (rows = name + glyph; selection drives load).
- `+` button → "New Preset" sheet that asks for a name.
- Slot context menu (rename, delete).
- Persistence layout for multiple slots + the currently-active slot.
- One-time migration from the legacy `presets/default.json`.

Out (future):
- Drag-to-reorder slots, duplicate-slot, export/import slots, per-slot AU presets within an AU's own preset library.
- Keyboard-driven slot creation (we get menu wiring "for free" later if we want it).
- A separate detail pane for "preset library" — slots stay sidebar-only.

## Open questions (decide before coding)

1. **Sidebar tab style.**
   Two reasonable shapes:
   - **(A) Segmented `Picker` at the top of the sidebar** (recommended) — matches Mail/Calendar sidebars, no new layout chrome, fits the existing `NavigationSplitView` sidebar column width.
   - **(B) Vertical icon rail** along the leading edge (Xcode-style). More chrome; harder to size inside `NavigationSplitView`.
   Recommend (A).

2. **AU selection semantics when a slot is active.**
   - **(A) Picking an AU replaces the active slot's component and resets state** (recommended — matches a "patch" workflow). Save persists; Restore reloads from disk.
   - **(B) Picking an AU only loads it into the engine; the slot's stored content is untouched until Save.**
   Recommend (A) — simpler mental model, matches today's behavior where the loaded state always reflects what plays.

3. **"New Preset" initial content.**
   - **(A) Empty slot** — user picks an AU after creating. (Recommended.)
   - **(B) Clone the currently-active slot.**
   Recommend (A); add "Duplicate" via row context menu later.

4. **No-active-slot state.**
   When the user is on the Presets tab with no slot selected, the detail shows the existing empty-selection view. Same applies right after creating a slot but before picking an AU. (No new state required.)

5. **Migration of `presets/default.json`.**
   On first run with the new schema: read the legacy file, create a slot named `"Default"`, mark it active, write the new files, delete the legacy one. Idempotent — if the new index already exists, the legacy file is ignored (or also deleted — pick one). Recommend: delete on successful migration.

## Architecture

### Persistence (`StorageKit`)

Today `RawPresetStore` writes `presets/default.json` containing only `RawPreset`. Move to:

- `presets/<uuid>.json` — one `RawPreset` per slot. Filename is the slot ID. **No name in the file** — names live in the index so listing is cheap.
- `presets_index.json` — `RawPresetIndex { entries: [RawPresetEntry], activeID: UUID? }` where `RawPresetEntry { id: UUID, name: String }`. Order in `entries` is display order.

The store stays a thin foreign-data wrapper (raw external IDs only, no domain types).

**Files / types added in `StorageKit/Sources/`:**
- `Models/RawPresetIndex.swift` — `public struct RawPresetIndex: Codable, Sendable, Equatable` + `RawPresetEntry`.
- Update `Services/RawPresetStore.swift`:
  - Drop `load(name:) / save(_:name:) / delete(name:)` named-string API.
  - Add `loadIndex() -> RawPresetIndex`, `saveIndex(_:)`, `load(id: UUID) -> RawPreset?`, `save(_ raw: RawPreset, id: UUID)`, `delete(id: UUID)`.
  - Path scheme: `presets/<uuid>` per entry, `presets_index` for the index. Storage key naming is snake_case per project convention; UUIDs in filenames are fine.
- `RawPresetStoreType` protocol mirrors that surface.

**Test support updates:** regenerate `RawPresetStoreMock` to match the new surface; update `RawPreset+Fake.swift` (no schema change to `RawPreset` itself, but the mock's `presets` dictionary becomes `[UUID: RawPreset]` and gains an `index: RawPresetIndex`).

### Domain (`PresetKit`)

Two value types, both `public`:

```swift
public typealias PresetSlotID = UUID

public struct PresetSlot: Sendable, Equatable, Identifiable {
    public let id: PresetSlotID
    public let name: String
}

public struct Preset: Sendable, Equatable {
    public let id: PresetSlotID
    public let name: String
    public let component: AudioUnitComponent
    public let state: Data
}
```

`PresetSlot` is what the sidebar list binds to (cheap to enumerate). `Preset` is the full thing fetched when a slot is loaded into the engine. Existing `Preset(component:state:)` callers all live in HostVM + tests, so the migration is local.

**`PresetProviderType` surface (replaces today's `loadDefault / saveDefault`):**

```swift
public protocol PresetProviderType: Sendable {
    func slots() async -> [PresetSlot]
    func activeID() async -> PresetSlotID?
    func setActive(_ id: PresetSlotID?) async
    func load(_ id: PresetSlotID) async -> Preset?
    func save(component: AudioUnitComponent, state: Data, into id: PresetSlotID) async
    func create(name: String) async -> PresetSlot          // empty slot, appended, active
    func rename(_ id: PresetSlotID, to name: String) async
    func delete(_ id: PresetSlotID) async
}
```

Save splits component+state instead of taking a full `Preset` because a brand-new slot has no component yet; encoding "save current engine state into slot X" as `(component, state, id)` keeps the API honest about what changes.

The provider also owns the legacy-file migration on first call to any read method (`slots()` / `activeID()` / `load()`). One-shot, guarded by a `migrated: Bool` actor flag.

**File-by-file changes in `PresetKit/Sources/`:**
- `Models/Preset.swift` — add `id` and `name`.
- `Models/PresetSlot.swift` — new.
- `Services/PresetProvider.swift` — rewrite around the new surface; legacy migration step.
- `Sources/Dependencies.swift` — unchanged shape, still wires the live provider.

**Test support:**
- `Preset+Fake.swift` — add `id: PresetSlotID = UUID()`, `name: String = "Test"`.
- `PresetSlot+Fake.swift` — new.
- `PresetProviderMock.swift` — extend `Calls` with the new methods; stub state holds `slots`, `activeID`, and a `[UUID: Preset]` map.

### App layer (`TinyAudioUnitHost`)

#### `HostViewModel`

State additions:
- `presetSlots: [PresetSlot]`
- `activeSlotID: PresetSlotID?`
- `sidebarTab: SidebarTab` (`.audioUnits` or `.presets`, default `.audioUnits`)
- `newPresetDialog: NewPresetDialogState?` (presence drives the sheet)

Action additions (or replacements):
- `case sidebarTabChanged(SidebarTab)`
- `case selectedSlot(PresetSlotID)`
- `case newPresetTapped` / `case newPresetDialogAction(NewPresetDialogAction)`
- `case renameSlot(PresetSlotID, String)` / `case deleteSlot(PresetSlotID)`
- Keep `selected(AudioUnitComponent)`, `saveCurrentPreset`, `restorePreset`, but they now operate via the active slot.

Behavior:
- `task`: load slots + active ID; if an active slot exists, load it into the engine (replaces today's `loadDefault`).
- `selected(component)`: as today, but on success **also** writes back `(component, state)` into the active slot via `save(component:state:into:)` so the slot reflects what's playing (decision 2/A). If no active slot exists, no-op for the persistence side (engine still loads; the user is in "preview" mode).
- `saveCurrentPreset`: writes the engine's current `fullState` back into the active slot (used after parameter tweaks). Disabled when no active slot.
- `restorePreset`: reloads the active slot's stored state into the engine.
- `selectedSlot(id)`: sets active, loads.
- `newPresetTapped`: presents the dialog.
- `newPresetDialogAction(.commit(name))`: `create(name:)` → slot becomes active → clears engine to `.empty`.
- `renameSlot` / `deleteSlot`: route to provider; on delete, if the deleted slot was active, clear engine + active ID.

#### Sidebar layout

`HostView`'s `NavigationSplitView` sidebar becomes:

```
VStack(spacing: 0) {
    Picker("", selection: ...) {
        Text("Audio Units").tag(SidebarTab.audioUnits)
        Text("Presets").tag(SidebarTab.presets)
    }
    .pickerStyle(.segmented)
    .padding(.horizontal).padding(.top, 8)

    switch tab {
    case .audioUnits: AudioUnitsSidebar(state:..., onAction: ...)
    case .presets:    PresetsSidebar(state:..., onAction: ...)
    }
}
```

Each sidebar is a subview following the **Subview communication** pattern (state struct + `onAction: (Action) -> Void`).

- `AudioUnitsSidebar` — wraps today's `List`/`Section`/`ForEach`. State: `groups`, `selectedComponent`, `isReady`, `isLoading`. Actions: `.selected(component)`, `.groupExpansionChanged(...)`. The HostVM wraps these as `.audioUnitsSidebarAction(...)`.
- `PresetsSidebar` — header row with title "Presets" and a trailing `+` button; below it a `List(selection:)` of slot rows. Row context menu: Rename, Delete. State: `slots`, `activeID`. Actions: `.selected(id)`, `.addTapped`, `.rename(id, name)`, `.delete(id)`. Parent wraps as `.presetsSidebarAction(...)`.

Both subviews go under `Features/Host/Subviews/`.

#### "New Preset" dialog

A new subview `NewPresetDialogView` presented as a `.sheet` from the host. Layout per the reference shot:

- Rounded background, ~440pt wide.
- Centered circular icon (`Image(systemName: "rectangle.stack")` on an accent-tinted disc).
- `TextField` with placeholder "Preset Name", large font.
- Cancel / Create buttons at the bottom. Create is disabled when the trimmed name is empty.

State + action (subview pattern, single `onAction`):

```swift
struct NewPresetDialogState: Sendable, Equatable {
    var name: String
    var isSaving: Bool
}

enum NewPresetDialogAction {
    case nameChanged(String)
    case cancel
    case commit
}
```

The text field uses a `Binding` derived from `state.name` + an `.nameChanged` action — this is the binding-shaped exception called out in CLAUDE.md.

The HostVM owns `NewPresetDialogState?` and handles `.newPresetDialogAction(.commit)` by calling the provider, dismissing the sheet, and selecting the new slot.

#### Toolbar

`HostView`'s toolbar already shows "Preset: Default". Replace with the active slot's name (or a placeholder when none). Save/Restore behavior is unchanged from the user's perspective but routes through the active slot.

### Dependency graph

No new modules. No new edges. PresetKit already depends on StorageKit + AudioUnitsKit. App already pulls PresetKit.

## Implementation order

Small, mergeable steps:

1. **StorageKit**: `RawPresetIndex` + `RawPresetEntry`, new `RawPresetStore` API, mock + fakes update, tests.
2. **PresetKit**: extend `Preset` with `id` + `name`, add `PresetSlot`, new `PresetProviderType` surface (incl. legacy migration), mock + fakes update, tests.
3. **HostVM**: extend state/actions to cover slots, active slot, and the new save semantics. Update existing tests; add tests for active-slot wiring, save-back-on-selection, restore, slot CRUD.
4. **HostView sidebar split**: introduce `SidebarTab`, extract `AudioUnitsSidebar` from inline code (state + onAction), add `PresetsSidebar` (state + onAction), drop a segmented `Picker` above them.
5. **New-preset sheet**: `NewPresetDialogView` + state/action wiring through the VM.
6. **Toolbar text** + active-slot binding.
7. **Manual QA**: create / rename / delete / switch slots; verify save and restore route to the active slot; verify migration of an existing `presets/default.json`.

Each step is independently testable; no step needs `mise run generate` (only Sources/ folders change).

## Notes on conventions

- New types in PresetKit are `public`; concrete impls stay `internal` behind their `Type` protocols.
- All sidebar subviews follow the dedicated-action-enum + single `onAction` closure pattern. The HostVM wraps each subview's enum in its own case.
- File-backed storage keys (`presets`, `presets_index`) stay snake_case; UUID filenames need no transformation.
- One init per type; live wiring for the new `PresetProvider` stays in `PresetKit.Dependencies.live` and is consumed via the existing `AppDependencies.presets.presetProvider` path — no convenience inits.
- `Type+Fake.swift` updates ship in the same commit as the type changes.
