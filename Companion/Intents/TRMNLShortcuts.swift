import AppIntents

struct TRMNLShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SyncCalendarIntent(),
            phrases: [
                "Sync my calendar to \(.applicationName)",
                "Update \(.applicationName) calendar",
                "Sync calendar with \(.applicationName)",
                "Refresh my \(.applicationName) display",
                "Update my \(.applicationName)",
                "Quick sync \(.applicationName)",
                "Sync \(.applicationName)"
            ],
            shortTitle: "Sync Calendar",
            systemImageName: "calendar.badge.clock"
        )
    }
    
    static var shortcutTileColor: ShortcutTileColor = .purple
}