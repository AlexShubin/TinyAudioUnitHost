//
//  SetupRefresher.swift
//  AudioSettingsKit
//
//  Created by Alex Shubin on 14.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AppKit
import Common
import Foundation

public protocol SetupRefresherType: Sendable {
    @discardableResult
    func startListening() -> Task<Void, Error>
}

final class SetupRefresher: SetupRefresherType {
    private let setupChecker: SetupCheckerType
    private let notificationCenter: NotificationCenterType

    init(setupChecker: SetupCheckerType, notificationCenter: NotificationCenterType) {
        self.setupChecker = setupChecker
        self.notificationCenter = notificationCenter
    }

    @discardableResult
    func startListening() -> Task<Void, Error> {
        let stream = notificationCenter.stream(for: NSApplication.didBecomeActiveNotification)
        return Task { [self] in
            for await _ in stream {
                await setupChecker.refresh()
            }
        }
    }
}
