//
//  ContentView.swift
//  Companion
//
//  Created by Mustapha Tarek BEN LECHHAB on 23.08.2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {    
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            SyncView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                }
                .tag(0)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(1)
        }
        .tint(AppTheme.primaryOrange)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: SyncHistory.self, inMemory: true)
}
