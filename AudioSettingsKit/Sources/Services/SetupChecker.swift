//
//  SetupChecker.swift
//  AudioSettingsKit
//
//  Created by Alex Shubin on 09.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AVFoundation
import Foundation

protocol SetupCheckerType: Sendable {
    func check(_ settings: AudioSettings) async -> Set<SetupRequirement>
}

struct SetupChecker: SetupCheckerType {
    private let captureDevice: AVCaptureDeviceGatewayType

    init(captureDevice: AVCaptureDeviceGatewayType) {
        self.captureDevice = captureDevice
    }

    func check(_ settings: AudioSettings) async -> Set<SetupRequirement> {
        if captureDevice.authorizationStatus(for: .audio) == .notDetermined {
            _ = await captureDevice.requestAccess(for: .audio)
        }
        var unmet: Set<SetupRequirement> = []
        if captureDevice.authorizationStatus(for: .audio) != .authorized {
            unmet.insert(.microphonePermission)
        }
        if settings.outputChannel == nil {
            // Treat "saved without channels" the same as "never configured" —
            // the user still needs to finish picking, not turn on a device.
            if let saved = settings.savedOutput, saved.selectedChannelCount > 0 {
                unmet.insert(.savedOutputDeviceUnavailable(name: saved.name))
            } else {
                unmet.insert(.noOutputDevice)
            }
        }
        return unmet
    }
}
