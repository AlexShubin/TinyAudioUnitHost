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
    var gatewaySpy: CoreAudioGatewaySpy!
    var sut: AggregateDeviceFactoryType!

    init() {
        gatewaySpy = CoreAudioGatewaySpy()
    }

    mutating func createSut() {
        sut = AggregateDeviceFactory(gateway: gatewaySpy)
    }

    // MARK: - create

    @Test
    mutating func createPassesDerivedConfigurationToGateway() {
        gatewaySpy.createAggregateDeviceResult = 42
        createSut()

        let id = sut.create(inputUID: "input-uid", outputUID: "output-uid")

        #expect(id == 42)
        guard gatewaySpy.calls.count == 1,
              case let .createAggregateDevice(name, uid, isPrivate, isStacked, mainSubDeviceUID, subDeviceUIDs) = gatewaySpy.calls.first
        else {
            Issue.record("expected a single createAggregateDevice call, got \(gatewaySpy.calls)")
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
        gatewaySpy.createAggregateDeviceResult = nil
        createSut()
        #expect(sut.create(inputUID: "in", outputUID: "out") == nil)
    }

    @Test
    mutating func createGeneratesUniqueUIDPerCall() {
        gatewaySpy.createAggregateDeviceResult = 1
        createSut()

        _ = sut.create(inputUID: "in", outputUID: "out")
        _ = sut.create(inputUID: "in", outputUID: "out")

        let uids = gatewaySpy.calls.compactMap { call -> String? in
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
        #expect(gatewaySpy.calls == [.destroyAggregateDevice(99)])
    }

    // MARK: - destroyOrphans

    @Test
    mutating func destroyOrphansDestroysDevicesWithOurPrefix() {
        gatewaySpy.allDeviceIDsResult = [1, 3]
        gatewaySpy.deviceUIDResult = AggregateDeviceFactory.uidPrefix + "a"
        createSut()

        sut.destroyOrphans()

        #expect(gatewaySpy.calls == [
            .allDeviceIDs,
            .deviceUID(1), .deviceUID(3),
            .destroyAggregateDevice(1), .destroyAggregateDevice(3),
        ])
    }

    @Test
    mutating func destroyOrphansDoesNothingWhenNoneMatch() {
        gatewaySpy.allDeviceIDsResult = [1]
        gatewaySpy.deviceUIDResult = "external-device"
        createSut()

        sut.destroyOrphans()

        #expect(gatewaySpy.calls == [.allDeviceIDs, .deviceUID(1)])
    }
}
