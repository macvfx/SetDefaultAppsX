import SwiftUI

@main
struct SetDefaultAppsXApp: App {
    @StateObject private var store = DefaultAppStore()

    var body: some Scene {
        WindowGroup("SetDefaultAppsX") {
            ContentView(store: store)
                .frame(minWidth: 700, minHeight: 560)
        }
        .commands {
            AppCommands()
        }

        Window("About SetDefaultAppsX", id: "about") {
            AboutView()
        }

        Window("Help", id: "help") {
            HelpView()
        }
    }
}

private struct AppCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About SetDefaultAppsX") {
                openWindow(id: "about")
            }
        }

        CommandGroup(replacing: .help) {
            Button("SetDefaultAppsX Help") {
                openWindow(id: "help")
            }
            .keyboardShortcut("/", modifiers: [.command, .shift])

            Divider()

            Link("code.matx.ca", destination: URL(string: "https://code.matx.ca")!)

            Link("GitHub Repository", destination: URL(string: "https://github.com/macvfx/SetDefaultAppsX")!)
        }
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var versionString: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(shortVersion) (\(buildVersion))"
    }

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "app.badge.checkmark")
                .font(.system(size: 56, weight: .light))
                .foregroundColor(.accentColor)

            VStack(spacing: 6) {
                Text("SetDefaultAppsX")
                    .font(.system(size: 22, weight: .semibold))
                Text("Set default applications for file types and URL schemes on macOS.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text(versionString)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Link("code.matx.ca", destination: URL(string: "https://code.matx.ca")!)
                .font(.headline)

            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(28)
        .frame(minWidth: 360, minHeight: 280)
    }
}

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("SetDefaultAppsX Help")
                        .font(.system(size: 24, weight: .semibold))
                    Text("Set default applications for file types and URL schemes.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }

            GroupBox("Getting Started") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Use the **Main Apps** tab to set defaults for common file types like PDF, text, email, and web browsing.")
                    Text("Use the **Coding Files** tab to set defaults for developer files like JSON, YAML, shell scripts, and more.")
                    Text("Select an app from the dropdown, then click **Set** to apply. Or use **Apply All Changes** to apply everything at once.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("How It Works") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SetDefaultAppsX uses native macOS APIs to query and set default handlers.")
                    Text("For file types, it uses `UTType` and `NSWorkspace` to find registered apps.")
                    Text("For URL schemes (mailto, http, ftp), it queries Launch Services directly.")
                    Text("Changes take effect immediately -- no restart or logout required.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Links") {
                VStack(alignment: .leading, spacing: 8) {
                    Link("code.matx.ca", destination: URL(string: "https://code.matx.ca")!)
                    Link("GitHub -- macvfx/SetDefaultAppsX", destination: URL(string: "https://github.com/macvfx/SetDefaultAppsX")!)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 560, minHeight: 400, alignment: .topLeading)
    }
}
