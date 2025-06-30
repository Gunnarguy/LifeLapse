@preconcurrency import AVFoundation
import UIKit

// VideoExporter is public to be accessible from other modules
public final class VideoExporter {
    // AVFoundation objects must be used on the main actor
    // because they are not Sendable and are not safe for concurrency.
    @MainActor private var assetWriter: AVAssetWriter?
    @MainActor private var assetWriterInput: AVAssetWriterInput?

    public init() { }

    @MainActor
    public func export(images: [UIImage], to url: URL) async throws -> URL {
        // Prepare all UIImage to CGImage on background thread
        let cgImages = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let mapped = images.compactMap { $0.cgImage }
                continuation.resume(returning: mapped)
            }
        }

        // Initialize AVAssetWriter and input on the main actor
        self.assetWriter = try AVAssetWriter(outputURL: url, fileType: .mov)
        guard let assetWriter = self.assetWriter else {
            throw NSError(domain: "VideoExporter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create AVAssetWriter"])
        }

        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: cgImages.first?.width ?? 1920,
            AVVideoHeightKey: cgImages.first?.height ?? 1080
        ]
        self.assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        guard let assetWriterInput = self.assetWriterInput else {
            throw NSError(domain: "VideoExporter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create AVAssetWriterInput"])
        }

        assetWriter.add(assetWriterInput)
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: .zero)

        let frameDuration = CMTime(value: 1, timescale: 30)
        var frameCount: Int64 = 0

        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterInput, sourcePixelBufferAttributes: nil)

        for cgImage in cgImages {
            while !assetWriterInput.isReadyForMoreMediaData {
                // Sleep to wait until input is ready
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }

            guard let pixelBuffer = cgImage.pixelBuffer() else {
                throw NSError(domain: "VideoExporter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create pixel buffer"])
            }

            let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frameCount))
            pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
            frameCount += 1
        }

        assetWriterInput.markAsFinished()
        await assetWriter.finishWriting()

        if assetWriter.status == .completed {
            return url
        } else {
            throw assetWriter.error ?? NSError(domain: "VideoExporter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Export failed"])
        }
    }
}

private extension CGImage {
    func pixelBuffer() -> CVPixelBuffer? {
        let options = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ] as CFDictionary

        var pxbuffer: CVPixelBuffer?
        let width = self.width
        let height = self.height

        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                                         kCVPixelFormatType_32ARGB, options,
                                         &pxbuffer)

        guard status == kCVReturnSuccess, let pixelBuffer = pxbuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        let pxdata = CVPixelBufferGetBaseAddress(pixelBuffer)

        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: pxdata, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                      space: rgbColorSpace,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
            return nil
        }

        context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

        return pixelBuffer
    }
}
