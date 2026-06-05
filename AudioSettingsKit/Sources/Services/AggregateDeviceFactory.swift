//
//  AggregateDeviceFactory.swift
//  AudioSettingsKit
//
//  Created by Alex Shubin on 27.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation

protocol AggregateDeviceFactoryType: Sendable {
    func create(inputUID: String, outputUID: String) -> UInt32?
    func destroy(id: UInt32)
    func destroyOrphans()
}

struct AggregateDeviceFactory: AggregateDeviceFactoryType {
    static let uidPrefix = "com.alexshubin.TinyAudioUnitHost.aggregate."

    private let devicesProvider: AudioDevicesProviderType
    private let gateway: CoreAudioGatewayType

    init(devicesProvider: AudioDevicesProviderType, gateway: CoreAudioGatewayType) {
        self.devicesProvider = devicesProvider
        self.gateway = gateway
    }

    func create(inputUID: String, outputUID: String) -> UInt32? {
        // Per-create unique UID: destroy is asynchronous, so reusing a fixed
        // UID across rapid reconnect cycles can race.
        let uid = Self.uidPrefix + UUID().uuidString
        return gateway.createAggregateDevice(
            name: "TinyAudioUnitHost Aggregate",
            uid: uid,
            isPrivate: true,
            isStacked: false,
            mainSubDeviceUID: outputUID,
            subDeviceUIDs: [inputUID, outputUID]
        )
    }

    func destroy(id: UInt32) {
        gateway.destroyAggregateDevice(id: id)
    }

    func destroyOrphans() {
        devicesProvider.devices(.all)
            .filter { $0.uid.hasPrefix(Self.uidPrefix) }
            .forEach { gateway.destroyAggregateDevice(id: $0.id) }
    }
}
