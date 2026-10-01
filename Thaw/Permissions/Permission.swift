//
//  Permission.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Cocoa
import Combine
import SwiftUI

// MARK: - Permission

/// An object that encapsulates the behavior of checking for and requesting
/// a specific permission for the app.
@MainActor
@Observable
class Permission: Identifiable {
    /// A Boolean value that indicates whether the app has this permission.
    private(set) var hasPermission = false {
        didSet {
            // Notify owners only when the effective permission changes.
            guard oldValue != hasPermission else { return }
            onChange?()
        }
    }

    /// Callback invoked after ``hasPermission`` changes, with the new value
    /// already stored. Set by owners (e.g. AppPermissions) that need to
    /// react to updates.
    @ObservationIgnored
    var onChange: (() -> Void)?

    /// The title of the permission.
    let title: String

    /// The name of the system symbol image to display next to the title.
    let iconName: String

    /// The color of the icon displayed next to the title.
    let iconColor: Color

    /// Descriptive details for the permission.
    let details: [String]

    /// A Boolean value that indicates if the app can work without this permission.
    let isRequired: Bool

    /// The URL of the settings pane to open.
    private let settingsURL: URL?

    /// The function that checks permissions.
    private let check: () -> Bool

    /// The function that requests permissions.
    private let request: () -> Void

    /// The function that opens a System Settings URL.
    private let openSettings: (URL) -> Bool

    /// Observer that runs on a timer to check permissions.
    private var timerCancellable: AnyCancellable?

    /// Creates a permission.
    ///
    /// - Parameters:
    ///   - title: The title of the permission.
    ///   - details: Descriptive details for the permission.
    ///   - isRequired: A Boolean value that indicates if the app can work without this permission.
    ///   - settingsURL: The URL of the settings pane to open.
    ///   - check: A function that checks permissions.
    ///   - request: A function that requests permissions.
    ///   - openSettings: A function that opens the settings URL.
    init(
        title: String,
        iconName: String,
        iconColor: Color,
        details: [String],
        isRequired: Bool,
        settingsURL: URL?,
        check: @escaping () -> Bool,
        request: @escaping () -> Void,
        openSettings: @escaping (URL) -> Bool = { NSWorkspace.shared.open($0) }
    ) {
        self.title = title
        self.iconName = iconName
        self.iconColor = iconColor
        self.details = details
        self.isRequired = isRequired
        self.settingsURL = settingsURL
        self.check = check
        self.request = request
        self.openSettings = openSettings
        startCheck()
    }

    /// Rechecks the system's effective authorization without requesting access.
    func refresh() {
        hasPermission = check()
        if hasPermission {
            stopCheck()
        }
    }

    /// Checks immediately, then polls until granted. Common run-loop modes
    /// keep checks running while a menu or another UI interaction is active.
    func startCheck() {
        stopCheck()
        refresh()
        guard !hasPermission else { return }
        timerCancellable = Timer.publish(every: 3, tolerance: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refresh()
            }
    }

    /// Performs the request and opens the System Settings app to the appropriate pane.
    func performRequest() {
        // Setup stops background permission polling once the app is running.
        // Restart it for every explicit request so later grants are observed.
        request()
        startCheck()
        if let settingsURL {
            _ = openSettings(settingsURL)
        }
    }

    /// Stops running the permission check.
    func stopCheck() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }
}

// MARK: - AccessibilityPermission

/// The Accessibility permission, required for Thaw to detect, move, and
/// interact with menu bar items on the user's behalf.
final class AccessibilityPermission: Permission {
    init() {
        super.init(
            title: String(localized: "Accessibility"),
            iconName: "accessibility",
            iconColor: .blue,
            details: [
                String(localized: "Detect the menu bar items on your Mac and where they're positioned."),
                String(localized: "Move menu bar items to rearrange or hide them."),
                String(localized: "Click menu bar items on your behalf, such as when using the search bar."),
            ],
            isRequired: true,
            // Keep an explicit settings URL so every click can recover the
            // flow if the user closes System Settings before granting access.
            settingsURL: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"),
            check: {
                AXHelpers.isProcessTrusted()
            },
            request: {
                AXHelpers.isProcessTrusted(prompt: true)
            }
        )
    }
}

// MARK: - ScreenRecordingPermission

/// The Screen Recording permission, used for sampling menu bar colors,
/// previewing menu bar items, and visual search. Optional — Thaw can run in
/// a limited mode without it.
final class ScreenRecordingPermission: Permission {
    init() {
        super.init(
            title: String(localized: "Screen Recording"),
            iconName: "record.circle",
            iconColor: .red,
            details: [
                String(localized: "Show live previews of your menu bar items."),
                String(localized: "Sample colors from the menu bar to adjust its tint and appearance."),
                String(localized: "Find menu bar items visually when searching."),
            ],
            isRequired: false,
            settingsURL: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"),
            check: {
                // Keep tray previews and layout views in sync with recovery;
                // they also read this cache after onboarding completes.
                ScreenCapture.cachedCheckPermissions(reset: true)
            },
            request: {
                ScreenCapture.requestPermissions()
            }
        )
    }
}
