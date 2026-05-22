//
//  SetupChecklistView.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 09.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AppKit
import AudioSettingsKit
import SwiftUI

struct SetupChecklistView: View {
    let unmet: Set<SetupRequirement>

    var body: some View {
        PlaceholderView {
            Text("Set up the app to start hosting")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
            VStack(alignment: .center, spacing: 8) {
                if unmet.contains(.microphonePermission) {
                    VStack(alignment: .center, spacing: 2) {
                        Button {
                            NSWorkspace.shared.open(URL(
                                string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
                            )!)
                        } label: {
                            Label("Grant microphone access…", systemImage: "mic")
                        }
                        .buttonStyle(.link)
                        Text("After granting access, please restart the app.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if let savedName = unmet.savedOutputDeviceName {
                    VStack(alignment: .center, spacing: 2) {
                        Text("Turn on “\(savedName)”")
                            .font(.body)
                        SettingsLink {
                            Label("…or choose another device", systemImage: "speaker.wave.2")
                        }
                        .buttonStyle(.link)
                    }
                } else if unmet.contains(.noOutputDevice) {
                    SettingsLink {
                        Label("Choose audio devices…", systemImage: "speaker.wave.2")
                    }
                    .buttonStyle(.link)
                }
            }
        }
    }
}

private extension Set<SetupRequirement> {
    var savedOutputDeviceName: String? {
        for requirement in self {
            if case .savedOutputDeviceUnavailable(let name) = requirement {
                return name
            }
        }
        return nil
    }
}
