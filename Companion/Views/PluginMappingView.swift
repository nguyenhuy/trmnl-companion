//
//  PluginMappingView.swift
//  Companion
//
//  Created for TRMNL plugin mapping interface.
//

import SwiftUI
import Observation

struct PluginMappingView: View {
    @Bindable var pluginManager: PluginMappingManager
    @Bindable var calendarSelection: CalendarSelectionManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Calendar Mapping")
                    .font(.headline)
                    .foregroundColor(AppTheme.labelColor)
                
                Spacer()
                
                if !pluginManager.plugins.isEmpty {
                    Menu {
                        Button("Clear All Mappings") {
                            pluginManager.clearAllMappings()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundColor(AppTheme.primaryOrange)
                    }
                }
            }
            .padding(.horizontal)
            
            if pluginManager.plugins.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "square.stack.3d.up.slash")
                        .font(.largeTitle)
                        .foregroundColor(AppTheme.tertiaryLabelColor)
                    
                    Text("No calendar plugins detected")
                        .font(.body)
                        .foregroundColor(AppTheme.secondaryLabelColor)
                    
                    Text("Connect a calendar inside TRMNL, then come back here")
                        .font(.caption)
                        .foregroundColor(AppTheme.tertiaryLabelColor)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(pluginManager.plugins, id: \.id) { plugin in
                            PluginMappingCard(
                                pluginId: plugin.id,
                                calendars: calendarSelection.calendars,
                                pluginManager: pluginManager
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

struct PluginMappingCard: View {
    let pluginId: Int
    let calendars: [CalendarModel]
    let pluginManager: PluginMappingManager
    @State private var isExpanded = false
    @Namespace private var animation
    
    var plugin: PluginModel? {
        pluginManager.plugins.first(where: { $0.id == pluginId })
    }
    
    var mappedCalendars: [CalendarModel] {
        guard let plugin = plugin else { return [] }
        return calendars.filter { plugin.mappedCalendarIds.contains($0.id) }
    }
    
    var unmappedCalendars: [CalendarModel] {
        guard let plugin = plugin else { return calendars }
        return calendars.filter { !plugin.mappedCalendarIds.contains($0.id) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let plugin = plugin {
                // Plugin header
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.82, blendDuration: 0)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(plugin.name)
                                .font(.headline)
                                .foregroundColor(AppTheme.labelColor)
                        
                        if !mappedCalendars.isEmpty {
                            Text("\(mappedCalendars.count) calendar\(mappedCalendars.count == 1 ? "" : "s") mapped")
                                .font(.caption)
                                .foregroundColor(AppTheme.primaryOrange)
                        } else {
                            Text("No calendars mapped")
                                .font(.caption)
                                .foregroundColor(AppTheme.secondaryLabelColor)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.forward")
                        .font(.caption)
                        .foregroundColor(AppTheme.tertiaryLabelColor)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isExpanded)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .fill(AppTheme.secondaryBackgroundColor)
                )
            }
                .buttonStyle(PlainButtonStyle())
                
                // Expanded content with smooth animation
                VStack(alignment: .leading, spacing: 8) {
                    if !mappedCalendars.isEmpty {
                        Text("Mapped Calendars")
                            .font(.caption)
                            .foregroundColor(AppTheme.secondaryLabelColor)
                            .padding(.horizontal)
                            .opacity(isExpanded ? 1 : 0)
                            .animation(.easeInOut(duration: 0.15).delay(isExpanded ? 0.05 : 0), value: isExpanded)
                        
                        ForEach(mappedCalendars, id: \.id) { calendar in
                            CalendarMappingRow(
                                calendar: calendar,
                                isMapped: true,
                                action: {
                                    pluginManager.unmapCalendar(calendar.id, from: plugin.id)
                                }
                            )
                            .opacity(isExpanded ? 1 : 0)
                            .scaleEffect(isExpanded ? 1 : 0.95, anchor: .top)
                            .animation(.spring(response: 0.22, dampingFraction: 0.78).delay(isExpanded ? 0.02 * Double(mappedCalendars.firstIndex(where: { $0.id == calendar.id }) ?? 0) : 0), value: isExpanded)
                        }
                    }
                    
                    if !unmappedCalendars.isEmpty {
                        Text("Available Calendars")
                            .font(.caption)
                            .foregroundColor(AppTheme.secondaryLabelColor)
                            .padding(.horizontal)
                            .padding(.top, mappedCalendars.isEmpty ? 0 : 8)
                            .opacity(isExpanded ? 1 : 0)
                            .animation(.easeInOut(duration: 0.15).delay(isExpanded ? 0.08 : 0), value: isExpanded)
                        
                        ForEach(unmappedCalendars, id: \.id) { calendar in
                            CalendarMappingRow(
                                calendar: calendar,
                                isMapped: false,
                                action: {
                                    pluginManager.mapCalendar(calendar.id, to: plugin.id)
                                }
                            )
                            .opacity(isExpanded ? 1 : 0)
                            .scaleEffect(isExpanded ? 1 : 0.95, anchor: .top)
                            .animation(.spring(response: 0.22, dampingFraction: 0.78).delay(isExpanded ? 0.02 * Double(unmappedCalendars.firstIndex(where: { $0.id == calendar.id }) ?? 0) + 0.05 : 0), value: isExpanded)
                        }
                    }
                    
                    if mappedCalendars.isEmpty && unmappedCalendars.isEmpty {
                        Text("No calendars available")
                            .font(.caption)
                            .foregroundColor(AppTheme.tertiaryLabelColor)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .opacity(isExpanded ? 1 : 0)
                            .animation(.easeInOut(duration: 0.15).delay(isExpanded ? 0.05 : 0), value: isExpanded)
                    }
                }
                .frame(maxHeight: isExpanded ? nil : 0)
                .clipped()
                .padding(.top, isExpanded ? 12 : 0)
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.82, blendDuration: 0), value: isExpanded)
    }
}

struct CalendarMappingRow: View {
    let calendar: CalendarModel
    let isMapped: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(calendar.color)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(calendar.title)
                        .font(.body)
                        .foregroundColor(AppTheme.labelColor)
                    
                    Text(calendar.source)
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryLabelColor)
                }
                
                Spacer()
                
                Image(systemName: isMapped ? "minus.circle.fill" : "plus.circle")
                    .font(.title3)
                    .foregroundColor(isMapped ? .red : AppTheme.primaryOrange)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius / 2)
                    .fill(AppTheme.backgroundColor.opacity(0.5))
            )
            .padding(.horizontal, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}