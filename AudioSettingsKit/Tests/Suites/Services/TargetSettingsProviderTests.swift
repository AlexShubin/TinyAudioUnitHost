//
//  TargetSettingsProviderTests.swift
//  AudioSettingsKitTests
//
//  Created by Alex Shubin on 04.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKitTestSupport
import Testing
@testable import AudioSettingsKit

@Suite
struct TargetSettingsProviderTests {
    var audioSettingsMock: AudioSettingsProviderMock!
    var devicesProviderMock: AudioDevicesProviderMock!
    var factoryMock: AggregateDeviceFactoryMock!
    var sut: TargetSettingsProviderType!

    init() {
        audioSettingsMock = AudioSettingsProviderMock()
        devicesProviderMock = AudioDevicesProviderMock()
        factoryMock = AggregateDeviceFactoryMock()
    }

    mutating func createSut() {
        sut = TargetSettingsProvider(
            audioSettings: audioSettingsMock,
            devicesProvider: devicesProviderMock,
            factory: factoryMock
        )
    }

    // MARK: - init

    @Test
    mutating func init_destroysOrphans() {
        createSut()

        #expect(factoryMock.calls == [.destroyOrphans])
    }

    // MARK: - resolveTarget

    @Test
    mutating func resolveTarget_noDevices_returnsNil() async {
        createSut()

        #expect(await sut.resolveTarget() == nil)
    }

    @Test
    mutating func resolveTarget_inputOnly_returnsNil() async {
        let inDevice = AudioDevice.fake(id: 1, uid: "in-uid")
        await audioSettingsMock.setSettings(.fake(inputDevice: inDevice))
        createSut()

        #expect(await sut.resolveTarget() == nil)
    }

    @Test
    mutating func resolveTarget_outputOnly_returnsTargetWithOutputDevice() async {
        let outDevice = AudioDevice.fake(id: 2, uid: "out-uid")
        let settings = AudioSettings.fake(outputDevice: outDevice)
        await audioSettingsMock.setSettings(settings)
        createSut()

        let result = await sut.resolveTarget()

        #expect(result == .fake(settings: settings, device: outDevice))
        #expect(factoryMock.calls == [.destroyOrphans])
    }

    @Test
    mutating func resolveTarget_sameInputAndOutput_returnsTargetWithOutput() async {
        let device = AudioDevice.fake(id: 1, uid: "uid")
        let settings = AudioSettings.fake(inputDevice: device, outputDevice: device)
        await audioSettingsMock.setSettings(settings)
        createSut()

        let result = await sut.resolveTarget()

        #expect(result == .fake(settings: settings, device: device))
        #expect(factoryMock.calls == [.destroyOrphans])
    }

    @Test
    mutating func resolveTarget_differentInputAndOutput_createsAggregateAndReturnsIt() async {
        let inDevice = AudioDevice.fake(id: 1, uid: "in-uid")
        let outDevice = AudioDevice.fake(id: 2, uid: "out-uid")
        let aggregate = AudioDevice.fake(id: 99, uid: "aggregate")
        let settings = AudioSettings.fake(inputDevice: inDevice, outputDevice: outDevice)
        await audioSettingsMock.setSettings(settings)
        factoryMock.createResult = 99
        devicesProviderMock.deviceByID = [99: aggregate]
        createSut()

        let result = await sut.resolveTarget()

        #expect(result == .fake(settings: settings, device: aggregate))
        #expect(factoryMock.calls == [
            .destroyOrphans,
            .create(inputUID: "in-uid", outputUID: "out-uid"),
        ])
    }

    @Test
    mutating func resolveTarget_aggregateCreationFails_returnsNil() async {
        let inDevice = AudioDevice.fake(id: 1, uid: "in-uid")
        let outDevice = AudioDevice.fake(id: 2, uid: "out-uid")
        await audioSettingsMock.setSettings(.fake(inputDevice: inDevice, outputDevice: outDevice))
        factoryMock.createResult = nil
        createSut()

        #expect(await sut.resolveTarget() == nil)
    }

    @Test
    mutating func resolveTarget_aggregateNotFoundInDevices_returnsNil() async {
        let inDevice = AudioDevice.fake(id: 1, uid: "in-uid")
        let outDevice = AudioDevice.fake(id: 2, uid: "out-uid")
        await audioSettingsMock.setSettings(.fake(inputDevice: inDevice, outputDevice: outDevice))
        factoryMock.createResult = 99
        devicesProviderMock.deviceByID = [:]
        createSut()

        #expect(await sut.resolveTarget() == nil)
    }

    @Test
    mutating func resolveTarget_secondCallSameUIDs_reusesCachedAggregate() async {
        let inDevice = AudioDevice.fake(id: 1, uid: "in-uid")
        let outDevice = AudioDevice.fake(id: 2, uid: "out-uid")
        let aggregate = AudioDevice.fake(id: 99, uid: "aggregate")
        await audioSettingsMock.setSettings(.fake(inputDevice: inDevice, outputDevice: outDevice))
        factoryMock.createResult = 99
        devicesProviderMock.deviceByID = [99: aggregate]
        createSut()

        _ = await sut.resolveTarget()
        let second = await sut.resolveTarget()

        #expect(second?.device == aggregate)
        #expect(factoryMock.calls == [
            .destroyOrphans,
            .create(inputUID: "in-uid", outputUID: "out-uid"),
        ])
    }

    @Test
    mutating func resolveTarget_uidsChanged_destroysCachedAndCreatesNew() async {
        let inDevice = AudioDevice.fake(id: 1, uid: "in-uid")
        let outDevice = AudioDevice.fake(id: 2, uid: "out-uid")
        let inDevice2 = AudioDevice.fake(id: 3, uid: "in-uid-2")
        let aggregate1 = AudioDevice.fake(id: 99, uid: "agg1")
        let aggregate2 = AudioDevice.fake(id: 100, uid: "agg2")
        await audioSettingsMock.setSettings(.fake(inputDevice: inDevice, outputDevice: outDevice))
        factoryMock.createResult = 99
        devicesProviderMock.deviceByID = [99: aggregate1]
        createSut()

        _ = await sut.resolveTarget()

        await audioSettingsMock.setSettings(.fake(inputDevice: inDevice2, outputDevice: outDevice))
        factoryMock.createResult = 100
        devicesProviderMock.deviceByID = [100: aggregate2]

        let second = await sut.resolveTarget()

        #expect(second?.device == aggregate2)
        #expect(factoryMock.calls == [
            .destroyOrphans,
            .create(inputUID: "in-uid", outputUID: "out-uid"),
            .destroy(99),
            .create(inputUID: "in-uid-2", outputUID: "out-uid"),
        ])
    }

    @Test
    mutating func resolveTarget_cachedAggregateGoneFromSystem_destroysCachedAndCreatesNew() async {
        let inDevice = AudioDevice.fake(id: 1, uid: "in-uid")
        let outDevice = AudioDevice.fake(id: 2, uid: "out-uid")
        let aggregate1 = AudioDevice.fake(id: 99, uid: "agg1")
        let aggregate2 = AudioDevice.fake(id: 100, uid: "agg2")
        await audioSettingsMock.setSettings(.fake(inputDevice: inDevice, outputDevice: outDevice))
        factoryMock.createResult = 99
        devicesProviderMock.deviceByID = [99: aggregate1]
        createSut()

        _ = await sut.resolveTarget()

        // Aggregate at id 99 disappears, factory now creates id 100
        factoryMock.createResult = 100
        devicesProviderMock.deviceByID = [100: aggregate2]

        let second = await sut.resolveTarget()

        #expect(second?.device == aggregate2)
        #expect(factoryMock.calls == [
            .destroyOrphans,
            .create(inputUID: "in-uid", outputUID: "out-uid"),
            .destroy(99),
            .create(inputUID: "in-uid", outputUID: "out-uid"),
        ])
    }

    @Test
    mutating func resolveTarget_switchToOutputOnlyAfterAggregate_destroysCached() async {
        let inDevice = AudioDevice.fake(id: 1, uid: "in-uid")
        let outDevice = AudioDevice.fake(id: 2, uid: "out-uid")
        let aggregate = AudioDevice.fake(id: 99, uid: "agg")
        await audioSettingsMock.setSettings(.fake(inputDevice: inDevice, outputDevice: outDevice))
        factoryMock.createResult = 99
        devicesProviderMock.deviceByID = [99: aggregate]
        createSut()

        _ = await sut.resolveTarget()

        await audioSettingsMock.setSettings(.fake(outputDevice: outDevice))

        let second = await sut.resolveTarget()

        #expect(second == .fake(settings: .fake(outputDevice: outDevice), device: outDevice))
        #expect(factoryMock.calls == [
            .destroyOrphans,
            .create(inputUID: "in-uid", outputUID: "out-uid"),
            .destroy(99),
        ])
    }

    @Test
    mutating func resolveTarget_switchToNoDevicesAfterAggregate_destroysCached() async {
        let inDevice = AudioDevice.fake(id: 1, uid: "in-uid")
        let outDevice = AudioDevice.fake(id: 2, uid: "out-uid")
        let aggregate = AudioDevice.fake(id: 99, uid: "agg")
        await audioSettingsMock.setSettings(.fake(inputDevice: inDevice, outputDevice: outDevice))
        factoryMock.createResult = 99
        devicesProviderMock.deviceByID = [99: aggregate]
        createSut()

        _ = await sut.resolveTarget()

        await audioSettingsMock.setSettings(.empty)

        #expect(await sut.resolveTarget() == nil)
        #expect(factoryMock.calls == [
            .destroyOrphans,
            .create(inputUID: "in-uid", outputUID: "out-uid"),
            .destroy(99),
        ])
    }
}
