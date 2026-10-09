//
//  Dependencies.swift
//  AudioSettingsKit
//
//  Created by Alex Shubin on 02.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import CoreMidiGatewayKit
import Foundation
import StorageKit

@MainActor
public struct Dependencies: Sendable {
    public let audioSettingsModel: AudioSettingsModelType
    public let devicesProvider: AudioDevicesProviderType
    public let midiDevicesProvider: MidiDevicesProviderType
    public let setupChecker: SetupCheckerType

    public static let live: Dependencies = {
        let coreAudioGateway = CoreAudioGateway()
        let devicesProvider = AudioDevicesProvider(gateway: coreAudioGateway)
        let coreMidiGateway = CoreMidiGatewayKit.Dependencies.live.coreMidiGateway
        let midiDevicesProvider = MidiDevicesProvider(gateway: coreMidiGateway)
        let audioSettingsModel = AudioSettingsModel(
            rawStore: StorageKit.Dependencies.live.rawSettingsStore,
            devicesProvider: devicesProvider,
            midiDevicesProvider: midiDevicesProvider,
            targetResolver: TargetDeviceResolver(
                devicesProvider: devicesProvider,
                factory: AggregateDeviceFactory(gateway: coreAudioGateway)
            ),
            deviceListChangeListener: DeviceListChangeListener(),
            midiSetupChangeListener: MidiSetupChangeListener(gateway: coreMidiGateway)
        )
        return Dependencies(
            audioSettingsModel: audioSettingsModel,
            devicesProvider: devicesProvider,
            midiDevicesProvider: midiDevicesProvider,
            setupChecker: SetupChecker(audioSettings: audioSettingsModel, captureDevice: AVCaptureDeviceGateway())
        )
    }()
}
