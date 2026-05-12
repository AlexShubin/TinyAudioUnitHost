//
//  SetupChecker.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 09.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import AVFoundation
import Foundation

enum SetupRequirement: Sendable, Equatable, Hashable {
    case microphonePermission
    case outputDevice
}

protocol SetupCheckerType: Sendable {
    var unmetStream: AsyncStream<Set<SetupRequirement>> { get }
    func refresh() async
}

final actor SetupChecker: SetupCheckerType {
    nonisolated let unmetStream: AsyncStream<Set<SetupRequirement>>
    private let continuation: AsyncStream<Set<SetupRequirement>>.Continuation

    private let targetSettingsProvider: TargetSettingsProviderType
    private let captureDevice: AVCaptureDeviceGatewayType
    private var unmet: Set<SetupRequirement>?

    init(
        targetSettingsProvider: TargetSettingsProviderType,
        captureDevice: AVCaptureDeviceGatewayType = AVCaptureDeviceGateway()
    ) {
        self.targetSettingsProvider = targetSettingsProvider
        self.captureDevice = captureDevice
        let (stream, continuation) = AsyncStream<Set<SetupRequirement>>.makeStream()
        self.unmetStream = stream
        self.continuation = continuation
    }

    deinit {
        continuation.finish()
    }

    func refresh() async {
        if captureDevice.authorizationStatus(for: .audio) == .notDetermined {
            _ = await captureDevice.requestAccess(for: .audio)
        }
        var next: Set<SetupRequirement> = []
        if captureDevice.authorizationStatus(for: .audio) != .authorized {
            next.insert(.microphonePermission)
        }
        if await targetSettingsProvider.resolveTarget() == nil {
            next.insert(.outputDevice)
        }
        if let unmet, unmet == next { return }
        unmet = next
        continuation.yield(next)
    }
}
