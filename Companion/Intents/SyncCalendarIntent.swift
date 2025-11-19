import AppIntents
import SwiftData

struct SyncCalendarIntent: AppIntent {
    static var title: LocalizedStringResource = "Sync Calendar"
    static var description = IntentDescription("Syncs all configured calendars to TRMNL")
    
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let syncService = SyncService()
        let oauth2Service = OAuth2Service.shared
        
        guard oauth2Service.isAuthenticated else {
            throw SyncIntentError.notAuthenticated
        }
        
        let modelContainer = try ModelContainer(for: SyncHistory.self)
        let modelContext = ModelContext(modelContainer)
        
        let pluginMappingManager = PluginMappingManager()
        let selectedPlugins = pluginMappingManager.loadMappings()
        
        let mappedPlugins = selectedPlugins.filter { !$0.mappedCalendarIds.isEmpty }
        guard !mappedPlugins.isEmpty else {
            throw SyncIntentError.noCalendarsMapped
        }
        
        let result = await syncService.performPluginBasedSync(
            plugins: mappedPlugins,
            apiKey: oauth2Service.currentToken?.accessToken ?? "",
            modelContext: modelContext
        )
        
        switch result {
        case .success(let syncSuccess):
            let message = "Synced \(syncSuccess.eventCount) events"
            return .result(dialog: IntentDialog(stringLiteral: message))
        case .failure(let error):
            throw SyncIntentError.syncFailed(error.userFriendlyMessage)
        }
    }
}

enum SyncIntentError: LocalizedError {
    case notAuthenticated
    case noCalendarsMapped
    case syncFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please log in to TRMNL first"
        case .noCalendarsMapped:
            return "No calendars mapped to plugins. Please map calendars in the app"
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        }
    }
}