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
    public let availableBufferSizes: [UInt32]
    public let availableSampleRates: [Float64]

    public init(
        id: UInt32,
        uid: String,
        name: String,
        inputChannels: [AudioChannel],
        outputChannels: [AudioChannel],
        availableBufferSizes: [UInt32],
        availableSampleRates: [Float64]
    ) {
        self.id = id
        self.uid = uid
        self.name = name
        self.inputChannels = inputChannels
        self.outputChannels = outputChannels
        self.availableBufferSizes = availableBufferSizes
        self.availableSampleRates = availableSampleRates
    }
}
