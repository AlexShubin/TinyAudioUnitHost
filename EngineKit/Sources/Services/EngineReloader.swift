//
//  EngineReloader.swift
//  EngineKit
//
//  Created by Alex Shubin on 14.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AppKit
import Common
import Foundation

public protocol EngineReloaderType: Sendable {
    @discardableResult
    func start() -> Task<Void, Error>
}

final class EngineReloader: EngineReloaderType {
    private let engine: EngineType
    private let workspaceNotificationCenter: NotificationCenterType

    init(engine: EngineType, workspaceNotificationCenter: NotificationCenterType) {
        self.engine = engine
        self.workspaceNotificationCenter = workspaceNotificationCenter
    }

    @discardableResult
    func start() -> Task<Void, Error> {
        let stream = workspaceNotificationCenter.stream(for: NSWorkspace.didWakeNotification)
        return Task { [self] in
            for await _ in stream {
                try? await engine.reload()
            }
        }
    }
}
