//
//  EngineReloader.swift
//  EngineKit
//
//  Created by Alex Shubin on 14.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AVFoundation
import Foundation

public protocol EngineReloaderType: Sendable {
    @discardableResult
    func startListening() -> Task<Void, Error>
}

final class EngineReloader: EngineReloaderType {
    private let engine: EngineType
    private let notificationCenter: NotificationCenterType

    init(engine: EngineType, notificationCenter: NotificationCenterType) {
        self.engine = engine
        self.notificationCenter = notificationCenter
    }

    private func handleConfigurationChange() async {
        try? await engine.reload()
    }

    @discardableResult
    func startListening() -> Task<Void, Error> {
        let stream = notificationCenter.stream(for: .AVAudioEngineConfigurationChange)
        return Task { [self] in
            for await _ in stream {
                await handleConfigurationChange()
            }
        }
    }
}
