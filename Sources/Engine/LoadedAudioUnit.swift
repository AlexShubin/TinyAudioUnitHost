//
//  LoadedAudioUnit.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 21.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AppKit

struct LoadedAudioUnit: Sendable {
    let component: AudioUnitComponent
    let requestViewController: @Sendable @MainActor () async -> NSViewController?
}
