//
//  SelectedInputChannel.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 23.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

enum SelectedInputChannel: Sendable, Equatable, Hashable {
    case mono(UInt32)
    case stereo(l: UInt32, r: UInt32)

    var channels: [UInt32] {
        switch self {
        case .mono(let channel): return [channel]
        case .stereo(let l, let r): return [l, r]
        }
    }

    init?(from array: [UInt32]) {
        switch array.count {
            case 0: return nil
            case 1: self = .mono(array[0])
            default: self = .stereo(l: array[0], r: array[1])
        }
    }
}
