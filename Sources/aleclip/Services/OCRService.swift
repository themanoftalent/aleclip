import Foundation
import AppKit
@preconcurrency import Vision

public final class OCRService: @unchecked Sendable {
    public static let shared = OCRService()

    private init() {}

    /// Extracts text from an NSImage or image Data asynchronously using Vision.
    public func recognizeText(from data: Data) async -> String? {
        guard let image = NSImage(data: data),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    print("OCR text recognition error: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }

                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }

                let fullText = recognizedStrings.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: fullText.isEmpty ? nil : fullText)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    print("Failed to perform OCR request: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
