//
//  EngineReloader.swift
//  EngineKit
//
//  Created by Alex Shubin on 14.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AppKit
import AVFoundation
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

    init(engine: EngineType, notificationCenter: NotificationCenterType) {
        self.engine = engine
        self.notificationCenter = notificationCenter
    }

    private func reloadEngine() async {
        try? await engine.reload()
    }

    @discardableResult
    func startListening(to trigger: ReloadTrigger) -> Task<Void, Error> {
        let stream = notificationCenter.stream(for: trigger.notificationName)
        return Task { [self] in
            for await _ in stream {
                await reloadEngine()
            }
        }
    }
}

private extension ReloadTrigger {
    var notificationName: Notification.Name {
        switch self {
        case .audioEngineConfigurationChange: .AVAudioEngineConfigurationChange
        case .workspaceDidWake: NSWorkspace.didWakeNotification
        }
    }
}
