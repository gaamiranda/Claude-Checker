# ClaudeMascot

A macOS menu bar app that displays your Claude API usage at a glance. See your session and weekly usage limits with a color-coded icon that changes based on your current consumption.

![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Menu Bar Icon** - A color-coded "C" icon shows your usage status at a glance:
  - **Green** (0-30% session usage) - Plenty of capacity remaining
  - **Blue** (30-70% session usage) - Moderate usage
  - **Red** (70-100% session usage) - Approaching limit
  - **Gray** - Loading or error state

- **Detailed Dashboard** - Click the icon to see:
  - Session usage (5-hour window)
  - Weekly usage (7-day aggregate)
  - Sonnet-specific weekly usage
  - Extra usage spending (if enabled)
  - Time until usage resets

- **Auto-Refresh** - Usage data updates automatically every 5 minutes
- **Launch at Login** - Optionally start the app when you log in

## Screenshots

| Menu Bar | Dashboard |
|----------|-----------|
| The icon in your menu bar | Click to see detailed usage |

## Requirements

- macOS 14.0 (Sonoma) or later
- [Claude Code CLI](https://claude.ai/code) installed and authenticated
- An active Claude subscription (Pro, Max, Team, or Enterprise)

## Installation

### Option 1: Download Release (Recommended)

1. Go to [Releases](../../releases)
2. Download the latest `ClaudeMascot.app.zip`
3. Extract and move `ClaudeMascot.app` to your `/Applications` folder
4. Open the app (you may need to right-click → Open the first time)

### Option 2: Build from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/claude-mascot.git
   cd claude-mascot/ClaudeMascot
   ```

2. Build the app:
   ```bash
   xcodebuild -scheme ClaudeMascot -configuration Release build
   ```

3. Copy to Applications:
   ```bash
   cp -R ~/Library/Developer/Xcode/DerivedData/ClaudeMascot-*/Build/Products/Release/ClaudeMascot.app /Applications/
   ```

4. Launch the app from `/Applications/ClaudeMascot.app`

## How It Works

ClaudeMascot reads your Claude authentication credentials and fetches usage data from Anthropic's API.

### Authentication Flow

1. **Keychain Access** - The app reads your OAuth token from macOS Keychain (stored by Claude Code CLI)
2. **API Request** - It calls the Anthropic usage endpoint with your token
3. **Display** - Usage percentages are shown in the menu bar and dashboard

### Why Keychain Access?

When you authenticate with Claude Code (`claude` CLI), your OAuth credentials are securely stored in the macOS Keychain under the service name `Claude Code-credentials`. 

ClaudeMascot needs to read these credentials to fetch your usage data. This is why:

- **The app runs without sandbox** - macOS sandboxing would prevent access to credentials stored by other apps
- **No password is stored by ClaudeMascot** - It only reads the existing credentials from Claude Code
- **Your credentials never leave your machine** - They're only used to make API calls to Anthropic

If you haven't authenticated with Claude Code yet, run:
```bash
claude login
```

### Fallback: Credentials File

If Keychain access fails, the app falls back to reading credentials from:
```
~/.claude/.credentials.json
```

## Privacy & Security

- **No data collection** - ClaudeMascot doesn't collect or transmit any personal data
- **Local only** - All processing happens on your machine
- **Open source** - You can audit the code yourself
- **Credentials stay secure** - OAuth tokens are read from Keychain, never stored separately

### Permissions Explained

| Permission | Why It's Needed |
|------------|-----------------|
| Keychain Access | Read Claude Code's OAuth token to authenticate API requests |
| Network Access | Fetch usage data from `api.anthropic.com` |
| Launch at Login | Optional - start the app automatically when you log in |

## Configuration

### Launch at Login

Toggle "Launch at Login" in the dashboard to have ClaudeMascot start automatically when you log in to your Mac.

### Manual Refresh

Click the refresh button (↻) in the dashboard to manually update usage data.

## Troubleshooting

### "Credentials not found" Error

1. Make sure Claude Code CLI is installed and authenticated:
   ```bash
   claude --version
   claude login
   ```

2. Verify credentials exist:
   ```bash
   security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null && echo "Found" || echo "Not found"
   ```

### "Token missing required scope" Error

Your token needs the `user:profile` scope. Re-authenticate with Claude Code:
```bash
claude logout
claude login
```

### Icon Not Showing in Menu Bar

1. Check if the app is running: `ps aux | grep ClaudeMascot`
2. Try quitting and relaunching the app
3. Check System Settings → Control Center → Menu Bar Only to ensure it's not hidden

### App Won't Open (macOS Gatekeeper)

Since the app isn't notarized, macOS may block it:
1. Right-click the app → Open
2. Click "Open" in the dialog
3. Or: System Settings → Privacy & Security → Click "Open Anyway"

## Technical Details

### API Endpoint

```
GET https://api.anthropic.com/api/oauth/usage
Headers:
  Authorization: Bearer <access_token>
  anthropic-beta: oauth-2025-04-20
```

### Response Format

```json
{
  "five_hour": { "utilization": 25.0, "resets_at": "2024-01-15T10:00:00Z" },
  "seven_day": { "utilization": 45.0, "resets_at": "2024-01-20T00:00:00Z" },
  "seven_day_sonnet": { "utilization": 10.0, "resets_at": null },
  "extra_usage": { "is_enabled": true, "monthly_limit": 100.0, "used_credits": 25.50 }
}
```

### Project Structure

```
ClaudeMascot/
├── ClaudeMascotApp.swift      # App entry point, MenuBarExtra setup
├── Info.plist                  # LSUIElement=true (no dock icon)
├── Assets.xcassets/            # App icon
├── Models/
│   ├── Credentials.swift       # OAuth credential models
│   └── UsageModels.swift       # API response models
├── Services/
│   ├── KeychainService.swift   # Keychain + file fallback
│   ├── UsageAPIClient.swift    # API client
│   └── LaunchAtLoginService.swift
├── ViewModels/
│   └── UsageViewModel.swift    # @Observable state management
└── Views/
    ├── DashboardView.swift     # Main popover UI
    └── UsageProgressBar.swift  # Reusable progress component
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with SwiftUI for macOS
- Uses SF Symbols for iconography
- Inspired by the need to keep track of Claude usage limits

---

**Note:** This is an unofficial app and is not affiliated with Anthropic. Claude is a trademark of Anthropic.
