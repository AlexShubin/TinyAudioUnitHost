//
//  AudioUnitComponent.swift
//  TinyAudioUnitHost
//
//  Created by ashubin on 22.04.26.
//

import AudioToolbox

struct AudioUnitComponent: Sendable, Identifiable, Hashable {
    let name: String
    let manufacturer: String
    let componentDescription: AudioComponentDescription

    var id: String {
        "\(componentDescription.componentType)-\(componentDescription.componentSubType)-\(componentDescription.componentManufacturer)"
    }

    static func == (lhs: AudioUnitComponent, rhs: AudioUnitComponent) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
