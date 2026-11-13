# Mac Power Switcher

<p align="center">
  <strong>A lightweight, native macOS menu bar app to keep your Mac awake with the lid closed.</strong>
</p>

<p align="center">
  <a href="https://github.com/gssisaac/mac-power-switcher/releases/latest">
    <img src="https://img.shields.io/github/v/release/gssisaac/mac-power-switcher?color=blue&label=Latest%20Release" alt="Latest Release">
  </a>
  <img src="https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey" alt="macOS 13+">
  <img src="https://img.shields.io/badge/notarization-Apple%20Notarized-success" alt="Apple Notarized">
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License">
  </a>
</p>

---

## ⚡ Quick Download

<p align="center">
  <a href="https://github.com/gssisaac/mac-power-switcher/releases/latest/download/MacPowerSwitcher.dmg">
    <img src="https://img.shields.io/badge/⬇️_Download-MacPowerSwitcher.dmg-blue?style=for-the-badge&logo=apple" alt="Download Mac Power Switcher DMG">
  </a>
</p>

<p align="center">
  <em>Or view all versions on the <a href="https://github.com/gssisaac/mac-power-switcher/releases">Releases page</a>.</em>
</p>

---

## 🚀 Features

- **⚡ True Lid-Close Operation:** Run long downloads, code compilation, server scripts, or render jobs with your MacBook lid closed—without needing an external monitor plugged in.
- **🛡️ Low-Battery Safety Guard:** If your Mac gets unplugged and the battery drops below your threshold (default: 10%), sleep prevention automatically turns off so your battery never drains to zero.
- **⏱️ Sleeps after the lid closes:** Pick 10m, 15m, 30m, 60m, a custom length, or Never. The time starts when the lid closes, not while you are using the Mac. When it ends, the Mac sleeps.
- **💻 Opening the lid resets it:** Wake mode stays on. Opening the lid cancels the sleep time and keeps the Mac awake. Closing the lid starts the full time again. The menu bar does not show a countdown.
- **🔒 Touch ID / Password Protection:** The first on or off after launch asks for Touch ID or your Mac password. Later changes in that session do not ask again.
- **🪶 Ultra-Lightweight & Native:** 100% native Swift & SwiftUI. No Electron, minimal CPU and RAM usage, lives entirely in your menu bar.
- **✨ Apple Notarized:** Signed with a Developer ID certificate and notarized by Apple for seamless Gatekeeper installation.

---

## 📥 Installation

1. **[Download the latest `MacPowerSwitcher.dmg`](https://github.com/gssisaac/mac-power-switcher/releases/latest/download/MacPowerSwitcher.dmg)**.
2. Open the `.dmg` and drag **Mac Power Switcher** into your **Applications** folder.
3. Open **Mac Power Switcher** from Applications or Spotlight.
4. Look for the lightning bolt icon (⚡) in your top menu bar.

> **Note on First Use:** The first time you turn wake mode on, macOS asks for administrator permission once to install a lightweight helper under `/Library/MacPowerSwitcher`. After each launch, the first **Turn on wake up** or **Turn off wake up** also asks for Touch ID or your password.

---

## 📖 How to Use

Click the menu bar icon (⚡) to manage sleep prevention:

- **Turn on wake up:** Keeps the Mac awake while the lid is open, on AC power. After the lid closes, the Mac stays awake until the time you set runs out, then sleeps.
- **Turn off wake up:** Reverts back to standard macOS sleep behavior.
- **Settings (`⌘,`):** Choose how long the Mac stays awake after the lid closes, and the minimum battery.

### Status Indicators

| Menu Bar Icon | Status |
| :--- | :--- |
| `bolt.fill` (⚡) | **Wake mode on** — The Mac stays awake while the lid is open. No countdown is shown. Closing the lid starts the sleep time. |
| `bolt.slash` | **Normal sleep** — Standard macOS power saving behavior. |

---

## ⚙️ Settings & Customization

Open **Settings** from the menu bar to customize:

1. **Sleep after closing the lid:** How long the Mac stays awake after the lid closes (`10m`, `15m`, `30m`, `60m`, custom minutes, or `Never`). The time does not count, and is not shown, while the lid is open. Opening the lid cancels it. Closing the lid starts the full time again. When the time ends, the Mac sleeps. Wake mode stays on, so the next open keeps the Mac awake.
2. **Minimum Battery Threshold:** Turn off wake mode if the battery reaches this percentage while unplugged with the lid closed.

Settings are saved locally to `~/.mac-power-switcher/settings.json`.

---

## 🔍 How It Works

Mac Power Switcher is a clean, native wrapper around macOS power management (`pmset -c disablesleep 1/0`):

- It only modifies power settings for **AC power (charger)**. On battery power, your Mac always sleeps normally unless customized otherwise.
- The one-time privileged helper (`/Library/MacPowerSwitcher/pmset-helper`) allows the app to update the `pmset` state securely without prompting you for root passwords on every click.

---

## 🗑️ Uninstallation

If you ever want to completely remove Mac Power Switcher:

1. Quit **Mac Power Switcher** from the menu bar.
2. Move `/Applications/MacPowerSwitcher.app` to Trash.
3. Run the following in Terminal to remove the helper and reset power settings to default:

```bash
sudo rm -rf /Library/MacPowerSwitcher /etc/sudoers.d/mac-power-switcher ~/.mac-power-switcher
sudo pmset -c disablesleep 0
```

---

## 🛠️ Building from Source

### Prerequisites

- macOS 13.0+
- Xcode Command Line Tools (`xcode-select --install`)

### Local Unsigned Build

```bash
git clone https://github.com/gssisaac/mac-power-switcher.git
cd mac-power-switcher
./build.sh
open dist/MacPowerSwitcher.dmg
```

### Signed & Notarized Release Build

```bash
# Set up credentials in scripts/deploy/apple-signing.env (see apple-signing.env.example)
bash scripts/deploy/build-macos.sh
```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
