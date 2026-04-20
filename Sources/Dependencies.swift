//
//  Dependencies.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import SwiftUI

struct Dependencies: Sendable {
    static let live = Dependencies()

    @MainActor func makeHostViewModel() -> HostViewModelType {
        let library = AudioUnitComponentsLibrary()

        return HostViewModel(
            engine: AudioUnitHostEngine(
                coreMidiManager: CoreMidiManager(),
                audioUnitComponentsLibrary: library
            ),
            library: library
        )
    }
}

// MARK: - Environment

extension EnvironmentValues {
    @Entry var dependencies: Dependencies = .live
}
