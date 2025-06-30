//  Export/VideoExporter.swift
import AVFoundation
import SwiftUI

enum VideoExporter {
    static func export(events: [Event]) -> AsyncStream<Double> {
        AsyncStream { continuation in
            Task.detached {
                // Extract event dates and other properties on main actor first
                let eventData = await MainActor.run {
                    events.map { event in
                        (date: event.date, significance: event.significance)
                    }
                }
                
                let fps: Double = 60
                let duration: Double = 60
                let frameCount = Int(duration * fps)
                let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1080, height: 1920))

                // Prepare AVWriter
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("timeline.mov")
                try? FileManager.default.removeItem(at: url)
                let writer = try! AVAssetWriter(url: url, fileType: .mov)
                let settings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: 1080,
                    AVVideoHeightKey: 1920
                ]
                let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
                let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input,
                                                                   sourcePixelBufferAttributes: nil)
                writer.add(input)
                writer.startWriting()
                writer.startSession(atSourceTime: .zero)

                let minDate = eventData.first?.date ?? Date.now
                let maxDate = eventData.last?.date ?? Date.now

                for frame in 0..<frameCount {
                    let progress = Double(frame)/Double(frameCount)
                    let time = CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(fps))

                    let virtualDate = minDate.addingTimeInterval(
                        progress * maxDate.timeIntervalSince(minDate)
                    )
                    let currentEvents = eventData.filter { abs($0.date.timeIntervalSince(virtualDate)) < 86_400 }

                    let img = await MainActor.run {
                        renderer.image { ctx in
                            UIColor.black.setFill(); ctx.fill(CGRect(origin: .zero, size: ctx.format.bounds.size))
                            for ev in currentEvents {
                                let x = CGFloat.random(in: 0...1080)
                                let y = CGFloat.random(in: 0...1920)
                                let radius = CGFloat(10 + 40*ev.significance)
                                UIColor.white.withAlphaComponent(0.8).setFill()
                                ctx.cgContext.fillEllipse(in: CGRect(x: x-radius, y: y-radius, width: 2*radius, height: 2*radius))
                            }
                        }
                    }
                    
                    while !input.isReadyForMoreMediaData { usleep(1_000) }
                    if let buf = await MainActor.run(body: { img.pixelBuffer() }) {
                        adaptor.append(buf, withPresentationTime: time)
                    }
                    continuation.yield(progress)
                }

                input.markAsFinished()
                writer.finishWriting {
                    continuation.yield(1.0)
                    continuation.finish()
                    // Present share sheet etc.
                }
            }
        }
    }
}

// UIImage → CVPixelBuffer helper
extension UIImage {
    func pixelBuffer() -> CVPixelBuffer? {
        let width = Int(size.width), height = Int(size.height)
        var pxbuf: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: true,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary
        guard CVPixelBufferCreate(kCFAllocatorDefault,
                                  width, height,
                                  kCVPixelFormatType_32BGRA,
                                  attrs, &pxbuf) == kCVReturnSuccess,
              let buf = pxbuf else { return nil }

        CVPixelBufferLockBaseAddress(buf, [])
        let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buf),
                            width: width, height: height,
                            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buf),
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
        ctx?.draw(cgImage!, in: CGRect(x: 0, y: 0, width: width, height: height))
        CVPixelBufferUnlockBaseAddress(buf, [])
        return buf
    }
}