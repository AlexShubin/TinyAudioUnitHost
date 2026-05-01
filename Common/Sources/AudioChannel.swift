//
//  AudioChannel.swift
//  Common
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public struct AudioChannel: Sendable, Identifiable, Hashable, Codable {
    public let id: UInt32
    public let name: String

    public init(id: UInt32, name: String) {
        self.id = id
        self.name = name
    }
}
