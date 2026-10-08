//
//  Cancellation.swift
//  Common
//
//  Created by Alex Shubin on 08.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public final class Cancellation: Sendable {
    private let cancel: @Sendable () -> Void

    public init(_ cancel: @escaping @Sendable () -> Void) {
        self.cancel = cancel
    }

    deinit {
        cancel()
    }
}
