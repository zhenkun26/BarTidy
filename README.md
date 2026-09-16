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
