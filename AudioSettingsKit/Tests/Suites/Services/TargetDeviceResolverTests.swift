//
//  TargetDeviceResolverTests.swift
//  AudioSettingsKitTests
//
//  Created by Alex Shubin on 08.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKitTestSupport
import Testing
@testable import AudioSettingsKit

@Suite @MainActor
struct TargetDeviceResolverTests {
    var devicesProviderSpy: AudioDevicesProviderSpy!
    var factorySpy: AggregateDeviceFactorySpy!
    var sut: TargetDeviceResolverType!

    init() {
        devicesProviderSpy = AudioDevicesProviderSpy()
        factorySpy = AggregateDeviceFactorySpy()
    }

    mutating func createSut() {
        sut = TargetDeviceResolver(devicesProvider: devicesProviderSpy, factory: factorySpy)
    }

    // MARK: - init

    @Test
    mutating func init_destroysOrphans() {
        createSut()

        #expect(factorySpy.calls == [.destroyOrphans])
    }

    // MARK: - resolve

    @Test
    mutating func resolve_noDevices_returnsNil() {
        createSut()

        #expect(sut.resolve(.empty) == nil)
    }

    @Test
    mutating func resolve_inputOnly_returnsNil() {
        createSut()

        #expect(sut.resolve(.fake(inputDevice: .fake(id: 1, uid: "in-uid"))) == nil)
    }

    @Test
    mutating func resolve_outputOnly_returnsOutputDevice() {
        let outDevice = AudioDevice.fake(id: 2, uid: "out-uid")
        createSut()

        #expect(sut.resolve(.fake(outputDevice: outDevice)) == outDevice)
        #expect(factorySpy.calls == [.destroyOrphans])
    }

    @Test
    mutating func resolve_sameInputAndOutput_returnsOutputDevice() {
        let device = AudioDevice.fake(id: 1, uid: "uid")
        createSut()

        #expect(sut.resolve(.fake(inputDevice: device, outputDevice: device)) == device)
        #expect(factorySpy.calls == [.destroyOrphans])
    }

    @Test
    mutating func resolve_differentInputAndOutput_createsAggregateAndReturnsIt() {
        let aggregate = AudioDevice.fake(id: 99, uid: "aggregate")
        factorySpy.createResult = 99
        devicesProviderSpy.deviceByID = [99: aggregate]
        createSut()

        let result = sut.resolve(.fake(inputDevice: .fake(id: 1, uid: "in-uid"), outputDevice: .fake(id: 2, uid: "out-uid")))

        #expect(result == aggregate)
        #expect(factorySpy.calls == [
            .destroyOrphans,
            .create(inputUID: "in-uid", outputUID: "out-uid"),
        ])
    }

    @Test
    mutating func resolve_aggregateCreationFails_returnsNil() {
        factorySpy.createResult = nil
        createSut()

        #expect(sut.resolve(.fake(inputDevice: .fake(id: 1, uid: "in-uid"), outputDevice: .fake(id: 2, uid: "out-uid"))) == nil)
    }

    @Test
    mutating func resolve_aggregateNotFoundInDevices_returnsNil() {
        factorySpy.createResult = 99
        devicesProviderSpy.deviceByID = [:]
        createSut()

        #expect(sut.resolve(.fake(inputDevice: .fake(id: 1, uid: "in-uid"), outputDevice: .fake(id: 2, uid: "out-uid"))) == nil)
    }

    @Test
    mutating func resolve_secondCallSameUIDs_reusesCachedAggregate() {
        let settings = AudioSettings.fake(inputDevice: .fake(id: 1, uid: "in-uid"), outputDevice: .fake(id: 2, uid: "out-uid"))
        let aggregate = AudioDevice.fake(id: 99, uid: "aggregate")
        factorySpy.createResult = 99
        devicesProviderSpy.deviceByID = [99: aggregate]
        createSut()

        _ = sut.resolve(settings)
        let second = sut.resolve(settings)

        #expect(second == aggregate)
        #expect(factorySpy.calls == [
            .destroyOrphans,
            .create(inputUID: "in-uid", outputUID: "out-uid"),
        ])
    }

    @Test
    mutating func resolve_uidsChanged_destroysCachedAndCreatesNew() {
        let outDevice = AudioDevice.fake(id: 2, uid: "out-uid")
        factorySpy.createResult = 99
        devicesProviderSpy.deviceByID = [99: .fake(id: 99, uid: "agg1")]
        createSut()
        _ = sut.resolve(.fake(inputDevice: .fake(id: 1, uid: "in-uid"), outputDevice: outDevice))

        let aggregate2 = AudioDevice.fake(id: 100, uid: "agg2")
        factorySpy.createResult = 100
        devicesProviderSpy.deviceByID = [100: aggregate2]
        let second = sut.resolve(.fake(inputDevice: .fake(id: 3, uid: "in-uid-2"), outputDevice: outDevice))

        #expect(second == aggregate2)
        #expect(factorySpy.calls == [
            .destroyOrphans,
            .create(inputUID: "in-uid", outputUID: "out-uid"),
            .destroy(99),
            .create(inputUID: "in-uid-2", outputUID: "out-uid"),
        ])
    }

    @Test
    mutating func resolve_cachedAggregateGoneFromSystem_destroysCachedAndCreatesNew() {
        let settings = AudioSettings.fake(inputDevice: .fake(id: 1, uid: "in-uid"), outputDevice: .fake(id: 2, uid: "out-uid"))
        factorySpy.createResult = 99
        devicesProviderSpy.deviceByID = [99: .fake(id: 99, uid: "agg1")]
        createSut()
        _ = sut.resolve(settings)

        let aggregate2 = AudioDevice.fake(id: 100, uid: "agg2")
        factorySpy.createResult = 100
        devicesProviderSpy.deviceByID = [100: aggregate2]
        let second = sut.resolve(settings)

        #expect(second == aggregate2)
        #expect(factorySpy.calls == [
            .destroyOrphans,
            .create(inputUID: "in-uid", outputUID: "out-uid"),
            .destroy(99),
            .create(inputUID: "in-uid", outputUID: "out-uid"),
        ])
    }

    @Test
    mutating func resolve_backToSingleDevice_destroysCachedAggregate() {
        let outDevice = AudioDevice.fake(id: 2, uid: "out-uid")
        factorySpy.createResult = 99
        devicesProviderSpy.deviceByID = [99: .fake(id: 99, uid: "agg1")]
        createSut()
        _ = sut.resolve(.fake(inputDevice: .fake(id: 1, uid: "in-uid"), outputDevice: outDevice))

        let result = sut.resolve(.fake(outputDevice: outDevice))

        #expect(result == outDevice)
        #expect(factorySpy.calls == [
            .destroyOrphans,
            .create(inputUID: "in-uid", outputUID: "out-uid"),
            .destroy(99),
        ])
    }
}
