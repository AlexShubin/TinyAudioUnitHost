//
//  AudioDeviceConfigurator.swift
//  AudioSettingsKit
//
//  Created by Alex Shubin on 09.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import CoreAudioGatewayKit
import Foundation
import OSLog

protocol AudioDeviceConfiguratorType: Sendable {
    func apply(_ settings: AudioSettings, to device: AudioDevice)
}

struct AudioDeviceConfigurator: AudioDeviceConfiguratorType {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "AudioDeviceConfigurator")
    private let gateway: CoreAudioGatewayType

    init(gateway: CoreAudioGatewayType) {
        self.gateway = gateway
    }

    func apply(_ settings: AudioSettings, to device: AudioDevice) {
        if let rate = settings.sampleRate {
            logging { try gateway.setSampleRate(rate, deviceID: device.id) }
        }
        if let frames = settings.bufferSize {
            logging { try gateway.setBufferSize(frames, deviceID: device.id) }
        }
    }

    private func logging(_ work: () throws -> Void) {
        do {
            try work()
        } catch {
            logger.warning("\(String(describing: error), privacy: .public)")
        }
    }
}
