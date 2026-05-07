//
//  Dependencies.swift
//  AudioUnitsKit
//
//  Created by Alex Shubin on 05.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public struct Dependencies: Sendable {
    public let audioUnitComponentsLibrary: AudioUnitComponentsLibraryType

    public static let live = Dependencies(
        audioUnitComponentsLibrary: AudioUnitComponentsLibrary()
    )
}
