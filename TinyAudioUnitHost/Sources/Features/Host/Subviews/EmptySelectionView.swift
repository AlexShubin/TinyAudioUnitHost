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
            Text("Select an audio unit")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
            Text(
                "The first time you load an audio unit, macOS will ask you to “lower security settings”. " +
                "This grants this app permission to host plugins — it doesn’t affect other apps or your system."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 360)
        }
    }
}
