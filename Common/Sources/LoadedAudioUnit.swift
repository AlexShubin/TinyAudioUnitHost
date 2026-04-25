//
//  LoadedAudioUnit.swift
//  Common
//
//  Created by Alex Shubin on 21.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AppKit

public struct LoadedAudioUnit: Sendable, Equatable {
    public let component: AudioUnitComponent
    public let requestViewController: @Sendable @MainActor () async -> NSViewController?

    public init(
        component: AudioUnitComponent,
        requestViewController: @escaping @Sendable @MainActor () async -> NSViewController?
    ) {
        self.component = component
        self.requestViewController = requestViewController
    }

    public static func == (lhs: LoadedAudioUnit, rhs: LoadedAudioUnit) -> Bool {
        lhs.component == rhs.component
    }
}
