//
//  SetupChecklistView.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 09.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AppKit
import SwiftUI

struct SetupChecklistView: View {
    let unmet: Set<SetupRequirement>

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
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
                if unmet.contains(.outputDevice) {
                    SettingsLink {
                        Label("Choose audio devices…", systemImage: "speaker.wave.2")
                    }
                    .buttonStyle(.link)
                }
            }
        }
    }
}
