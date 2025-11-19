//
//  SyncViewModel.swift
//  Companion
//
//  Created by Mustapha Tarek BEN LECHHAB on 23.08.2025.
//

import Foundation
import SwiftUI
import EventKit
import SwiftData
import ErrorKit
import Observation

@Observable
@MainActor
class SyncViewModel {
    var calendarSelection = CalendarSelectionManager()
    var pluginMappingManager = PluginMappingManager()
    var isLoadingCalendars = false
    var isLoadingPlugins = false
    var showingAlert = false
    var alertMessage = ""
    var alertTitle = ""
    var showingToast = false
    var toastMessage = ""
    var isToastSuccess = true
    
    private let oauth2Service = OAuth2Service.shared
    
    let calendarService = CalendarService.shared
    var syncService = SyncService()
    
    var hasApiKey: Bool {
        oauth2Service.isAuthenticated
    }
    
    init() {
        Task {
            await initialize()
        }
    }
    
    func initialize() async {
        syncService.statusMessage = ""
        // Check OAuth2 authentication first
        if hasApiKey {
            // Load plugins
            await loadPlugins()
            // Then load calendars
            await checkPermissionsAndLoadCalendars()
        } else {
            await MainActor.run {
                syncService.statusMessage = "Please login to syncrhonize your calendars"
            }
        }
    }
    
    func loadPlugins() async {
        guard hasApiKey else { return }
        
        isLoadingPlugins = true
        
        guard let token = await oauth2Service.getAccessToken() else { return }
        let result = await APIService.shared.getPluginSettings(apiKey: token)
        
        switch result {
        case .success(let pluginSettings):
            pluginMappingManager.loadPlugins(from: pluginSettings)
        case .failure(let error):
            Logger.log.error("Failed to load plugins: %@", error.userFriendlyMessage)
            // Don't show alert for plugin loading failure - handle silently
        }
        
        isLoadingPlugins = false
    }
    
    func checkPermissionsAndLoadCalendars() async {
        isLoadingCalendars = true
        
        if !calendarService.hasCalendarAccess() {
            let granted = await calendarService.requestAccess()
            if !granted {
                alertTitle = "Calendar Access Required"
                alertMessage = "Please grant calendar access in Settings to sync your events."
                showingAlert = true
                isLoadingCalendars = false
                return
            }
        }
        
        await calendarService.loadCalendars()
        calendarSelection.loadCalendars(from: calendarService.calendars)
        isLoadingCalendars = false
    }
    
    func performSync(modelContext: ModelContext) async {
        // Check if API key is configured
        guard hasApiKey else {
            alertTitle = "Login Required"
            alertMessage = "Please login to your TRMNL account first."
            showingAlert = true
            return
        }
        
        // Get mapped plugins
        let mappedPlugins = pluginMappingManager.getMappedPlugins()
        guard !mappedPlugins.isEmpty else {
            alertTitle = "No Calendar Mappings"
            alertMessage = "Please map at least one calendar to a plugin before syncing."
            showingAlert = true
            return
        }
        
        // Perform sync
        guard let token = await oauth2Service.getAccessToken() else {
            await MainActor.run {
                alertTitle = "Authentication Error"
                alertMessage = "Please login"
                showingAlert = true
            }
            return
        }
        
        let result = await syncService.performPluginBasedSync(
            plugins: mappedPlugins,
            apiKey: token,
            modelContext: modelContext
        )
        
        switch result {
        case .success(let syncSuccess):
            // Show success as a toast notification
            let eventText = syncSuccess.eventCount == 1 ? "event" : "events"
            let pluginText = syncSuccess.pluginCount == 1 ? "plugin" : "plugins"
            toastMessage = "Synced \(syncSuccess.eventCount) \(eventText) to \(syncSuccess.pluginCount) \(pluginText)"
            isToastSuccess = true
            showingToast = true
            
        case .failure(let error):
            // Show errors as alerts (more prominent for issues that need attention)
            if case .noEventsFound = error {
                alertTitle = "No Events to Sync"
                alertMessage = "No events were found in the selected calendars for the sync period."
            } else {
                alertTitle = "Sync Failed"
                alertMessage = error.userFriendlyMessage
            }
            showingAlert = true
        }
    }
    
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
