//
//  AVCaptureDeviceGatewayMock.swift
//  AudioSettingsKitTestSupport
//
//  Created by Alex Shubin on 09.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import AVFoundation

public final class AVCaptureDeviceGatewayMock: AVCaptureDeviceGatewayType, @unchecked Sendable {
    public enum Calls: Equatable, Sendable {
        case authorizationStatus
        case requestAccess
    }

    public private(set) var calls: [Calls] = []
    public var authorizationStatusResult: AVAuthorizationStatus = .notDetermined
    public var requestAccessResult: Bool = true

    public init(
        authorizationStatusResult: AVAuthorizationStatus = .notDetermined,
        requestAccessResult: Bool = true
    ) {
        self.authorizationStatusResult = authorizationStatusResult
        self.requestAccessResult = requestAccessResult
    }

    public func authorizationStatus(for mediaType: AVMediaType) -> AVAuthorizationStatus {
        calls.append(.authorizationStatus)
        return authorizationStatusResult
    }

    public func requestAccess(for mediaType: AVMediaType) async -> Bool {
        calls.append(.requestAccess)
        return requestAccessResult
    }
}
