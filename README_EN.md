# BrewGUI

<p align="center">
  <img src="ref/icon_option_c.png" alt="BrewGUI Logo" width="128" height="128" />
</p>

<p align="center">
  <strong>A lightweight, native, and transparent Homebrew GUI client for macOS</strong>
</p>

<p align="center">
  <a href="readme.md">简体中文</a> · <b>English</b>
</p>

<p align="center">
  <a href="https://github.com/cfqbridge/BrewGUI/releases"><img src="https://img.shields.io/badge/Release-v2.0.261107-blue.svg" alt="Release Version"></a>
  <a href="#"><img src="https://img.shields.io/badge/Platform-macOS%2014.0%2B%20%7C%20Apple%20Silicon-black.svg" alt="Platform"></a>
  <a href="#"><img src="https://img.shields.io/badge/Swift-6.0%20%7C%20Native%20AppKit%20%2B%20SwiftUI-orange.svg" alt="Swift"></a>
  <a href="#"><img src="https://img.shields.io/badge/i18n-简体中文%20%7C%20繁體中文%20%7C%20English-teal.svg" alt="i18n"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPL--3.0-green.svg" alt="License"></a>
</p>

---

## 🌟 Why BrewGUI?

[Homebrew](https://brew.sh/) is the indispensable package manager for macOS, yet daily CLI workflows often run into friction:
- **Zero progress feedback during large Cask upgrades**: Non-TTY pipes hide `curl` progress, making hundreds-of-megabyte downloads feel frozen.
- **Disconnected local apps in `/Applications`**: Manually installed `.dmg` apps sit outside Homebrew Cask tracking or drift out of sync with Cask versions.
- **Hidden disk bloat**: Gigabytes of cached installers in `~/Library/Caches/Homebrew/downloads` and orphaned Formula dependencies pile up silently.
- **Tedious machine migration**: Reinstalling dozens of packages one by one or blocked by a single slow Cask download.

**BrewGUI** solves these pain points with a 100% native **Swift 6 + SwiftUI + AppKit** architecture—no Electron, ultra-low memory footprint, instant search, and complete transparency over every `brew` command executed.

---

## ✨ Key Features

### 1. 🪟 Dual Interaction Mode (Desktop Window + Menu Bar Resident)
- **Left-Click to Open, Right-Click for Quick Popover**: Left-click the menu bar icon to summon the main window; right-click to open an adaptive popover showing outdated packages and one-click upgrades.
- **Silent Launch at Login**: Optionally start silently in the menu bar (`--silent`) and automatically hide the Dock icon whenever the main window is closed.
- **Scheduled Background Checks**: Automatically run `brew update` every 12h or 72h in the background with a subtle red badge when updates arrive.

### 2. 🔍 Bilingual Scenario Search & Smart Local App Adoption (`Adopt`)
- **Millisecond Search with Category Pills**: Built-in dictionary of 170+ popular Mac apps with bilingual aliases, functional tags, and 11 one-click category presets (`Essentials`, `Screenshot`, `Archive`, `Media`, `Translate`, `Productivity`, `Dev & CLI`, `AI Tools`, `Network`, `System & Clean`).
- **Smart `/Applications` Scanner & 4-Category Risk Advisories**: Automatically detects manually installed apps and flags **Mac App Store apps**, **version-locked production/plugin apps**, **apps with faster built-in updaters**, and **possible name/version collisions**, complete with a visual decision guide and one-click ignore for flagged items.
- **Version-Aware Force Upgrade**: When a local app is older than the Homebrew Cask version, BrewGUI uses `brew install --cask --force` to adopt and upgrade the app in one step rather than merely claiming an outdated bundle.

### 3. 📦 Installed Packages & On-Disk Bundle Verification
- **Multi-Dimensional Filtering**: Filter by Outdated, Top-Level (`brew leaves`), Formulae, Casks, or Pinned status (`brew pin` / `unpin`).
- **Real `Info.plist` Version Check**: Cross-checks `/Applications/<App>.app/Contents/Info.plist` against Homebrew's recorded version to catch version drift.
- **Clean Uninstall & `--zap`**: Uninstall Casks normally or with `--zap` to purge associated caches and preference files.

### 4. 🧹 4-in-1 Advanced Maintenance (Cache / `:zap` Leftovers / Services / Doctor)
- **Download Cache & Orphan Formulae**: Inspect every cached archive in `~/Library/Caches/Homebrew/downloads`, run `brew cleanup --prune=all`, and clean unused dependencies via `brew autoremove`.
- **Uninstalled App Leftover Scanner (`:zap`)**: Cross-references Cask `:zap` rules against installed Brew packages and `/Applications` `CFBundleIdentifier`s to safely detect and move orphaned `~/Library` folders of previously uninstalled apps to macOS Trash.
- **Background Services Manager (`brew services`)**: View, start, stop, restart, or run launchd background services (MySQL, Redis, PostgreSQL, Nginx, Ollama, Syncthing).
- **Environment Health & Tap Manager (`brew doctor` & `brew tap`)**: Run `brew doctor` with structured warning cards and manage third-party Tap repositories (`user/repo`).

### 5. ⚡️ Batch Install & Environment Migration
- **Paste & Parse**: Paste raw package lists or `brew install` scripts to resolve catalog status in real time.
- **Concurrent Download Size Probing**: Probes HTTP `HEAD Content-Length` concurrently so you can preview package sizes and filter lightweight packages (`<100MB`) first.
- **Hybrid Queue Scheduling**: Merges Formulae into a single dependency-shared command while queuing Casks individually so you can skip slow downloads at any time.
- **One-Click Export**: Export all top-level Formulae (`leaves`) and Casks from your Mac for effortless migration.

### 6. 📊 Real-Time Download Speed & Task Control
- **Live `.incomplete` Progress Tracking**: Monitors Homebrew's active download stream to display real-time percentage, downloaded bytes, and transfer speed (`KB/s`, `MB/s`).
- **Full Queue Control**: Skip the current package, stop all tasks, remove queued items, or retry failed/skipped tasks with one click.

### 7. 🌐 Multi-Language (i18n) & In-App Self-Update (v1.6)
- **Zero-Latency Language Switching**: Built-in **Simplified Chinese (`zh-Hans`)**, **Traditional Chinese (`zh-Hant`)**, and **English (`en`)** with System Default auto-detection. Switch languages anytime from the sidebar footer or menu bar popover without restarting.
- **SHA256-Verified In-App Self-Update**: Automatically checks GitHub Releases `version.json` (with automatic mirror fallback), downloads the latest `BrewGUI.dmg` in the background, verifies its `SHA256` checksum via `CryptoKit`, silently mounts and replaces `/Applications/BrewGUI.app`, clears quarantine attributes (`xattr -cr`), and relaunches.

---

## 💻 System Requirements

- **OS**: macOS 14.0 (Sonoma) or later
- **Architecture**: Apple Silicon (`arm64` — M1 / M2 / M3 / M4)
- **Prerequisite**: [Homebrew](https://brew.sh/) installed (default `/opt/homebrew`; if not installed, BrewGUI v2.0 includes an in-app terminal-free graphical installer with mirror speed testing and automatic `PATH` configuration)

---

## 🚀 Installation

### Option 1: Download DMG Installer (Recommended)
1. Download the latest `BrewGUI.dmg` from [GitHub Releases](https://github.com/cfqbridge/BrewGUI/releases).
2. Open `BrewGUI.dmg` and drag `BrewGUI.app` into the `Applications` folder.
3. On first launch:
   - If macOS Gatekeeper prompts that the developer cannot be verified, open **System Settings → Privacy & Security** and click **Open Anyway** (or run `xattr -cr /Applications/BrewGUI.app`).
   - Grant **App Management** permission when prompted so BrewGUI can install and update applications in `/Applications`.

### Option 2: Build from Source
Only macOS Command Line Tools (`swift` 6.0+) are required—full Xcode is not needed:

```zsh
# 1. Clone the repository
git clone https://github.com/cfqbridge/BrewGUI.git
cd BrewGUI

# 2. Build and package .app & .dmg
./scripts/bundle_app.sh

# 3. Launch the app
open dist/BrewGUI.app
```

---

## 🛠️ Project Structure

```text
├── Package.swift               # Swift Package Manager manifest
├── readme.md                   # Chinese documentation (default)
├── README_EN.md                # English documentation
├── Sources/
│   └── BrewGUI/                # Native SwiftUI + AppKit source code
├── scripts/
│   └── bundle_app.sh           # Automated build, ad-hoc codesign & DMG packaging script
└── ref/
    ├── DESIGN_SUMMARY.md       # Visual design summary & archive notes
    ├── icon_option_c.png       # App icon source (1024x1024 PNG)
    ├── dmg_bg_option_c.png     # Retina DMG installer background
    └── dmg_DS_Store            # Pre-built Finder DMG layout template for CI
```

---

## 📄 License & Non-Commercial Notice

This project is licensed under the **GNU General Public License v3.0 (GPL-3.0)** — see the [LICENSE](LICENSE) file for details.

### Additional Non-Commercial / Anti-Abuse Notice
- Without explicit prior written authorization from the original author, no individual or organization may repackage this software or its derivatives as proprietary software, distribute it on commercial app stores for profit, sell it, or bundle commercial advertisements.
- Personal use, study, issue reporting, and open-source Pull Requests are warmly welcome!
