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

Thin wrapper over the CoreAudio HAL aggregate APIs.

```swift
import CoreAudio

enum AggregateDeviceFactory {
    static func create(
        inputDeviceID: AudioDeviceID,
        outputDeviceID: AudioDeviceID
    ) -> AudioDeviceID? {
        guard let inputUID = deviceUID(for: inputDeviceID),
              let outputUID = deviceUID(for: outputDeviceID)
        else { return nil }

        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey as String: "TinyAudioUnitHost Aggregate",
            kAudioAggregateDeviceUIDKey as String: "com.alexshubin.TinyAudioUnitHost.aggregate",
            kAudioAggregateDeviceIsPrivateKey as String: 1,
            kAudioAggregateDeviceIsStackedKey as String: 0,
            kAudioAggregateDeviceMasterSubDeviceKey as String: outputUID,
            kAudioAggregateDeviceSubDeviceListKey as String: [
                [kAudioSubDeviceUIDKey as String: inputUID],
                [kAudioSubDeviceUIDKey as String: outputUID],
            ],
        ]

        var aggregateID: AudioDeviceID = 0
        let status = AudioHardwareCreateAggregateDevice(description as CFDictionary, &aggregateID)
        return status == noErr ? aggregateID : nil
    }

    static func destroy(_ deviceID: AudioDeviceID) {
        AudioHardwareDestroyAggregateDevice(deviceID)
    }

    private static func deviceUID(for deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid: CFString?
        var size = UInt32(MemoryLayout<CFString?>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &uid)
        return status == noErr ? (uid as String?) : nil
    }
}
```

### 2. `AudioUnitEngine.swift` — replace the two setters

Replace `setInputDevice` / `setOutputDevice` with a single `bindDevices` that:

- If input == output, binds that single device directly.
- If one is nil, binds the non-nil one directly.
- Otherwise creates (or reuses) an aggregate and binds that.
- Destroys any previously created aggregate so we don't leak private devices.

```swift
// protocol:
func bindDevices(input: AudioDevice?, output: AudioDevice?)

// actor state:
private var currentAggregateID: AudioDeviceID?

func bindDevices(input: AudioDevice?, output: AudioDevice?) {
    if let previous = currentAggregateID {
        AggregateDeviceFactory.destroy(previous)
        currentAggregateID = nil
    }

    let targetID: AudioDeviceID?
    switch (input, output) {
    case (let dev?, nil), (nil, let dev?):
        targetID = dev.id
    case let (dev1?, dev2?) where dev1.id == dev2.id:
        targetID = dev1.id
    case let (inDev?, outDev?):
        let aggID = AggregateDeviceFactory.create(
            inputDeviceID: inDev.id,
            outputDeviceID: outDev.id
        )
        currentAggregateID = aggID
        targetID = aggID
    case (nil, nil):
        targetID = nil
    }

    guard let targetID, let audioUnit = engine.outputNode.audioUnit else { return }
    setCurrentDevice(targetID, on: audioUnit)
}
```

### 3. `AudioUnitEngineManager.applyConnections` — collapse to one call

```swift
await engine.bindDevices(
    input: settings.input.device,
    output: settings.output.device
)
// ...then connectInputs / connectOutputs as before
```

## Rough spots

- **Channel indices shift inside the aggregate.** Sub-devices concatenate; the
  aggregate's input scope lists all input channels across sub-devices in list
  order, same for output. The current `AudioChannel.id` is the 1-indexed channel
  number inside the original device. If the input device is listed first, its
  input channels stay at indices 1..N. If the output device also has inputs
  (Apollo does), those tack on after. `setInputChannelMap` will need to bias
  by that offset, or we restrict the input picker to channels belonging to the
  selected input device only.
- **Clock master matters.** Whichever sub-device is named master drives the
  clock; the other is resampled. Output device as master is usually right for
  monitoring.
- **Cleanup on quit.** Private aggregate devices persist until destroyed or
  until reboot. Destroying on every `reconnect()` covers the normal flow, but a
  crash mid-session orphans the aggregate. Not fatal (private + reboot clears)
  but an app-termination handler would be cleaner.
- **Sample rate mismatch.** If input and output devices run at different rates,
  CoreAudio will resample. Works, costs a little latency.
- **Rebuild on every device change.** Destroy + create each reconnect. Fine for
  user-initiated switches — do not call `reconnect()` on unrelated events.
