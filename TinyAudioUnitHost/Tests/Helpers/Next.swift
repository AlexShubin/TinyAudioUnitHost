//
//  Next.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 07.06.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Observation

@MainActor
func next<T>(_ value: () -> T) async {
    await withCheckedContinuation { continuation in
        _ = withObservationTracking(value, onChange: {
            continuation.resume()
        })
    }
}
