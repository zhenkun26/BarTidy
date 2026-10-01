# BarTidy

A personal [Thaw](https://github.com/thaw-app/Thaw) fork for macOS menu bar storage.

Items you do not stash stay in the menu bar. Hover the BarTidy icon to expand the tray; move away to collapse it.

This is a self-use project. Upstream Thaw changes may be merged over time. Issues and PRs are unlikely to be handled here — file them on [Thaw](https://github.com/thaw-app/Thaw/issues) instead.

Requires macOS 26+. Quit official Thaw before running BarTidy.

## Changes from Thaw

- New extras stay **Visible**. Only items you drag into Hidden are stored.
- Notch overflow is **off**, so unstored items are not auto-ejected.
- Hover the **BarTidy icon** (not empty menu bar space) to show the tray; leaving the icon and tray hides it after the hover delay (~0.2s).
- App identity is `BarTidy` / `dev.zhenkun.BarTidy`, with Thaw’s Sparkle feed disabled.
- Teamless local builds capture Hidden icons in the authorized app process, avoiding a fresh legacy-capture helper and its privacy alert each time the tray opens. Certificate-signed builds retain Thaw's recyclable helper.

Layout engine, search, hotkeys, profiles, triggers, and appearance are unchanged. The Swift module and source tree remain `Thaw` so upstream diffs stay readable.

## Usage

1. Open `Thaw.xcodeproj` in Xcode (**Open Existing Project…**, not Create New Project).
2. Scheme **Thaw**, destination **My Mac**. Product is `BarTidy.app`.
3. Run with ▶ or `⌘R`. Grant Accessibility when prompted.
4. In **Settings → Menu Bar Layout**, drag items to hide into Hidden. Leave frequent items in Visible.
5. Hover the BarTidy icon to open the tray.

```sh
xcodebuild -scheme Thaw -configuration Debug -destination 'platform=macOS' build
```

### Recovering permissions after a local rebuild

Only Accessibility is required to continue. Screen Recording enables icon previews in the tray, color sampling, and visual search.

The default local build uses ad-hoc signing. Its code identity changes when the app is rebuilt, so macOS can reject the new build even while an old BarTidy entry remains enabled in System Settings. Thaw's distributed builds use a certificate-based signing identity instead.

Use **Show Current App in Finder** on the permissions screen to locate the running copy. In **System Settings → Privacy & Security**, remove the old BarTidy entry and add that current copy for Accessibility and, if desired, Screen Recording. Restart BarTidy if macOS asks, or use **Restart BarTidy**. The screen rechecks access when the app becomes active; **Check Again** also refreshes it immediately. Keep using the same installed copy until the next rebuild.

Preserving authorization across rebuilds requires a consistent signing certificate and designated requirement. Keeping the same app name or bundle ID alone is insufficient.

Hover and background capture only run after a non-prompting system permission check succeeds. If access is missing or revoked, grant it from the permissions screen or **Settings → Advanced**, then restart if requested. Hover never asks for permission.

The local offscreen fallback still uses SkyLight because ScreenCaptureKit cannot capture icons parked outside the display on macOS 26. That API has a known small per-call allocation leak; in teamless builds it accumulates in BarTidy until quit. A certificate-signed build uses the recyclable helper to contain it. The growth has not been measured for this fork.

## Tracking Thaw

Upstream: [thaw-app/Thaw](https://github.com/thaw-app/Thaw) (`development`). Keep BarTidy defaults and hover behavior when merging:

- `Thaw/Utilities/Defaults.swift`
- `Thaw/Events/HIDEventManager.swift`
- display name, bundle ID, Sparkle off, this README

## License

[GPL-3.0](LICENSE), same as Thaw and [Ice](https://github.com/jordanbaird/Ice).

## Credits

- [Jordan Baird / Ice](https://github.com/jordanbaird/Ice)
- [Toni Förster / Thaw](https://github.com/thaw-app/Thaw)
