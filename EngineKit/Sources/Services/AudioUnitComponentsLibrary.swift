//
//  AudioUnitComponentsLibrary.swift
//  EngineKit
//
//  Created by Alex Shubin on 20.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AVFoundation

public protocol AudioUnitComponentsLibraryType: Sendable {
    var components: [AudioUnitComponent] { get }
}

final class AudioUnitComponentsLibrary: AudioUnitComponentsLibraryType {
    let components: [AudioUnitComponent]

    init() {
        let predicate = NSPredicate(format: "typeName IN %@", [
            AVAudioUnitTypeEffect,
            AVAudioUnitTypeMusicEffect,
            AVAudioUnitTypeMusicDevice
        ])
        components = AVAudioUnitComponentManager.shared()
            .components(matching: predicate)
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
