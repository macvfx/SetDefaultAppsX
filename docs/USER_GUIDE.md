# SetDefaultAppsX -- User Guide

## What Does This App Do?

SetDefaultAppsX lets you choose which applications open each file type and URL scheme on your Mac. For example, you can set Firefox as your default web browser, Sublime Text as the default for `.json` files, or Outlook as your default email client -- all from a single window.

## Getting Started

### Opening the App

Build and run from source:

```bash
cd SetDefaultAppsX
swift run
```

Or open `Package.swift` in Xcode and press **Cmd+R**.

When the app launches, it automatically scans your system for all registered handlers across every supported file type. This takes a moment on first launch.

### The Main Window

The window has three sections:

1. **Header** -- App title, description, and a Refresh button.
2. **Tab picker** -- Switch between **Apps** and **Code**.
3. **File type list** -- One row per file type, each with its own controls.

---

## Using the Apps Tab

The Apps tab covers everyday file types and URL schemes:

| Row | What It Controls |
|-----|-----------------|
| Email (mailto) | Which app opens when you click an email link |
| Web Browser (http/s) | Your default web browser |
| File Transfer (ftp) | Which app handles FTP links |
| PDF Documents | Which app opens `.pdf` files |
| Text Files (.txt) | Which app opens plain text files |
| Markdown (.md) | Which app opens Markdown files |
| Spreadsheets (.xlsx) | Which app opens Excel spreadsheets |
| Documents (.docx) | Which app opens Word documents |
| Rich Text (.rtf) | Which app opens RTF files |
| HTML Files (.html) | Which app opens HTML files |
| CSV Files (.csv) | Which app opens CSV files |

## Using the Code Tab

The Code tab covers developer and configuration file types:

| Row | What It Controls |
|-----|-----------------|
| JSON (.json) | JSON configuration and data files |
| YAML (.yaml) | YAML configuration files |
| TOML (.toml) | TOML configuration files |
| Property List (.plist) | macOS property list files |
| Mobile Config (.mobileconfig) | Apple configuration profiles |
| XML (.xml) | XML files |
| Shell Scripts (.sh) | Bash shell scripts |
| Zsh Scripts (.zsh) | Zsh shell scripts |
| Python (.py) | Python source files |
| Ruby (.rb) | Ruby source files |
| Swift (.swift) | Swift source files |
| JavaScript (.js) | JavaScript source files |

---

## Changing a Default App

Each row in the file type list works the same way:

### 1. Review the Current Default

On the left side of each row you'll see:
- The **file type name** and an icon
- **Current:** followed by the app icon and name of whatever is set right now

### 2. Pick a New App

The **dropdown menu** on the right shows every app on your Mac that has registered itself as capable of opening that file type. Each entry shows the app's icon and name.

Select the app you want to use.

### 3. Apply the Change

Click the **Set** button next to that row. The button is only enabled when your selection differs from the current default.

The current default label will update to reflect the change.

### 4. Apply All Changes at Once

If you've changed selections in multiple rows, click **Apply All Changes** at the bottom of the window. This applies every row where your selection differs from the current default.

---

## Refreshing the App List

If you install or remove an application while SetDefaultAppsX is open, click the **Refresh** button in the top-right corner. This re-scans the system for all registered handlers in the current tab.

---

## How macOS Default Apps Work

### File Extensions (UTTypes)

When you double-click a `.pdf` file in Finder, macOS looks up the **Uniform Type Identifier** (UTType) for that extension -- in this case `com.adobe.pdf`. It then checks which application is registered as the default handler for that UTType.

SetDefaultAppsX uses `NSWorkspace.setDefaultApplication(at:toOpen:)` to change this registration. The change takes effect immediately -- Finder will use the new app next time you open that file type.

### URL Schemes

URL schemes like `mailto:`, `https:`, and `ftp:` work differently. When you click a link in any app, macOS checks which application is registered as the default handler for that scheme.

SetDefaultAppsX uses `LSSetDefaultHandlerForURLScheme` to change URL scheme handlers. Some URL scheme changes (particularly `https`) may trigger a macOS confirmation dialog asking you to verify the change.

### Why Some Apps Don't Appear

An app only appears in the dropdown if it has registered itself with macOS as capable of opening that file type. If your preferred app doesn't appear:

- Make sure the app is installed in `/Applications` or `/System/Applications`
- Some apps need to be launched at least once before macOS registers their file type associations
- The app may not have declared support for that specific file type in its Info.plist

---

## Troubleshooting

### "No apps found" for a file type

This means macOS doesn't have a UTType registered for that extension, or no installed apps declare support for it. This is common for uncommon extensions like `.toml` or `.mobileconfig`. In these cases, SetDefaultAppsX shows a list of known text editors as fallback candidates.

### Change didn't take effect

Some changes require Finder to refresh its Launch Services database. Try:
- Closing and reopening Finder (Option-right-click the Finder icon in the Dock, then Relaunch)
- Logging out and back in

### URL scheme change shows a system dialog

This is expected behavior. macOS asks for confirmation when changing the default web browser or email client. Click the confirmation button in the system dialog to complete the change.

### App crashes or won't launch

Make sure you're running macOS 13 Ventura or later. The app uses APIs that are not available on older macOS versions.

---

## Privacy and Security

SetDefaultAppsX:

- **Does not access the internet** -- All operations are local.
- **Does not modify any files** -- It only calls macOS system APIs to register default handlers.
- **Does not require admin privileges** -- Default app settings are per-user.
- **Does not collect any data** -- No telemetry, no analytics, no phone-home.
- **Runs entirely in user space** -- No background processes, no launch daemons.
