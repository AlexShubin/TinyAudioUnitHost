//
//  MainWindowViewModelTests.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 22.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKitTestSupport
import EngineKitTestSupport
import Testing
@testable import TinyAudioUnitHost

@MainActor
@Suite
struct MainWindowViewModelTests {
    var engineReloaderMock: EngineReloaderMock!
    var setupRefresherMock: SetupRefresherMock!
    var sut: MainWindowViewModelType!

    init() {
        engineReloaderMock = EngineReloaderMock()
        setupRefresherMock = SetupRefresherMock()
    }

    mutating func createSut() {
        sut = MainWindowViewModel(
            engineReloader: engineReloaderMock,
            setupRefresher: setupRefresherMock
        )
    }

    @Test
    mutating func task_startsBothListeners() async {
        createSut()

        await sut.accept(action: .task)

        #expect(engineReloaderMock.calls == [.startListening])
        #expect(setupRefresherMock.calls == [.startListening])
    }
}
