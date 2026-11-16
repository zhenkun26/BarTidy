//
//  PermissionTests.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import Thaw

/// Covers ``Permission``'s request/poll cycle through its injected closures,
/// so nothing here touches the real TCC database.
@MainActor
@Suite("Permission request polling")
struct PermissionTests {
    @Test("A request restarts polling after checks have been stopped", .timeLimit(.minutes(1)))
    func performRequestRestartsPollingAfterChecksStop() async throws {
        var isGranted = false
        var requestCount = 0
        var openedSettingsURLs = [URL]()
        let settingsURL = try #require(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        )
        let permission = Permission(
            title: "Test Permission",
            iconName: "checkmark",
            iconColor: .blue,
            details: [],
            isRequired: false,
            settingsURL: settingsURL,
            check: { isGranted },
            request: { requestCount += 1 },
            openSettings: { url in
                openedSettingsURLs.append(url)
                return true
            }
        )

        permission.stopCheck()
        permission.performRequest()
        permission.stopCheck()
        permission.performRequest()
        isGranted = true

        // Resume only once if another refresh occurs after the grant.
        await confirmation("Permission grant is observed after polling restarts") { granted in
            await withCheckedContinuation { continuation in
                var hasResumed = false
                permission.onChange = {
                    guard permission.hasPermission, !hasResumed else {
                        return
                    }
                    hasResumed = true
                    granted()
                    continuation.resume()
                }
            }
        }

        #expect(requestCount == 2)
        #expect(openedSettingsURLs == [settingsURL, settingsURL])
        #expect(permission.hasPermission)
    }

    @Test("Returning from settings observes a grant even after setup stopped polling")
    func refreshAfterChecksStop() {
        var isGranted = false
        var requestCount = 0
        let permission = testPermission(
            required: true,
            check: { isGranted },
            request: { requestCount += 1 }
        )
        permission.stopCheck()
        isGranted = true

        permission.refresh()

        #expect(permission.hasPermission)
        #expect(requestCount == 0)
    }

    @Test("A synchronous request grant is reflected immediately")
    func requestRefreshesImmediately() {
        var isGranted = false
        let permission = testPermission(
            required: true,
            check: { isGranted },
            request: { isGranted = true }
        )

        permission.performRequest()

        #expect(permission.hasPermission)
    }

    @Test("Repeated refreshes notify only on grant and revocation")
    func refreshNotifiesOnTransitions() {
        var isGranted = false
        let permission = testPermission(required: true, check: { isGranted })
        defer { permission.stopCheck() }
        var observed = [Bool]()
        permission.onChange = { observed.append(permission.hasPermission) }

        permission.refresh()
        isGranted = true
        permission.refresh()
        permission.refresh()
        isGranted = false
        permission.startCheck()
        permission.refresh()

        #expect(observed == [true, false])
    }

    @Test("The manager recovers after paused checks without requiring optional access")
    func managerRefreshesPausedPermissions() {
        var accessibilityGranted = false
        var screenRecordingGranted = false
        let manager = AppPermissions(
            accessibility: testPermission(required: true, check: { accessibilityGranted }),
            screenRecording: testPermission(required: false, check: { screenRecordingGranted })
        )
        defer { manager.stopAllChecks() }
        manager.stopAllChecks()
        #expect(manager.permissionsState == .missing)

        accessibilityGranted = true
        manager.startAllChecks()
        #expect(manager.permissionsState == .hasRequired)

        screenRecordingGranted = true
        manager.refresh()
        #expect(manager.permissionsState == .hasAll)

        accessibilityGranted = false
        manager.refresh()
        #expect(manager.permissionsState == .missing)
    }

    @Test("Retry cannot bypass a rejected required permission")
    func retryKeepsRequiredPermissionGate() {
        let manager = AppPermissions(
            accessibility: testPermission(required: true, check: { false }),
            screenRecording: testPermission(required: false, check: { true })
        )
        defer { manager.stopAllChecks() }

        manager.startAllChecks()
        manager.refresh()

        #expect(manager.permissionsState == .missing)
        #expect(!manager.accessibility.hasPermission)
    }

    private func testPermission(
        required: Bool,
        check: @escaping () -> Bool,
        request: @escaping () -> Void = {}
    ) -> Permission {
        Permission(
            title: "Test Permission",
            iconName: "checkmark",
            iconColor: .blue,
            details: [],
            isRequired: required,
            settingsURL: nil,
            check: check,
            request: request,
            openSettings: { _ in false }
        )
    }
}

@Suite("Screen recording permission detection")
struct ScreenRecordingPermissionTests {
    @Test("A positive system preflight does not depend on menu bar titles")
    func positivePreflightWins() {
        var inspectedWindows = false
        let granted = ScreenCapture.checkPermissions(
            preflight: { true },
            windows: {
                inspectedWindows = true
                return []
            }
        )

        #expect(granted)
        #expect(!inspectedWindows)
    }

    @Test("An untitled first item does not hide a later live permission grant")
    func skipsUntitledFirstWindow() throws {
        let windows = try [window(title: nil), window(title: "Status item")]

        #expect(ScreenCapture.checkPermissions(preflight: { false }, windows: { windows }))
    }

    @Test("An app's own titled window cannot establish screen recording access")
    func ownWindowIsIgnored() throws {
        let windows = try [window(title: "BarTidy", ownerPID: ProcessInfo.processInfo.processIdentifier)]

        #expect(!ScreenCapture.checkPermissions(preflight: { false }, windows: { windows }))
    }

    @Test("Untitled foreign windows do not fabricate a grant")
    func missingAccessRemainsFalse() throws {
        let windows = try [window(title: nil)]

        #expect(!ScreenCapture.checkPermissions(preflight: { false }, windows: { windows }))
        #expect(!ScreenCapture.checkPermissions(preflight: { false }, windows: { [] }))
    }

    private func window(title: String?, ownerPID: pid_t = 999999) throws -> WindowInfo {
        let dictionary: [String: Any] = [
            "windowID": 12345,
            "ownerPID": ownerPID,
            "bounds": [[0, 0], [20, 22]],
            "layer": 25,
            "title": title as Any? ?? NSNull(),
            "ownerName": "Fixture",
            "isOnScreen": true,
        ]
        return try JSONDecoder().decode(WindowInfo.self, from: JSONSerialization.data(withJSONObject: dictionary))
    }
}
