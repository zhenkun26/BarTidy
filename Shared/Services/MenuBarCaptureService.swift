//
//  MenuBarCaptureService.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import CoreGraphics
import Foundation

/// Offscreen menu-bar capture XPC vocabulary.
///
/// SkyLight's `SLWindowListCreateImageFromArray` leaks a small dictionary in
/// the calling process per successful call (commit `0e045faf`). This service
/// exists so that leak can be reclaimed by exiting the helper. Visible-section
/// icons stay on ScreenCaptureKit in the app; Always Hidden stays at 1 fps.
nonisolated enum MenuBarCaptureService {
    private static let diagLog = DiagLog(category: "MenuBarCaptureService")

    static let name = "com.stonerl.Thaw.MenuBarCaptureService"

    /// Exit after this many successful SkyLight composites.
    ///
    /// Commit `0e045faf` measured ~168 B per leaked dictionary. 1,800 calls is
    /// about 60 s at 30 fps and ~300 KB of helper growth before recycle.
    static let recycleAfterCaptureCount = 1_800

    static let maxWindowCount = 64
    static let maxBytesPerFrame = 4 * 1_024 * 1_024
    static let minAlwaysHiddenInterval: TimeInterval = 1

    /// Premultiplied BGRA, little-endian — the capture-path pixel layout.
    static let bgraBitmapInfo: UInt32 =
        CGImageAlphaInfo.premultipliedFirst.rawValue
        | CGBitmapInfo.byteOrder32Little.rawValue
}

nonisolated extension MenuBarCaptureService {
    struct CaptureBatchRequest: Codable, Equatable {
        var requestID: UInt64
        var windowIDs: [CGWindowID]
        var optionRawValue: UInt32
        var expectedScale: Double
    }

    struct Frame: Codable, Equatable {
        var windowID: CGWindowID
        var width: Int
        var height: Int
        var bytesPerRow: Int
        var scale: Double
        var pixels: Data
    }

    struct CaptureBatchResponse: Codable, Equatable {
        var requestID: UInt64
        var instanceID: UInt64
        var frames: [Frame]
    }

    enum Request: Codable, Equatable {
        case start
        /// Points the helper's diagnostic logger at `filePath`, or turns its
        /// file logging off when `nil`. Sent at startup, and again whenever the
        /// helper is out of date — a replaced session, or a log rotation.
        ///
        /// `rotationPolicy` carries the app's retention settings, so the helper
        /// prunes the shared log directory by the same rules rather than by its
        /// own defaults.
        case configureLogging(filePath: String?, rotationPolicy: DiagnosticLogger.RotationPolicy?)
        case captureBatch(CaptureBatchRequest)
        case recycle
    }

    enum Response: Codable, Equatable {
        case start
        case configureLogging
        case captureBatch(CaptureBatchResponse)
        case recycle
    }
}

nonisolated extension MenuBarCaptureService {
    /// Teamless local builds use the already-authorized application process.
    /// A fresh legacy-capture XPC process can show another privacy alert on
    /// each hover even while ScreenCaptureKit recognizes the app's grant.
    static func usesCaptureHelper(teamIdentifier: String?) -> Bool {
        teamIdentifier != nil
    }

    /// Shared geometry and frame validation for the local and XPC backends.
    /// Authorization is checked before window enumeration or capture.
    static func captureFrames(
        _ request: CaptureBatchRequest,
        permissionCheck: () -> Bool = { CGPreflightScreenCaptureAccess() },
        allowedWindows: () -> Set<CGWindowID> = {
            Set(Bridging.getMenuBarWindowList(option: .itemsOnly))
        },
        windowBounds: (CGWindowID) -> CGRect? = { Bridging.getWindowBounds(for: $0) },
        captureImage: ([CGWindowID], CGWindowImageOption) -> CGImage? = {
            Bridging.captureWindowsImage(windowIDs: $0, options: $1)
        }
    ) -> [Frame] {
        guard permissionCheck() else { return [] }
        let scale = CGFloat(request.expectedScale)
        guard scale > 0, scale.isFinite else { return [] }

        let allowed = allowedWindows()
        let windowIDs = validatedWindowIDs(request.windowIDs, allowed: allowed)
        guard !windowIDs.isEmpty else { return [] }

        var storage = [CGWindowID: CGRect]()
        var orderedIDs = [CGWindowID]()
        var boundsUnion = CGRect.null
        for windowID in windowIDs {
            guard let bounds = windowBounds(windowID) else { continue }
            guard Bridging.isValidCaptureBounds(bounds, scale: scale) else { continue }
            storage[windowID] = bounds
            orderedIDs.append(windowID)
            boundsUnion = boundsUnion.union(bounds)
        }
        guard !orderedIDs.isEmpty,
              Bridging.isValidCaptureBounds(boundsUnion, scale: scale)
        else {
            return []
        }

        let options = CGWindowImageOption(rawValue: request.optionRawValue)
        let composite = captureImage(orderedIDs, options)
        guard let composite else {
            diagLog.debug("captureFrames: SkyLight returned nil for \(orderedIDs.count) windows")
            return []
        }

        let expectedWidth = boundsUnion.width * scale
        guard abs(CGFloat(composite.width) - expectedWidth) < 1 else {
            diagLog.debug(
                "captureFrames: width mismatch (expected \(expectedWidth), got \(composite.width))"
            )
            return []
        }

        if let encoded = encodeBGRA(composite),
           isFullyTransparentBGRA(
               pixels: encoded.pixels,
               width: composite.width,
               height: composite.height,
               bytesPerRow: encoded.bytesPerRow
           )
        {
            return []
        }

        var frames = [Frame]()
        var batchBytes = 0
        for windowID in orderedIDs {
            guard let bounds = storage[windowID] else { continue }
            let cropRect = CGRect(
                x: (bounds.origin.x - boundsUnion.origin.x) * scale,
                y: (bounds.origin.y - boundsUnion.origin.y) * scale,
                width: bounds.width * scale,
                height: bounds.height * scale
            )
            guard let cropped = composite.cropping(to: cropRect),
                  let encoded = encodeBGRA(cropped)
            else {
                continue
            }
            batchBytes += encoded.pixels.count
            guard batchBytes <= 16 * 1024 * 1024 else { break }
            frames.append(
                Frame(
                    windowID: windowID,
                    width: cropped.width,
                    height: cropped.height,
                    bytesPerRow: encoded.bytesPerRow,
                    scale: request.expectedScale,
                    pixels: encoded.pixels
                )
            )
        }
        return frames
    }

    /// Drops zeros, duplicates, non-members, and anything past ``maxWindowCount``.
    static func validatedWindowIDs(
        _ ids: [CGWindowID],
        allowed: Set<CGWindowID>
    ) -> [CGWindowID] {
        var seen = Set<CGWindowID>()
        var result = [CGWindowID]()
        result.reserveCapacity(min(ids.count, maxWindowCount))
        for id in ids {
            guard id != 0, !seen.contains(id), allowed.contains(id) else { continue }
            seen.insert(id)
            result.append(id)
            if result.count == maxWindowCount { break }
        }
        return result
    }

    static func isValidBGRAFrame(
        width: Int,
        height: Int,
        bytesPerRow: Int,
        pixelCount: Int
    ) -> Bool {
        guard width > 0, height > 0 else { return false }
        guard width <= Bridging.maximumCaptureDimension,
              height <= Bridging.maximumCaptureDimension
        else { return false }
        guard bytesPerRow >= width * 4 else { return false }
        let expected = bytesPerRow * height
        guard pixelCount >= expected, expected <= maxBytesPerFrame else { return false }
        return true
    }

    static func shouldRecycle(
        captureCount: Int,
        budget: Int = recycleAfterCaptureCount
    ) -> Bool {
        captureCount >= budget
    }

    static func acceptedResponse(
        requestID: UInt64,
        response: Response
    ) -> CaptureBatchResponse? {
        guard case let .captureBatch(batch) = response, batch.requestID == requestID else {
            return nil
        }
        return batch
    }

    static func encodeBGRA(_ image: CGImage) -> (pixels: Data, bytesPerRow: Int)? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bgraBitmapInfo
        ), let dataPtr = context.data else {
            return nil
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let stride = context.bytesPerRow
        let count = stride * height
        guard count > 0, count <= maxBytesPerFrame else { return nil }
        return (Data(bytes: dataPtr, count: count), stride)
    }

    static func makeImage(from frame: Frame) -> CGImage? {
        guard isValidBGRAFrame(
            width: frame.width,
            height: frame.height,
            bytesPerRow: frame.bytesPerRow,
            pixelCount: frame.pixels.count
        ) else {
            return nil
        }
        guard frame.scale > 0, frame.scale.isFinite else { return nil }
        guard let provider = CGDataProvider(data: frame.pixels as CFData) else {
            return nil
        }
        return CGImage(
            width: frame.width,
            height: frame.height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: frame.bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: bgraBitmapInfo),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    static func isFullyTransparentBGRA(
        pixels: Data,
        width: Int,
        height: Int,
        bytesPerRow: Int
    ) -> Bool {
        guard isValidBGRAFrame(
            width: width,
            height: height,
            bytesPerRow: bytesPerRow,
            pixelCount: pixels.count
        ) else {
            return true
        }
        return pixels.withUnsafeBytes { buffer in
            guard let base = buffer.bindMemory(to: UInt8.self).baseAddress else {
                return true
            }
            for row in 0 ..< height {
                let rowBase = base + row * bytesPerRow
                for column in 0 ..< width where rowBase[column * 4 + 3] != 0 {
                    return false
                }
            }
            return true
        }
    }
}
