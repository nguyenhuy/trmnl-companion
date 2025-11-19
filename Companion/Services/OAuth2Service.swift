//
//  OAuth2Service.swift
//  Companion
//
//  Created for TRMNL OAuth2 authentication support.
//

import Foundation
import SwiftUI
import SafariServices
import CryptoKit
import ErrorKit

enum OAuth2Error: Throwable {
    case invalidURL
    case invalidState
    case invalidResponse
    case missingCode
    case missingAccessToken
    case tokenExchangeFailed(String)
    case networkError(String)
    
    var userFriendlyMessage: String {
        switch self {
        case .invalidURL:
            return "Invalid authentication URL"
        case .invalidState:
            return "Authentication state validation failed"
        case .invalidResponse:
            return "Invalid response from authentication server"
        case .missingCode:
            return "Missing authorization code"
        case .missingAccessToken:
            return "Failed to receive access token"
        case .tokenExchangeFailed(let error):
            return "Token exchange failed: \(error)"
        case .networkError(let error):
            return "Network error: \(error)"
        }
    }
}

struct OAuth2Token: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int?
    let refreshToken: String?
    let scope: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
        case createdAt = "created_at"
    }
    
    init(accessToken: String, tokenType: String, expiresIn: Int?, refreshToken: String?, scope: String?, createdAt: Date = Date()) {
        self.accessToken = accessToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
        self.refreshToken = refreshToken
        self.scope = scope
        self.createdAt = createdAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        tokenType = try container.decode(String.self, forKey: .tokenType)
        expiresIn = try container.decodeIfPresent(Int.self, forKey: .expiresIn)
        refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken)
        scope = try container.decodeIfPresent(String.self, forKey: .scope)
        
        // If createdAt exists in storage, use it; otherwise use current time
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accessToken, forKey: .accessToken)
        try container.encode(tokenType, forKey: .tokenType)
        try container.encodeIfPresent(expiresIn, forKey: .expiresIn)
        try container.encodeIfPresent(refreshToken, forKey: .refreshToken)
        try container.encodeIfPresent(scope, forKey: .scope)
        try container.encode(createdAt, forKey: .createdAt)
    }
    
    var expiresAt: Date? {
        guard let expiresIn = expiresIn else { return nil }
        return createdAt.addingTimeInterval(TimeInterval(expiresIn))
    }
    
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() >= expiresAt
    }
    
    var needsRefresh: Bool {
        guard let expiresAt = expiresAt else { return false }
        // Refresh if within 1 hour of expiry
        let refreshThreshold = expiresAt.addingTimeInterval(-3600) // 1 hour before expiry
        return Date() >= refreshThreshold
    }
}

@Observable
class OAuth2Service {
    static let shared = OAuth2Service()
    
    // OAuth2 Configuration
    private let clientId = "1f5ac5e9b27e8efbe335b490e27ab576"
    private let clientSecret = "5dcf83ed7458f333b79e04015d364e0f7f48d85c667deb7692c172b69801e236"
    private let authorizationURL = "https://usetrmnl.com/oauth/authorize"
    private let tokenURL = "https://usetrmnl.com/api/oauth/token"
    private let redirectURI = "trmnlapp://callback"
    
    // Current authentication state
    var isAuthenticating = false
    var currentToken: OAuth2Token?
    var authenticationError: OAuth2Error?
    
    // State management for OAuth2 flow
    private var currentState: String?
    
    @ObservationIgnored
    @AppStorage("OAuth2Token") private var storedTokenData: Data?
    
    private init() {
        loadStoredToken()
    }
    
    // MARK: - Token Storage
    
    private func loadStoredToken() {
        guard let tokenData = storedTokenData else { return }
        
        do {
            let token = try JSONDecoder().decode(OAuth2Token.self, from: tokenData)
            if !token.isExpired {
                currentToken = token
            } else {
                // Token is expired, clear it
                clearStoredToken()
            }
        } catch {
            Logger.log.error("Failed to decode stored OAuth2 token: %@", error.localizedDescription)
            clearStoredToken()
        }
    }
    
    private func storeToken(_ token: OAuth2Token) {
        do {
            let tokenData = try JSONEncoder().encode(token)
            storedTokenData = tokenData
            currentToken = token
        } catch {
            Logger.log.error("Failed to encode OAuth2 token: %@", error.localizedDescription)
        }
    }
    
    private func clearStoredToken() {
        storedTokenData = nil
        currentToken = nil
    }
    
    // MARK: - OAuth2 Flow
    
    /// Start the OAuth2 authentication flow
    func startAuthentication() -> URL? {
        // Generate secure random state
        let state = generateState()
        currentState = state
        
        var components = URLComponents(string: authorizationURL)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "scope", value: "read") // Adjust scope as needed
        ]
        
        guard let url = components?.url else {
            authenticationError = .invalidURL
            return nil
        }
        
        isAuthenticating = true
        authenticationError = nil
        
        return url
    }
    
    /// Handle the callback from the OAuth2 provider
    func handleCallback(url: URL) async -> Result<OAuth2Token, OAuth2Error> {
        defer {
            isAuthenticating = false
            currentState = nil
        }
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            let error = OAuth2Error.invalidResponse
            authenticationError = error
            return .failure(error)
        }
        
        // Extract parameters from callback URL
        let queryParams: [String: String] = Dictionary(uniqueKeysWithValues: queryItems.compactMap { item in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })
        
        // Validate state parameter
        guard let returnedState = queryParams["state"] else {
            Logger.log.error("Missing state parameter in OAuth2 callback")
            let error = OAuth2Error.invalidState
            authenticationError = error
            return .failure(error)
        }
        
        guard returnedState == currentState else {
            Logger.log.error("State parameter mismatch. Expected: %@, Got: %@", currentState ?? "nil", returnedState)
            let error = OAuth2Error.invalidState
            authenticationError = error
            return .failure(error)
        }
        
        Logger.log.info("State parameter validation successful")
        
        // Check for authorization code
        guard let code = queryParams["code"] else {
            let error = OAuth2Error.missingCode
            authenticationError = error
            return .failure(error)
        }
        
        // Exchange code for token (including state for additional security)
        return await exchangeCodeForToken(code: code, state: returnedState)
    }
    
    /// Exchange authorization code for access token
    private func exchangeCodeForToken(code: String, state: String) async -> Result<OAuth2Token, OAuth2Error> {
        guard let url = URL(string: tokenURL) else {
            let error = OAuth2Error.invalidURL
            authenticationError = error
            return .failure(error)
        }
        
        Logger.log.info("Starting token exchange for code: %@", String(code.prefix(10)) + "...")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        
        // Prepare form data (including state parameter)
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "client_secret", value: clientSecret),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "state", value: state)
        ]
        
        request.httpBody = components.query?.data(using: .utf8)
        
        // Log request details
        if let bodyString = String(data: request.httpBody ?? Data(), encoding: .utf8) {
            Logger.log.info("Token exchange request body: %@", bodyString)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Log response details
            if let httpResponse = response as? HTTPURLResponse {
                Logger.log.info("Token exchange response status: %d", httpResponse.statusCode)
                
                if let responseString = String(data: data, encoding: .utf8) {
                    Logger.log.info("Token exchange response body: %@", responseString)
                }
                
                guard httpResponse.statusCode == 200 else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    let error = OAuth2Error.tokenExchangeFailed(errorMessage)
                    authenticationError = error
                    return .failure(error)
                }
            }
            
            // Decode token response and create with current timestamp
            var token = try JSONDecoder().decode(OAuth2Token.self, from: data)
            // Ensure we set the current time for proper expiration tracking
            token = OAuth2Token(
                accessToken: token.accessToken,
                tokenType: token.tokenType,
                expiresIn: token.expiresIn,
                refreshToken: token.refreshToken,
                scope: token.scope,
                createdAt: Date()
            )
            
            // Store the token
            storeToken(token)
            authenticationError = nil
            
            Logger.log.info("Successfully obtained OAuth2 token")
            return .success(token)
            
        } catch {
            Logger.log.error("Token exchange network error: %@", error.localizedDescription)
            let authError = OAuth2Error.networkError(error.localizedDescription)
            authenticationError = authError
            return .failure(authError)
        }
    }
    
    // MARK: - Token Management
    
    /// Get the current access token if available and valid, refreshing if needed
    func getAccessToken() async -> String? {
        guard let token = currentToken else { return nil }
        
        // If token is expired, try to refresh it
        if token.isExpired {
            Logger.log.info("Token is expired, attempting refresh...")
            let result = await refreshTokenIfNeeded()
            switch result {
            case .success(let newToken):
                return newToken.accessToken
            case .failure:
                return nil
            }
        }
        
        // If token needs refresh (within 1 hour of expiry), refresh it
        if token.needsRefresh {
            Logger.log.info("Token needs refresh (within 1 hour of expiry), refreshing...")
            let result = await refreshTokenIfNeeded()
            switch result {
            case .success(let newToken):
                return newToken.accessToken
            case .failure:
                // Even if refresh fails, return current token if not expired
                return token.isExpired ? nil : token.accessToken
            }
        }
        
        return token.accessToken
    }
    
    /// Get the current access token synchronously (without refresh)
    func getCurrentAccessToken() -> String? {
        guard let token = currentToken, !token.isExpired else { return nil }
        return token.accessToken
    }
    
    /// Check if the user is currently authenticated
    var isAuthenticated: Bool {
        return currentToken != nil && !currentToken!.isExpired
    }
    
    /// Sign out the user by clearing stored tokens
    func signOut() {
        clearStoredToken()
        authenticationError = nil
    }

    /// Cancel an in-progress authentication flow
    func cancelAuthentication() {
        isAuthenticating = false
        currentState = nil
        authenticationError = nil
    }
    
    // MARK: - Token Refresh
    
    /// Refresh the access token if needed
    private func refreshTokenIfNeeded() async -> Result<OAuth2Token, OAuth2Error> {
        guard let token = currentToken,
              let refreshToken = token.refreshToken else {
            return .failure(.missingAccessToken)
        }
        
        return await refreshAccessToken(refreshToken: refreshToken)
    }
    
    /// Refresh the access token using the refresh token
    private func refreshAccessToken(refreshToken: String) async -> Result<OAuth2Token, OAuth2Error> {
        guard let url = URL(string: tokenURL) else {
            return .failure(.invalidURL)
        }
        
        Logger.log.info("Starting token refresh...")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        
        // Prepare refresh token request
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "client_secret", value: clientSecret)
        ]
        
        request.httpBody = components.query?.data(using: .utf8)
        
        // Log request details
        if let bodyString = String(data: request.httpBody ?? Data(), encoding: .utf8) {
            Logger.log.info("Token refresh request body: %@", bodyString)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Log response details
            if let httpResponse = response as? HTTPURLResponse {
                Logger.log.info("Token refresh response status: %d", httpResponse.statusCode)
                
                if let responseString = String(data: data, encoding: .utf8) {
                    Logger.log.info("Token refresh response body: %@", responseString)
                }
                
                guard httpResponse.statusCode == 200 else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    let error = OAuth2Error.tokenExchangeFailed(errorMessage)
                    authenticationError = error
                    return .failure(error)
                }
            }
            
            // Decode new token response
            let newToken = try JSONDecoder().decode(OAuth2Token.self, from: data)
            
            // Store the new token
            storeToken(newToken)
            authenticationError = nil
            
            Logger.log.info("Successfully refreshed OAuth2 token")
            return .success(newToken)
            
        } catch {
            Logger.log.error("Token refresh network error: %@", error.localizedDescription)
            let authError = OAuth2Error.networkError(error.localizedDescription)
            authenticationError = authError
            return .failure(authError)
        }
    }
    
    // MARK: - Utility Methods
    
    /// Generate a cryptographically secure random state parameter
    private func generateState() -> String {
        let data = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    /// Check if a URL is our OAuth callback
    static func isOAuthCallback(url: URL) -> Bool {
        return url.scheme == "trmnlapp" && url.host == "callback"
    }
}
