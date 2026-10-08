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

@Suite @MainActor
struct SetupCheckerTests {
    var audioSettingsSpy: AudioSettingsModelSpy!
    var captureDeviceSpy: AVCaptureDeviceGatewaySpy!
    var sut: SetupCheckerType!

    init() {
        audioSettingsSpy = AudioSettingsModelSpy()
        captureDeviceSpy = AVCaptureDeviceGatewaySpy()
    }

    mutating func createSut() {
        sut = SetupChecker(
            audioSettings: audioSettingsSpy,
            captureDevice: captureDeviceSpy
        )
    }

    @Test
    mutating func check_micAndOutputOK_returnsEmpty() async {
        audioSettingsSpy.settings = .fake(outputChannel: .mono(.fake()))
        captureDeviceSpy = AVCaptureDeviceGatewaySpy(authorizationStatusResult: .authorized)
        createSut()

        #expect(await sut.check() == [])
    }

    @Test
    mutating func check_micDenied_returnsMicrophoneRequirement() async {
        audioSettingsSpy.settings = .fake(outputChannel: .mono(.fake()))
        captureDeviceSpy = AVCaptureDeviceGatewaySpy(authorizationStatusResult: .denied)
        createSut()

        #expect(await sut.check() == [.microphonePermission])
    }

    @Test
    mutating func check_micNotDetermined_requestsAccess() async {
        audioSettingsSpy.settings = .fake(outputChannel: .mono(.fake()))
        captureDeviceSpy = AVCaptureDeviceGatewaySpy(
            authorizationStatusResult: .notDetermined,
            requestAccessResult: true
        )
        createSut()

        _ = await sut.check()

        #expect(captureDeviceSpy.calls.contains(.requestAccess))
    }

    @Test
    mutating func check_noOutputChannelAndNoSavedOutput_returnsNoOutputDevice() async {
        audioSettingsSpy.settings = .empty
        captureDeviceSpy = AVCaptureDeviceGatewaySpy(authorizationStatusResult: .authorized)
        createSut()

        #expect(await sut.check() == [.noOutputDevice])
    }

    @Test
    mutating func check_savedOutputButOffline_returnsSavedOutputDeviceUnavailableWithName() async {
        audioSettingsSpy.settings = .fake(savedOutput: SavedDevice(uid: "apollo-uid", name: "Apollo x8", selectedChannelCount: 2)
        )
        captureDeviceSpy = AVCaptureDeviceGatewaySpy(authorizationStatusResult: .authorized)
        createSut()

        #expect(await sut.check() == [.savedOutputDeviceUnavailable(name: "Apollo x8")])
    }

    @Test
    mutating func check_savedOutputWithoutChannels_returnsNoOutputDevice() async {
        audioSettingsSpy.settings = .fake(savedOutput: SavedDevice(uid: "apollo-uid", name: "Apollo x8", selectedChannelCount: 0)
        )
        captureDeviceSpy = AVCaptureDeviceGatewaySpy(authorizationStatusResult: .authorized)
        createSut()

        #expect(await sut.check() == [.noOutputDevice])
    }

    @Test
    mutating func check_bothMissing_returnsBoth() async {
        audioSettingsSpy.settings = .empty
        captureDeviceSpy = AVCaptureDeviceGatewaySpy(authorizationStatusResult: .denied)
        createSut()

        #expect(await sut.check() == [.microphonePermission, .noOutputDevice])
    }
}
