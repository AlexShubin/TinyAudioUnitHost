//
//  AudioUnitComponentsLibrary.swift
//  TinyAudioUnitHost
//
//  Created by ashubin on 20.04.26.
//

import AVFoundation

protocol AudioUnitComponentsLibraryType: Sendable {
    var components: [AudioUnitComponent] { get }
}

final class AudioUnitComponentsLibrary: AudioUnitComponentsLibraryType {
    let components: [AudioUnitComponent]

    init() {
        components = AVAudioUnitComponentManager.shared()
            .components(matching: AudioComponentDescription(
                componentType: 0,
                componentSubType: 0,
                componentManufacturer: 0,
                componentFlags: 0,
                componentFlagsMask: 0
            ))
            .map { component in
                AudioUnitComponent(
                    name: component.name,
                    manufacturer: component.manufacturerName,
                    componentDescription: component.audioComponentDescription
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
