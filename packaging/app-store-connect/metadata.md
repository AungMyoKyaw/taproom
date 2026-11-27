# Taproom — App Store Connect & Release Metadata (v0.2.0)

> **Mac App Store Note**: `Taproom` currently executes `/opt/homebrew/bin/brew` without App Sandbox (`com.apple.security.app-sandbox`). Mac App Store submissions require App Sandbox, which blocks arbitrary Homebrew CLI/Cask execution. Use this metadata pack for direct/Cask/landing-page listings, or for App Store Connect if a sandboxed helper architecture is added later.

---

## App Information

- **App Name**: Taproom — Homebrew Cockpit
- **Subtitle** *(≤30 chars)*: Native macOS Homebrew Manager
- **Bundle ID**: `dev.taproom.app`
- **SKU**: `taproom-macos-01`
- **Primary Category**: Developer Tools
- **Secondary Category**: Utilities
- **Version**: `0.2.0` (Build `2`)
- **Pricing**: Free (`$0.00` — all features unlocked)
- **Age Rating**: `4+`
- **Export Compliance (`ITSAppUsesNonExemptEncryption`)**: `NO` (set in `Resources/Info.plist`)
- **App Privacy**: **Data Not Collected** (100% local SQLite FTS5 catalog + local `brew` subprocess; no telemetry, analytics, or third-party tracking SDKs)

## URLs

- **Support URL**: `https://github.com/AungMyoKyaw/taproom/issues`
- **Marketing URL**: `https://github.com/AungMyoKyaw/taproom`
- **Privacy Policy URL**: `https://github.com/AungMyoKyaw/taproom/blob/master/README.md`

## Promotional Text *(≤170 chars)*

```text
Manage Homebrew formulae, casks, services, taps, and Brewfiles in a native macOS Tahoe Liquid Glass cockpit—with instant FTS5 search, Rosetta audit, and one-click app adoption.
```

## Keywords *(≤100 chars, comma-separated)*

```text
homebrew,brew,package manager,cask,developer tools,macos,terminal,services,brewfile,rosetta
```

## What's New in 0.2.0 *(≤4,000 chars)*

```text
- Adopt Existing Apps: Scan /Applications and ~/Applications, match unmanaged apps to Homebrew casks, and adopt them with one click.
- Rosetta & Architecture Audit: Flag Intel (x86_64) apps running under Rosetta on Apple Silicon alongside ARM64 and Universal badges.
- Operation History & Missing Check: Review past install/upgrade/maintenance runs with timestamps and durations, and run brew missing from Maintenance.
- Custom Binary & Proxy Overrides: Configure a custom brew executable path and HTTP/HTTPS proxy directly in Settings.
- All features unlocked for free.
```

## Description *(≤4,000 chars)*

```text
Taproom is a native macOS 26 (Tahoe) Homebrew cockpit built with SwiftUI, Liquid Glass navigation chrome, and local SQLite FTS5 search.

Built for engineers and power users who want zero-latency package inspection, deterministic upgrade queues, and live daemon control without leaving native macOS:

• Installed Catalog & Inspector (⌘I): Browse and sort formulae and casks with Cellar/Caskroom disk sizes, leaf/dependency filters, clickable dependency and reverse-dependency chips, and caveats.
• Outdated & Greedy Casks (⌘U): Upgrade individual packages or all outdated packages at once, with an optional --greedy toggle for auto-updating casks and pin/unpin controls.
• Instant FTS5 Discovery: Local SQLite FTS5 BM25 search across formulae.brew.sh metadata with offline cache fallback.
• Adopt Existing Apps & Rosetta Audit: Scan /Applications and ~/Applications to match manually installed apps to Homebrew casks (brew install --cask --adopt) and spot Intel (x86_64) apps running under Rosetta.
• Services, Taps, Maintenance & Brewfile: Start/stop/restart brew services from the main window or menu bar extra, manage taps, run brew doctor and brew missing, clean cache, autoremove orphans, review operation history, and export or import Brewfiles.
• Command Palette (⌘K) & Serial Queue (⌘L): Keyboard-first fuzzy launcher and FIFO brew runner with live ANSI-stripped log streaming, cancellation, and SUDO_ASKPASS elevation.
```

## App Review Notes *(if submitted)*

```text
Taproom is a local macOS GUI for Homebrew. No account or login is required. All data stays on-device; network requests only fetch public Homebrew catalog metadata from formulae.brew.sh and run user-initiated brew commands.
```

## Screenshots

- Live capture (`packaging/app-store-connect/screenshots/01-taproom-live.png`)
- Additional dark/light renders (`design/renders/01-installed-dark.png` through `05-palette-menubar-light.png`)
