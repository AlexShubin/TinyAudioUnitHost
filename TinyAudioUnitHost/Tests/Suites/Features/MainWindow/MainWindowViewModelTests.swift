//
//  MainWindowViewModelTests.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 22.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKitTestSupport
import EngineKitTestSupport
import PurchasesKitTestSupport
import Testing
@testable import TinyAudioUnitHost

@MainActor
@Suite
struct MainWindowViewModelTests {
    var midiManagerMock: MidiManagerMock!
    var engineReloaderMock: EngineReloaderMock!
    var setupRefresherMock: SetupRefresherMock!
    var purchasesServiceMock: PurchasesServiceMock!
    var sut: MainWindowViewModelType!

    init() {
        midiManagerMock = MidiManagerMock()
        engineReloaderMock = EngineReloaderMock()
        setupRefresherMock = SetupRefresherMock()
        purchasesServiceMock = PurchasesServiceMock()
    }

    mutating func createSut() {
        sut = MainWindowViewModel(
            midiManager: midiManagerMock,
            engineReloader: engineReloaderMock,
            setupRefresher: setupRefresherMock,
            purchasesService: purchasesServiceMock
        )
    }

    @Test
    mutating func task_startsAllListeners() async {
        createSut()

        await sut.accept(action: .task)

        #expect(midiManagerMock.calls == [.startListening])
        #expect(engineReloaderMock.calls == [.startListening])
        #expect(setupRefresherMock.calls == [.startListening])
        #expect(purchasesServiceMock.calls == [.startListening])
    }
}
