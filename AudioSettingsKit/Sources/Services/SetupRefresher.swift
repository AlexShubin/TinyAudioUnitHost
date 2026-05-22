//
//  SetupRefresher.swift
//  AudioSettingsKit
//
//  Created by Alex Shubin on 14.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation

public protocol SetupRefresherType: Sendable {
    @discardableResult
    func startListening() -> Task<Void, Error>
}

final class SetupRefresher: SetupRefresherType {
    private let setupChecker: SetupCheckerType
    private let deviceListListener: DeviceListChangeListenerType

    init(
        setupChecker: SetupCheckerType,
        deviceListListener: DeviceListChangeListenerType
    ) {
        self.setupChecker = setupChecker
        self.deviceListListener = deviceListListener
    }

    @discardableResult
    func startListening() -> Task<Void, Error> {
        let stream = deviceListListener.stream()
        return Task { [setupChecker] in
            for await _ in stream {
                await setupChecker.refresh()
            }
        }
    }
}
