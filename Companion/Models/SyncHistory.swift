//
//  SyncHistory.swift
//  Companion
//
//  Created by Mustapha Tarek BEN LECHHAB on 23.08.2025.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class SyncHistory {
    var timestamp: Date
    var status: SyncStatus
    var eventCount: Int
    var errorMessage: String?
    var syncDuration: TimeInterval
    
    enum SyncStatus: String, Codable {
        case success
        case failed
        case empty
        
        var systemImageName: String {
            switch self {
            case .success:
                return "checkmark.circle.fill"
            case .failed:
                return "xmark.circle.fill"
            case .empty:
                return "exclamationmark.triangle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .success:
                return .green
            case .failed:
                return .red
            case .empty:
                return .yellow
            }
        }
        
        var label: LocalizedStringKey {
            switch self {
            case .success:
                return "Success"
            case .failed:
                return "Failed"
            case .empty:
                return "No events"
            }
        }
    }
    
    init(timestamp: Date = Date(), 
         status: SyncStatus, 
         eventCount: Int = 0, 
         errorMessage: String? = nil,
         syncDuration: TimeInterval = 0) {
        self.timestamp = timestamp
        self.status = status
        self.eventCount = eventCount
        self.errorMessage = errorMessage
        self.syncDuration = syncDuration
    }
}
