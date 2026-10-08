//
//  PresetNameError.swift
//  PresetKit
//
//  Created by Alex Shubin on 19.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public enum PresetNameError: Error, Sendable, Equatable {
    case empty
    case invalidCharacter
    case duplicate
}
