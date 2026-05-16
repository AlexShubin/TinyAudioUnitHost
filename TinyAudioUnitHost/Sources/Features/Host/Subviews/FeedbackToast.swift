//
//  FeedbackToast.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 15.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
import SwiftUI

struct FeedbackToast: View {
    let state: FeedbackToastViewState
    let onAction: (FeedbackToastAction) -> Void

    var body: some View {
        Label(state.kind.message, systemImage: state.kind.systemImage)
            .foregroundStyle(.green)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: .capsule)
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            .task(id: state.id) {
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                onAction(.timedOut)
            }
    }
}

enum FeedbackToastAction {
    case timedOut
}

struct FeedbackToastViewState: Sendable, Equatable {
    enum Kind: Sendable, Equatable {
        case saved
        case restored
    }

    let id: UUID
    let kind: Kind
}

private extension FeedbackToastViewState.Kind {
    var message: String {
        switch self {
        case .saved: "Saved"
        case .restored: "Restored"
        }
    }

    var systemImage: String {
        switch self {
        case .saved: "checkmark.circle.fill"
        case .restored: "arrow.uturn.backward.circle.fill"
        }
    }
}
