//
//  SetupChecker.swift
//  AudioSettingsKit
//
//  Created by Alex Shubin on 09.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AVFoundation
import Foundation

public enum SetupRequirement: Sendable, Equatable, Hashable {
    case microphonePermission
    case noOutputDevice
    case savedOutputDeviceUnavailable(name: String)
}

public protocol SetupCheckerType: Sendable {
    var unmetStream: AsyncStream<Set<SetupRequirement>> { get }
    func refresh() async
}

public final actor SetupChecker: SetupCheckerType {
    public nonisolated let unmetStream: AsyncStream<Set<SetupRequirement>>
    private let continuation: AsyncStream<Set<SetupRequirement>>.Continuation

    private let audioSettings: AudioSettingsProviderType
    private let captureDevice: AVCaptureDeviceGatewayType
    private var unmet: Set<SetupRequirement>?

    public init(
        audioSettings: AudioSettingsProviderType,
        captureDevice: AVCaptureDeviceGatewayType = AVCaptureDeviceGateway()
    ) {
        self.audioSettings = audioSettings
        self.captureDevice = captureDevice
        let (stream, continuation) = AsyncStream<Set<SetupRequirement>>.makeStream()
        self.unmetStream = stream
        self.continuation = continuation
    }

    deinit {
        continuation.finish()
    }

    public func refresh() async {
        if captureDevice.authorizationStatus(for: .audio) == .notDetermined {
            _ = await captureDevice.requestAccess(for: .audio)
        }
        var next: Set<SetupRequirement> = []
        if captureDevice.authorizationStatus(for: .audio) != .authorized {
            next.insert(.microphonePermission)
        }
        let settings = await audioSettings.current()
        if settings.outputChannel == nil {
            // Treat "saved without channels" the same as "never configured" —
            // the user still needs to finish picking, not turn on a device.
            if let saved = settings.savedOutput, saved.selectedChannelCount > 0 {
                next.insert(.savedOutputDeviceUnavailable(name: saved.name))
            } else {
                next.insert(.noOutputDevice)
            }
        }
        if let unmet, unmet == next { return }
        unmet = next
        continuation.yield(next)
    }
}
