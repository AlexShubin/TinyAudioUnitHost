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
    func startListening() -> [Task<Void, Error>]
}

final class SetupRefresher: SetupRefresherType {
    private let setupChecker: SetupCheckerType
    private let notificationCenter: NotificationCenterType
    private let deviceListListener: DeviceListChangeListenerType

    init(
        setupChecker: SetupCheckerType,
        notificationCenter: NotificationCenterType,
        deviceListListener: DeviceListChangeListenerType
    ) {
        self.setupChecker = setupChecker
        self.notificationCenter = notificationCenter
        self.deviceListListener = deviceListListener
    }

    @discardableResult
    func startListening() -> [Task<Void, Error>] {
        let streams: [AsyncStream<Void>] = [
            notificationCenter.stream(for: NSApplication.didBecomeActiveNotification),
            deviceListListener.stream()
        ]
        return streams.map { stream in
            Task { [setupChecker] in
                for await _ in stream {
                    await setupChecker.refresh()
                }
            }
        }
    }
}
