//
//  CalendarModel.swift
//  Companion
//
//  Created by Mustapha Tarek BEN LECHHAB on 23.08.2025.
//

import Foundation
import EventKit
import SwiftUI
import Observation

struct CalendarModel: Identifiable, Hashable {
    let id: String
    let title: String
    let color: Color
    let source: String
    
    init(from calendar: EKCalendar) {
        self.id = calendar.calendarIdentifier
        self.title = calendar.title
        self.color = Color(cgColor: calendar.cgColor)
        self.source = calendar.source.title
    }
    
    static func == (lhs: CalendarModel, rhs: CalendarModel) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@Observable
class CalendarSelectionManager {
    var calendars: [CalendarModel] = []
    
    
    func loadCalendars(from ekCalendars: [EKCalendar]) {
        self.calendars = ekCalendars.map { calendar in
            CalendarModel(from: calendar)
        }
    }
}
