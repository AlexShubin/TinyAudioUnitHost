//
//  EmptySelectionView.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 16.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import SwiftUI

struct EmptySelectionView: View {
    var body: some View {
        PlaceholderView {
            Text("Add a plug-in or pick a preset")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
            Text(
                "The first time you load a plug-in, macOS might ask you to “lower security settings”. " +
                "This grants this app permission to host plug-ins — it doesn’t affect other apps or your system."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 360)
        }
    }
}
