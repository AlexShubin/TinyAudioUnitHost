//
//  SetupRefresherTests.swift
//  AudioSettingsKitTests
//
//  Created by Alex Shubin on 14.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKitTestSupport
import Testing
@testable import AudioSettingsKit

@Suite
struct SetupRefresherTests {
    var setupCheckerMock: SetupCheckerMock!
    var deviceListListenerMock: DeviceListChangeListenerMock!
    var sut: SetupRefresher!

    init() {
        setupCheckerMock = SetupCheckerMock()
        deviceListListenerMock = DeviceListChangeListenerMock()
    }

    mutating func createSut() {
        sut = SetupRefresher(
            setupChecker: setupCheckerMock,
            deviceListListener: deviceListListenerMock
        )
    }

    @Test
    mutating func start_subscribesToDeviceListChanges() {
        createSut()

        _ = sut.start()

        #expect(deviceListListenerMock.calls == [.stream])
    }

    @Test
    mutating func start_emittedDeviceListChange_refreshesSetup() async {
        createSut()

        let task = sut.start()
        deviceListListenerMock.emit()
        deviceListListenerMock.finish()
        try? await task.value

        #expect(setupCheckerMock.calls == [.refresh])
    }
}
