//
//  SyncButton.swift
//  Companion
//
//  Created by Mustapha Tarek BEN LECHHAB on 23.08.2025.
//

import SwiftUI

struct SyncButton: View {
    let action: () async -> Void
    let isEnabled: Bool
    @Binding var isSyncing: Bool
    @Binding var syncProgress: Double
    
    var body: some View {
        Button(action: {
            Task {
                await action()
            }
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .fill(isEnabled && !isSyncing ? AppTheme.primaryOrange : Color.gray.opacity(0.3))
                    .frame(height: 56)
                
                if isSyncing {
                    HStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                        
                        Text("Syncing...")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if syncProgress > 0 {
                            Text("\(Int(syncProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.title3)
                            .foregroundColor(.white)
                        
                        Text("Sync Now")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .disabled(!isEnabled || isSyncing)
        .animation(.easeInOut, value: isSyncing)
    }
}