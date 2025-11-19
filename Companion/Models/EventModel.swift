//
//  EventModel.swift
//  Companion
//
//  Created by Mustapha Tarek BEN LECHHAB on 23.08.2025.
//

import Foundation
import EventKit

struct EventModel: Codable {
    // periphery:ignore
    let summary: String
    // periphery:ignore
    let start: String
    // periphery:ignore
    let startFull: String
    // periphery:ignore
    let dateTime: String
    // periphery:ignore
    let end: String
    // periphery:ignore
    let endFull: String
    // periphery:ignore
    let allDay: Bool
    // periphery:ignore
    let description: String
    // periphery:ignore
    let status: String
    // periphery:ignore
    let calendarIdentifier: String
    
    enum CodingKeys: String, CodingKey {
        case summary
        case start
        case startFull = "start_full"
        case dateTime = "date_time"
        case end
        case endFull = "end_full"
        case allDay = "all_day"
        case description
        case status
        case calendarIdentifier = "calname"
    }

    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
        
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    
    init(from event: EKEvent) {
        self.summary = event.title ?? ""
                
        if let startDate = event.startDate {
            self.start = Self.timeFormatter.string(from: startDate)
            self.startFull = Self.dateFormatter.string(from: startDate)
            self.dateTime = Self.dateFormatter.string(from: startDate)
        } else {
            self.start = ""
            self.startFull = ""
            self.dateTime = ""
        }
        
        if let endDate = event.endDate {
            // if isAllDay, then add a second to round to 00:00
            if event.isAllDay {
                var date = endDate
                date.addTimeInterval(TimeInterval(1))
                self.end = Self.timeFormatter.string(from: date)
                self.endFull = Self.dateFormatter.string(from: date)
            } else {
                self.end = Self.timeFormatter.string(from: endDate)
                self.endFull = Self.dateFormatter.string(from: endDate)
            }
        } else {
            self.end = ""
            self.endFull = ""
        }
        
        self.allDay = event.isAllDay
        self.description = event.notes ?? ""
        self.status = event.status == .confirmed ? "confirmed" : "tentative"
        
        // Calendar Identifier Strategy:
        // Using calendarItemExternalIdentifier as the primary identifier.
        // This provides the best cross-device consistency for server-backed calendars.
        // 
        // IMPORTANT: Apple warns that duplicates are possible with this identifier
        // (e.g., ICS imports, shared calendars, delegates). The remote service
        // should handle duplicates by using a combination of:
        // - calendar_identifier (calendarItemExternalIdentifier)
        // - start_full (timestamp)
        // - summary (title)
        // This combination should be unique enough for proper deduplication.
        //
        // Fallback to calendarItemIdentifier if external identifier is not available.
        // This is stable on this device across app launches.
        self.calendarIdentifier = event.calendarItemExternalIdentifier ?? event.calendarItemIdentifier
    }
}
