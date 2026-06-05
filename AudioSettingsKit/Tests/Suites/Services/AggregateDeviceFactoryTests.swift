//
//  AggregateDeviceFactoryTests.swift
//  AudioSettingsKitTests
//
//  Created by Alex Shubin on 29.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Testing
import AudioSettingsKitTestSupport
@testable import AudioSettingsKit

@Suite
struct AggregateDeviceFactoryTests {
    var devicesProviderMock: AudioDevicesProviderMock!
    var gatewayMock: CoreAudioGatewayMock!
    var sut: AggregateDeviceFactoryType!

    init() {
        devicesProviderMock = AudioDevicesProviderMock()
        gatewayMock = CoreAudioGatewayMock()
    }

    mutating func createSut() {
        sut = AggregateDeviceFactory(devicesProvider: devicesProviderMock, gateway: gatewayMock)
    }

    // MARK: - create

    @Test
    mutating func createPassesDerivedConfigurationToGateway() {
        gatewayMock.createAggregateDeviceResult = 42
        createSut()

        let id = sut.create(inputUID: "input-uid", outputUID: "output-uid")

        #expect(id == 42)
        guard gatewayMock.calls.count == 1,
              case let .createAggregateDevice(name, uid, isPrivate, isStacked, mainSubDeviceUID, subDeviceUIDs) = gatewayMock.calls.first
        else {
            Issue.record("expected a single createAggregateDevice call, got \(gatewayMock.calls)")
            return
        }
        #expect(name == "TinyAudioUnitHost Aggregate")
        #expect(uid.hasPrefix(AggregateDeviceFactory.uidPrefix))
        #expect(isPrivate)
        #expect(!isStacked)
        #expect(mainSubDeviceUID == "output-uid")
        #expect(subDeviceUIDs == ["input-uid", "output-uid"])
    }

    @Test
    mutating func createReturnsNilWhenGatewayFails() {
        gatewayMock.createAggregateDeviceResult = nil
        createSut()
        #expect(sut.create(inputUID: "in", outputUID: "out") == nil)
    }

    @Test
    mutating func createGeneratesUniqueUIDPerCall() {
        gatewayMock.createAggregateDeviceResult = 1
        createSut()

        _ = sut.create(inputUID: "in", outputUID: "out")
        _ = sut.create(inputUID: "in", outputUID: "out")

        let uids = gatewayMock.calls.compactMap { call -> String? in
            guard case let .createAggregateDevice(_, uid, _, _, _, _) = call else { return nil }
            return uid
        }
        #expect(uids.count == 2)
        #expect(uids[0] != uids[1])
    }

    // MARK: - destroy

    @Test
    mutating func destroyForwardsToGateway() {
        createSut()
        sut.destroy(id: 99)
        #expect(gatewayMock.calls == [.destroyAggregateDevice(99)])
    }

    // MARK: - destroyOrphans

    @Test
    mutating func destroyOrphansDestroysOnlyOurAggregateDevices() {
        devicesProviderMock.devicesResult = [
            .fake(id: 1, uid: AggregateDeviceFactory.uidPrefix + "a"),
            .fake(id: 2, uid: "some-other-device"),
            .fake(id: 3, uid: AggregateDeviceFactory.uidPrefix + "b")
        ]
        createSut()

        sut.destroyOrphans()

        #expect(gatewayMock.calls == [.destroyAggregateDevice(1), .destroyAggregateDevice(3)])
        #expect(devicesProviderMock.calls == [.devices(.all)])
    }

    @Test
    mutating func destroyOrphansDoesNothingWhenNoneMatch() {
        devicesProviderMock.devicesResult = [.fake(id: 1, uid: "external-device")]
        createSut()
        sut.destroyOrphans()
        #expect(gatewayMock.calls.isEmpty)
    }
}
