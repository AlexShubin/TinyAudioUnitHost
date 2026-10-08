//
//  AudioSettingsModel.swift
//  AudioSettingsKit
//
//  Created by Alex Shubin on 08.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Common
import Observation
import StorageKit

@MainActor
public protocol AudioSettingsModelType: AnyObject, Observable, Sendable {
    var settings: AudioSettings { get }
    var targetDevice: AudioDevice? { get }
    var inputDevices: [AudioDevice] { get }
    var outputDevices: [AudioDevice] { get }
    var midiDevices: [MidiDevice] { get }
    var delegate: AudioSettingsModelDelegate? { get set }
    func load() async
    func save(_ settings: AudioSettings) async
}

@MainActor
public protocol AudioSettingsModelDelegate: AnyObject {
    func audioSettingsDidChange() async
}

@MainActor @Observable
final class AudioSettingsModel: AudioSettingsModelType {
    private(set) var settings: AudioSettings = .empty
    private(set) var targetDevice: AudioDevice?
    private(set) var inputDevices: [AudioDevice] = []
    private(set) var outputDevices: [AudioDevice] = []
    private(set) var midiDevices: [MidiDevice] = []

    @ObservationIgnored weak var delegate: AudioSettingsModelDelegate?

    @ObservationIgnored private let rawStore: RawSettingsStoreType
    @ObservationIgnored private let devicesProvider: AudioDevicesProviderType
    @ObservationIgnored private let midiDevicesProvider: MidiDevicesProviderType
    @ObservationIgnored private let targetResolver: TargetDeviceResolverType
    @ObservationIgnored private var deviceListObservation: Cancellation?
    @ObservationIgnored private var midiSetupObservation: Cancellation?
    @ObservationIgnored private var devices: [AudioDevice] = []

    init(
        rawStore: RawSettingsStoreType,
        devicesProvider: AudioDevicesProviderType,
        midiDevicesProvider: MidiDevicesProviderType,
        targetResolver: TargetDeviceResolverType,
        deviceListChangeListener: DeviceListChangeListenerType,
        midiSetupChangeListener: MidiSetupChangeListenerType
    ) {
        self.rawStore = rawStore
        self.devicesProvider = devicesProvider
        self.midiDevicesProvider = midiDevicesProvider
        self.targetResolver = targetResolver
        deviceListObservation = deviceListChangeListener.observeChanges { [weak self] in
            await self?.load()
        }
        // Must be the process's first CoreMIDI call, made on the main run loop,
        // otherwise the process would never receive another MIDI notification.
        midiSetupObservation = midiSetupChangeListener.observeChanges { [weak self] in
            await self?.refreshMidiDevices()
        }
    }

    func load() async {
        devices = await devicesProvider.scanDevices()
        inputDevices = devices.filter { !$0.inputChannels.isEmpty && !$0.isHiddenFromPicker }
        outputDevices = devices.filter { !$0.outputChannels.isEmpty && !$0.isHiddenFromPicker }
        await apply(rawStore.current)
    }

    func save(_ settings: AudioSettings) async {
        let raw = RawAudioSettings(settings)
        rawStore.save(raw)
        await apply(raw)
    }

    private func refreshMidiDevices() async {
        await apply(rawStore.current)
    }

    private func apply(_ raw: RawAudioSettings) async {
        let previous = (settings, targetDevice)
        midiDevices = midiDevicesProvider.devices
        let loaded = AudioSettings(raw: raw, devices: devices, midiDevices: midiDevices)
        let device = targetResolver.resolve(loaded)
        settings = loaded.defaulting(to: device)
        targetDevice = device
        guard previous != (settings, targetDevice) else { return }
        await delegate?.audioSettingsDidChange()
    }
}

private extension AudioSettings {
    init(raw: RawAudioSettings, devices: [AudioDevice], midiDevices: [MidiDevice]) {
        let inputDevice = raw.input.flatMap { saved in devices.first { $0.uid == saved.uid } }
        let outputDevice = raw.output.flatMap { saved in devices.first { $0.uid == saved.uid } }
        let selectedMidiUIDs = Set(raw.selectedMidiUIDs)
        self.init(
            inputDevice: inputDevice,
            outputDevice: outputDevice,
            inputChannel: SelectedChannel(
                ids: raw.input?.selectedChannels ?? [],
                in: inputDevice?.inputChannels ?? []
            ),
            outputChannel: SelectedChannel(
                ids: raw.output?.selectedChannels ?? [],
                in: outputDevice?.outputChannels ?? []
            ),
            bufferSize: raw.bufferSize,
            sampleRate: raw.sampleRate,
            savedInput: raw.input?.saved,
            savedOutput: raw.output?.saved,
            selectedMidiDevices: Set(midiDevices.filter { selectedMidiUIDs.contains($0.uid) })
        )
    }

    func defaulting(to device: AudioDevice?) -> AudioSettings {
        guard let device else { return self }
        return AudioSettings(
            inputDevice: inputDevice,
            outputDevice: outputDevice,
            inputChannel: inputChannel,
            outputChannel: outputChannel,
            bufferSize: device.availableBufferSizes.resolving(bufferSize, preferring: 32),
            sampleRate: device.availableSampleRates.resolving(sampleRate, preferring: 48_000),
            savedInput: savedInput,
            savedOutput: savedOutput,
            selectedMidiDevices: selectedMidiDevices
        )
    }
}

private extension Array where Element: Equatable {
    func resolving(_ current: Element?, preferring preferred: Element) -> Element? {
        guard !isEmpty else { return nil }
        if let current, contains(current) { return current }
        return contains(preferred) ? preferred : first
    }
}

private extension RawAudioSettings {
    init(_ settings: AudioSettings) {
        let inputChannelIDs = settings.inputChannel?.channels.map(\.id) ?? []
        let outputChannelIDs = settings.outputChannel?.channels.map(\.id) ?? []
        self.init(
            input: settings.inputDevice.map { device in
                RawDeviceSettings(uid: device.uid, name: device.name, selectedChannels: inputChannelIDs)
            },
            output: settings.outputDevice.map { device in
                RawDeviceSettings(uid: device.uid, name: device.name, selectedChannels: outputChannelIDs)
            },
            bufferSize: settings.bufferSize,
            sampleRate: settings.sampleRate,
            selectedMidiUIDs: settings.selectedMidiDevices.map(\.uid).sorted()
        )
    }
}

private extension RawDeviceSettings {
    var saved: SavedDevice {
        SavedDevice(uid: uid, name: name, selectedChannelCount: selectedChannels.count)
    }
}

private extension AudioDevice {
    var isHiddenFromPicker: Bool {
        uid.hasPrefix("CADefaultDeviceAggregate-") ||
            uid.hasPrefix(AggregateDeviceFactory.uidPrefix)
    }
}

private extension SelectedChannel {
    init?(ids: [UInt32], in channels: [AudioChannel]) {
        let resolved = ids.compactMap { id in channels.first { $0.id == id } }
        self.init(from: resolved)
    }
}
