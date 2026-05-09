//
//  PresetProviderMock.swift
//  PresetKitTestSupport
//
//  Created by Alex Shubin on 09.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import PresetKit

public actor PresetProviderMock: PresetProviderType {
    public enum Calls: Equatable, Sendable {
        case loadDefault
        case loadSession
        case saveDefault(Preset)
        case saveSession(Preset)
        case deleteSession
    }

    public private(set) var calls: [Calls] = []
    public var defaultPreset: Preset?
    public var sessionPreset: Preset?

    public init(defaultPreset: Preset? = nil, sessionPreset: Preset? = nil) {
        self.defaultPreset = defaultPreset
        self.sessionPreset = sessionPreset
    }

    public func loadDefault() -> Preset? {
        calls.append(.loadDefault)
        return defaultPreset
    }

    public func loadSession() -> Preset? {
        calls.append(.loadSession)
        return sessionPreset
    }

    public func saveDefault(_ preset: Preset) {
        defaultPreset = preset
        sessionPreset = nil
        calls.append(.saveDefault(preset))
    }

    public func saveSession(_ preset: Preset) {
        sessionPreset = preset
        calls.append(.saveSession(preset))
    }

    public func deleteSession() {
        sessionPreset = nil
        calls.append(.deleteSession)
    }

    public func setDefaultPreset(_ value: Preset?) {
        defaultPreset = value
    }

    public func setSessionPreset(_ value: Preset?) {
        sessionPreset = value
    }
}
