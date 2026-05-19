//
//  PurchasesView.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import PurchasesKit
import SwiftUI

struct PurchasesView: View {
    @State var viewModel: PurchasesViewModelType

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "crown.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow.gradient)
                .padding(.top, 32)

            VStack(spacing: 8) {
                Text("Tiny Audio Unit Host Pro")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Save and manage unlimited presets.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if viewModel.state.isPro {
                proSection
            } else {
                buySection
            }

            if let errorMessage = viewModel.state.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .frame(width: 440)
        .task {
            await viewModel.accept(action: .task)
        }
    }

    @ViewBuilder
    private var proSection: some View {
        VStack(spacing: 12) {
            Text("You're Pro.")
                .font(.headline)
                .foregroundStyle(.primary)
            Button("Restore Purchase") {
                Task { await viewModel.accept(action: .restoreTapped) }
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.state.phase == .restoring)
        }
    }

    @ViewBuilder
    private var buySection: some View {
        VStack(spacing: 12) {
            if let price = viewModel.state.productInfo?.displayPrice {
                Text(price)
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            Button {
                Task { await viewModel.accept(action: .buyTapped) }
            } label: {
                if viewModel.state.phase == .purchasing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Upgrade to Pro")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.state.phase != .idle)

            Button("Restore Purchase") {
                Task { await viewModel.accept(action: .restoreTapped) }
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.state.phase == .restoring)
        }
    }
}

struct PurchasesViewState: Sendable, Equatable {
    var isPro: Bool
    var productInfo: ProProductInfo?
    var phase: Phase
    var errorMessage: String?

    enum Phase: Sendable, Equatable {
        case idle
        case purchasing
        case restoring
    }
}

enum PurchasesViewAction: Sendable, Equatable {
    case task
    case buyTapped
    case restoreTapped
}
