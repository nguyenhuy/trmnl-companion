//
//  PluginModel.swift
//  Companion
//
//  Created for TRMNL plugin mapping support.
//

import Foundation
import ErrorKit

/// Represents a remote TRMNL plugin
struct PluginModel: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    // periphery:ignore
    let pluginId: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case pluginId = "plugin_id"
        case mappedCalendarIds
    }
    
    /// Calendar IDs mapped to this plugin
    var mappedCalendarIds: Set<String> = []
    
    /// Initialize from API response
    init(from pluginSetting: PluginSetting) {
        self.id = pluginSetting.id
        self.name = pluginSetting.name
        self.pluginId = pluginSetting.pluginId
        self.mappedCalendarIds = []
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: PluginModel, rhs: PluginModel) -> Bool {
        lhs.id == rhs.id
    }
}

/// Manages the mapping between local calendars and remote plugins
@Observable
class PluginMappingManager {
    static let shared = PluginMappingManager()
    
    /// All available plugins from the API
    var plugins: [PluginModel] = []
    
    /// Storage key for persisting mappings
    private let mappingsKey = "trmnl_plugin_mappings"
    
    /// Load plugins from API response
    func loadPlugins(from pluginSettings: [PluginSetting]) {
        // Load saved mappings
        let savedMappings = loadMappings()
        
        // Create plugin models with saved mappings
        self.plugins = pluginSettings.map { setting in
            var plugin = PluginModel(from: setting)
            
            // Restore saved mappings if they exist
            if let savedPlugin = savedMappings.first(where: { $0.id == plugin.id }) {
                plugin.mappedCalendarIds = savedPlugin.mappedCalendarIds
            }
            
            return plugin
        }
    }
    
    /// Map a calendar to a plugin
    func mapCalendar(_ calendarId: String, to pluginId: Int) {
        guard let index = plugins.firstIndex(where: { $0.id == pluginId }) else { return }
        plugins[index].mappedCalendarIds.insert(calendarId)
        saveMappings()
    }
    
    /// Remove a calendar mapping from a plugin
    func unmapCalendar(_ calendarId: String, from pluginId: Int) {
        guard let index = plugins.firstIndex(where: { $0.id == pluginId }) else { return }
        plugins[index].mappedCalendarIds.remove(calendarId)
        saveMappings()
    }
    
    /// Get plugins that have at least one calendar mapped
    func getMappedPlugins() -> [PluginModel] {
        return plugins.filter { !$0.mappedCalendarIds.isEmpty }
    }
    
    /// Clear all mappings
    func clearAllMappings() {
        for index in plugins.indices {
            plugins[index].mappedCalendarIds.removeAll()
        }
        saveMappings()
    }
    
    // MARK: - Persistence
    
    private func saveMappings() {
        let encoder = JSONEncoder()
        do {
            let encoded = try encoder.encode(plugins)
            UserDefaults.standard.set(encoded, forKey: mappingsKey)
        } catch {
            Logger.log.error("Failed to encode and save plugin mappings: %@", error.localizedDescription)
        }
    }
    
    func loadMappings() -> [PluginModel] {
        guard let data = UserDefaults.standard.data(forKey: mappingsKey) else {
            return []
        }
        
        do {
            let plugins = try JSONDecoder().decode([PluginModel].self, from: data)
            return plugins
        } catch {
            Logger.log.error("Failed to decode plugin mappings: %@", error.localizedDescription)
            return []
        }
    }
}
