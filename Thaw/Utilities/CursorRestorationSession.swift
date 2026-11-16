//
//  CursorRestorationSession.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import CoreGraphics
import Foundation
import Synchronization

/// Owns cursor restoration across a complete synthetic operation, including
/// retries and nested recovery. The observer survives HIDEventManager.stopAll().
@MainActor
final class CursorRestorationSession {
    struct Interrupted: Error {}
    struct MonitoringUnavailable: Error {}

    nonisolated struct Input: Sendable {
        let type: CGEventType
        let sourceStateID: Int64
        let location: CGPoint

        init(_ event: CGEvent) {
            type = event.type
            sourceStateID = event.getIntegerValueField(.eventSourceStateID)
            location = event.location
        }

        init(type: CGEventType, sourceStateID: Int64, location: CGPoint) {
            self.type = type
            self.sourceStateID = sourceStateID
            self.location = location
        }
    }

    nonisolated struct State: Sendable {
        var restorationPoint: CGPoint
        var interrupted = false

        mutating func receive(_ input: Input) {
            guard input.sourceStateID == Int64(CGEventSourceStateID.hidSystemState.rawValue) else { return }
            switch input.type {
            case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
                guard input.location.x.isFinite, input.location.y.isFinite else { return }
                restorationPoint = input.location
                interrupted = true
            case .scrollWheel, .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
                 .otherMouseDown, .otherMouseUp:
                // A scroll/click has no new pointer position. Its location may
                // be the synthetic warp point, so retain the last real move.
                interrupted = true
            default:
                break
            }
        }
    }

    /// Injected effects let tests run the production lifetime/cancellation
    /// code without moving the system cursor or needing TCC access.
    struct Environment {
        var location: () -> CGPoint?
        var startMonitoring: (@escaping @Sendable (Input) -> Void) throws -> (() -> Void)
        var hide: (Duration) -> Void
        var restore: (CGPoint) -> Void
        var show: () -> Void

        static var live: Self {
            Self(
                location: { MouseHelpers.locationCoreGraphics },
                startMonitoring: { receive in
                    let tap = EventTap(
                        label: "Cursor restoration",
                        types: [
                            .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
                            .scrollWheel, .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
                            .otherMouseDown, .otherMouseUp,
                        ],
                        location: .sessionEventTap,
                        placement: .headInsertEventTap,
                        option: .listenOnly
                    ) { _, event in
                        receive(Input(event))
                        return event
                    }
                    tap.enable()
                    guard tap.isEnabled else {
                        tap.invalidate()
                        throw MonitoringUnavailable()
                    }
                    return { tap.invalidate() }
                },
                hide: { MouseHelpers.hideCursor(watchdogTimeout: $0) },
                restore: { MouseHelpers.restoreCursorPosition(to: $0) },
                show: { MouseHelpers.showCursor() }
            )
        }
    }

    @TaskLocal static var current: CursorRestorationSession?
    nonisolated private let state: Mutex<State>

    private init(point: CGPoint) {
        state = Mutex(State(restorationPoint: point))
    }

    static func checkForInterruption() throws {
        try Task.checkCancellation()
        if current?.state.withLock({ $0.interrupted }) == true {
            throw Interrupted()
        }
    }

    static func withSession<Result>(
        environment: Environment = .live,
        watchdogTimeout: Duration = .seconds(30),
        hideCursor: Bool = true,
        operation: () async throws -> Result
    ) async throws -> Result {
        try checkForInterruption()
        if current != nil {
            return try await operation()
        }
        guard let point = environment.location() else {
            throw MonitoringUnavailable()
        }
        let session = CursorRestorationSession(point: point)
        let stopMonitoring = try environment.startMonitoring { input in
            session.state.withLock { $0.receive(input) }
        }
        if hideCursor { environment.hide(watchdogTimeout) }
        defer {
            // Restore after all normal/fallback releases, even after real
            // input: a later synthetic event may have overwritten its position.
            environment.restore(session.state.withLock { $0.restorationPoint })
            if hideCursor { environment.show() }
            stopMonitoring()
        }
        return try await $current.withValue(session) {
            try checkForInterruption()
            return try await operation()
        }
    }
}
