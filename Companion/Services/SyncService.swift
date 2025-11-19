//
//  SyncService.swift
//  Companion
//
//  Created by Mustapha Tarek BEN LECHHAB on 23.08.2025.
//

import Foundation
import EventKit
import SwiftData
import Observation
import ErrorKit

enum SyncError: Throwable {
    case noCalendarsSelected
    case noEventsFound
    case apiError(APIError)
    case persistenceError(String)
    
    var userFriendlyMessage: String {
        switch self {
        case .noCalendarsSelected:
            return "Please select at least one calendar to sync."
        case .noEventsFound:
            return "No events found in the selected calendars for the sync period."
        case .apiError(let apiError):
            return apiError.userFriendlyMessage
        case .persistenceError(let details):
            return "Failed to save sync history: \(details)"
        }
    }
}

struct SyncSuccess {
    let eventCount: Int
    let syncDuration: TimeInterval
    let pluginCount: Int
    
    init(eventCount: Int, syncDuration: TimeInterval, pluginCount: Int = 1) {
        self.eventCount = eventCount
        self.syncDuration = syncDuration
        self.pluginCount = pluginCount
    }
}

@Observable
class SyncService {
    var isSyncing = false
    var syncProgress: Double = 0
    var lastSyncDate: Date?
    var lastSyncStatus: SyncHistory.SyncStatus?
    var statusMessage: String = ""
    
    private let calendarService = CalendarService.shared
    private let apiService = APIService.shared
    
    init() {
        loadLastSyncInfo()
    }
    
    func refreshLastSyncInfo() {
        loadLastSyncInfo()
    }
    
    private func loadLastSyncInfo() {
        if let lastSync = UserDefaults.standard.object(forKey: "LastSyncDate") as? Date {
            lastSyncDate = lastSync
        }
        if let statusRaw = UserDefaults.standard.string(forKey: "LastSyncStatus"),
           let status = SyncHistory.SyncStatus(rawValue: statusRaw) {
            lastSyncStatus = status
        }
    }
    
    private func saveLastSyncInfo(date: Date, status: SyncHistory.SyncStatus) {
        UserDefaults.standard.set(date, forKey: "LastSyncDate")
        UserDefaults.standard.set(status.rawValue, forKey: "LastSyncStatus")
        lastSyncDate = date
        lastSyncStatus = status
    }
    
    /// Perform sync for multiple plugins with mapped calendars
    /// - Parameters:
    ///   - plugins: Array of plugins with mapped calendar IDs
    ///   - calendarSelection: Calendar selection manager with all calendars
    ///   - apiKey: User's API key
    ///   - modelContext: SwiftData model context for history
    /// - Returns: Success with total event count and plugin count, or failure
    func performPluginBasedSync(
        plugins: [PluginModel],
        apiKey: String,
        modelContext: ModelContext
    ) async -> Result<SyncSuccess, SyncError> {
        await MainActor.run {
            isSyncing = true
            syncProgress = 0
            statusMessage = "Preparing sync..."
        }
        
        let startTime = Date()
        var totalEventCount = 0
        var successfulPlugins = 0
        var failedPlugins: [(plugin: String, error: APIError)] = []
        
        // Fetch events once and cache them per plugin to avoid duplicate API calls
        var pluginEventsCache: [Int: [EKEvent]] = [:]
        var hasAnyEvents = false
        
        for plugin in plugins {
            let calendarIds = plugin.mappedCalendarIds
            let events = await calendarService.fetchEvents(from: calendarIds)
            if !events.isEmpty {
                hasAnyEvents = true
                pluginEventsCache[plugin.id] = events
            }
        }
        
        // If no events found at all, return early with appropriate error
        if !hasAnyEvents {
            await MainActor.run {
                isSyncing = false
                syncProgress = 0
                statusMessage = "No events found"
            }
            
            // Save sync history for zero events
            let syncHistory = SyncHistory(
                timestamp: Date(),
                status: .empty,
                eventCount: 0,
                errorMessage: "No events found in selected calendars",
                syncDuration: Date().timeIntervalSince(startTime)
            )
            
            modelContext.insert(syncHistory)
            Logger.log.info("Inserting empty sync history (no events found)")
            
            do {
                try modelContext.save()
                Logger.log.info("Successfully saved empty sync history")
            } catch {
                Logger.log.error("Failed to save empty sync history: %@", error.localizedDescription)
            }
            
            saveLastSyncInfo(date: Date(), status: .empty)
            
            return .failure(.noEventsFound)
        }
        
        // Calculate progress increments
        let progressPerPlugin = 0.9 / Double(plugins.count)
        var currentProgress = 0.1
        
        // Process each plugin using cached events
        for plugin in plugins {
            let progress = currentProgress
            await MainActor.run {
                statusMessage = "Syncing to \(plugin.name)..."
                syncProgress = progress
            }
            
            // Use cached events instead of fetching again
            guard let events = pluginEventsCache[plugin.id], !events.isEmpty else {
                Logger.log.info("No events found for plugin: %@", plugin.name)
                currentProgress += progressPerPlugin
                continue
            }
            
            // Convert events to EventModel
            let eventModels = events.map { EventModel(from: $0) }
            
            // Send to API for this specific plugin
            let result = await apiService.updatePluginData(
                apiKey: apiKey,
                settingID: plugin.id,
                events: eventModels
            )
            
            switch result {
            case .success(let count):
                totalEventCount += count
                successfulPlugins += 1
                Logger.log.info("Successfully synced %d events to plugin: %@", count, plugin.name)
                
            case .failure(let error):
                failedPlugins.append((plugin: plugin.name, error: error))
                Logger.log.error("Failed to sync to plugin %@: %@", plugin.name, error.userFriendlyMessage)
            }
            
            currentProgress += progressPerPlugin
        }
        
        let syncDuration = Date().timeIntervalSince(startTime)
        let timestamp = Date()
        
        // Determine overall sync status
        let syncStatus: SyncHistory.SyncStatus
        let errorMessage: String?
        
        if successfulPlugins > 0 {
            syncStatus = failedPlugins.isEmpty ? .success : .success
            errorMessage = failedPlugins.isEmpty ? nil : 
                "Partial sync: \(failedPlugins.count) plugin(s) failed"
        } else {
            syncStatus = .failed
            errorMessage = "All plugins failed to sync"
        }
        
        // Create and save sync history
        let syncHistory = SyncHistory(
            timestamp: timestamp,
            status: syncStatus,
            eventCount: totalEventCount,
            errorMessage: errorMessage,
            syncDuration: syncDuration
        )
        
        modelContext.insert(syncHistory)
        Logger.log.info("Inserting sync history: %d events, status: %@", totalEventCount, syncStatus.rawValue)
        
        do {
            try modelContext.save()
            Logger.log.info("Successfully saved sync history to database")
        } catch {
            Logger.log.error("Failed to save sync history: %@", error.localizedDescription)
        }
        
        saveLastSyncInfo(date: timestamp, status: syncStatus)
        
        let finalEventCount = totalEventCount
        let finalPluginCount = successfulPlugins
        await MainActor.run {
            isSyncing = false
            syncProgress = 1.0
            if finalPluginCount > 0 {
                statusMessage = "Synced \(finalEventCount) events to \(finalPluginCount) plugin(s)"
            } else {
                statusMessage = "Sync failed"
            }
        }
        
        // Return appropriate result
        if successfulPlugins > 0 {
            return .success(SyncSuccess(
                eventCount: totalEventCount,
                syncDuration: syncDuration,
                pluginCount: successfulPlugins
            ))
        } else {
            // Return the first error encountered if all syncs failed
            if let firstError = failedPlugins.first?.error {
                return .failure(.apiError(firstError))
            } else {
                // This should rarely happen - only if no plugins were processed
                return .failure(.apiError(.noPluginSettingFound))
            }
        }
    }
}
