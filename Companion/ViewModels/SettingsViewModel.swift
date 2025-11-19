//
//  SettingsViewModel.swift
//  Companion
//
//  Created by Mustapha Tarek BEN LECHHAB on 23.08.2025.
//

import Foundation
import SwiftUI
import SwiftData
import Observation

@Observable
@MainActor
class SettingsViewModel {
    var appVersion: String = ""
    var buildNumber: String = ""
    var syncHistoryItems: [SyncHistory] = []
    
    // OAuth2 Configuration
    private let oauth2Service = OAuth2Service.shared
    var currentUser: User?
    var isRefreshing = false
    
    // OAuth2 authentication state
    var isAuthenticating: Bool {
        oauth2Service.isAuthenticating
    }
    
    var oauth2Error: String? {
        oauth2Service.authenticationError?.userFriendlyMessage
    }
    
    // Background Sync Configuration
    private let backgroundTaskManager = BackgroundTaskManager.shared
    
    var lastBackgroundSyncDate: Date? {
        backgroundTaskManager.lastSyncDate
    }
    
    var isTestingBackgroundSync = false
    
    var isAuthenticated: Bool {
        return oauth2Service.isAuthenticated
    }
    
    init() {
        loadAppInfo()
        loadUserFromToken()
    }
    
    private func loadAppInfo() {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            appVersion = version
        }
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            buildNumber = build
        }
    }
    
    func loadSyncHistory(from modelContext: ModelContext) {
        let descriptor = FetchDescriptor<SyncHistory>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            syncHistoryItems = try modelContext.fetch(descriptor)
        } catch {
            Logger.log.error("Failed to fetch sync history: %@", error.localizedDescription)
        }
    }
    
    func clearSyncHistory(from modelContext: ModelContext) {
        for item in syncHistoryItems {
            modelContext.delete(item)
        }
        
        do {
            try modelContext.save()
            syncHistoryItems.removeAll()
        } catch {
            Logger.log.error("Failed to clear sync history: %@", error.localizedDescription)
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return String(format: "%.0fms", duration * 1000)
        } else if duration < 60 {
            return String(format: "%.1fs", duration)
        } else {
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            return String(format: "%dm %ds", minutes, seconds)
        }
    }
    
    // MARK: - User Data Management
    
    private func loadUserFromToken() {
        // Load user data if we have a valid OAuth2 token
        if oauth2Service.isAuthenticated {
            Task {
                await refreshUserData()
            }
        }
    }
    
    func refreshUserData() async {
        guard let token = await oauth2Service.getAccessToken() else { return }
        
        isRefreshing = true
        
        let result = await APIService.shared.getCurrentUser(apiKey: token)
        
        isRefreshing = false
        
        switch result {
        case .success(let user):
            currentUser = user
        case .failure(let error):
            // Don't clear the user on refresh failure, but log the error
            Logger.log.error("Failed to refresh user data: %@", error.userFriendlyMessage)
        }
    }
    
    // MARK: - OAuth2 Authentication
    
    func startOAuth2Login() -> URL? {
        return oauth2Service.startAuthentication()
    }

    func cancelOAuth2Login() {
        oauth2Service.cancelAuthentication()
    }

    func signOut() {
        oauth2Service.signOut()
        currentUser = nil
    }
    
    func getCurrentAccessToken() async -> String? {
        return await oauth2Service.getAccessToken()
    }
}
