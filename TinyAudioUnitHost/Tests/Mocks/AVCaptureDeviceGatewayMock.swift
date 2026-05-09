//
//  AVCaptureDeviceGatewayMock.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 09.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AVFoundation
@testable import TinyAudioUnitHost

final class AVCaptureDeviceGatewayMock: AVCaptureDeviceGatewayType, @unchecked Sendable {
    enum Calls: Equatable, Sendable {
        case authorizationStatus
        case requestAccess
    }

    private(set) var calls: [Calls] = []
    var authorizationStatusResult: AVAuthorizationStatus = .notDetermined
    var requestAccessResult: Bool = true

    init(
        authorizationStatusResult: AVAuthorizationStatus = .notDetermined,
        requestAccessResult: Bool = true
    ) {
        self.authorizationStatusResult = authorizationStatusResult
        self.requestAccessResult = requestAccessResult
    }

    func authorizationStatus(for mediaType: AVMediaType) -> AVAuthorizationStatus {
        calls.append(.authorizationStatus)
        return authorizationStatusResult
    }

    func requestAccess(for mediaType: AVMediaType) async -> Bool {
        calls.append(.requestAccess)
        return requestAccessResult
    }
}
