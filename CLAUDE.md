# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Workflow

All code changes must go through a pull request. Before a PR is considered done:

1. Add the **`tested`** label to the PR.
2. The **Tests** GitHub Actions pipeline must pass (trigger it manually via Actions → Tests → Run workflow if it hasn't run yet).

## Build & Test

Open the project in Xcode:
```bash
open BirthdayReminder.xcodeproj
```

Build from the command line (requires a simulator booted or available):
```bash
xcodebuild build \
  -project BirthdayReminder.xcodeproj \
  -scheme BirthdayReminder \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
```

Run tests (mirrors the GitHub Actions workflow):
```bash
xcodebuild test \
  -project BirthdayReminder.xcodeproj \
  -scheme BirthdayReminder \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  | xcpretty --color
```

Tests can also be triggered manually via **GitHub Actions → Tests → Run workflow**.

## Project Configuration

| Key | Value |
|-----|-------|
| Bundle ID | `kkulykk.BirthdayReminder` |
| App Group | `group.kkulykk.BirthdayReminder` |
| Dev Team | `28JPTEDA4Z` |
| Deployment target | iOS 26.0 |
| Xcode | 26.2 (uses `PBXFileSystemSynchronizedRootGroup`) |
| SwiftData store path | App Group container → `BirthdayReminder.store` |

## Architecture

### Targets

| Target | Description |
|--------|-------------|
| `BirthdayReminder` | Main SwiftUI app |
| `BirthdayWidget` | WidgetKit extension (lock screen + home screen) |
| `BirthdayShareExtension` | Share extension for saving wishlist items |

### Shared Code (`Shared/`)

Files compiled into multiple targets:

- **`Person.swift`** — SwiftData `@Model`. Stores birthday data, contact info, photo, wishlist relationship, and congratulation tracking. Contains all computed date helpers (`nextBirthdayDate`, `daysUntilBirthday`, `isBirthdayToday`, etc.). Compiled into main app + share extension only (not the widget).
- **`WishlistItem.swift`** — SwiftData `@Model` with a `person` inverse relationship. Same targets as `Person.swift`.
- **`SharedContainer.swift`** — `makeSharedModelContainer()` creates the SwiftData container pointed at the App Group URL, with a fallback to the default container.
- **`WidgetDataManager.swift`** — Lightweight `Codable` struct (`WidgetBirthday`) and `WidgetDataManager` enum that reads/writes a JSON-encoded array to `UserDefaults(suiteName:)`. Compiled into all three targets.

### Data Flow

```
App (active) → fetches Person[] via SwiftData
             → writes [WidgetBirthday] to UserDefaults (App Group)
             → calls WidgetCenter.shared.reloadAllTimelines()

Widget       → reads [WidgetBirthday] from UserDefaults in getTimeline()
             → refreshes at next midnight

Share Ext    → opens same SwiftData store via App Group URL
             → reads Person[], inserts WishlistItem
```

### Main App Structure

- **`BirthdayReminderApp.swift`** — App entry point. On `.active` phase, reschedules notifications and writes widget data.
- **`ContentView.swift`** → **`BirthdayListView.swift`** — Root view. Displays four sections: Missed Yesterday, Today, Upcoming (paginated 5 at a time), Past This Year.
- **`Views/PersonDetailView.swift`** — Detail view; renders differently based on `style` (`.today`, `.upcoming`, `.past`, `.missed`).
- **`Services/NotificationService.swift`** — Schedules up to 64 `UNCalendarNotificationTrigger` notifications. Uses `UNTimeIntervalNotificationTrigger(timeInterval: 2)` when the birthday is today (calendar trigger would skip to next year).
- **`Services/ContactsService.swift`** — Fetches `CNContact` records that have a birthday set. Import merges by `contactIdentifier`; existing records only update photo data.

### Widget Extension

`BirthdayWidget.swift` — Single file. Supports `.accessoryCircular`, `.accessoryRectangular`, `.accessoryInline` (lock screen) and `.systemSmall` (home screen). All widget views share the same `BirthdayEntry` timeline entry. The `nearestDay` helper on `BirthdayEntry` groups people sharing the soonest `daysUntil` value.

### Share Extension

`ShareView.swift` — SwiftUI sheet hosted by `ShareViewController`. Parses the incoming `NSExtensionItem` for a URL or plain text, lets the user pick a `Person`, and inserts a `WishlistItem` directly into the shared SwiftData store without launching the main app.

### Notification ID Convention

Notification identifiers follow the pattern `"birthday-<personID.uuidString>"`. Cancellation and deduplication rely on this format.
