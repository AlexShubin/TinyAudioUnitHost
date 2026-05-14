//
//  LoadingView.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 14.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import SwiftUI

struct LoadingView: View {
    var body: some View {
        PlaceholderView {
            ProgressView()
                .foregroundStyle(.secondary)
        }
    }
}
