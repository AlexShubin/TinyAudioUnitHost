//
//  AudioUnitComponentsLibrary.swift
//  TinyAudioUnitHost
//
//  Created by ashubin on 20.04.26.
//

import AVFoundation

struct AudioUnitComponent: Sendable, Identifiable {
    let id: String
    let name: String
    let manufacturer: String
    let componentDescription: AudioComponentDescription
}

protocol AudioUnitComponentsLibraryType: Sendable {
    var components: [AudioUnitComponent] { get }
}

final class AudioUnitComponentsLibrary: AudioUnitComponentsLibraryType {
    let components: [AudioUnitComponent]

    init() {
        var desc = AudioComponentDescription()
        desc.componentType = kAudioUnitType_MusicDevice
        desc.componentSubType = 0
        desc.componentManufacturer = 0
        desc.componentFlags = 0
        desc.componentFlagsMask = 0

        let found = AVAudioUnitComponentManager.shared().components(matching: desc)
        components = found.map { component in
            AudioUnitComponent(
                id: "\(component.manufacturerName).\(component.name)",
                name: component.name,
                manufacturer: component.manufacturerName,
                componentDescription: component.audioComponentDescription
            )
        }
    }
}
