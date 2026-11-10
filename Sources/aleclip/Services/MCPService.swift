import Foundation
import AppKit

@MainActor
public final class MCPService {
    public static let shared = MCPService()

    private init() {}

    public func handleJSONRPC(input: String) -> String? {
        guard let data = input.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let method = json["method"] as? String else {
            return nil
        }

        let id = json["id"]

        switch method {
        case "initialize":
            let result: [String: Any] = [
                "protocolVersion": "2024-11-05",
                "capabilities": [
                    "tools": [:]
                ],
                "serverInfo": [
                    "name": "aleclip-mcp",
                    "version": "2.1.0"
                ]
            ]
            return formatResponse(id: id, result: result)

        case "tools/list":
            let tools: [[String: Any]] = [
                [
                    "name": "get_recent_clips",
                    "description": "Fetch the most recent items from the Clipale clipboard history.",
                    "inputSchema": [
                        "type": "object",
                        "properties": [
                            "limit": ["type": "integer", "description": "Number of items to retrieve (default 10)"]
                        ]
                    ]
                ],
                [
                    "name": "search_clipboard",
                    "description": "Search across all clipboard history, OCR text from images, titles, and tags.",
                    "inputSchema": [
                        "type": "object",
                        "properties": [
                            "query": ["type": "string", "description": "Search keyword or phrase"]
                        ],
                        "required": ["query"]
                    ]
                ],
                [
                    "name": "add_clip",
                    "description": "Add a new text or code snippet to the Clipale clipboard history.",
                    "inputSchema": [
                        "type": "object",
                        "properties": [
                            "text": ["type": "string", "description": "Content of the clip"],
                            "title": ["type": "string", "description": "Optional title for the clip"]
                        ],
                        "required": ["text"]
                    ]
                ],
                [
                    "name": "get_collections",
                    "description": "List all user pinboards and collections.",
                    "inputSchema": [
                        "type": "object",
                        "properties": [:]
                    ]
                ]
            ]
            return formatResponse(id: id, result: ["tools": tools])

        case "tools/call":
            guard let params = json["params"] as? [String: Any],
                  let toolName = params["name"] as? String else {
                return formatError(id: id, code: -32602, message: "Invalid params")
            }
            let args = params["arguments"] as? [String: Any] ?? [:]
            let toolResult = executeTool(name: toolName, arguments: args)
            return formatResponse(id: id, result: ["content": [["type": "text", "text": toolResult]]])

        default:
            return formatError(id: id, code: -32601, message: "Method not found: \(method)")
        }
    }

    private func executeTool(name: String, arguments: [String: Any]) -> String {
        let storage = StorageService.shared
        switch name {
        case "get_recent_clips":
            let limit = arguments["limit"] as? Int ?? 10
            let items = Array(storage.clips.prefix(limit))
            let descriptions = items.enumerated().map { index, item in
                "[\(index + 1)] [\(item.type.rawValue)] \(item.displayTitle): \(item.plainText.prefix(120))"
            }
            return descriptions.joined(separator: "\n\n")

        case "search_clipboard":
            guard let query = arguments["query"] as? String else { return "Missing query parameter." }
            let matches = storage.clips.filter { $0.matches(query: query) }
            if matches.isEmpty {
                return "No clips found matching query '\(query)'."
            }
            let lines = matches.prefix(10).map { "- [\(String(describing: $0.sourceAppName ?? "Unknown"))] \($0.displayTitle)" }
            return "Found \(matches.count) items matching '\(query)':\n" + lines.joined(separator: "\n")

        case "add_clip":
            guard let text = arguments["text"] as? String, !text.isEmpty else { return "Text cannot be empty." }
            let title = arguments["title"] as? String
            let detected = ContentDetector.shared.analyzeText(text)
            let item = ClipItem(
                type: detected.detectedType,
                plainText: text,
                title: title,
                sourceAppName: "MCP Agent",
                contentHash: UUID().uuidString,
                detectedLanguage: detected.detectedLanguage,
                isSensitive: detected.isSensitive
            )
            storage.addClip(item)
            return "Successfully added clip to Clipale with ID: \(item.id.uuidString)"

        case "get_collections":
            let cols = storage.collections
            if cols.isEmpty { return "No collections created yet." }
            return cols.map { "- \($0.name) (ID: \($0.id.uuidString))" }.joined(separator: "\n")

        default:
            return "Unknown tool: \(name)"
        }
    }

    private func formatResponse(id: Any?, result: [String: Any]) -> String {
        let resp: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id ?? NSNull(),
            "result": result
        ]
        if let data = try? JSONSerialization.data(withJSONObject: resp, options: []),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }

    private func formatError(id: Any?, code: Int, message: String) -> String {
        let resp: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id ?? NSNull(),
            "error": ["code": code, "message": message]
        ]
        if let data = try? JSONSerialization.data(withJSONObject: resp, options: []),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }

    /// Runs the stdio loop for MCP integration
    public func runStdioServer() {
        let input = FileHandle.standardInput
        while true {
            let lineData = input.availableData
            guard !lineData.isEmpty, let line = String(data: lineData, encoding: .utf8) else {
                break
            }
            if let response = handleJSONRPC(input: line) {
                print(response)
                fflush(stdout)
            }
        }
    }
}
