//
//  AudioUnitComponent.swift
//  Common
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioToolbox

public struct AudioUnitComponent: Sendable, Identifiable, Hashable {
    public let name: String
    public let manufacturer: String
    public let componentDescription: AudioComponentDescription

    public init(name: String, manufacturer: String, componentDescription: AudioComponentDescription) {
        self.name = name
        self.manufacturer = manufacturer
        self.componentDescription = componentDescription
    }

    public var id: String {
        "\(componentDescription.componentType)-\(componentDescription.componentSubType)-\(componentDescription.componentManufacturer)"
    }

    public static func == (lhs: AudioUnitComponent, rhs: AudioUnitComponent) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
