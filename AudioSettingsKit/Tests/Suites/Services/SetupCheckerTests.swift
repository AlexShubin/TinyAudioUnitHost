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
    var targetSettingsMock: TargetSettingsProviderMock!
    var captureDeviceMock: AVCaptureDeviceGatewayMock!
    var sut: SetupCheckerType!

    init() {
        targetSettingsMock = TargetSettingsProviderMock()
        captureDeviceMock = AVCaptureDeviceGatewayMock()
    }

    mutating func createSut() {
        sut = SetupChecker(
            targetSettingsProvider: targetSettingsMock,
            captureDevice: captureDeviceMock
        )
    }

    @Test
    mutating func refresh_micAndTargetOK_yieldsEmpty() async {
        targetSettingsMock = TargetSettingsProviderMock(resolveTargetResult: .fake())
        captureDeviceMock = AVCaptureDeviceGatewayMock(authorizationStatusResult: .authorized)
        createSut()
        var iterator = sut.unmetStream.makeAsyncIterator()

        await sut.refresh()

        #expect(await iterator.next() == [])
    }

    @Test
    mutating func refresh_micDenied_yieldsMicrophoneRequirement() async {
        targetSettingsMock = TargetSettingsProviderMock(resolveTargetResult: .fake())
        captureDeviceMock = AVCaptureDeviceGatewayMock(authorizationStatusResult: .denied)
        createSut()
        var iterator = sut.unmetStream.makeAsyncIterator()

        await sut.refresh()

        #expect(await iterator.next() == [.microphonePermission])
    }

    @Test
    mutating func refresh_micNotDetermined_requestsAccess() async {
        targetSettingsMock = TargetSettingsProviderMock(resolveTargetResult: .fake())
        captureDeviceMock = AVCaptureDeviceGatewayMock(
            authorizationStatusResult: .notDetermined,
            requestAccessResult: true
        )
        createSut()

        await sut.refresh()

        #expect(captureDeviceMock.calls.contains(.requestAccess))
    }

    @Test
    mutating func refresh_noTarget_yieldsOutputDeviceRequirement() async {
        targetSettingsMock = TargetSettingsProviderMock(resolveTargetResult: nil)
        captureDeviceMock = AVCaptureDeviceGatewayMock(authorizationStatusResult: .authorized)
        createSut()
        var iterator = sut.unmetStream.makeAsyncIterator()

        await sut.refresh()

        #expect(await iterator.next() == [.outputDevice])
    }

    @Test
    mutating func refresh_bothMissing_yieldsBoth() async {
        targetSettingsMock = TargetSettingsProviderMock(resolveTargetResult: nil)
        captureDeviceMock = AVCaptureDeviceGatewayMock(authorizationStatusResult: .denied)
        createSut()
        var iterator = sut.unmetStream.makeAsyncIterator()

        await sut.refresh()

        #expect(await iterator.next() == [.microphonePermission, .outputDevice])
    }

    @Test
    mutating func refresh_calledAgainWithoutChange_doesNotYieldDuplicate() async {
        targetSettingsMock = TargetSettingsProviderMock(resolveTargetResult: .fake())
        captureDeviceMock = AVCaptureDeviceGatewayMock(authorizationStatusResult: .authorized)
        createSut()
        var iterator = sut.unmetStream.makeAsyncIterator()

        await sut.refresh()
        #expect(await iterator.next() == [])

        await sut.refresh()

        await targetSettingsMock.setResolveTargetResult(nil)
        await sut.refresh()
        #expect(await iterator.next() == [.outputDevice])
    }
}
