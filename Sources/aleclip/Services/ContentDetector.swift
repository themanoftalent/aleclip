import Foundation

public struct ContentDetectionResult: Sendable {
    public let detectedType: ClipType
    public let detectedLanguage: String?
    public let isSensitive: Bool
    public let sensitiveReason: String?
}

public final class ContentDetector: Sendable {
    public static let shared = ContentDetector()

    private init() {}

    public func analyzeText(_ text: String) -> ContentDetectionResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Sensitive Data Detection
        if let sensitiveReason = checkSensitive(trimmed) {
            return ContentDetectionResult(
                detectedType: .text,
                detectedLanguage: nil,
                isSensitive: true,
                sensitiveReason: sensitiveReason
            )
        }

        // 2. Code detection
        if let language = detectProgrammingLanguage(trimmed) {
            return ContentDetectionResult(
                detectedType: .code,
                detectedLanguage: language,
                isSensitive: false,
                sensitiveReason: nil
            )
        }

        // 3. Link detection
        if (trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")),
           let url = URL(string: trimmed), url.host != nil {
            return ContentDetectionResult(
                detectedType: .link,
                detectedLanguage: nil,
                isSensitive: false,
                sensitiveReason: nil
            )
        }

        // 4. Default plain text
        return ContentDetectionResult(
            detectedType: .text,
            detectedLanguage: nil,
            isSensitive: false,
            sensitiveReason: nil
        )
    }

    private func checkSensitive(_ text: String) -> String? {
        // OpenAI / Anthropic / GitHub / AWS API keys
        if text.range(of: #"(?:sk-[a-zA-Z0-9_-]{20,}|ghp_[a-zA-Z0-9]{20,}|AKIA[0-9A-Z]{16}|Bearer\s+[a-zA-Z0-9_\-\.]{30,})"#, options: .regularExpression) != nil {
            return "API Key / Access Token"
        }

        // Private Keys
        if text.contains("-----BEGIN PRIVATE KEY-----") || text.contains("-----BEGIN RSA PRIVATE KEY-----") {
            return "Private Cryptographic Key"
        }

        // Credit Cards (13-19 digits with optional hyphens/spaces)
        let ccRegex = #"\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13}|3(?:0[0-5]|[68][0-9])[0-9]{11}|6(?:011|5[0-9]{2})[0-9]{12}|(?:2131|1800|35\d{3})\d{11})\b"#
        if text.range(of: ccRegex, options: .regularExpression) != nil {
            return "Credit Card Number"
        }

        return nil
    }

    private func detectProgrammingLanguage(_ text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
        guard lines.count >= 2 || text.contains("{") || text.contains("import ") || text.contains("def ") else {
            return nil
        }

        // JSON check
        if (text.hasPrefix("{") && text.hasSuffix("}")) || (text.hasPrefix("[") && text.hasSuffix("]")) {
            if let data = text.data(using: .utf8), (try? JSONSerialization.jsonObject(with: data)) != nil {
                return "JSON"
            }
        }

        // Swift
        if text.contains("import SwiftUI") || text.contains("import Foundation") || text.contains("func ") && text.contains("-> ") || text.contains("@MainActor") || text.contains("guard let ") {
            return "Swift"
        }

        // Python
        if text.contains("def ") && text.contains(":") || text.contains("import numpy") || text.contains("import os") || text.contains("elif ") || text.contains("if __name__ == '__main__':") {
            return "Python"
        }

        // TypeScript / JavaScript
        if text.contains("const ") || text.contains("let ") && text.contains(" = ") || text.contains("function ") || text.contains("=> {") || text.contains("export default") {
            return "JavaScript / TypeScript"
        }

        // HTML / XML
        if (text.hasPrefix("<!DOCTYPE html>") || (text.contains("<div") && text.contains("</div>")) || text.contains("<html")) {
            return "HTML"
        }

        // SQL
        let upper = text.uppercased()
        if (upper.contains("SELECT ") && upper.contains(" FROM ")) || upper.contains("INSERT INTO ") || upper.contains("CREATE TABLE ") {
            return "SQL"
        }

        // Shell / Bash
        if text.hasPrefix("#!/bin/bash") || text.hasPrefix("#!/bin/zsh") || text.contains("echo ") && text.contains("export ") {
            return "Shell"
        }

        return nil
    }
}
