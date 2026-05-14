//
//  EngineReloader.swift
//  EngineKit
//
//  Created by Alex Shubin on 14.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AppKit
import AVFoundation
import Common
import Foundation

public enum ReloadTrigger: Sendable {
    case audioEngineConfigurationChange
    case workspaceDidWake
}

public protocol EngineReloaderType: Sendable {
    @discardableResult
    func startListening(to trigger: ReloadTrigger) -> Task<Void, Error>
}

final class EngineReloader: EngineReloaderType {
    private let engine: EngineType
    private let notificationCenter: NotificationCenterType
    private let workspaceNotificationCenter: NotificationCenterType

    init(
        engine: EngineType,
        notificationCenter: NotificationCenterType,
        workspaceNotificationCenter: NotificationCenterType
    ) {
        self.engine = engine
        self.notificationCenter = notificationCenter
        self.workspaceNotificationCenter = workspaceNotificationCenter
    }

    private func reloadEngine() async {
        try? await engine.reload()
    }

    @discardableResult
    func startListening(to trigger: ReloadTrigger) -> Task<Void, Error> {
        let stream: AsyncStream<Void>
        switch trigger {
        case .audioEngineConfigurationChange:
            stream = notificationCenter.stream(for: .AVAudioEngineConfigurationChange)
        case .workspaceDidWake:
            stream = workspaceNotificationCenter.stream(for: NSWorkspace.didWakeNotification)
        }
        return Task { [self] in
            for await _ in stream {
                await reloadEngine()
            }
        }
    }
}
