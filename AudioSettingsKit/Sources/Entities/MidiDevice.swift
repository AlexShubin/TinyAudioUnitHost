//
//  MidiDevice.swift
//  AudioSettingsKit
//
//  Created by Alex Shubin on 02.07.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public struct MidiDevice: Sendable, Identifiable, Hashable {
    public let ref: UInt32
    public let uid: Int32
    public let name: String

    public var id: Int32 { uid }

    public init(ref: UInt32, uid: Int32, name: String) {
        self.ref = ref
        self.uid = uid
        self.name = name
    }
}
