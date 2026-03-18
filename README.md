# SetDefaultAppsX

A native macOS application for setting default apps for file types and URL schemes. Built in Swift with SwiftUI.

SetDefaultAppsX replaces the shell script + swiftDialog approach with a lightweight, dependency-free native app that uses Apple's own `NSWorkspace` and `UTType` APIs to query and set default handlers.

## Features

- **Two-tab interface** -- Main Apps (mail, web, PDF, text, MHL, etc.) and Coding Files (JSON, YAML, TOML, plist, shell, etc.)
- **Zero dependencies** -- No swiftDialog, no utiluti, no Homebrew. Just macOS frameworks.
- **Per-row controls** -- See the current default, pick a replacement from a dropdown of all registered apps, and apply individually or in bulk.
- **App icons** -- Each candidate app is shown with its real icon for quick identification.
- **Modern APIs** -- Uses `NSWorkspace.setDefaultApplication(at:toOpen:)` (macOS 12+) for file extensions and `LSSetDefaultHandlerForURLScheme` for URL schemes.

## Requirements

- macOS 13 Ventura or later
- Xcode 16+ (for building from source)

## Quick Start

### Open in Xcode

```bash
open SetDefaultAppsX.xcodeproj
```

Then press **Cmd+R** to build and run.

### Build from the command line

```bash
xcodebuild -project SetDefaultAppsX.xcodeproj -scheme SetDefaultAppsX -configuration Debug build
```

## Supported File Types

### Main Apps Tab

| Category | Type | Method |
|----------|------|--------|
| Email | `mailto` | URL scheme |
| Web Browser | `https` | URL scheme |
| File Transfer | `ftp` | URL scheme |
| PDF Documents | `.pdf` | UTType |
| Text Files | `.txt` | UTType |
| Markdown | `.md` | UTType |
| Spreadsheets | `.xlsx` | UTType |
| Documents | `.docx` | UTType |
| Rich Text | `.rtf` | UTType |
| HTML Files | `.html` | UTType |
| CSV Files | `.csv` | UTType |
| Media Hash List | `.mhl` | UTType |

### Coding Files Tab

| Category | Type | Method |
|----------|------|--------|
| JSON | `.json` | UTType |
| YAML | `.yaml` | UTType |
| TOML | `.toml` | UTType |
| Property List | `.plist` | UTType |
| Mobile Config | `.mobileconfig` | UTType |
| XML | `.xml` | UTType |
| Shell Scripts | `.sh` | UTType |
| Zsh Scripts | `.zsh` | UTType |
| Python | `.py` | UTType |
| Ruby | `.rb` | UTType |
| Swift | `.swift` | UTType |
| JavaScript | `.js` | UTType |

## Project Structure

```
SetDefaultAppsX/
├── SetDefaultAppsX.xcodeproj        # Xcode project (generated via xcodegen)
├── project.yml                      # xcodegen spec
├── README.md                        # This file
├── App/
│   ├── Info.plist                   # Bundle ID, version, app metadata
│   ├── SetDefaultAppsX.entitlements # Entitlements
│   └── Assets.xcassets/             # App icon and accent color
├── Sources/
│   ├── SetDefaultAppsXApp.swift     # @main app entry point, About & Help windows
│   ├── ContentView.swift            # Main window UI (tabs, rows, controls)
│   ├── DefaultAppStore.swift        # Core logic: lookup, set, state management
│   └── FileTypeDefinitions.swift    # File type entries and category definitions
└── docs/
    ├── USER_GUIDE.md                # End-user guide
    ├── ARCHITECTURE.md              # Code architecture and design
    └── CHANGELOG.md                 # Version history
```

## How It Works

SetDefaultAppsX uses native macOS APIs exclusively:

1. **Discovery** -- `NSWorkspace.urlsForApplications(toOpen:)` finds all apps registered to handle a UTType or URL scheme.
2. **Current default** -- `NSWorkspace.urlForApplication(toOpen:)` identifies the current default handler.
3. **Setting defaults** -- `NSWorkspace.setDefaultApplication(at:toOpen:)` for file types, `LSSetDefaultHandlerForURLScheme` for URL schemes.
4. **App metadata** -- `Bundle(url:)` and `FileManager.displayName(atPath:)` resolve display names and bundle identifiers.

No command-line tools are shelled out to. Everything runs in-process.

## Origins

SetDefaultAppsX is the native Swift successor to the SetDefaultAppsX.sh shell scripts (v1.0--v2.1) originally created by Scott Kendall. The shell versions used swiftDialog for the GUI and utiluti for UTI management. This native app eliminates those dependencies entirely while providing a richer, faster experience.

See [docs/CHANGELOG.md](docs/CHANGELOG.md) for the full evolution from shell script to native app.

## Links

- [code.matx.ca](https://code.matx.ca)
- [GitHub -- macvfx/SetDefaultAppsX](https://github.com/macvfx/SetDefaultAppsX)

## Credits

- **Scott Kendall** -- Original SetDefaultApps shell script
- **Bart Reardon** -- swiftDialog (used by the shell script predecessors)
- **Armin Briegel** (scriptingOSX) -- utiluti (used by the shell script predecessors)

## License

See the project repository for license information.
