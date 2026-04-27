# Buffer Size Setting — Branch Notes

Working branch: `feature/buffer-size-setting`.

## Done

1. **`AudioDevice.availableBufferSizes`** — every `AudioDevice` carries a pre-filtered list of supported buffer sizes. Provider intersects `[16, 32, 64, 128, 256, 512, 1024, 2048]` with each device's `kAudioDevicePropertyBufferFrameSizeRange`.
2. **`TargetAudioDevice`** (`EngineKit/Sources/Models/`) — value type bundling the resolved `AudioDevice` (single device or aggregate) with its `inputOffset` / `outputOffset`. The aggregate's `availableBufferSizes` reflects what the aggregate itself supports (queried after creation via `AudioDevicesProvider.device(id:)`).
3. **Pull-based orchestration.** Services read state from the settings store; VMs only persist + nudge.
   - `AggregateDeviceManagerType.resolveTarget() async -> TargetAudioDevice?` — parameterless. Reads `AudioSettingsStoreType` internally and caches by input/output device IDs so calling it multiple times for unchanged settings does not recreate the aggregate.
   - `AudioUnitEngineManagerType.reload()` and `load(component:)` — both read `AudioSettingsStoreType` for channels and call `aggregateDeviceManager.resolveTarget()` for the device. No engine-side params for target/input/output.
4. **VMs are thin.**
   - `DevicePickerViewModel` writes to `AudioSettingsStore`, then fires `onChange`.
   - `SettingsViewModel.applyToEngine()` is now: `await engine.reload(); target = await aggregateDeviceManager.resolveTarget()`. It still exposes observable `target: TargetAudioDevice?` for the buffer-size picker.
   - `HostViewModel` no longer holds `settingsStore` or `aggregateDeviceManager`. `.selected` just calls `engine.load(component:)`.

## Left to do

### A. UI — buffer-size picker

- New `BufferSizePickerView` + `BufferSizePickerViewModel` under `TinyAudioUnitHost/Sources/Features/Settings/Subviews/`.
- VM observes `SettingsViewModel.target` (already wired). `availableSizes = target?.device.availableBufferSizes ?? []`. Picker disabled when target is nil.
- Add `bufferSize: UInt32?` to `AudioSettings` in `Common/Sources/AudioSettings.swift`. Persist via `AudioSettingsStore.update`.
- Slot the picker into `SettingsView` as a third `Form` pane below the two device pickers (matches the existing `formStyle(.grouped)` pattern).
- VM action: `selectSize(UInt32)` → persist to store → ask SettingsVM to re-apply (same `onChange` callback pattern as `DevicePickerViewModel`, or a direct method on SettingsVM).

### B. Wire to engine

- `AudioUnitEngineManager.applyConnections()` already reads settings — extend it to also read `settings.bufferSize` and pass it to the engine layer. No public-API signature change needed (still just `reload()` / `load(component:)`).
- In `AudioUnitEngine`, after `bindDevice`, set `kAudioDevicePropertyBufferFrameSize` on the resolved target's HAL device. Order matters: bind → set buffer size → connect formats.

## Open questions to resolve in step A

1. **Default when nothing stored.** Pin a default (e.g. 256), or read the device's current buffer size on first encounter? Picking 256 is simpler and matches common DAW defaults.
2. **Stale selection on device switch.** If the user switches to a device that doesn't support the previously stored size, do we clamp to the closest supported, drop to nil, or pick a new default? Probably clamp.
3. **Selected size persisted globally vs per-device.** Right now the design assumes one global `bufferSize` on `AudioSettings`. Per-device remembering is more complex; skip unless needed.

## Files most likely to touch

- `Common/Sources/AudioSettings.swift` — add `bufferSize: UInt32?`.
- `TinyAudioUnitHost/Sources/Features/Settings/SettingsView.swift` — slot in the new picker view.
- `TinyAudioUnitHost/Sources/Features/Settings/SettingsViewModel.swift` — own the buffer picker VM, pass bufferSize into `applyToEngine`.
- `TinyAudioUnitHost/Sources/Features/Settings/Subviews/BufferSizePickerView.swift` (new).
- `TinyAudioUnitHost/Sources/Features/Settings/Subviews/BufferSizePickerViewModel.swift` (new).
- `EngineKit/Sources/AudioUnitEngine/AudioUnitEngineManager.swift` — read `bufferSize` from store inside `applyConnections()` and forward to engine.
- `EngineKit/Sources/AudioUnitEngine/AudioUnitEngine.swift` — set the HAL property.
- `TinyAudioUnitHost/Sources/Dependencies.swift` — wire any new deps.
