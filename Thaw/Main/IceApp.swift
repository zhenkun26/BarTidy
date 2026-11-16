//
//  IceApp.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI

/// The process entry point.
///
/// Wraps ``IceApp`` so a command-line invocation can be served and the
/// process exited before AppKit starts. ``IceApp`` cannot do this itself:
/// its `@NSApplicationDelegateAdaptor` builds the `AppDelegate` — and with
/// it the whole `AppState` — as the `App` value is constructed, which is
/// already too late to decline to run.
@main
enum ThawMain {
    #if DEBUG
        private(set) static var isRunningUnitTestHost = false
    #endif

    static func main() {
        #if DEBUG
            // The unit-test host must never construct AppDelegate/AppState,
            // register menu bar items, migrate preferences, or request TCC access.
            // This variable is set only by the scheme's Test action.
            if ProcessInfo.processInfo.environment["BARTIDY_UNIT_TEST_HOST"] == "1" {
                isRunningUnitTestHost = true
                UnitTestHostApp.main()
                return
            }
        #endif
        guard !LayoutResetCommand.runIfRequested() else {
            return
        }
        IceApp.main()
    }
}

#if DEBUG
    private struct UnitTestHostApp: App {
        var body: some Scene {
            Settings { EmptyView() }
        }
    }
#endif

struct IceApp: App {
    @NSApplicationDelegateAdaptor var appDelegate: AppDelegate

    var body: some Scene {
        SettingsWindow(appState: appDelegate.appState)
        PermissionsWindow(appState: appDelegate.appState)
    }
}
