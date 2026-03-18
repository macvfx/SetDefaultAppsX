import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var store: DefaultAppStore
    @State private var selectedCategory: FileTypeCategory = .main

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 12)

            Divider()

            // Tab picker
            Picker("Category", selection: $selectedCategory) {
                ForEach(FileTypeCategory.allCases) { category in
                    Label(category.rawValue, systemImage: category.systemImage)
                        .tag(category)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            // File type list
            fileTypeList(for: selectedCategory)

            Divider()

            // Bottom bar
            bottomBar
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
        }
        .frame(minWidth: 700, minHeight: 560)
        .task {
            await store.loadAll(category: .main)
            await store.loadAll(category: .coding)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "app.badge.checkmark")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text("SetDefaultAppsX")
                    .font(.system(size: 24, weight: .semibold))
                Text("Choose which applications open each file type and URL scheme.")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task {
                    await store.loadAll(category: selectedCategory)
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
    }

    // MARK: - File Type List

    private func fileTypeList(for category: FileTypeCategory) -> some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(category.entries) { entry in
                    FileTypeRow(entry: entry, store: store)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            Text(store.globalStatus)
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Apply All Changes") {
                Task {
                    await store.applyAll(category: selectedCategory)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - File Type Row

struct FileTypeRow: View {
    let entry: FileTypeEntry
    @ObservedObject var store: DefaultAppStore

    private var state: FileTypeState {
        store.states[entry.id] ?? FileTypeState()
    }

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            Image(systemName: entry.systemImage)
                .font(.system(size: 18))
                .foregroundColor(.accentColor)
                .frame(width: 28, alignment: .center)

            // Label + current default
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.headline)
                    .lineLimit(1)
                if let current = state.currentDefault {
                    HStack(spacing: 4) {
                        Text("Current:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        AppIconLabel(app: current, small: true)
                    }
                } else if !state.isLoading {
                    Text("No default set")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 200, alignment: .leading)

            Spacer()

            // App picker -- use Menu for consistent sizing with icons
            if state.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 260, alignment: .trailing)
            } else if state.candidates.isEmpty {
                Text("No apps found")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(width: 260, alignment: .trailing)
            } else {
                appMenu
                    .frame(width: 260, alignment: .trailing)
            }

            // Set button
            Button("Set") {
                Task {
                    await store.setDefault(entry: entry)
                }
            }
            .disabled(state.isLoading || !hasChanged)
            .buttonStyle(.bordered)
            .frame(width: 56)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var appMenu: some View {
        Menu {
            ForEach(state.candidates) { app in
                Button {
                    var s = store.states[entry.id] ?? FileTypeState()
                    s.selectedAppID = app.id
                    store.states[entry.id] = s
                } label: {
                    Label {
                        Text(app.displayName)
                    } icon: {
                        Image(nsImage: app.icon)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                if let selected = state.candidates.first(where: { $0.id == state.selectedAppID }) {
                    Image(nsImage: selected.icon)
                        .resizable()
                        .frame(width: 18, height: 18)
                    Text(selected.displayName)
                        .lineLimit(1)
                } else {
                    Text("Select an app...")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
        }
        .menuStyle(.borderlessButton)
    }

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

    private var hasChanged: Bool {
        guard let selectedID = state.selectedAppID else { return false }
        if let currentDefault = state.currentDefault {
            return selectedID != currentDefault.id
        }
        return true
    }
}

// MARK: - App Icon + Label

struct AppIconLabel: View {
    let app: HandlerApp
    let small: Bool

    var body: some View {
        HStack(spacing: small ? 4 : 6) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: small ? 14 : 18, height: small ? 14 : 18)
            Text(app.displayName)
                .font(small ? .caption : .callout)
                .lineLimit(1)
        }
    }
}
