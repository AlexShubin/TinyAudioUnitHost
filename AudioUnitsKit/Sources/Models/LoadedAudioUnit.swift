//
//  LoadedAudioUnit.swift
//  AudioUnitsKit
//
//  Created by Alex Shubin on 21.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AppKit

public struct LoadedAudioUnit: Sendable, Equatable {
    public let component: AudioUnitComponent
    public let audioUnit: AUAudioUnitType

    public init(
        component: AudioUnitComponent,
        audioUnit: AUAudioUnitType
    ) {
        self.component = component
        self.audioUnit = audioUnit
    }


    public static func == (lhs: LoadedAudioUnit, rhs: LoadedAudioUnit) -> Bool {
        lhs.component == rhs.component && lhs.audioUnit === rhs.audioUnit
    }
}
