//
//  SelectedChannel.swift
//  Common
//
//  Created by Alex Shubin on 23.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public enum SelectedChannel: Sendable, Equatable, Hashable, Codable {
    case mono(AudioChannel)
    case stereo(l: AudioChannel, r: AudioChannel)

    public var channels: [AudioChannel] {
        switch self {
        case .mono(let channel): return [channel]
        case .stereo(let l, let r): return [l, r]
        }
    }

    public init?(from array: [AudioChannel]) {
        switch array.count {
            case 0: return nil
            case 1: self = .mono(array[0])
            default: self = .stereo(l: array[0], r: array[1])
        }
    }

    public init?(ids: [UInt32], in channels: [AudioChannel]) {
        let resolved = ids.compactMap { id in channels.first { $0.id == id } }
        self.init(from: resolved)
    }
}
