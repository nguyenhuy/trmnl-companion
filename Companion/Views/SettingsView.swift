//
//  SettingsView.swift
//  Companion
//
//  Created by Mustapha Tarek BEN LECHHAB on 23.08.2025.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = SettingsViewModel()
    @State private var showingClearHistoryAlert = false
    @State private var showingOAuth2Login = false
    @State private var oauth2LoginURL: URL?
    
    var body: some View {
        NavigationStack {
            Form {
                // API Configuration Section
                Section {
                    if viewModel.isAuthenticated {
                        // Show authenticated state
                        HStack {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .foregroundColor(.green)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Connected")
                                    .font(.body)
                                    .foregroundColor(AppTheme.labelColor)
                                
                                if let user = viewModel.currentUser {
                                    Text(user.email)
                                        .font(.caption)
                                        .foregroundColor(AppTheme.secondaryLabelColor)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        
                        Button(action: {
                            viewModel.signOut()
                        }) {
                            HStack {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.red)
                                    .frame(width: 30)
                                
                                Text("Disconnect")
                                    .foregroundColor(.red)
                            }
                        }
                    } else {
                        // Show unauthenticated state
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.xmark")
                                    .foregroundColor(AppTheme.tertiaryLabelColor)
                                    .frame(width: 30)
                                
                                VStack(alignment: .leading) {
                                    Text("Not Connected")
                                        .font(.body)
                                        .foregroundColor(AppTheme.labelColor)
                                    
                                    Text("Login to connect your TRMNL account")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.secondaryLabelColor)
                                }
                            }
                            
                            Button(action: {
                                if let url = viewModel.startOAuth2Login() {
                                    oauth2LoginURL = url
                                    showingOAuth2Login = true
                                }
                            }) {
                                HStack {
                                    if viewModel.isAuthenticating {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .frame(width: 20, height: 20)
                                    } else {
                                        Image(systemName: "key")
                                    }
                                    Text("Login")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.isAuthenticating)
                            
                            if let oauth2Error = viewModel.oauth2Error {
                                Text(oauth2Error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                            }
                            
                            Text("Login")
                                .font(.caption)
                                .foregroundColor(AppTheme.tertiaryLabelColor)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                
                // Sync History Section
                Section("Sync History") {
                    if viewModel.syncHistoryItems.isEmpty {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(AppTheme.tertiaryLabelColor)
                                .frame(width: 30)
                            
                            Text("No sync history")
                                .foregroundColor(AppTheme.secondaryLabelColor)
                        }
                        .padding(.vertical, 8)
                    } else {
                        ForEach(viewModel.syncHistoryItems.prefix(5)) { item in
                            HStack {
                                Image(systemName: item.status.systemImageName)
                                    .foregroundColor(item.status.color)
                                    .frame(width: 30)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(viewModel.formatDate(item.timestamp))
                                        .font(.body)
                                    
                                    HStack {
                                        Text("\(item.eventCount) events")
                                            .font(.caption)
                                            .foregroundColor(AppTheme.secondaryLabelColor)
                                        
                                        Text("•")
                                            .font(.caption)
                                            .foregroundColor(AppTheme.tertiaryLabelColor)
                                        
                                        Text(viewModel.formatDuration(item.syncDuration))
                                            .font(.caption)
                                            .foregroundColor(AppTheme.secondaryLabelColor)
                                    }
                                    
                                    if let error = item.errorMessage {
                                        Text(error)
                                            .font(.caption)
                                            .foregroundColor(.red)
                                            .lineLimit(2)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        
                        Button(action: {
                            showingClearHistoryAlert = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .frame(width: 30)
                                
                                Text("Clear History")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                
                // Support Section
                Section("Support") {
                    Link(destination: URL(string: "https://help.usetrmnl.com")!) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(AppTheme.primaryOrange)
                                .frame(width: 30)
                            
                            Text("Help & Documentation")
                                .foregroundColor(AppTheme.labelColor)
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(AppTheme.tertiaryLabelColor)
                        }
                    }
                    
                    Link(destination: URL(string: "mailto:support@usetrmnl.com")!) {
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundColor(AppTheme.primaryOrange)
                                .frame(width: 30)
                            
                            Text("Contact Support")
                                .foregroundColor(AppTheme.labelColor)
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(AppTheme.tertiaryLabelColor)
                        }
                    }
                }
                
                // App Info Section
                Section("About") {
                    HStack {
                        Image(systemName: "app.badge")
                            .foregroundColor(AppTheme.primaryOrange)
                            .frame(width: 30)
                        
                        Text("Version")
                        Spacer()
                        Text("\(viewModel.appVersion) (\(viewModel.buildNumber))")
                            .foregroundColor(AppTheme.secondaryLabelColor)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.refreshUserData()
                viewModel.loadSyncHistory(from: modelContext)
            }
        }
        .onAppear {
            viewModel.loadSyncHistory(from: modelContext)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Reload sync history when app returns from background
            viewModel.loadSyncHistory(from: modelContext)
        }
        .onReceive(NotificationCenter.default.publisher(for: .oauthAuthenticationSucceeded)) { _ in
            // Refresh user data when OAuth2 authentication succeeds
            Task {
                await viewModel.refreshUserData()
            }
            showingOAuth2Login = false
        }
        .alert("Clear Sync History", isPresented: $showingClearHistoryAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                viewModel.clearSyncHistory(from: modelContext)
            }
        } message: {
            Text("Are you sure you want to clear all sync history? This action cannot be undone.")
        }
        .sheet(isPresented: $showingOAuth2Login) {
            if let url = oauth2LoginURL {
                OAuth2LoginView(
                    isPresented: $showingOAuth2Login,
                    authURL: url,
                    onCompletion: {
                        // OAuth2 callback will be handled by CompanionApp
                        oauth2LoginURL = nil
                    },
                    onCancellation: {
                        // Reset authentication state when user cancels
                        viewModel.cancelOAuth2Login()
                    }
                )
            }
        }
    }
}
