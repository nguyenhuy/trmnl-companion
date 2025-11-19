//
//  CompanionApp.swift
//  Companion
//
//  Created by Mustapha Tarek BEN LECHHAB on 23.08.2025.
//

import SwiftUI
import SwiftData
import BackgroundTasks
import AppIntents

extension Notification.Name {
    static let oauthAuthenticationSucceeded = Notification.Name("oauthAuthenticationSucceeded")
}

@main
struct CompanionApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SyncHistory.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
        // Initialize calendar service early
        _ = CalendarService.shared
        
        // Register background tasks - must be done early in app lifecycle
        BackgroundTaskManager.shared.registerBackgroundTasks()
        
        // Register App Shortcuts
        TRMNLShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // Handle OAuth2 callback
                    if OAuth2Service.isOAuthCallback(url: url) {
                        Task {
                            let result = await OAuth2Service.shared.handleCallback(url: url)
                            switch result {
                            case .success(_):
                                Logger.log.info("OAuth2 authentication successful")
                                // Notify the app that authentication succeeded
                                NotificationCenter.default.post(name: .oauthAuthenticationSucceeded, object: nil)
                            case .failure(let error):
                                Logger.log.error("OAuth2 authentication failed: %@", error.userFriendlyMessage)
                            }
                        }
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
