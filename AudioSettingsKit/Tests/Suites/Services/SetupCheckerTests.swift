//
//  SetupCheckerTests.swift
//  AudioSettingsKitTests
//
//  Created by Alex Shubin on 09.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKitTestSupport
import AVFoundation
import Foundation
import Testing
@testable import AudioSettingsKit

@Suite
struct SetupCheckerTests {
    var audioSettingsMock: AudioSettingsProviderMock!
    var captureDeviceMock: AVCaptureDeviceGatewayMock!
    var sut: SetupCheckerType!

    init() {
        audioSettingsMock = AudioSettingsProviderMock()
        captureDeviceMock = AVCaptureDeviceGatewayMock()
    }

    mutating func createSut() {
        sut = SetupChecker(
            audioSettings: audioSettingsMock,
            captureDevice: captureDeviceMock
        )
    }

    @Test
    mutating func refresh_micAndOutputOK_yieldsEmpty() async {
        audioSettingsMock = AudioSettingsProviderMock(settings: .fake(outputChannel: .mono(.fake())))
        captureDeviceMock = AVCaptureDeviceGatewayMock(authorizationStatusResult: .authorized)
        createSut()
        var iterator = sut.unmetStream.makeAsyncIterator()

        await sut.refresh()

        #expect(await iterator.next() == [])
    }

    @Test
    mutating func refresh_micDenied_yieldsMicrophoneRequirement() async {
        audioSettingsMock = AudioSettingsProviderMock(settings: .fake(outputChannel: .mono(.fake())))
        captureDeviceMock = AVCaptureDeviceGatewayMock(authorizationStatusResult: .denied)
        createSut()
        var iterator = sut.unmetStream.makeAsyncIterator()

        await sut.refresh()

        #expect(await iterator.next() == [.microphonePermission])
    }

    @Test
    mutating func refresh_micNotDetermined_requestsAccess() async {
        audioSettingsMock = AudioSettingsProviderMock(settings: .fake(outputChannel: .mono(.fake())))
        captureDeviceMock = AVCaptureDeviceGatewayMock(
            authorizationStatusResult: .notDetermined,
            requestAccessResult: true
        )
        createSut()

        await sut.refresh()

        #expect(captureDeviceMock.calls.contains(.requestAccess))
    }

    @Test
    mutating func refresh_noOutputChannelAndNoSavedOutput_yieldsNoOutputDevice() async {
        audioSettingsMock = AudioSettingsProviderMock(settings: .empty)
        captureDeviceMock = AVCaptureDeviceGatewayMock(authorizationStatusResult: .authorized)
        createSut()
        var iterator = sut.unmetStream.makeAsyncIterator()

        await sut.refresh()

        #expect(await iterator.next() == [.noOutputDevice])
    }

    @Test
    mutating func refresh_savedOutputButOffline_yieldsSavedOutputDeviceUnavailableWithName() async {
        audioSettingsMock = AudioSettingsProviderMock(
            settings: .fake(savedOutput: SavedDevice(uid: "apollo-uid", name: "Apollo x8", selectedChannelCount: 2))
        )
        captureDeviceMock = AVCaptureDeviceGatewayMock(authorizationStatusResult: .authorized)
        createSut()
        var iterator = sut.unmetStream.makeAsyncIterator()

        await sut.refresh()

        #expect(await iterator.next() == [.savedOutputDeviceUnavailable(name: "Apollo x8")])
    }

    @Test
    mutating func refresh_savedOutputButOfflineAndUnnamed_yieldsRequirementWithNilName() async {
        audioSettingsMock = AudioSettingsProviderMock(
            settings: .fake(savedOutput: SavedDevice(uid: "apollo-uid", name: nil, selectedChannelCount: 1))
        )
        captureDeviceMock = AVCaptureDeviceGatewayMock(authorizationStatusResult: .authorized)
        createSut()
        var iterator = sut.unmetStream.makeAsyncIterator()

        await sut.refresh()

        #expect(await iterator.next() == [.savedOutputDeviceUnavailable(name: nil)])
    }

    @Test
    mutating func refresh_savedOutputWithoutChannels_yieldsNoOutputDevice() async {
        audioSettingsMock = AudioSettingsProviderMock(
            settings: .fake(savedOutput: SavedDevice(uid: "apollo-uid", name: "Apollo x8", selectedChannelCount: 0))
        )
        captureDeviceMock = AVCaptureDeviceGatewayMock(authorizationStatusResult: .authorized)
        createSut()
        var iterator = sut.unmetStream.makeAsyncIterator()

        await sut.refresh()

        #expect(await iterator.next() == [.noOutputDevice])
    }

    @Test
    mutating func refresh_bothMissing_yieldsBoth() async {
        audioSettingsMock = AudioSettingsProviderMock(settings: .empty)
        captureDeviceMock = AVCaptureDeviceGatewayMock(authorizationStatusResult: .denied)
        createSut()
        var iterator = sut.unmetStream.makeAsyncIterator()

        await sut.refresh()

        #expect(await iterator.next() == [.microphonePermission, .noOutputDevice])
    }

    @Test
    mutating func refresh_calledAgainWithoutChange_doesNotYieldDuplicate() async {
        audioSettingsMock = AudioSettingsProviderMock(settings: .fake(outputChannel: .mono(.fake())))
        captureDeviceMock = AVCaptureDeviceGatewayMock(authorizationStatusResult: .authorized)
        createSut()
        var iterator = sut.unmetStream.makeAsyncIterator()

        await sut.refresh()
        #expect(await iterator.next() == [])

        await sut.refresh()

        await audioSettingsMock.setSettings(.empty)
        await sut.refresh()
        #expect(await iterator.next() == [.noOutputDevice])
    }
}
