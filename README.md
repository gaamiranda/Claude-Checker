# Claude-Checker

A macOS menu bar app that displays your Claude and Cursor API usage at a glance. See your usage limits with color-coded progress bars that show your current consumption.

![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Tabbed Interface** - Switch between Claude and Cursor usage tracking
- **Claude Usage Dashboard**:
  - Session usage (5-hour window)
  - Weekly usage (7-day aggregate)
  - Sonnet-specific weekly usage
  - Extra usage spending (if enabled)
  - Time until usage resets
- **Cursor Usage Dashboard**:
  - Plan usage with spending limits (Pro: $20, Pro+: $60, Ultra: $200)
  - On-demand usage tracking
  - Billing cycle reset date
  - Membership type display
- **Auto-Refresh** - Usage data updates automatically every 5 minutes
- **Launch at Login** - Optionally start the app when you log in

## Screenshots

| Menu Bar | Claude Tab | Cursor Tab |
|----------|------------|------------|
| Icon in your menu bar | Claude usage details | Cursor usage details |

## Requirements

- macOS 14.0 (Sonoma) or later
- For Claude: [Claude Code CLI](https://claude.ai/code) installed and authenticated
- For Cursor: Browser access to cursor.com (for cookie authentication)

## Installation

### Option 1: Download Release (Recommended)

1. Go to [Releases](../../releases)
2. Download the latest `Claude-Checker.app.zip`
3. Extract and move `Claude-Checker.app` to your `/Applications` folder
4. Open the app (you may need to right-click → Open the first time)

### Option 2: Build from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/claude-checker.git
   cd claude-checker/Claude-Checker
   ```

2. Build the app:
   ```bash
   xcodebuild -scheme Claude-Checker -configuration Release build
   ```

3. Copy to Applications:
   ```bash
   cp -R ~/Library/Developer/Xcode/DerivedData/Claude-Checker-*/Build/Products/Release/Claude-Checker.app /Applications/
   ```

4. Launch the app from `/Applications/Claude-Checker.app`

## Setup

### Claude Setup

Claude authentication is automatic if you have Claude Code CLI installed:

1. Install and authenticate Claude Code CLI:
   ```bash
   claude login
   ```
2. Launch Claude-Checker - it will automatically read your credentials

### Cursor Setup

Cursor requires manual cookie configuration:

1. Open the app and switch to the **Cursor** tab
2. Open [cursor.com](https://cursor.com) in your browser and log in
3. Open Developer Tools (Cmd+Option+I)
4. Go to the **Network** tab and refresh the page
5. Click any request to `cursor.com`
6. In the Headers tab, find and copy the `Cookie` header value
7. Paste the cookie into the app and click **Save Cookie**

The cookie is stored locally and used to authenticate with Cursor's API.

## How It Works

### Claude Authentication

1. **Keychain Access** - The app reads your OAuth token from macOS Keychain (stored by Claude Code CLI)
2. **API Request** - It calls the Anthropic usage endpoint with your token
3. **Display** - Usage percentages are shown in the dashboard

### Cursor Authentication

1. **Cookie Storage** - Your browser cookie is stored in UserDefaults
2. **API Request** - It calls Cursor's usage-summary endpoint
3. **Display** - Plan usage and on-demand spending are shown

### Why Keychain Access?

When you authenticate with Claude Code (`claude` CLI), your OAuth credentials are securely stored in the macOS Keychain under the service name `Claude Code-credentials`. 

Claude-Checker needs to read these credentials to fetch your usage data. This is why:

- **The app runs without sandbox** - macOS sandboxing would prevent access to credentials stored by other apps
- **No password is stored by Claude-Checker** - It only reads the existing credentials from Claude Code
- **Your credentials never leave your machine** - They're only used to make API calls to Anthropic

### Fallback: Credentials File

If Keychain access fails, the app falls back to reading credentials from:
```
~/.claude/.credentials.json
```

## Privacy & Security

- **No data collection** - Claude-Checker doesn't collect or transmit any personal data
- **Local only** - All processing happens on your machine
- **Open source** - You can audit the code yourself
- **Credentials stay secure** - OAuth tokens are read from Keychain, cookies stored locally

### Permissions Explained

| Permission | Why It's Needed |
|------------|-----------------|
| Keychain Access | Read Claude Code's OAuth token to authenticate API requests |
| Network Access | Fetch usage data from `api.anthropic.com` and `cursor.com` |
| Launch at Login | Optional - start the app automatically when you log in |

## Configuration

### Launch at Login

Toggle "Launch at Login" in the dashboard to have Claude-Checker start automatically when you log in to your Mac.

### Manual Refresh

Click the refresh button (↻) in the dashboard to manually update usage data.

### Clear Cursor Cookie

Click the (✕) button next to the refresh button in the Cursor tab to clear your stored cookie and reconfigure.

## Troubleshooting

### Claude: "Credentials not found" Error

1. Make sure Claude Code CLI is installed and authenticated:
   ```bash
   claude --version
   claude login
   ```

2. Verify credentials exist:
   ```bash
   security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null && echo "Found" || echo "Not found"
   ```

### Claude: "Token missing required scope" Error

Your token needs the `user:profile` scope. Re-authenticate with Claude Code:
```bash
claude logout
claude login
```

### Cursor: "Cookie expired or invalid" Error

Your browser cookie has expired. Get a fresh cookie:
1. Log in to cursor.com in your browser
2. Open DevTools → Network tab
3. Refresh and copy a new Cookie header
4. Paste it in the app

### Icon Not Showing in Menu Bar

1. Check if the app is running: `ps aux | grep Claude-Checker`
2. Try quitting and relaunching the app
3. Check System Settings → Control Center → Menu Bar Only to ensure it's not hidden

### App Won't Open (macOS Gatekeeper)

Since the app isn't notarized, macOS may block it:
1. Right-click the app → Open
2. Click "Open" in the dialog
3. Or: System Settings → Privacy & Security → Click "Open Anyway"

## Technical Details

### Claude API Endpoint

```
GET https://api.anthropic.com/api/oauth/usage
Headers:
  Authorization: Bearer <access_token>
  anthropic-beta: oauth-2025-04-20
```

### Cursor API Endpoint

```
GET https://www.cursor.com/api/usage-summary
Headers:
  Cookie: <browser_cookie>
```

### Cursor Plan Limits

| Plan | Monthly Limit |
|------|---------------|
| Pro | $20 |
| Pro+ | $60 |
| Ultra | $200 |

### Project Structure

```
Claude-Checker/
├── ClaudeCheckerApp.swift      # App entry point, MenuBarExtra setup
├── Info.plist                  # LSUIElement=true (no dock icon)
├── Assets.xcassets/            # App icon
├── Models/
│   ├── Credentials.swift       # OAuth credential models
│   ├── UsageModels.swift       # Claude API response models
│   └── CursorModels.swift      # Cursor API response models
├── Services/
│   ├── KeychainService.swift   # Keychain + file fallback
│   ├── UsageAPIClient.swift    # Claude API client
│   ├── CursorAPIClient.swift   # Cursor API client
│   ├── CursorCookieService.swift # Cookie storage
│   └── LaunchAtLoginService.swift
├── ViewModels/
│   ├── UsageViewModel.swift    # Claude state management
│   └── CursorViewModel.swift   # Cursor state management
└── Views/
    ├── DashboardView.swift     # Main tabbed UI
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

---

**Note:** This is an unofficial app and is not affiliated with Anthropic or Cursor. Claude is a trademark of Anthropic.
