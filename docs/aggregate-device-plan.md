# Aggregate Device Plan

## Background

`AVAudioEngine` on macOS uses a single shared AUHAL unit for both input and
output (confirmed: `engine.inputNode.audioUnit == engine.outputNode.audioUnit`).
That unit can only be bound to one device at a time via
`kAudioOutputUnitProperty_CurrentDevice`, and because it has both input and
output enabled, the chosen device must provide both input and output streams.

This is why setting a full-duplex device (e.g. UAD Apollo) works, while setting
an input-only device (e.g. MacBook mic) fails with
`kAudioUnitErr_InvalidPropertyValue` (-10851).

## Chosen approach

Create a **private aggregate device** on the fly that combines the user's
selected input and output devices, then bind the single shared HAL to that
aggregate. This preserves the existing single-`AVAudioEngine` architecture and
keeps the independent input/output pickers in the UI.

## Sketch

### 1. New file: `Sources/Engine/AggregateDeviceFactory.swift`

Stateless struct with instance methods — protocol + DI wiring gets figured out
in code.

```swift
import CoreAudio

struct AggregateDeviceFactory {
    static let uidPrefix = "com.alexshubin.TinyAudioUnitHost.aggregate."

    func create(inputDeviceID: AudioDeviceID, outputDeviceID: AudioDeviceID) -> AudioDeviceID? {
        guard let inputUID = Self.deviceUID(for: inputDeviceID),
              let outputUID = Self.deviceUID(for: outputDeviceID)
        else { return nil }

        // Defensive: caller collapses same-device to a direct bind, but guard
        // here too so the sub-device list can't ever contain duplicates.
        var subDevices: [[String: Any]] = [[kAudioSubDeviceUIDKey as String: outputUID]]
        if inputUID != outputUID {
            subDevices.insert([kAudioSubDeviceUIDKey as String: inputUID], at: 0)
        }

        // Per-create unique UID: destroy is asynchronous, so reusing a fixed
        // UID across rapid reconnect cycles can race. The prefix lets startup
        // cleanup find orphaned aggregates by enumeration.
        let uid = Self.uidPrefix + UUID().uuidString

        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey as String: "TinyAudioUnitHost Aggregate",
            kAudioAggregateDeviceUIDKey as String: uid,
            kAudioAggregateDeviceIsPrivateKey as String: 1,
            kAudioAggregateDeviceIsStackedKey as String: 0,
            kAudioAggregateDeviceMainSubDeviceKey as String: outputUID,
            kAudioAggregateDeviceSubDeviceListKey as String: subDevices,
        ]

        var aggregateID: AudioDeviceID = 0
        let status = AudioHardwareCreateAggregateDevice(description as CFDictionary, &aggregateID)
        return status == noErr ? aggregateID : nil
    }

    func destroy(_ deviceID: AudioDeviceID) {
        AudioHardwareDestroyAggregateDevice(deviceID)
    }

    // Enumerate devices; destroy any whose UID starts with our prefix. Call
    // once at app startup to reap aggregates orphaned by a prior crash.
    func destroyOrphans() {
        for deviceID in Self.allDeviceIDs() {
            guard let uid = Self.deviceUID(for: deviceID),
                  uid.hasPrefix(Self.uidPrefix)
            else { continue }
            AudioHardwareDestroyAggregateDevice(deviceID)
        }
    }

    private static func deviceUID(for deviceID: AudioDeviceID) -> String? { /* as before */ }
    private static func allDeviceIDs() -> [AudioDeviceID] { /* kAudioHardwarePropertyDevices */ }
}
```

### 2. `AudioUnitEngine.swift` — single `bindDevice`

Replace `setInputDevice` / `setOutputDevice` with one entry point. The engine
knows nothing about aggregates — it just binds whatever device ID the manager
hands it.

```swift
// protocol:
func bindDevice(_ deviceID: AudioDeviceID?)

// actor:
func bindDevice(_ deviceID: AudioDeviceID?) {
    guard let deviceID, let audioUnit = engine.outputNode.audioUnit else { return }
    setCurrentDevice(deviceID, on: audioUnit)
}
```

### 3. `AudioUnitEngineManager` — dispatch + aggregate lifecycle

Manager owns the dispatch and the `currentAggregateID` bookkeeping. The
`bindingIntent` switch is a pure static function so it can be tested directly
without touching the factory or engine. DI shape (protocol, init param,
actor-vs-class) gets decided in code.

```swift
enum DeviceBindingIntent: Equatable, Sendable {
    case none
    case direct(AudioDeviceID)
    case aggregate(input: AudioDeviceID, output: AudioDeviceID)
}

// Pure — no state, no I/O. Test this directly.
static func bindingIntent(input: AudioDevice?, output: AudioDevice?) -> DeviceBindingIntent {
    switch (input, output) {
    case (nil, nil):
        return .none
    case let (dev?, nil), let (nil, dev?):
        return .direct(dev.id)
    case let (inDev?, outDev?) where inDev.id == outDev.id:
        return .direct(inDev.id)
    case let (inDev?, outDev?):
        return .aggregate(input: inDev.id, output: outDev.id)
    }
}

private func applyConnections() async {
    let settings = await settingsStore.current()

    if let previous = currentAggregateID {
        aggregateFactory.destroy(previous)
        currentAggregateID = nil
    }

    let targetID: AudioDeviceID?
    switch Self.bindingIntent(input: settings.input.device, output: settings.output.device) {
    case .none:
        targetID = nil
    case .direct(let id):
        targetID = id
    case .aggregate(let inputID, let outputID):
        let id = aggregateFactory.create(inputDeviceID: inputID, outputDeviceID: outputID)
        currentAggregateID = id
        targetID = id
    }

    await engine.bindDevice(targetID)

    if let input = settings.input.selectedChannel {
        await engine.connectInputs(channels: input)
    }
    if let output = settings.output.selectedChannel {
        await engine.connectOutputs(channels: output)
    }
}
```

Call `aggregateFactory.destroyOrphans()` once at app launch, before the first
`applyConnections()`.

## Rough spots

- **Channel indices shift inside the aggregate.** Sub-devices concatenate; the
  aggregate's input scope lists all input channels across sub-devices in list
  order, same for output. The current `AudioChannel.id` is the 1-indexed channel
  number inside the original device. If the input device is listed first, its
  input channels stay at indices 1..N. If the output device also has inputs
  (Apollo does), those tack on after. Use `kAudioOutputUnitProperty_ChannelMap`
  on the shared AUHAL to remap the aggregate's flattened channel space back to
  the engine's 1..N view — input scope on element 1 (map size = desired capture
  channels, values = hardware indices to pull from), output scope on element 0
  (map size = total aggregate output channels, `-1` for silence elsewhere).
  This keeps `setInputChannelMap` / output wiring oblivious to the sub-device
  offset. Same pattern Apple documents for iOS multiroute sessions — applies
  here because the aggregate is our equivalent of a flattened route.
- **Clock master matters.** Whichever sub-device is named master drives the
  clock; the other is resampled. Output device as master is usually right for
  monitoring.
- **Cleanup on quit.** Private aggregate devices persist until destroyed or
  until reboot. Destroying on every `reconnect()` covers the normal flow, but a
  crash mid-session orphans the aggregate. Mitigation: on app startup,
  enumerate devices (`kAudioHardwarePropertyDevices`) and destroy any whose
  UID starts with `AggregateDeviceFactory.uidPrefix`. Runs once, closes the
  crash-leak without needing a termination handler. An app-termination handler
  on top is optional polish.
- **`AudioHardwareDestroyAggregateDevice` is asynchronous.** Destruction may
  complete after the call returns. If `create` reused a fixed UID, a
  destroy→create round-trip during `reconnect()` could collide with the
  still-draining prior device. The unique-per-create UID (`uidPrefix + UUID`)
  sidesteps this entirely — no polling or delay needed.
- **Sample rate mismatch.** If input and output devices run at different rates,
  CoreAudio will resample. Works, costs a little latency.
- **Rebuild on every device change.** Destroy + create each reconnect. Fine for
  user-initiated switches — do not call `reconnect()` on unrelated events.
