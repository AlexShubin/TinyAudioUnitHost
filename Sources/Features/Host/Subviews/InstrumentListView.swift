//
//  InstrumentListView.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import SwiftUI

struct InstrumentListView: View {
    let instruments: [AudioUnitComponent]
    @Binding var selectedID: String?

    var body: some View {
        List(instruments, selection: $selectedID) { instrument in
            VStack(alignment: .leading) {
                Text(instrument.name)
                Text(instrument.manufacturer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .tag(instrument.id)
        }
        .navigationTitle("Instruments")
    }
}
