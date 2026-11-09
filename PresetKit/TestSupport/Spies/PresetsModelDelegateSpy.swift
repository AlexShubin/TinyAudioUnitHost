//
//  PresetsModelDelegateSpy.swift
//  PresetKitTestSupport
//
//  Created by Alex Shubin on 09.11.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import PresetKit

@MainActor
public final class PresetsModelDelegateSpy: PresetsModelDelegate {
    public enum Calls: Equatable, Sendable {
        case presetsDidActivate(chain: [PresetSlot?])
    }

    public private(set) var calls: [Calls] = []

    public init() {}

    public func presetsDidActivate(chain: [PresetSlot?]) async {
        calls.append(.presetsDidActivate(chain: chain))
    }
}
