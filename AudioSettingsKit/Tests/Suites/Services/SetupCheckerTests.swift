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
    var captureDeviceSpy: AVCaptureDeviceGatewaySpy!
    var sut: SetupCheckerType!

    init() {
        captureDeviceSpy = AVCaptureDeviceGatewaySpy()
    }

    mutating func createSut() {
        sut = SetupChecker(captureDevice: captureDeviceSpy)
    }

    @Test
    mutating func check_micAndOutputOK_returnsEmpty() async {
        let settings: AudioSettings = .fake(outputChannel: .mono(.fake()))
        captureDeviceSpy = AVCaptureDeviceGatewaySpy(authorizationStatusResult: .authorized)
        createSut()

        #expect(await sut.check(settings) == [])
    }

    @Test
    mutating func check_micDenied_returnsMicrophoneRequirement() async {
        let settings: AudioSettings = .fake(outputChannel: .mono(.fake()))
        captureDeviceSpy = AVCaptureDeviceGatewaySpy(authorizationStatusResult: .denied)
        createSut()

        #expect(await sut.check(settings) == [.microphonePermission])
    }

    @Test
    mutating func check_micNotDetermined_requestsAccess() async {
        let settings: AudioSettings = .fake(outputChannel: .mono(.fake()))
        captureDeviceSpy = AVCaptureDeviceGatewaySpy(
            authorizationStatusResult: .notDetermined,
            requestAccessResult: true
        )
        createSut()

        _ = await sut.check(settings)

        #expect(captureDeviceSpy.calls.contains(.requestAccess))
    }

    @Test
    mutating func check_noOutputChannelAndNoSavedOutput_returnsNoOutputDevice() async {
        let settings: AudioSettings = .empty
        captureDeviceSpy = AVCaptureDeviceGatewaySpy(authorizationStatusResult: .authorized)
        createSut()

        #expect(await sut.check(settings) == [.noOutputDevice])
    }

    @Test
    mutating func check_savedOutputButOffline_returnsSavedOutputDeviceUnavailableWithName() async {
        let settings: AudioSettings = .fake(savedOutput: SavedDevice(uid: "apollo-uid", name: "Apollo x8", selectedChannelCount: 2))
        captureDeviceSpy = AVCaptureDeviceGatewaySpy(authorizationStatusResult: .authorized)
        createSut()

        #expect(await sut.check(settings) == [.savedOutputDeviceUnavailable(name: "Apollo x8")])
    }

    @Test
    mutating func check_savedOutputWithoutChannels_returnsNoOutputDevice() async {
        let settings: AudioSettings = .fake(savedOutput: SavedDevice(uid: "apollo-uid", name: "Apollo x8", selectedChannelCount: 0))
        captureDeviceSpy = AVCaptureDeviceGatewaySpy(authorizationStatusResult: .authorized)
        createSut()

        #expect(await sut.check(settings) == [.noOutputDevice])
    }

    @Test
    mutating func check_bothMissing_returnsBoth() async {
        let settings: AudioSettings = .empty
        captureDeviceSpy = AVCaptureDeviceGatewaySpy(authorizationStatusResult: .denied)
        createSut()

        #expect(await sut.check(settings) == [.microphonePermission, .noOutputDevice])
    }
}
