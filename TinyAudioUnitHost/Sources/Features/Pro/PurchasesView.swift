//
//  PurchasesView.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import SwiftUI

struct PurchasesView: View {
    @State var viewModel: PurchasesViewModelType

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: viewModel.isPro ? "star.fill" : "star")
                .font(.system(size: 48))
                .foregroundStyle(viewModel.isPro ? Color.yellow : Color.secondary)
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

            if viewModel.isPro {
                proSection
            } else {
                buySection
            }

            if let errorMessage = viewModel.errorMessage {
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
            .disabled(viewModel.isRestoreButtonDisabled)
        }
    }

    @ViewBuilder
    private var buySection: some View {
        VStack(spacing: 12) {
            if let priceLabel = viewModel.priceLabel {
                Text(priceLabel)
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            Button {
                Task { await viewModel.accept(action: .buyTapped) }
            } label: {
                if viewModel.isPurchasing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Upgrade to Pro")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isUpgradeButtonDisabled)

            Button("Restore Purchase") {
                Task { await viewModel.accept(action: .restoreTapped) }
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.isRestoreButtonDisabled)
        }
    }
}
