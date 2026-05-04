//
//  AudioUnitComponentsLibraryMock.swift
//  EngineKitTestSupport
//
//  Created by Alex Shubin on 04.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import EngineKit

public final class AudioUnitComponentsLibraryMock: AudioUnitComponentsLibraryType, @unchecked Sendable {
    public var components: [AudioUnitComponent]

    public init(components: [AudioUnitComponent] = []) {
        self.components = components
    }
}
