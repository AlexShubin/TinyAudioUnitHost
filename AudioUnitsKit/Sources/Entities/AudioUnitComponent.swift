//
//  AudioUnitComponent.swift
//  AudioUnitsKit
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioToolbox

public struct AudioUnitComponent: Sendable, Identifiable, Hashable {
    public enum Kind: Sendable {
        case instrument
        case effect
    }

    public struct ID: Sendable, Hashable {
        public let type: UInt32
        public let subType: UInt32
        public let manufacturer: UInt32

        public init(type: UInt32, subType: UInt32, manufacturer: UInt32) {
            self.type = type
            self.subType = subType
            self.manufacturer = manufacturer
        }
    }

    public let id: ID
    public let name: String
    public let manufacturer: String

    public init(id: ID, name: String, manufacturer: String) {
        self.id = id
        self.name = name
        self.manufacturer = manufacturer
    }

    public var kind: Kind {
        id.type == kAudioUnitType_MusicDevice ? .instrument : .effect
    }

    public static func == (lhs: AudioUnitComponent, rhs: AudioUnitComponent) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension AudioUnitComponent.ID {
    init(_ description: AudioComponentDescription) {
        self.init(
            type: description.componentType,
            subType: description.componentSubType,
            manufacturer: description.componentManufacturer
        )
    }
}
