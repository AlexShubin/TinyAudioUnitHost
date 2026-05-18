//
//  RawActivePresetState.swift
//  StorageKit
//
//  Created by Alex Shubin on 18.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public struct RawActivePresetState: Sendable, Equatable, Codable {
    public var name: String

    public init(name: String) {
        self.name = name
    }
}
