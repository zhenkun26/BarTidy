//
//  HoverRevealKeepAliveTests.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Testing
@testable import Thaw

/// Pins the hover storage-box keep-open rule: reveal stays while the cursor
/// is on the box or the Thaw Bar, and collapses when it leaves both. Inline
/// expansion is the exception — the rest of the menu bar still counts so the
/// user can reach a revealed item.
@Suite("Hover reveal keep-alive")
struct HoverRevealKeepAliveTests {
    @Test("Hovering the storage box keeps the reveal open")
    func storageBoxKeepsRevealOpen() {
        #expect(
            HIDEventManager.shouldKeepHoverReveal(
                overStorageBox: true,
                overIceBar: false,
                overMenuBar: true,
                usesIceBar: true
            )
        )
    }

    @Test("Hovering the Thaw Bar keeps the reveal open")
    func thawBarKeepsRevealOpen() {
        #expect(
            HIDEventManager.shouldKeepHoverReveal(
                overStorageBox: false,
                overIceBar: true,
                overMenuBar: false,
                usesIceBar: true
            )
        )
    }

    @Test("Leaving the box and Thaw Bar collapses the reveal")
    func leavingBoxAndBarCollapsesReveal() {
        #expect(
            !HIDEventManager.shouldKeepHoverReveal(
                overStorageBox: false,
                overIceBar: false,
                overMenuBar: true,
                usesIceBar: true
            )
        )
    }

    @Test("Inline expansion stays open while the cursor is still in the menu bar")
    func inlineExpansionStaysOpenOverMenuBar() {
        #expect(
            HIDEventManager.shouldKeepHoverReveal(
                overStorageBox: false,
                overIceBar: false,
                overMenuBar: true,
                usesIceBar: false
            )
        )
    }

    @Test("Inline expansion collapses once the cursor leaves the menu bar")
    func inlineExpansionCollapsesOffMenuBar() {
        #expect(
            !HIDEventManager.shouldKeepHoverReveal(
                overStorageBox: false,
                overIceBar: false,
                overMenuBar: false,
                usesIceBar: false
            )
        )
    }
}
