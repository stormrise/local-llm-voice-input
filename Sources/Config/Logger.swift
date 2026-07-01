//
// Logger.swift
// LocalVoice
//
// App-wide logging utility
//
// Copyright © 2025 LocalVoice. All rights reserved.
// Licensed under the Apache License 2.0 — see LICENSE file for details.
// Author: LocalVoice Team
//

import Foundation

/// Simple file-based debug logger for LocalVoice.
/// Writes to ~/Library/Application Support/com.vocaltype.app/debug.log
final class AppLogger: @unchecked Sendable {
    static let shared = AppLogger()

    private let logURL: URL
    private let queue = DispatchQueue(label: "com.vocaltype.logger", qos: .utility)
    private let maxSize: Int = 5 * 1024 * 1024  // 5MB max

    private init() {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = supportDir.appendingPathComponent("com.vocaltype.app", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        logURL = appDir.appendingPathComponent("debug.log")
        write(level: "INIT", message: "Logger initialized")
        write(level: "INIT", message: "LocalVoice version: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "dev")")
        write(level: "INIT", message: "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
    }

    func write(level: String, message: String, file: String = #fileID, line: Int = #line) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let shortFile = file.split(separator: "/").last ?? "?"
        let lineMsg = "[\(timestamp)] [\(level)] [\(shortFile):\(line)] \(message)"
        queue.async { [weak self] in
            guard let self = self else { return }
            guard let data = "\(lineMsg)\n".data(using: .utf8) else { return }
            do {
                if let fh = try? FileHandle(forWritingTo: self.logURL) {
                    fh.seekToEndOfFile()
                    fh.write(data)
                    fh.closeFile()
                } else {
                    try data.write(to: self.logURL, options: .atomic)
                }
                // Trim if too large
                self.trimIfNeeded()
            } catch {
                // Can't log the log failure — silent
            }
        }
    }

    func info(_ message: String, file: String = #fileID, line: Int = #line) {
        write(level: "INFO", message: message, file: file, line: line)
    }

    func warn(_ message: String, file: String = #fileID, line: Int = #line) {
        write(level: "WARN", message: message, file: file, line: line)
    }

    func error(_ message: String, file: String = #fileID, line: Int = #line) {
        write(level: "ERROR", message: message, file: file, line: line)
    }

    func debug(_ message: String, file: String = #fileID, line: Int = #line) {
        write(level: "DEBUG", message: message, file: file, line: line)
    }

    /// Read the entire log for display
    func readLog() -> String {
        guard let data = try? Data(contentsOf: logURL) else { return "No log file" }
        return String(data: data, encoding: .utf8) ?? "Log unreadable"
    }

    /// Clear the log
    func clear() {
        try? "".data(using: .utf8)?.write(to: logURL)
    }

    private func trimIfNeeded() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: logURL.path),
              let size = attrs[.size] as? Int, size > maxSize else { return }
        guard let data = try? Data(contentsOf: logURL),
              let trimmed = String(data: data, encoding: .utf8) else { return }
        // Keep last 1MB
        let tail = String(trimmed.suffix(1024 * 1024))
        try? tail.data(using: .utf8)?.write(to: logURL)
    }
}
