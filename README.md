# TRMNL Calendar Companion

<div align="center">
  <img src="Companion/Assets.xcassets/trmnl-logo-brand.imageset/trmnl-logo--brand.svg" alt="TRMNL Logo" width="200">
</div>

## 📱 Overview

TRMNL Calendar Companion is an iOS app that syncs calendar events with the TRMNL platform. Built with SwiftUI and EventKit, it provides a simple, efficient, and privacy friendly way to keep a TRMNL display updated with the users latest schedule.

## ✨ Features

- **📅 Multi-Calendar Support**: Select and sync events from multiple calendars
- **🎯 Plugin-Based Sync**: Map calendars to TRMNL plugins for organized display
- **🔑 Secure Authentication**: Browser-based login with automatic API key detection
- **🔄 Full Sync**: Always syncs events from 6 days ago to 30 days ahead
- **📊 Sync History**: Track all sync operations with detailed logs
- **🎨 Modern Design**: Clean interface with TRMNL branding
- **🌓 Dark Mode**: Full support for iOS light and dark themes
- **🔒 Privacy First**: Calendar permissions handled transparently
- **⚡ Efficient**: Memory-optimized event processing with smart event merging
- **🚀 iOS 17+ Features**: Built with @Observable for seamless reactive UI updates
- **🛡️ Robust Error Handling**: Type-safe errors with helpful user messages via ErrorKit
- **♻️ Smart Refresh**: Pull-to-refresh and automatic updates when switching tabs

## 📋 Requirements

- iOS 17.0 or later
- iPhone or iPad
- Internet connection for syncing
- Calendar access permission

## 🚀 Installation

Note: this repository is for educational purposes. It does not Just Work with [BYOS clients](https://docs.usetrmnl.com/go/diy/byos). Support may be added by maintainers but is not planned.

### From Xcode

1. Clone the repository:
```bash
git clone https://github.com/bilqisium/trmnl-companion.git
cd trmnl-companion
```

2. Open in Xcode:
```bash
open Companion.xcodeproj
```

3. Select your development team in project settings

4. Build and run on your device or simulator

### Configuration

1. **TRMNL Account Setup**:
   - Launch the app and navigate to Settings
   - Tap "Login to TRMNL" to open the browser
   - Login to your account at https://usetrmnl.com

2. **Calendar Permissions**: The app will automatically request calendar access on first launch and handle gracefully refusal, by redirecting to settings with an explanation.

## 📖 Usage

### First Launch

1. **Login to TRMNL**: Navigate to Settings and authenticate with your TRMNL account
2. **Grant Calendar Access**: When prompted, allow the app to access your calendars
3. **Map Calendars to Plugins**: In the Sync tab, assign calendars to your TRMNL plugins
4. **Start Syncing**: Tap the sync button to send your events to TRMNL

### Sync Tab

The main sync interface shows:
- **Last Sync Info**: When the last successful sync occurred
- **Plugin Mapping**: Organize your calendars by assigning them to TRMNL plugins
- **Calendar List**: All available calendars grouped by plugin
- **Sync Button**: Initiates the sync process (disabled when no calendars are mapped)
- **Pull to Refresh**: Swipe down to reload plugins and calendars

### Settings Tab

Manage your account and view app information:
- **TRMNL Account**: Login status and email
- **Sync History**: View past sync operations with timestamps and event counts
- **Clear History**: Remove all sync history records
- **Support Links**: Access help and documentation
- **App Version**: Current version and build number

## 🔧 Technical Details

### Architecture

The app follows MVVM architecture with SwiftUI and modern iOS 17+ features:
- **Models**: Data structures for events, calendars, plugins, and sync history
- **Services**: Business logic for EventKit, networking, and sync operations with typed Result<T,E> error handling
- **ViewModels**: Presentation logic with @Observable macro for reactive state management
- **Views**: SwiftUI components with automatic observation of nested objects
- **@Observable**: Modern observation framework eliminating boilerplate and solving nested object issues
- **Error Handling**: Type-safe errors with ErrorKit integration providing consistent user-friendly messages
- **Async/Await**: Modern Swift concurrency for all network and EventKit operations
- **AppStorage**: Persistent API key storage using UserDefaults wrapper

### Event Format

Events are converted to JSON with the following structure:
```json
{
  "summary": "Meeting Title",
  "start": "14:30",
  "start_full": "2025-08-24T14:30:00.000-04:00",
  "date_time": "2025-08-24T14:30:00.000-04:00",
  "end": "15:30",
  "end_full": "2025-08-24T15:30:00.000-04:00",
  "all_day": false,
  "description": "Meeting description",
  "status": "confirmed",
  "calendar_identifier": "unique-calendar-id"
}
```

### API Integration

The app integrates with TRMNL's private API at `https://usetrmnl.com/api-docs`:

#### Endpoints
- **GET /plugin_settings?plugin_id=calendars**: Fetch calendar plugin configuration
- **POST /plugin_settings/{id}/data**: Update plugin with calendar events

#### Authentication
- Bearer token authentication using API key from user's TRMNL account
- API key stored securely using AppStorage (UserDefaults)
- Automatic clipboard monitoring for seamless login flow

### Plugin System

The app uses a plugin-based architecture for organizing calendar events:
- **Plugin ID**: Default calendar plugin identifier
- **Calendar Mapping**: Multiple calendars can be mapped to a single plugin
- **Event Merging**: Events from all calendars mapped to a plugin are combined
- **One Request Per Plugin**: Optimized to send a single API request per plugin

### Calendar Identification

The app uses Apple's provided `calendarItemExternalIdentifier` as the primary identifier for cross-device consistency, with `calendarItemIdentifier` as a fallback.
The remote service should handle potential duplicates across calendars by combining:
- calendar_identifier
- start_full (timestamp)
- summary (title)

### Error Handling

The app implements comprehensive error handling with type safety:
- **Typed Errors**: All errors use Result<Success, Error> pattern for compile-time safety
- **User-Friendly Messages**: ErrorKit integration ensures consistent, helpful error messages
- **Error Propagation**: Errors are properly propagated from network layer through services to UI
- **Rich Error Context**: Success results include metadata like event count and sync duration

### Dependencies

- **ErrorKit**: For consistent user-friendly error messages across the app (see https://github.com/FlineDev/ErrorKit to know more about ErrorKit usage)
- **EventKit**: Apple's framework for calendar and reminder access
- **SwiftData**: Modern persistence framework for sync history
- **SafariServices**: In-app browser for authentication flow

## 🛠️ Development

### Building from Source from the CLI

```bash
# Build for simulator
xcodebuild -project Companion.xcodeproj \
  -scheme Companion \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0' \
  build

# Run tests
xcodebuild test -project Companion.xcodeproj \
  -scheme Companion \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0'
```

### Code Quality

The project includes a Periphery script for detecting unused code:
```bash
./run_periphery.sh --clean
```
