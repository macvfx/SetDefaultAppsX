import AppKit
import Foundation
import UniformTypeIdentifiers

/// Represents an application that can handle a file type or URL scheme.
struct HandlerApp: Identifiable, Hashable, Sendable {
    let url: URL
    let displayName: String
    let bundleIdentifier: String

    var id: String { bundleIdentifier }

    /// The app's icon from its bundle.
    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }
}

/// Tracks the current default and candidate apps for a single file type entry.
struct FileTypeState {
    var currentDefault: HandlerApp?
    var candidates: [HandlerApp] = []
    var selectedAppID: HandlerApp.ID?
    var isLoading: Bool = false
    var statusMessage: String = ""
}

/// The main store that manages default app lookups and assignments.
@MainActor
final class DefaultAppStore: ObservableObject {

    /// Per-file-type state keyed by FileTypeEntry.id
    @Published var states: [String: FileTypeState] = [:]
    @Published var globalStatus: String = "Ready."

    // MARK: - Public API

    /// Load candidate apps for a given file type entry.
    func load(entry: FileTypeEntry) async {
        var state = states[entry.id] ?? FileTypeState()
        state.isLoading = true
        states[entry.id] = state

        switch entry.kind {
        case .urlScheme(let scheme):
            await loadURLScheme(scheme: scheme, entryID: entry.id)
        case .fileExtension(let ext):
            await loadFileExtension(ext: ext, entryID: entry.id)
        }
    }

    /// Load all entries in a category.
    func loadAll(category: FileTypeCategory) async {
        for entry in category.entries {
            await load(entry: entry)
        }
    }

    /// Set the selected app as the default for a file type entry.
    func setDefault(entry: FileTypeEntry) async {
        guard var state = states[entry.id],
              let selectedID = state.selectedAppID,
              let selectedApp = state.candidates.first(where: { $0.id == selectedID }) else {
            return
        }

        state.isLoading = true
        states[entry.id] = state

        switch entry.kind {
        case .urlScheme(let scheme):
            await setURLSchemeDefault(scheme: scheme, app: selectedApp, entryID: entry.id)
        case .fileExtension(let ext):
            await setFileExtensionDefault(ext: ext, app: selectedApp, entryID: entry.id)
        }
    }

    /// Apply all selected defaults for a category.
    func applyAll(category: FileTypeCategory) async {
        for entry in category.entries {
            guard let state = states[entry.id],
                  let selectedID = state.selectedAppID,
                  let currentDefault = state.currentDefault else { continue }
            // Only apply if the selection differs from current default
            if selectedID != currentDefault.id {
                await setDefault(entry: entry)
            }
        }
        globalStatus = "All changes applied."
    }

    // MARK: - URL Scheme Handling

    private func loadURLScheme(scheme: String, entryID: String) async {
        var state = FileTypeState()

        // Build a dummy URL for the scheme so we can use NSWorkspace APIs
        let dummyURL = URL(string: "\(scheme)://example.com")!

        // Get current default handler for URL scheme
        if let defaultAppURL = NSWorkspace.shared.urlForApplication(toOpen: dummyURL) {
            state.currentDefault = Self.handlerApp(for: defaultAppURL)
        }

        // Get all handlers for URL scheme
        let allAppURLs = NSWorkspace.shared.urlsForApplications(toOpen: dummyURL)
        var apps: [HandlerApp] = []
        var seen = Set<String>()
        for appURL in allAppURLs {
            let app = Self.handlerApp(for: appURL)
            guard seen.insert(app.id).inserted else { continue }
            if Self.isValidCandidate(app) {
                apps.append(app)
            }
        }
        state.candidates = apps.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

        state.selectedAppID = state.currentDefault?.id ?? state.candidates.first?.id
        state.isLoading = false
        state.statusMessage = state.candidates.isEmpty
            ? "No apps found for \(scheme)."
            : "\(state.candidates.count) app(s) available."
        states[entryID] = state
    }

    private func setURLSchemeDefault(scheme: String, app: HandlerApp, entryID: String) async {
        var state = states[entryID] ?? FileTypeState()

        // LSSetDefaultHandlerForURLScheme is the only API for setting URL scheme defaults
        let result = LSSetDefaultHandlerForURLScheme(scheme as CFString, app.bundleIdentifier as CFString)
        if result == noErr {
            state.currentDefault = app
            state.statusMessage = "Set \(app.displayName) as default for \(scheme)."
        } else {
            state.statusMessage = "Failed to set default (error \(result))."
        }
        state.isLoading = false
        states[entryID] = state
    }

    // MARK: - File Extension Handling

    private func loadFileExtension(ext: String, entryID: String) async {
        var state = FileTypeState()

        guard let utType = UTType(filenameExtension: ext) else {
            state.statusMessage = "No UTI found for .\(ext)."
            state.isLoading = false
            states[entryID] = state
            return
        }

        // Get current default
        if let defaultURL = NSWorkspace.shared.urlForApplication(toOpen: utType) {
            state.currentDefault = Self.handlerApp(for: defaultURL)
        }

        // Get all candidate apps
        let candidateURLs = NSWorkspace.shared.urlsForApplications(toOpen: utType)
        var apps: [HandlerApp] = []
        var seen = Set<String>()
        for url in candidateURLs {
            let app = Self.handlerApp(for: url)
            guard seen.insert(app.id).inserted else { continue }
            if Self.isValidCandidate(app) {
                apps.append(app)
            }
        }

        // Add fallback editors if no candidates found
        if apps.isEmpty {
            apps = Self.fallbackEditors()
        }

        state.candidates = apps.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        state.selectedAppID = state.currentDefault?.id ?? state.candidates.first?.id
        state.isLoading = false
        state.statusMessage = state.candidates.isEmpty
            ? "No apps found for .\(ext)."
            : "\(state.candidates.count) app(s) available."
        states[entryID] = state
    }

    private func setFileExtensionDefault(ext: String, app: HandlerApp, entryID: String) async {
        guard let utType = UTType(filenameExtension: ext) else {
            var state = states[entryID] ?? FileTypeState()
            state.isLoading = false
            state.statusMessage = "No UTI found for .\(ext)."
            states[entryID] = state
            return
        }

        var state = states[entryID] ?? FileTypeState()
        do {
            try await NSWorkspace.shared.setDefaultApplication(at: app.url, toOpen: utType)
            state.currentDefault = app
            state.statusMessage = "Set \(app.displayName) as default for .\(ext)."
        } catch {
            state.statusMessage = "Failed: \(error.localizedDescription)"
        }
        state.isLoading = false
        states[entryID] = state
    }

    // MARK: - Helpers

    private static func handlerApp(for url: URL) -> HandlerApp {
        let bundle = Bundle(url: url)
        let displayName = FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")
        let bundleID = bundle?.bundleIdentifier ?? url.lastPathComponent

        return HandlerApp(
            url: url,
            displayName: displayName,
            bundleIdentifier: bundleID
        )
    }

    private static func isValidCandidate(_ app: HandlerApp) -> Bool {
        let composite = "\(app.displayName) \(app.bundleIdentifier)".lowercased()
        let blocked = ["logic pro", "garageband.systemextension"]
        return blocked.allSatisfy { !composite.contains($0) }
    }

    private static func fallbackEditors() -> [HandlerApp] {
        let knownPaths = [
            "/Applications/MHL Verify.app",
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
}
