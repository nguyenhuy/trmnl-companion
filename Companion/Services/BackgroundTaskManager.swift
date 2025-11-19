//
//  BackgroundTaskManager.swift
//  Companion
//
//  Created for TRMNL Calendar background sync support.
//

import Foundation
import SwiftUI
import BackgroundTasks
import SwiftData
import Observation
import ErrorKit

enum BackgroundTaskError: Throwable {
    case taskSchedulingFailed(String)
    case syncServiceUnavailable
    case noAPIKey
    case noPluginsConfigured
    
    var userFriendlyMessage: String {
        switch self {
        case .taskSchedulingFailed(let reason):
            return "Failed to schedule background sync: \(reason)"
        case .syncServiceUnavailable:
            return "Sync service is not available for sync"
        case .noAPIKey:
            return "Not logged in."
        case .noPluginsConfigured:
            return "No plugins configured for sync"
        }
    }
}

@Observable
class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    
    // Background task identifier - must match Info.plist
    static let backgroundTaskIdentifier = "com.usetrmnl.app.refresh"
    
    // Track if tasks have been registered
    private var hasRegisteredTasks = false
    
    private let backgroundSyncInterval: TimeInterval = 3600 // 1 hour
    
    @ObservationIgnored
    @AppStorage("LastBackgroundSyncTimestamp") private var lastBackgroundSyncTimestamp: TimeInterval = 0

    var lastSyncDate: Date? {
        didSet {
            if let date = lastSyncDate {
                lastBackgroundSyncTimestamp = date.timeIntervalSince1970
            } else {
                lastBackgroundSyncTimestamp = 0
            }
        }
    }
    
    private init() {
        // Load last sync date
        lastSyncDate = lastBackgroundSyncTimestamp > 0 ? Date(timeIntervalSince1970: lastBackgroundSyncTimestamp) : nil
    }
    
    // MARK: - Task Registration
    
    /// Register background task handlers with the system
    /// Should be called from AppDelegate or App initialization
    func registerBackgroundTasks() {
        guard !hasRegisteredTasks else {
            Logger.log.info("Background tasks already registered")
            return
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.backgroundTaskIdentifier,
            using: DispatchQueue.main
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleBackgroundSync(task: refreshTask)
        }
        
        hasRegisteredTasks = true
        Logger.log.info("Registered background task: %@", Self.backgroundTaskIdentifier)
        
        scheduleBackgroundSync()
    }
    
    // MARK: - Task Scheduling
    
    /// Schedule the next background sync
    func scheduleBackgroundSync() {
        // Cancel any existing pending requests first
        BGTaskScheduler.shared.cancelAllTaskRequests()
        
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskIdentifier)
        
        // Calculate earliest begin date based on interval
        let earliestBeginDate = Date(timeIntervalSinceNow: backgroundSyncInterval)
        request.earliestBeginDate = earliestBeginDate
        
        do {
            try BGTaskScheduler.shared.submit(request)
            Logger.log.info("Scheduled background sync for %@", earliestBeginDate.description)
        } catch {
            Logger.log.error("Failed to schedule background task: %@", error.localizedDescription)
        }
    }
    
    /// Cancel all pending background sync tasks
    func cancelBackgroundSync() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.backgroundTaskIdentifier)
        Logger.log.info("Cancelled background sync tasks")
    }
    
    // MARK: - Task Execution
    
    /// Handle the background sync task
    private func handleBackgroundSync(task: BGAppRefreshTask) {
        Logger.log.info("Starting background sync task")
        
        // Schedule the next sync immediately
        scheduleBackgroundSync()
        
        // Create a task to perform the sync
        let syncTask = Task {
            do {
                // Check for OAuth2 token
                let oauth2Service = OAuth2Service.shared
                guard let apiKey = await oauth2Service.getAccessToken() else {
                    throw BackgroundTaskError.noAPIKey
                }
                
                // Ensure calendar access is available
                let calendarService = CalendarService.shared
                guard calendarService.hasCalendarAccess() else {
                    Logger.log.error("Background sync failed: No calendar access")
                    throw BackgroundTaskError.syncServiceUnavailable
                }
                
                // Get plugin mappings
                let mappingManager = PluginMappingManager.shared
                let plugins = mappingManager.loadMappings()
                
                // Filter plugins that have mapped calendars
                let activePlugins = plugins.filter { !$0.mappedCalendarIds.isEmpty }
                
                guard !activePlugins.isEmpty else {
                    throw BackgroundTaskError.noPluginsConfigured
                }
                
                // Create model container for SwiftData
                let schema = Schema([SyncHistory.self])
                let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
                
                // Create a new context for background work
                let modelContext = ModelContext(modelContainer)
                modelContext.autosaveEnabled = false // Disable autosave to control when we save
                
                // Perform the sync
                let syncService = SyncService()
                let result = await syncService.performPluginBasedSync(
                    plugins: activePlugins,
                    apiKey: apiKey,
                    modelContext: modelContext
                )
                
                // Update last sync date
                await MainActor.run {
                    self.lastSyncDate = Date()
                }
                
                // Handle result
                switch result {
                case .success(let syncSuccess):
                    Logger.log.info("Background sync successful: %d events synced to %d plugins", 
                                  syncSuccess.eventCount, syncSuccess.pluginCount)
                    task.setTaskCompleted(success: true)
                    
                case .failure(let error):
                    Logger.log.error("Background sync failed: %@", error.userFriendlyMessage)
                    task.setTaskCompleted(success: false)
                }
                
            } catch {
                Logger.log.error("Background sync error: %@", error.localizedDescription)
                task.setTaskCompleted(success: false)
            }
        }
        
        // Set expiration handler
        task.expirationHandler = {
            Logger.log.warning("Background sync task expired")
            self.scheduleBackgroundSync()
            syncTask.cancel()
        }
    }
}
