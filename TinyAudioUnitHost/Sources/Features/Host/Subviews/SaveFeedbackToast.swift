//
//  SaveFeedbackToast.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 15.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import SwiftUI

struct SaveFeedbackToast: View {
    let id: UUID
    let onTimeout: () -> Void

    var body: some View {
        Label("Saved", systemImage: "checkmark.circle.fill")
            .foregroundStyle(.green)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: .capsule)
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            .task(id: id) {
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                onTimeout()
            }
    }
}
