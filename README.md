# SetDefaultAppsX
"Enhanced" version of [SetDefaultapps](https://github.com/ScottEKendall/JAMF-Pro-Scripts/tree/main/SetDefaultApps) by Scott E Kendall

# SetDefaultAppsX Setup Instructions

## Overview

SetDefaultAppsX is a macOS script that allows users to set default applications for various file types (mailto, http, ftp, documents, etc.) using a graphical dialog interface.

## Quick Start (Simplest Method)

1. Install utiluti: https://github.com/scriptingosx/utiluti
2. Run the script: `./SetDefaultAppsX.sh`

That's it! The script will automatically:
- Download and install swiftDialog if needed
- Create directories in `/Users/Shared/SetDefaultAppsX/`
- Run without requiring sudo

## Requirements

- macOS (Apple Silicon or Intel)
- **utiluti** - Command-line tool for managing UTI (Uniform Type Identifier) associations
  - Install from: https://github.com/scriptingosx/utiluti
- **swiftDialog** - Will be automatically downloaded and installed if not present
  - Source: https://github.com/bartreardon/swiftDialog

## Installation Steps

### Step 1: (Optional) Run the Preparation Script for System-Wide Setup

**Note**: The preparation script is optional. If not run, SetDefaultAppsX will automatically create directories in `/Users/Shared/SetDefaultAppsX/` instead.

For a system-wide installation in `/Library/Application Support/`, run:

```bash
sudo ./PrepareSetDefaultAppsX.sh
```

This script will create:
- `/Library/Application Support/SetDefaultAppsX/` - Main support directory
- `/Library/Application Support/SetDefaultAppsX/logs/` - Log files directory
- `/Library/Application Support/SetDefaultAppsX/SupportFiles/` - Optional banner images

**If you skip this step**, the script will automatically use `/Users/Shared/SetDefaultAppsX/` and create all necessary directories there without requiring sudo.

### Step 2: (Optional) Add Custom Banner Image

If you want to customize the dialog banner:

```bash
sudo cp your-banner-image.png "/Library/Application Support/SetDefaultAppsX/SupportFiles/SD_BannerImage.png"
```

### Step 3: Install utiluti

Install the utiluti command-line tool:

```bash
# Download and install from GitHub
# Visit: https://github.com/scriptingosx/utiluti
```

### Step 4: Run SetDefaultAppsX

Once the preparation is complete, any user can run the script without sudo:

```bash
./SetDefaultAppsX.sh
```

## Directory Structure

### With PrepareSetDefaultAppsX.sh (System-Wide)

After running PrepareSetDefaultAppsX.sh, the following structure will exist:

```
/Library/Application Support/SetDefaultAppsX/
├── logs/
│   └── SetDefaultAppsX.log
└── SupportFiles/
    └── SD_BannerImage.png (optional)
```

### Without PrepareSetDefaultAppsX.sh (Automatic Fallback)

If the preparation script is not run, the script will automatically create:

```
/Users/Shared/SetDefaultAppsX/
├── logs/
│   └── SetDefaultAppsX.log
└── SupportFiles/
    └── SD_BannerImage.png (optional)
```

## Manual Setup (Alternative)

If you prefer to manually create the directories instead of using the preparation script:

```bash
# Create directories
sudo mkdir -p "/Library/Application Support/SetDefaultAppsX/logs"
sudo mkdir -p "/Library/Application Support/SetDefaultAppsX/SupportFiles"

# Set permissions
sudo chmod 755 "/Library/Application Support/SetDefaultAppsX"
sudo chmod 777 "/Library/Application Support/SetDefaultAppsX/logs"
sudo chmod 755 "/Library/Application Support/SetDefaultAppsX/SupportFiles"
```

## Managed Preferences (Optional)

For enterprise deployments, you can use a managed preferences plist to customize settings:

**Location**: `/Library/Managed Preferences/com.setdefaultappsx.defaults.plist`

**Keys**:
- `SupportFiles` - Path to support files directory
- `BannerImage` - Filename of banner image
- `BannerPadding` - Number of spaces for banner text padding

Example:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>SupportFiles</key>
    <string>/Library/Application Support/SetDefaultAppsX/SupportFiles/</string>
    <key>BannerImage</key>
    <string>SD_BannerImage.png</string>
    <key>BannerPadding</key>
    <integer>5</integer>
</dict>
</plist>
```

## Troubleshooting

### Warning: "Application Support directory not found"

This is normal if you haven't run the preparation script. The script will automatically fall back to `/Users/Shared/SetDefaultAppsX/` and create all necessary directories there.

If you want to use the system-wide location instead, run:
```bash
sudo ./PrepareSetDefaultAppsX.sh
```

### Error: "Cannot create log file"

This should not happen with the automatic fallback to `/Users/Shared`. If it does, check that `/Users/Shared` exists and is writable:
```bash
ls -ld /Users/Shared
```

### Error: "utiluti is not installed"

Install utiluti from: https://github.com/scriptingosx/utiluti

### swiftDialog not installing

The script will automatically download and install swiftDialog from GitHub. Ensure you have internet connectivity.

## File Descriptions

| File | Purpose |
|------|---------|
| `PrepareSetDefaultAppsX.sh` | One-time setup script (run with sudo) |
| `SetDefaultAppsX.sh` | Main script for setting default apps (run as user) |
| `SETUP.md` | This documentation file |

## Version History

- **2.0** (2025-12-15)
  - Removed JAMF dependencies
  - Added standalone swiftDialog installer
  - Fixed Apple Silicon CPU detection
  - Replaced GiantEagle references with SetDefaultAppsX
  - Removed sudo from main script
  - Added preparation script for directory setup

- **1.0** (2025-12-11)
  - Initial version by Scott Kendall

## Support

For issues or questions:
- utiluti: https://github.com/scriptingosx/utiluti
- swiftDialog: https://github.com/bartreardon/swiftDialog
