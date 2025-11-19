//
//  APIService.swift
//  Companion
//
//  Created by Mustapha Tarek BEN LECHHAB on 23.08.2025.
//

import Foundation
import ErrorKit

// MARK: - Data Models

/// User data returned from the /me endpoint
struct User: Codable {
    // periphery:ignore
    let name: String
    // periphery:ignore
    let email: String
    // periphery:ignore
    let firstName: String
    // periphery:ignore
    let lastName: String
    // periphery:ignore
    let locale: String
    // periphery:ignore
    let timeZone: String
    // periphery:ignore
    let timeZoneIANA: String
    // periphery:ignore
    let utcOffset: Int
    // periphery:ignore
    let apiKey: String?

    enum CodingKeys: String, CodingKey {
        case name
        case email
        case firstName = "first_name"
        case lastName = "last_name"
        case locale
        case timeZone = "time_zone"
        case timeZoneIANA = "time_zone_iana"
        case utcOffset = "utc_offset"
        case apiKey = "api_key"
    }
}

/// Plugin setting data returned from /plugin_settings
struct PluginSetting: Codable {
    let id: Int
    let name: String
    let pluginId: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case pluginId = "plugin_id"
    }
}

/// Response wrappers for API responses
struct UserResponse: Codable {
    let data: User
}

struct PluginSettingsResponse: Codable {
    let data: [PluginSetting]
}

/// Wrapper for events payload to match API requirements
struct EventsPayload: Codable {
    // periphery:ignore
    let events: [EventModel]
}

/// Final payload structure for updating plugin data
struct MergeVariablesPayload: Codable {
    // periphery:ignore
    let mergeVariables: EventsPayload
    
    enum CodingKeys : String, CodingKey {
        case mergeVariables = "merge_variables"
    }
}

// MARK: - Errors

enum APIError: Throwable {
    case invalidURL
    case encodingFailed(String)
    case networkError(NetworkErrorType)
    case httpError(HTTPErrorType)
    case invalidResponse
    case noAPIKey
    case noPluginSettingFound
    
    enum NetworkErrorType {
        case noConnection
        case timeout
        case other(String)
    }
    
    enum HTTPErrorType {
        case unauthorized
        case badRequest
        case serverError
        case notFound
        case dataCannotBeModified
        case unexpectedStatus(Int)
    }
    
    var userFriendlyMessage: String {
        switch self {
        case .invalidURL:
            return "Invalid server configuration. Please contact support."
        case .encodingFailed(let details):
            return "Failed to prepare data for sync: \(details)"
        case .networkError(let type):
            switch type {
            case .noConnection:
                return "No internet connection. Please check your network and try again."
            case .timeout:
                return "Request timed out. Please try again."
            case .other(let message):
                return "Network error: \(message)"
            }
        case .httpError(let type):
            switch type {
            case .unauthorized:
                return "Authentication failed, please log out and try again."
            case .badRequest:
                return "Invalid request format. Please contact support."
            case .serverError:
                return "Server error. Please try again later."
            case .notFound:
                return "Resource not found. Please check your configuration."
            case .dataCannotBeModified:
                return "Plugin data cannot be modified. Please check your permissions."
            case .unexpectedStatus(let code):
                return "Unexpected server response (code: \(code)). Please try again."
            }
        case .invalidResponse:
            return "Invalid response from server. Please try again."
        case .noAPIKey:
            return "Not logged in, please login in settings."
        case .noPluginSettingFound:
            return "Calendar plugin not found in your account. Please ensure it's enabled on TRMNL."
        }
    }
}

// MARK: - API Service

/// Service responsible for all TRMNL API interactions
///
/// ## Workflow:
/// 1. User configures API key in Settings (obtainable from https://usetrmnl.com/account)
/// 2. App validates the key using `getCurrentUser()`
/// 3. During sync:
///    - Fetch plugin settings for the calendar plugin (ID: 58)
///    - Extract the plugin setting ID from the response
///    - Update plugin data with calendar events
///
/// ## Authentication:
/// All endpoints require the API key in the Authorization header as "Bearer {apikey}"
/// API key is stored using @AppStorage for persistence
class APIService {
    static let shared = APIService()
    
    // MARK: - Constants
    
    /// Base URL for all API endpoints
    private let baseURL = "https://usetrmnl.com/api"
    
    /// Default plugin ID for the calendar plugin
    private let calendarPluginID = "calendars"
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Get current user data
    /// - Parameter apiKey: The user's API key
    /// - Returns: User data on success, APIError on failure
    ///
    /// Endpoint: GET /me
    /// Used to validate the API key and get user information
    func getCurrentUser(apiKey: String) async -> Result<User, APIError> {
        guard !apiKey.isEmpty else {
            return .failure(.noAPIKey)
        }
        
        guard let url = URL(string: "\(baseURL)/me") else {
            return .failure(.invalidURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }
            
            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                let userResponse = try decoder.decode(UserResponse.self, from: data)
                return .success(userResponse.data)
            case 401:
                return .failure(.httpError(.unauthorized))
            default:
                return .failure(.httpError(.unexpectedStatus(httpResponse.statusCode)))
            }
        } catch let urlError as URLError {
            return .failure(handleURLError(urlError))
        } catch {
            return .failure(.networkError(.other(error.localizedDescription)))
        }
    }
    
    /// Get plugin settings for a specific plugin
    /// - Parameters:
    ///   - apiKey: The user's API key
    ///   - pluginID: The plugin ID to query (defaults to calendar plugin: 58)
    /// - Returns: Array of plugin settings on success, APIError on failure
    ///
    /// Endpoint: GET /plugin_settings?plugin_id={id}
    /// Used to get the plugin setting ID needed for updating data
    func getPluginSettings(apiKey: String, pluginID: String? = nil) async -> Result<[PluginSetting], APIError> {
        guard !apiKey.isEmpty else {
            return .failure(.noAPIKey)
        }
        
        let id = pluginID ?? calendarPluginID
        guard let url = URL(string: "\(baseURL)/plugin_settings?plugin_id=\(id)") else {
            return .failure(.invalidURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }
            
            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                let settingsResponse = try decoder.decode(PluginSettingsResponse.self, from: data)
                return .success(settingsResponse.data)
            case 401:
                return .failure(.httpError(.unauthorized))
            default:
                return .failure(.httpError(.unexpectedStatus(httpResponse.statusCode)))
            }
        } catch let urlError as URLError {
            return .failure(handleURLError(urlError))
        } catch {
            return .failure(.networkError(.other(error.localizedDescription)))
        }
    }
    
    /// Update plugin data with calendar events
    /// - Parameters:
    ///   - apiKey: The user's API key
    ///   - settingID: The plugin setting ID obtained from getPluginSettings
    ///   - events: Array of calendar events to sync
    /// - Returns: Number of events synced on success, APIError on failure
    ///
    /// Endpoint: POST /plugin_settings/{id}/data
    /// Payload format: { "merge_variables": { "events": [...] } }
    func updatePluginData(apiKey: String, settingID: Int, events: [EventModel]) async -> Result<Int, APIError> {
        guard !apiKey.isEmpty else {
            return .failure(.noAPIKey)
        }
        
        guard let url = URL(string: "\(baseURL)/plugin_settings/\(settingID)/data") else {
            return .failure(.invalidURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            // Create the properly nested payload
            let eventsPayload = EventsPayload(events: events)
            let payload = MergeVariablesPayload(mergeVariables: eventsPayload)
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(payload)
            request.httpBody = jsonData
            
            #if DEBUG
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                Logger.log.info("Sending JSON to plugin_settings/%d/data: %@", settingID, jsonString)
            }
            #endif
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }
            
            #if DEBUG
            if let responseData = String(data: data, encoding: .utf8) {
                Logger.log.info("Server response: %@", responseData)
            }
            #endif
            
            switch httpResponse.statusCode {
            case 200...299:
                return .success(events.count)
            case 401:
                return .failure(.httpError(.unauthorized))
            case 404:
                return .failure(.httpError(.notFound))
            case 422:
                return .failure(.httpError(.dataCannotBeModified))
            case 400:
                return .failure(.httpError(.badRequest))
            case 500...599:
                return .failure(.httpError(.serverError))
            default:
                return .failure(.httpError(.unexpectedStatus(httpResponse.statusCode)))
            }
        } catch let encodingError as EncodingError {
            return .failure(.encodingFailed(encodingError.localizedDescription))
        } catch let urlError as URLError {
            return .failure(handleURLError(urlError))
        } catch {
            return .failure(.networkError(.other(error.localizedDescription)))
        }
    }
    
    // MARK: - Private Helpers
    
    private func handleURLError(_ error: URLError) -> APIError {
        switch error.code {
        case .notConnectedToInternet:
            return .networkError(.noConnection)
        case .timedOut:
            return .networkError(.timeout)
        default:
            return .networkError(.other(error.localizedDescription))
        }
    }
}
