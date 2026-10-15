//
//  CursorRestorationSessionTests.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import CoreGraphics
import Foundation
import Testing
@testable import Thaw

@MainActor
@Suite("Cursor restoration sessions")
struct CursorRestorationSessionTests {
    private typealias Session = CursorRestorationSession

    @MainActor
    private final class Pointer {
        var point = CGPoint(x: 800, y: 500)
        var events = [String]()
        var receiver: (@Sendable (Session.Input) -> Void)?
        var monitorAvailable = true

        var environment: Session.Environment {
            .init(
                location: { self.point },
                startMonitoring: { receive in
                    guard self.monitorAvailable else { throw Session.MonitoringUnavailable() }
                    self.events.append("monitor")
                    self.receiver = receive
                    return {
                        self.events.append("stop")
                        self.receiver = nil
                    }
                },
                hide: { _ in self.events.append("hide") },
                restore: { self.point = $0; self.events.append("restore") },
                show: { self.events.append("show") }
            )
        }

        func input(_ type: CGEventType, at point: CGPoint, synthetic: Bool = false) {
            self.point = point
            receiver?(.init(
                type: type,
                sourceStateID: Int64((synthetic ? CGEventSourceStateID.combinedSessionState : .hidSystemState).rawValue),
                location: point
            ))
        }
    }

    @Test("Synthetic releases cannot replace the saved cursor point")
    func syntheticRelease() async throws {
        let pointer = Pointer()
        let original = pointer.point
        try await Session.withSession(environment: pointer.environment) {
            pointer.input(.leftMouseDown, at: .zero, synthetic: true)
            pointer.input(.leftMouseDragged, at: CGPoint(x: -4000, y: 16), synthetic: true)
            pointer.input(.leftMouseUp, at: .zero, synthetic: true)
            try Session.checkForInterruption()
        }
        #expect(pointer.point == original)
        #expect(pointer.events == ["monitor", "hide", "restore", "show", "stop"])
    }

    @Test(
        "A real move wins even when a later synthetic release overwrites it",
        arguments: [CGEventType.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
    )
    func realMovementWins(type: CGEventType) async throws {
        let pointer = Pointer()
        let userPoint = CGPoint(x: -300, y: 1100)
        try await Session.withSession(environment: pointer.environment) {
            pointer.input(type, at: userPoint)
            pointer.input(.leftMouseUp, at: .zero, synthetic: true)
            #expect(throws: Session.Interrupted.self) { try Session.checkForInterruption() }
        }
        #expect(pointer.point == userPoint)
    }

    @Test(
        "Scrolling or clicking interrupts without adopting a synthetic position",
        arguments: [
            CGEventType.scrollWheel, .leftMouseDown, .leftMouseUp, .rightMouseDown,
            .rightMouseUp, .otherMouseDown, .otherMouseUp,
        ]
    )
    func stationaryInput(type: CGEventType) async throws {
        let pointer = Pointer()
        let original = pointer.point
        try await Session.withSession(environment: pointer.environment) {
            pointer.input(.mouseMoved, at: .zero, synthetic: true)
            pointer.input(type, at: .zero)
            #expect(throws: Session.Interrupted.self) { try Session.checkForInterruption() }
        }
        #expect(pointer.point == original)
    }

    @Test("A scroll after real movement retains the last real position")
    func scrollAfterMove() async throws {
        let pointer = Pointer()
        let userPoint = CGPoint(x: 600, y: 700)
        try await Session.withSession(environment: pointer.environment) {
            pointer.input(.mouseMoved, at: userPoint)
            pointer.input(.mouseMoved, at: .zero, synthetic: true)
            pointer.input(.scrollWheel, at: .zero)
        }
        #expect(pointer.point == userPoint)
    }

    @Test("Nested recovery restores once and shares the physical-input history")
    func nestedRecovery() async throws {
        let pointer = Pointer()
        let userPoint = CGPoint(x: 400, y: 900)
        try await Session.withSession(environment: pointer.environment) {
            pointer.input(.mouseMoved, at: .zero, synthetic: true)
            try await Session.withSession(environment: pointer.environment) {
                pointer.input(.mouseMoved, at: userPoint)
                pointer.input(.leftMouseUp, at: .zero, synthetic: true)
            }
        }
        #expect(pointer.point == userPoint)
        #expect(pointer.events == ["monitor", "hide", "restore", "show", "stop"])
    }

    @Test("An interrupted transaction never enters a later operation")
    func interruptionStopsLaterWork() async throws {
        let pointer = Pointer()
        var ran = false
        try await Session.withSession(environment: pointer.environment) {
            pointer.input(.scrollWheel, at: .zero)
            do {
                try await Session.withSession(environment: pointer.environment) { ran = true }
                Issue.record("Expected interruption")
            } catch is Session.Interrupted {
                // Expected: no later synthetic operation may begin.
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
        #expect(!ran)
    }

    @Test("Failure performs release cleanup before cursor restoration")
    func failureCleanup() async {
        struct Failure: Error {}
        let pointer = Pointer()
        let userPoint = CGPoint(x: 300, y: 400)
        do {
            try await Session.withSession(environment: pointer.environment) {
                defer {
                    pointer.input(.leftMouseUp, at: .zero, synthetic: true)
                    pointer.events.append("release")
                }
                pointer.input(.mouseMoved, at: userPoint)
                throw Failure()
            }
            Issue.record("Expected failure")
        } catch is Failure {
            // Expected: cleanup must still run.
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(pointer.point == userPoint)
        #expect(pointer.events == ["monitor", "hide", "release", "restore", "show", "stop"])
    }

    @Test("Cancellation after a warp still restores and shows the cursor")
    func cancellationDuringRegistration() async {
        let pointer = Pointer()
        let original = pointer.point
        let task = Task { @MainActor in
            try await Session.withSession(environment: pointer.environment) {
                pointer.input(.mouseMoved, at: .zero, synthetic: true)
                withUnsafeCurrentTask { $0?.cancel() }
                try await Task.sleep(for: .milliseconds(10))
            }
        }
        do {
            try await task.value
            Issue.record("Expected cancellation")
        } catch is CancellationError {
            // Expected: cancellation must still restore visibility and position.
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(pointer.point == original)
        #expect(pointer.events == ["monitor", "hide", "restore", "show", "stop"])
    }

    @Test("Missing monitoring fails before hiding or performing synthetic work")
    func unavailableMonitor() async {
        let pointer = Pointer()
        pointer.monitorAvailable = false
        var ran = false
        do {
            try await Session.withSession(environment: pointer.environment) { ran = true }
            Issue.record("Expected monitoring failure")
        } catch is Session.MonitoringUnavailable {
            // Expected: fail before touching the cursor.
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(!ran)
        #expect(pointer.events.isEmpty)
    }

    @Test("A caller-owned cursor hide is not unbalanced by the session")
    func externalCursorVisibility() async throws {
        let pointer = Pointer()
        let original = pointer.point
        try await Session.withSession(environment: pointer.environment, hideCursor: false) {
            pointer.input(.leftMouseUp, at: .zero, synthetic: true)
        }
        #expect(pointer.point == original)
        #expect(pointer.events == ["monitor", "restore", "stop"])
    }

    @Test("Selective storage keeps unchosen items visible by default")
    func selectiveStorageDefaults() {
        #expect(Defaults.DefaultValue.newItemsSection == "visible")
        #expect(MenuBarItemManager.NewItemsPlacement.defaultValue.sectionKey == "visible")
        #expect(!Defaults.DefaultValue.enableMenuBarItemOverflow)
        #expect(!Defaults.DefaultValue.enableAlwaysHiddenSection)
        #expect(Defaults.DefaultValue.showOnHover)
        #expect(Defaults.DefaultValue.useIceBar)
    }

    @Test("Invalid physical coordinates never become a restoration target")
    func invalidCoordinates() async throws {
        let pointer = Pointer()
        let original = pointer.point
        try await Session.withSession(environment: pointer.environment) {
            pointer.input(.mouseMoved, at: CGPoint(x: CGFloat.nan, y: 20))
        }
        #expect(pointer.point == original)
    }
}
