//
//  BindableCommandMock.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 13.08.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
@testable import TinyAudioUnitHost

@MainActor
final class BindableCommandMock: CommandType, CommandBinderType {
    enum Calls: Equatable {
        case bind
        case execute
    }

    private(set) var calls: [Calls] = []

    private(set) var action: (() -> Void)?
    func bind(_ action: @escaping () -> Void) {
        self.action = action
        calls.append(.bind)
    }

    func execute() {
        calls.append(.execute)
    }
}
