# Birthday Reminder

A native iOS application built with SwiftUI to help you keep track of birthdays and never miss an important celebration.

## Overview

Birthday Reminder is an iOS app that lets you manage birthdays for your friends, family, and colleagues. The app sends timely notifications so you always remember to wish the people you care about on their special day.

## Features

- Add and manage birthday entries (name, date, and optional notes)
- Receive push notifications ahead of upcoming birthdays
- View a chronological list of upcoming birthdays
- Supports both iPhone and iPad

## Requirements

- Xcode 15 or later
- iOS 17.0 or later
- An Apple Developer account (for device deployment)

## Getting Started

### Clone the repository

```bash
git clone https://github.com/kkulykk/birthday-reminder.git
cd birthday-reminder
```

### Open in Xcode

```bash
open BirthdayReminder.xcodeproj
```

### Run the app

1. Select a simulator or a connected iOS device from the scheme picker in Xcode.
2. Press **Cmd + R** (or click the Run button) to build and launch the app.

> **Note:** To run on a physical device you need to set your Apple Developer Team in the project signing settings.

## Project Structure

```
BirthdayReminder/
├── BirthdayReminderApp.swift   # App entry point (@main)
├── ContentView.swift           # Root view
└── Assets.xcassets/            # App icons, accent color, and other assets
```

## Development

The project uses SwiftUI and has no external package dependencies — everything is built on top of Apple's standard frameworks.

### Build configurations

| Configuration | Purpose |
|---------------|---------|
| Debug | Development builds with full debug symbols |
| Release | Optimised production builds (LLVM whole-module optimisation) |

## Contributing

1. Fork the repository.
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. Commit your changes: `git commit -m "Add your feature"`
4. Push to the branch: `git push origin feature/your-feature-name`
5. Open a Pull Request.

## License

This project is available under the MIT License. See the [LICENSE](LICENSE) file for details.

## Author

Roman Kulyk
