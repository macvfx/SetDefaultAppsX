# SetDefaultAppsX -- Code Architecture

## Overview

SetDefaultAppsX is a native macOS app built with **SwiftUI** and **Swift Package Manager**. It follows the **MVVM** (Model-View-ViewModel) pattern where `DefaultAppStore` acts as the shared ViewModel/store, `FileTypeDefinitions.swift` provides the model layer, and `ContentView.swift` contains the view hierarchy.

```
┌──────────────────────────────────────────────────┐
│                  SwiftUI Views                    │
│                                                   │
│  SetDefaultAppsXApp  ──>  ContentView             │
│                           ├── FileTypeRow (x N)   │
│                           │   └── AppIconLabel    │
│                           └── AboutView           │
├──────────────────────────────────────────────────┤
│               DefaultAppStore                     │
│          (@MainActor ObservableObject)            │
│                                                   │
│  ┌─────────────┐   ┌──────────────────────┐      │
│  │ FileTypeState│   │  load() / setDefault()│     │
│  │ per entry    │   │  loadAll() / applyAll()│    │
│  └─────────────┘   └──────────────────────┘      │
├──────────────────────────────────────────────────┤
│            macOS System APIs                      │
│                                                   │
│  NSWorkspace          UTType          LaunchSvcs  │
│  ├ urlForApp(toOpen:) ├ init(ext:)   LSSetDefault │
│  ├ urlsForApps(toOpen:)              HandlerFor   │
│  └ setDefaultApp(at:toOpen:)         URLScheme    │
└──────────────────────────────────────────────────┘
```

## File-by-File Breakdown

### SetDefaultAppsX.xcodeproj

```
Platform: macOS 13+
Swift version: 6.0
Single app target: "SetDefaultAppsX"
Source path: Sources/
No external dependencies.
```

The app is built as a native Xcode project with a proper `.app` bundle, `Info.plist`, entitlements, and asset catalog. Build from the command line with `xcodebuild`, or open in Xcode via `open SetDefaultAppsX.xcodeproj` and press **Cmd+R**.

---

### Sources/SetDefaultAppsXApp.swift

**Role:** Application entry point and scene declaration.

```swift
@main
struct SetDefaultAppsXApp: App {
    @StateObject private var store = DefaultAppStore()
    // ...
}
```

Key responsibilities:
- Creates the single `DefaultAppStore` instance as a `@StateObject`
- Declares the main `WindowGroup` containing `ContentView`
- Declares the About window as a secondary `Window` scene
- Provides custom `Commands` to replace the default About menu item

**Design choice:** The store is owned by the `App` struct and passed down via `@ObservedObject`. This ensures a single source of truth across the entire view hierarchy.

---

### Sources/FileTypeDefinitions.swift

**Role:** Static data model. Defines every file type the app supports.

#### Core types

```swift
enum FileTypeKind: Sendable {
    case urlScheme(String)       // "mailto", "https", "ftp"
    case fileExtension(String)   // "pdf", "json", "sh"
}

struct FileTypeEntry: Identifiable, Sendable {
    let id: String
    let displayName: String
    let systemImage: String      // SF Symbol name
    let kind: FileTypeKind
}

enum FileTypeCategory: String, CaseIterable, Identifiable, Sendable {
    case main = "Apps"
    case coding = "Code"
    var entries: [FileTypeEntry] { ... }
}
```

**Design choice:** `FileTypeKind` is an enum with associated values rather than a protocol or subclass hierarchy. This makes exhaustive switching in `DefaultAppStore` trivial and eliminates any type-erasure complexity.

**Adding a new file type** requires only one change: append a `FileTypeEntry` to the appropriate static array in `FileTypeCategory`. The UI, state management, and API calls all derive from the entry's `kind`.

#### URL schemes vs file extensions

The `FileTypeKind` enum encodes the fundamental difference in how macOS handles these two categories:

- **URL schemes** (`mailto`, `https`, `ftp`) are handled by `LSSetDefaultHandlerForURLScheme` and `NSWorkspace.urlForApplication(toOpen: URL)` using a synthetic URL like `mailto://example.com`.
- **File extensions** (`pdf`, `json`, `sh`) are handled by `NSWorkspace.setDefaultApplication(at:toOpen: UTType)` using `UTType(filenameExtension:)`.

This distinction is encoded once in the data model and consumed by `DefaultAppStore`, so the view layer never needs to know about it.

---

### Sources/DefaultAppStore.swift

**Role:** ViewModel / business logic. Manages state for every file type entry and exposes async methods for loading and setting defaults.

#### Data types

```swift
struct HandlerApp: Identifiable, Hashable, Sendable {
    let url: URL                    // /Applications/Safari.app
    let displayName: String         // "Safari"
    let bundleIdentifier: String    // "com.apple.Safari"
    var icon: NSImage { ... }       // Computed from NSWorkspace
}

struct FileTypeState {
    var currentDefault: HandlerApp?
    var candidates: [HandlerApp]
    var selectedAppID: HandlerApp.ID?
    var isLoading: Bool
    var statusMessage: String
}
```

#### State storage

```swift
@MainActor
final class DefaultAppStore: ObservableObject {
    @Published var states: [String: FileTypeState] = [:]
    @Published var globalStatus: String = "Ready."
}
```

The store uses a **flat dictionary** keyed by `FileTypeEntry.id`. This avoids nested observable objects and keeps SwiftUI diffing efficient -- when a single entry's state changes, only the row for that entry re-renders.

#### Key methods

| Method | Purpose |
|--------|---------|
| `load(entry:)` | Query macOS for the current default and all candidates for one file type |
| `loadAll(category:)` | Load all entries in a tab sequentially |
| `setDefault(entry:)` | Apply the selected app as the new default for one file type |
| `applyAll(category:)` | Apply all changed selections in a tab |

#### URL scheme loading

```swift
private func loadURLScheme(scheme: String, entryID: String) async {
    let dummyURL = URL(string: "\(scheme)://example.com")!
    // Current default
    let defaultAppURL = NSWorkspace.shared.urlForApplication(toOpen: dummyURL)
    // All candidates
    let allAppURLs = NSWorkspace.shared.urlsForApplications(toOpen: dummyURL)
    // ...
}
```

**Design note:** `NSWorkspace` URL scheme queries require a full URL, not just a scheme string. We construct a synthetic URL like `mailto://example.com` for the lookup. This is the modern replacement for the deprecated `LSCopyAllHandlersForURLScheme`.

#### URL scheme setting

```swift
private func setURLSchemeDefault(scheme: String, app: HandlerApp, ...) async {
    LSSetDefaultHandlerForURLScheme(scheme as CFString, app.bundleIdentifier as CFString)
}
```

**Design note:** There is no modern `NSWorkspace` equivalent for *setting* URL scheme defaults. `LSSetDefaultHandlerForURLScheme` is the only API, which is why it's still used here despite deprecation warnings. Apple has not provided a replacement.

#### File extension loading and setting

```swift
private func loadFileExtension(ext: String, entryID: String) async {
    guard let utType = UTType(filenameExtension: ext) else { ... }
    let defaultURL = NSWorkspace.shared.urlForApplication(toOpen: utType)
    let candidateURLs = NSWorkspace.shared.urlsForApplications(toOpen: utType)
    // ...
}

private func setFileExtensionDefault(ext: String, app: HandlerApp, ...) async {
    let utType = UTType(filenameExtension: ext)!
    try await NSWorkspace.shared.setDefaultApplication(at: app.url, toOpen: utType)
}
```

All file extension operations go through `UTType`. This is Apple's recommended approach since macOS 11.

#### Fallback editors

When macOS returns zero candidates for a file type (common for `.toml`, `.yaml`, `.mobileconfig`), the store provides a hardcoded list of well-known text editors:

```swift
private static func fallbackEditors() -> [HandlerApp] {
    let knownPaths = [
        "/Applications/Visual Studio Code.app",
        "/Applications/BBEdit.app",
        "/Applications/CotEditor.app",
        "/Applications/Sublime Text.app",
        "/Applications/Nova.app",
        "/Applications/Xcode.app",
        "/System/Applications/TextEdit.app",
    ]
    return knownPaths
        .map(URL.init(fileURLWithPath:))
        .filter { FileManager.default.fileExists(atPath: $0.path) }
        .map(handlerApp(for:))
}
```

Only editors that actually exist on the system are included.

#### Candidate filtering

A small blocklist prevents non-useful apps from appearing:

```swift
private static func isValidCandidate(_ app: HandlerApp) -> Bool {
    let blocked = ["logic pro", "garageband.systemextension"]
    // ...
}
```

This follows the same pattern used in the MHL Verify reference project.

---

### Sources/ContentView.swift

**Role:** The entire view hierarchy for the main window.

#### View hierarchy

```
ContentView
├── headerView          (app title, description, refresh button)
├── Picker (segmented)  (Apps / Code toggle)
├── ScrollView
│   └── LazyVStack
│       └── FileTypeRow (x N per category)
│           ├── SF Symbol icon
│           ├── Label + current default (AppIconLabel)
│           ├── Picker dropdown (candidates)
│           └── "Set" button
└── bottomBar           (status text + "Apply All Changes" button)
```

#### FileTypeRow

Each row is a self-contained view that reads its state from `store.states[entry.id]`:

```swift
struct FileTypeRow: View {
    let entry: FileTypeEntry
    @ObservedObject var store: DefaultAppStore

    private var state: FileTypeState {
        store.states[entry.id] ?? FileTypeState()
    }
}
```

The **Set** button is only enabled when `hasChanged` is true:

```swift
private var hasChanged: Bool {
    guard let selectedID = state.selectedAppID else { return false }
    if let currentDefault = state.currentDefault {
        return selectedID != currentDefault.id
    }
    return true
}
```

The **dropdown picker** uses a custom `Binding` that writes back to the store's state dictionary:

```swift
private var selectedBinding: Binding<HandlerApp.ID?> {
    Binding(
        get: { state.selectedAppID },
        set: { newValue in
            var s = store.states[entry.id] ?? FileTypeState()
            s.selectedAppID = newValue
            store.states[entry.id] = s
        }
    )
}
```

#### AppIconLabel

A small reusable component that renders an app's icon and name:

```swift
struct AppIconLabel: View {
    let app: HandlerApp
    let small: Bool  // caption size for "Current:" label, callout size for dropdown
}
```

The icon comes from `HandlerApp.icon`, which calls `NSWorkspace.shared.icon(forFile:)`.

---

## Data Flow

```
User selects app in dropdown
        │
        v
selectedBinding.set()  ──>  store.states[entry.id].selectedAppID = newValue
        │
        v
SwiftUI re-renders FileTypeRow  (hasChanged becomes true, "Set" button enables)
        │
        v
User clicks "Set"
        │
        v
store.setDefault(entry:)
  ├── URL scheme:  LSSetDefaultHandlerForURLScheme(...)
  └── File ext:    NSWorkspace.setDefaultApplication(at:toOpen:)
        │
        v
store.states[entry.id].currentDefault = selectedApp
        │
        v
SwiftUI re-renders FileTypeRow  (currentDefault label updates, hasChanged becomes false)
```

## Concurrency Model

- `DefaultAppStore` is `@MainActor` -- all state mutations happen on the main thread.
- `NSWorkspace.setDefaultApplication(at:toOpen:)` is an async API -- the store's methods are `async` and called from `Task { }` blocks in the view layer.
- `LSSetDefaultHandlerForURLScheme` is synchronous but fast -- it's called directly within an async context without blocking concerns.

## Extending the App

### Adding a new file type

1. Add a `FileTypeEntry` to the appropriate array in `FileTypeDefinitions.swift`:

```swift
FileTypeEntry(
    id: "ext-rs",
    displayName: "Rust (.rs)",
    systemImage: "gearshape",
    kind: .fileExtension("rs")
)
```

That's it. The store, views, and state management all derive from the entry list automatically.

### Adding a new tab/category

1. Add a case to `FileTypeCategory`
2. Add its `entries` array
3. The segmented picker and view automatically include it via `CaseIterable`

### Adding a new URL scheme

```swift
FileTypeEntry(
    id: "ssh",
    displayName: "SSH (ssh)",
    systemImage: "lock.shield",
    kind: .urlScheme("ssh")
)
```

The store's `loadURLScheme` / `setURLSchemeDefault` methods handle all URL schemes generically.

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Swift Package instead of Xcode project | Simpler, no `.xcodeproj` to maintain, builds from CLI |
| Flat `[String: FileTypeState]` dictionary | Avoids nested ObservableObjects; efficient SwiftUI diffing |
| `FileTypeKind` enum | Exhaustive switching; URL vs extension logic isolated to store |
| Static entry arrays | No runtime discovery needed; adding types is a one-line change |
| `@MainActor` on the store | All state mutations on main thread; no data races |
| `HandlerApp.icon` as computed property | Icons loaded on demand, not stored in state |
| Fallback editors list | Common text editors shown when macOS returns empty candidates |
| No external dependencies | The app uses only Apple frameworks -- no SPM packages |

## Relationship to the Shell Script

The shell scripts (`SetDefaultAppsX.sh` v1.0--v2.1) solved the same problem but required:

- **swiftDialog** for the GUI (a separate 5MB download)
- **utiluti** for UTI queries (another external binary)
- **Shell process management** (`launchctl asuser`, `runAsUser`)
- **JSON construction** (manually building swiftDialog JSON blobs)

The native app replaces all of this with direct API calls:

| Shell Script | Native App |
|-------------|------------|
| `utiluti url list mailto` | `NSWorkspace.urlsForApplications(toOpen: URL("mailto://..."))` |
| `utiluti type set $uti $bundleId` | `NSWorkspace.setDefaultApplication(at:toOpen:)` |
| `utiluti url set mailto $bundleId` | `LSSetDefaultHandlerForURLScheme(...)` |
| `utiluti get-uti pdf` | `UTType(filenameExtension: "pdf")` |
| swiftDialog JSON blob | SwiftUI `Picker` + `List` |
| `runAsUser` / `launchctl asuser` | Not needed (app runs as current user) |
