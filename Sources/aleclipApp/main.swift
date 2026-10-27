import Foundation
import AppKit
import AleClipCore

if CommandLine.arguments.contains("--mcp") {
    // Run headless MCP (Model Context Protocol) server over stdio
    MCPService.shared.runStdioServer()
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
