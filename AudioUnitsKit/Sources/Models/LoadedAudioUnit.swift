//
//  LoadedAudioUnit.swift
//  AudioUnitsKit
//
//  Created by Alex Shubin on 21.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AppKit

public struct LoadedAudioUnit: Equatable, Sendable {
    public let component: AudioUnitComponent
    public let audioUnit: AUAudioUnitWrapper

    public init(
        component: AudioUnitComponent,
        audioUnit: AUAudioUnitWrapper
    ) {
        self.component = component
        self.audioUnit = audioUnit
    }
}
