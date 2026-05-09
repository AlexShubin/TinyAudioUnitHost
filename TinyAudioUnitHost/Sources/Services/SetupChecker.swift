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
    private let isMicrophoneAuthorized: @Sendable () -> Bool
    private let ensureMicrophoneDecision: @Sendable () async -> Void
    private var unmet: Set<SetupRequirement>?

    init(
        targetSettingsProvider: TargetSettingsProviderType,
        isMicrophoneAuthorized: @escaping @Sendable () -> Bool = {
            AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        },
        ensureMicrophoneDecision: @escaping @Sendable () async -> Void = {
            if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
                _ = await AVCaptureDevice.requestAccess(for: .audio)
            }
        }
    ) {
        self.targetSettingsProvider = targetSettingsProvider
        self.isMicrophoneAuthorized = isMicrophoneAuthorized
        self.ensureMicrophoneDecision = ensureMicrophoneDecision
        let (stream, continuation) = AsyncStream<Set<SetupRequirement>>.makeStream()
        self.unmetStream = stream
        self.continuation = continuation
        Task { await self.refresh() }
    }

    deinit {
        continuation.finish()
    }

    func refresh() async {
        await ensureMicrophoneDecision()
        var next: Set<SetupRequirement> = []
        if !isMicrophoneAuthorized() {
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
