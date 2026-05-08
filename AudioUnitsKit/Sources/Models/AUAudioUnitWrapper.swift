//
//  AUAudioUnitWrapper.swift
//  AudioUnitsKit
//
//  Created by Alex Shubin on 06.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AppKit
import CoreAudioKit

public final class AUAudioUnitWrapper: AUAudioUnitType, @unchecked Sendable {
    private let au: AUAudioUnit
    private let token: AUParameterObserverToken?
    private let continuation: AsyncStream<Void>.Continuation
    public let modifications: AsyncStream<Void>

    public init(_ au: AUAudioUnit) {
        self.au = au
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        self.modifications = stream
        self.continuation = continuation
        self.token = au.parameterTree?.token(byAddingParameterObserver: { _, _ in
            continuation.yield()
        })
    }

    deinit {
        if let token {
            au.parameterTree?.removeParameterObserver(token)
        }
        continuation.finish()
    }

    public var fullState: Data? {
        get { au.fullState?.binaryPlist }
        set { au.fullState = newValue?.asStringAnyDictionary }
    }

    @MainActor
    public func requestViewController() async -> NSViewController? {
        await withCheckedContinuation { continuation in
            au.requestViewController { continuation.resume(returning: $0) }
        }
    }
}

private extension [String: Any] {
    var binaryPlist: Data? {
        try? PropertyListSerialization.data(fromPropertyList: self, format: .binary, options: 0)
    }
}

private extension Data {
    var asStringAnyDictionary: [String: Any]? {
        let plist = try? PropertyListSerialization.propertyList(from: self, options: [], format: nil)
        return plist as? [String: Any]
    }
}
