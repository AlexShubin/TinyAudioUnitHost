//
//  RawPresetTests.swift
//  StorageKitTests
//
//  Created by Alex Shubin on 11.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
import StorageKitTestSupport
import Testing
@testable import StorageKit

@Suite
struct RawPresetTests {
    // MARK: - decode v1

    @Test
    func decode_v1File_migratesToSourceSlotWithoutInserts() throws {
        let json = #"{"componentType":1,"componentSubType":2,"componentManufacturer":3,"state":"3q0="}"#

        let preset = try JSONDecoder().decode(RawPreset.self, from: Data(json.utf8))

        #expect(preset == RawPreset.fake(
            source: .fake(
                componentType: 1,
                componentSubType: 2,
                componentManufacturer: 3,
                name: "",
                manufacturer: "",
                state: Data([0xDE, 0xAD]),
                isBypassed: false
            ),
            inserts: []
        ))
        #expect(preset.version == RawPreset.currentVersion)
    }

    // MARK: - decode v2

    @Test
    func decode_v2File_readsSourceAndGappedInserts() throws {
        let json = #"""
        {
          "version": 2,
          "source": {"componentType":1,"componentSubType":2,"componentManufacturer":3,"name":"AUSampler","manufacturer":"Apple","state":"3q0=","isBypassed":false},
          "inserts": [null, {"componentType":4,"componentSubType":5,"componentManufacturer":6,"name":"AUDelay","manufacturer":"Apple","state":"","isBypassed":true}]
        }
        """#

        let preset = try JSONDecoder().decode(RawPreset.self, from: Data(json.utf8))

        #expect(preset == RawPreset.fake(
            source: .fake(
                componentType: 1,
                componentSubType: 2,
                componentManufacturer: 3,
                name: "AUSampler",
                manufacturer: "Apple",
                state: Data([0xDE, 0xAD])
            ),
            inserts: [
                nil,
                .fake(
                    componentType: 4,
                    componentSubType: 5,
                    componentManufacturer: 6,
                    name: "AUDelay",
                    manufacturer: "Apple",
                    isBypassed: true
                ),
            ]
        ))
    }

    @Test
    func decode_v2FileWithoutSource_sourceIsNil() throws {
        let json = #"{"version":2,"inserts":[]}"#

        let preset = try JSONDecoder().decode(RawPreset.self, from: Data(json.utf8))

        #expect(preset == RawPreset.fake(source: nil, inserts: []))
    }

    // MARK: - encode

    @Test
    func encode_writesCurrentVersion() throws {
        let data = try JSONEncoder().encode(RawPreset.fake())

        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["version"] as? Int == RawPreset.currentVersion)
    }

    @Test
    func encodeThenDecode_roundTrips() throws {
        let preset = RawPreset.fake(
            source: nil,
            inserts: [nil, .fake(name: "AUDelay", state: Data([0x01]), isBypassed: true), nil]
        )

        let decoded = try JSONDecoder().decode(RawPreset.self, from: JSONEncoder().encode(preset))

        #expect(decoded == preset)
    }
}
