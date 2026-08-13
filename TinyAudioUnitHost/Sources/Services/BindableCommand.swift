//
//  BindableCommand.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 13.08.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation

@MainActor
protocol CommandType: AnyObject, Sendable {
    func execute()
}

@MainActor
protocol CommandBinderType: AnyObject, Sendable {
    func bind(_ action: @escaping () -> Void)
}

@MainActor
final class BindableCommand: CommandType, CommandBinderType {
    private var action: (() -> Void)?

    nonisolated init() {}

    func bind(_ action: @escaping () -> Void) {
        self.action = action
    }

    func execute() {
        action?()
    }
}
