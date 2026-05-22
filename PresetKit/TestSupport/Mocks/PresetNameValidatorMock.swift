//
//  PresetNameValidatorMock.swift
//  PresetKitTestSupport
//
//  Created by Alex Shubin on 19.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import PresetKit

public final class PresetNameValidatorMock: PresetNameValidatorType, @unchecked Sendable {
    public enum Calls: Equatable, Sendable {
        case validate(name: String, mode: ValidationMode)
    }

    public var result: PresetNameError?
    public private(set) var calls: [Calls] = []

    public init(result: PresetNameError? = nil) {
        self.result = result
    }

    public func validate(name: String, for mode: ValidationMode) -> PresetNameError? {
        calls.append(.validate(name: name, mode: mode))
        return result
    }
}
