//
//  LoadedAudioUnit.swift
//  EngineKit
//
//  Created by Alex Shubin on 21.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AppKit
import CoreAudioKit

public struct LoadedAudioUnit: Sendable, Equatable {
    public let component: AudioUnitComponent
    nonisolated(unsafe) private let auAudioUnit: AUAudioUnit

    public init(
        component: AudioUnitComponent,
        auAudioUnit: AUAudioUnit
    ) {
        self.component = component
        self.auAudioUnit = auAudioUnit
    }

    @MainActor
    public func requestViewController() async -> NSViewController? {
        await withCheckedContinuation { continuation in
            auAudioUnit.requestViewController { continuation.resume(returning: $0) }
        }
    }
}
