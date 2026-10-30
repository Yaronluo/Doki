#!/usr/bin/env swift

// Generates a silent, self-made MP4 test clip for the tvOS player shell.
// It is deliberately marked as demo content and is not an anime or provider
// stream. AVPlayer still uses its normal media clock, seek and resume paths.
//
// Run:
//   swift scripts/generate-demo-video.swift --seconds 1440 --fps 2
//
// The default output is App/tvOS/Resources/DemoMedia/doki-demo-24min.mp4.

import AppKit
import AVFoundation
import CoreGraphics
import CoreText
import Foundation

struct Options {
    var seconds: Double = 1_440
    var fps: Int32 = 2
    var width = 960
    var height = 540
    var output = "App/tvOS/Resources/DemoMedia/doki-demo-24min.mp4"
    var minimal = false
}

func parseOptions() -> Options {
    var options = Options()
    var arguments = Array(CommandLine.arguments.dropFirst())
    while let flag = arguments.first {
        arguments.removeFirst()
        if flag == "--minimal" {
            options.minimal = true
            continue
        }
        guard let value = arguments.first else { break }
        arguments.removeFirst()
        switch flag {
        case "--seconds": options.seconds = Double(value) ?? options.seconds
        case "--fps": options.fps = Int32(value) ?? options.fps
        case "--width": options.width = Int(value) ?? options.width
        case "--height": options.height = Int(value) ?? options.height
        case "--output": options.output = value
        default: break
        }
    }
    return options
}

let options = parseOptions()
let outputURL = URL(fileURLWithPath: options.output)
try? FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try? FileManager.default.removeItem(at: outputURL)

let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
writer.shouldOptimizeForNetworkUse = true

let compression: [String: Any] = [
    AVVideoAverageBitRateKey: 520_000,
    AVVideoProfileLevelKey: AVVideoProfileLevelH264MainAutoLevel,
    AVVideoMaxKeyFrameIntervalKey: Int(options.fps) * 30,
    AVVideoExpectedSourceFrameRateKey: Int(options.fps),
    AVVideoAllowFrameReorderingKey: false,
    AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC
]
let videoSettings: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: options.width,
    AVVideoHeightKey: options.height,
    AVVideoCompressionPropertiesKey: compression
]

let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(
    assetWriterInput: input,
    sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: options.width,
        kCVPixelBufferHeightKey as String: options.height,
        kCVPixelBufferCGImageCompatibilityKey as String: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
    ]
)

guard writer.canAdd(input) else {
    fatalError("AVAssetWriter cannot add video input")
}
writer.add(input)
guard writer.startWriting() else {
    fatalError("startWriting failed: \(writer.error?.localizedDescription ?? "unknown")")
}
writer.startSession(atSourceTime: .zero)

let totalFrames = max(1, Int(options.seconds * Double(options.fps)))
let width = options.width
let height = options.height
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue
    | CGBitmapInfo.byteOrder32Little.rawValue

let titleFont = NSFont.monospacedSystemFont(ofSize: 20, weight: .semibold)
let clockFont = NSFont.monospacedDigitSystemFont(ofSize: 54, weight: .medium)
let subFont = NSFont.monospacedSystemFont(ofSize: 15, weight: .regular)
let white = NSColor(calibratedWhite: 0.94, alpha: 1)
let teal = NSColor(calibratedRed: 0.24, green: 0.86, blue: 0.77, alpha: 1)
let ink = NSColor(calibratedRed: 0.03, green: 0.06, blue: 0.09, alpha: 1)

func clockText(_ seconds: Double) -> String {
    let total = max(0, Int(seconds))
    return String(format: "%02d:%02d", total / 60, total % 60)
}

func drawFrame(_ context: CGContext, frame: Int) {
    let t = Double(frame) / Double(options.fps)
    let progress = min(1, max(0, t / options.seconds))

    // Background: deep ink with a soft teal glow. The shadow is a normal
    // drawing operation, not a fake Liquid Glass screenshot.
    let colors = [
        NSColor(calibratedRed: 0.02, green: 0.05, blue: 0.08, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.02, green: 0.12, blue: 0.14, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.01, green: 0.03, blue: 0.05, alpha: 1).cgColor
    ] as CFArray
    let locations: [CGFloat] = [0, 0.5, 1]
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: CGFloat(height)),
            end: CGPoint(x: CGFloat(width), y: 0),
            options: []
        )
    }

    let glowX = CGFloat(width) * 0.70 + CGFloat(sin(t / 11)) * 60
    let glowY = CGFloat(height) * 0.55 + CGFloat(cos(t / 17)) * 40
    context.saveGState()
    context.setFillColor(teal.withAlphaComponent(0.16).cgColor)
    context.fillEllipse(in: CGRect(
        x: glowX - 280,
        y: glowY - 280,
        width: 560,
        height: 560
    ))
    context.setFillColor(NSColor.white.withAlphaComponent(0.035).cgColor)
    context.fillEllipse(in: CGRect(
        x: glowX - 190,
        y: glowY - 190,
        width: 380,
        height: 380
    ))
    context.restoreGState()

    // Fine orbit lines.
    context.saveGState()
    context.setStrokeColor(NSColor.white.withAlphaComponent(0.09).cgColor)
    context.setLineWidth(1)
    for index in 0..<7 {
        let inset = CGFloat(index) * 58
        context.strokeEllipse(in: CGRect(
            x: 60 + inset,
            y: 100 + inset * 0.32,
            width: CGFloat(width) - 120 - inset * 2,
            height: CGFloat(height) - 160 - inset * 0.64
        ))
    }
    context.restoreGState()

    // A moving scan line keeps the still frame visibly tied to media time.
    let scanY = CGFloat(height) * (0.18 + 0.64 * CGFloat(progress))
    context.saveGState()
    context.setStrokeColor(teal.withAlphaComponent(0.36).cgColor)
    context.setLineWidth(2)
    context.move(to: CGPoint(x: 0, y: scanY))
    context.addLine(to: CGPoint(x: CGFloat(width), y: scanY))
    context.strokePath()
    context.restoreGState()

    // Text. The minimal variant leaves the frame free of burned-in UI so the
    // native player chrome is the only source of labels and time.
    if !options.minimal {
        context.saveGState()
        context.textMatrix = .identity
        let title = NSAttributedString(
            string: "DOKI  /  SELF-MADE DEMO SAMPLE  /  NOT AN ANIME STREAM",
            attributes: [.font: titleFont, .foregroundColor: white.withAlphaComponent(0.62)]
        )
        let titleLine = CTLineCreateWithAttributedString(title)
        context.textPosition = CGPoint(x: 52, y: CGFloat(height) - 64)
        CTLineDraw(titleLine, context)

        let clock = NSAttributedString(
            string: clockText(t),
            attributes: [.font: clockFont, .foregroundColor: white]
        )
        let clockLine = CTLineCreateWithAttributedString(clock)
        context.textPosition = CGPoint(x: 52, y: 62)
        CTLineDraw(clockLine, context)

        let note = NSAttributedString(
            string: "24:00 sample · silent · local MP4 · seek / pause / resume test",
            attributes: [.font: subFont, .foregroundColor: white.withAlphaComponent(0.48)]
        )
        let noteLine = CTLineCreateWithAttributedString(note)
        context.textPosition = CGPoint(x: 52, y: 36)
        CTLineDraw(noteLine, context)

        let chapter = NSAttributedString(
            string: progress < 0.33 ? "ACT I · THE LETTER" : (progress < 0.66 ? "ACT II · THE ORBIT" : "ACT III · THE REPLY"),
            attributes: [.font: subFont, .foregroundColor: teal.withAlphaComponent(0.9)]
        )
        let chapterLine = CTLineCreateWithAttributedString(chapter)
        context.textPosition = CGPoint(x: CGFloat(width) - 340, y: 52)
        CTLineDraw(chapterLine, context)
        context.restoreGState()
    }

    // Bottom progress rail.
    context.setFillColor(NSColor.white.withAlphaComponent(0.12).cgColor)
    context.fill(CGRect(x: 52, y: 20, width: CGFloat(width) - 104, height: 3))
    context.setFillColor(teal.withAlphaComponent(0.95).cgColor)
    context.fill(CGRect(
        x: 52,
        y: 20,
        width: (CGFloat(width) - 104) * CGFloat(progress),
        height: 3
    ))
}

var frame = 0
while frame < totalFrames {
    if !input.isReadyForMoreMediaData {
        Thread.sleep(forTimeInterval: 0.002)
        continue
    }
    guard let pool = adaptor.pixelBufferPool else {
        fatalError("Missing pixel buffer pool")
    }
    var buffer: CVPixelBuffer?
    let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer)
    guard status == kCVReturnSuccess, let pixelBuffer = buffer else {
        fatalError("CVPixelBufferPoolCreatePixelBuffer failed: \(status)")
    }

    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    if let base = CVPixelBufferGetBaseAddress(pixelBuffer),
       let context = CGContext(
           data: base,
           width: width,
           height: height,
           bitsPerComponent: 8,
           bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
           space: colorSpace,
           bitmapInfo: bitmapInfo
       ) {
        context.setFillColor(ink.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        drawFrame(context, frame: frame)
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

    let time = CMTime(value: Int64(frame), timescale: options.fps)
    guard adaptor.append(pixelBuffer, withPresentationTime: time) else {
        fatalError("append failed: \(writer.error?.localizedDescription ?? "unknown")")
    }
    frame += 1
    if frame % 300 == 0 {
        print("encoded \(frame)/\(totalFrames) frames")
    }
}

input.markAsFinished()
let group = DispatchGroup()
group.enter()
writer.finishWriting {
    group.leave()
}
group.wait()

if writer.status != .completed {
    fatalError("finishWriting failed: \(writer.error?.localizedDescription ?? "unknown")")
}

let asset = AVURLAsset(url: outputURL)
let semaphore = DispatchSemaphore(value: 0)
Task {
    do {
        let duration = try await asset.load(.duration)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        print("wrote \(outputURL.path)")
        print("duration: \(duration.seconds) seconds; video tracks: \(tracks.count)")
        semaphore.signal()
    } catch {
        print("wrote \(outputURL.path); duration check failed: \(error)")
        semaphore.signal()
    }
}
semaphore.wait()
