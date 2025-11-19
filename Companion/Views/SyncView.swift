//
//  SyncView.swift
//  Companion
//
//  Created by Mustapha Tarek BEN LECHHAB on 23.08.2025.
//

import SwiftUI
import SwiftData

struct SyncView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = SyncViewModel()
    @Binding var selectedTab: Int
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with logo and status
            VStack(spacing: 16) {
                Image("trmnl-logo-brand")
                    .foregroundColor(.white)
                
                // Show different content based on login status
                if viewModel.hasApiKey {
                    // Last sync info
                    if let lastSyncDate = viewModel.syncService.lastSyncDate {
                        VStack(spacing: 4) {
                            Text("Last Sync")
                                .font(.caption)
                                .foregroundColor(AppTheme.secondaryLabelColor)
                            
                            Text("\(lastSyncDate, style: .relative) ago")
                                .font(.caption)
                                .foregroundColor(AppTheme.primaryOrange)
                            
                            if let status = viewModel.syncService.lastSyncStatus {
                                HStack(spacing: 4) {
                                    Image(systemName: status.systemImageName)
                                        .font(.caption)
                                        .foregroundColor(status.color)
                                    
                                    Text(status.label)
                                        .font(.caption)
                                        .foregroundColor(status.color)
                                }
                            }
                        }
                    }
                } else {
                    Text("Connect to TRMNL")
                        .font(.headline)
                        .foregroundColor(AppTheme.labelColor)
                    
                    Text("Login to sync your calendars")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryLabelColor)
                }
            }
            .padding()
            
            Divider()
            
            // Main content area
            if !viewModel.hasApiKey {
                // Show login button when not authenticated
                Spacer()
                
                VStack(spacing: 24) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(AppTheme.primaryOrange)
                    
                    VStack(spacing: 8) {
                        Text("Login Required")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.labelColor)
                        
                        Text("Connect your TRMNL account to sync calendars")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(AppTheme.secondaryLabelColor)
                            .padding(.horizontal)
                    }
                    
                    Button(action: {
                        selectedTab = 1 // Switch to Settings tab
                    }) {
                        HStack {
                            Image(systemName: "gear")
                            Text("Log in to TRMNL")
                        }
                        .frame(maxWidth: 280)
                        .padding()
                        .background(AppTheme.primaryOrange)
                        .foregroundColor(.white)
                        .cornerRadius(AppTheme.cornerRadius)
                    }
                }
                
                Spacer()
                
            } else if viewModel.isLoadingPlugins || viewModel.isLoadingCalendars {
                // Loading state
                Spacer()
                ProgressView("Loading...")
                    .padding()
                Spacer()
                
            } else if !viewModel.calendarService.hasCalendarAccess() {
                // Calendar access required
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.largeTitle)
                        .foregroundColor(AppTheme.tertiaryLabelColor)
                    
                    Text("Calendar Access Required")
                        .font(.headline)
                        .foregroundColor(AppTheme.labelColor)
                    
                    Text("Please grant calendar access in Settings to sync your events.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(AppTheme.secondaryLabelColor)
                        .padding(.horizontal)
                    
                    Button("Open Settings") {
                        viewModel.openSettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.primaryOrange)
                }
                Spacer()
                
            } else {
                // Show plugin mapping interface
                ScrollView {
                    VStack(spacing: 20) {
                        // Plugin mapping section
                        PluginMappingView(
                            pluginManager: viewModel.pluginMappingManager,
                            calendarSelection: viewModel.calendarSelection
                        )
                        .padding(.top)
                    }
                }
                
                // Sync button
                SyncButton(
                    action: {
                        await viewModel.performSync(modelContext: modelContext)
                    },
                    isEnabled: !viewModel.pluginMappingManager.getMappedPlugins().isEmpty,
                    isSyncing: $viewModel.syncService.isSyncing,
                    syncProgress: $viewModel.syncService.syncProgress
                )
                .padding()
            }
            
            // Status message
            if !viewModel.syncService.statusMessage.isEmpty && viewModel.hasApiKey {
                Text(viewModel.syncService.statusMessage)
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryLabelColor)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
        .refreshable {
            // Always allow refresh, even when not logged in
            await viewModel.initialize()
        }
        .onChange(of: selectedTab) { _, newTab in
            // Reload when returning to this tab
            if newTab == 0 {
                Task {
                    await viewModel.initialize()
                }
            }
        }
        .onAppear {
            // Check for API key changes when view appears
            Task {
                await viewModel.initialize()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Refresh sync info when app returns from background
            viewModel.syncService.refreshLastSyncInfo()
        }
        .onReceive(NotificationCenter.default.publisher(for: .oauthAuthenticationSucceeded)) { _ in
            // Reload when OAuth2 authentication succeeds
            Task {
                await viewModel.initialize()
            }
        }
        .alert(viewModel.alertTitle, isPresented: $viewModel.showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
        .toast(
            isShowing: $viewModel.showingToast,
            message: viewModel.toastMessage,
            isSuccess: viewModel.isToastSuccess
        )
    }
}

#Preview {
    SyncView(selectedTab: .constant(0))
        .modelContainer(for: SyncHistory.self, inMemory: true)
}
