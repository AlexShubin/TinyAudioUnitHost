//
//  AudioDevice.swift
//  Common
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public struct AudioDevice: Sendable, Identifiable, Hashable {
    public let id: UInt32
    public let uid: String
    public let name: String
    public let inputChannels: [AudioChannel]
    public let outputChannels: [AudioChannel]

    public init(id: UInt32, uid: String, name: String, inputChannels: [AudioChannel], outputChannels: [AudioChannel]) {
        self.id = id
        self.uid = uid
        self.name = name
        self.inputChannels = inputChannels
        self.outputChannels = outputChannels
    }
}

public struct AudioChannel: Sendable, Identifiable, Hashable {
    public let id: UInt32
    public let name: String

    public init(id: UInt32, name: String) {
        self.id = id
        self.name = name
    }
}
