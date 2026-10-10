//
//  SystemWakeObserver.swift
//  EngineKit
//
//  Created by Alex Shubin on 14.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AppKit
import Common

@MainActor
public protocol SystemWakeObserverType: Sendable {
    func start()
}

@MainActor
final class SystemWakeObserver: SystemWakeObserverType {
    private let engine: EngineType
    private let workspaceNotificationCenter: NotificationCenterType
    private var observation: Cancellation?

    init(engine: EngineType, workspaceNotificationCenter: NotificationCenterType) {
        self.engine = engine
        self.workspaceNotificationCenter = workspaceNotificationCenter
    }

    func start() {
        guard observation == nil else { return }
        observation = workspaceNotificationCenter.observe(NSWorkspace.didWakeNotification) { [engine] in
            try? await engine.reload()
        }
    }
}
