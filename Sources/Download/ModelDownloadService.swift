//
// ModelDownloadService.swift
// LocalVoice
//
// Multi-source model download with resume
//
// Copyright © 2025 LocalVoice. All rights reserved.
// Licensed under the Apache License 2.0 — see LICENSE file for details.
// Author: LocalVoice Team
//

import Foundation

// MARK: - Model Download Service

/// Downloads MLX model files from HuggingFace / HF Mirror / ModelScope.
/// Lives on MainActor because it updates @Observable AppState.
@MainActor
class ModelDownloadService {
    private weak var state: AppState?
    /// Per-engine active download tasks. Keyed by STTEngine.rawValue.
    private var activeTasks: [String: Task<Void, Error>] = [:]
    private let fileManager = FileManager.default

    // -- Download stats tracking --
    private var downloadStartTime: Date?
    private var sessionDownloadedBytes: Int64 = 0
    private var lastSpeedUpdate: Date?
    private var lastSpeedBytes: Int64 = 0

    init(state: AppState) {
        self.state = state
    }

    // MARK: - Public API

    /// Start downloading a model from the configured source.
    nonisolated func startDownload(engine: STTEngine, source: ModelSource) {
        Task { await self._startDownload(engine: engine, source: source) }
    }

    /// Cancel an ongoing download for a specific engine. Preserves partial files for resume.
    func cancel(engine: STTEngine) {
        activeTasks[engine.rawValue]?.cancel()
        activeTasks[engine.rawValue] = nil
        // Mark partial exists so UI can show "Resume"
        state?.models.hasPartialDownload[engine.rawValue] = hasPartialFiles(engine: engine)
    }

    /// Delete downloaded model files AND partial files.
    func deleteModel(engine: STTEngine) throws {
        let dir = modelDirectory(for: engine)
        if fileManager.fileExists(atPath: dir.path) {
            try fileManager.removeItem(at: dir)
        }
        let partialDir = partialDirectory(for: engine)
        if fileManager.fileExists(atPath: partialDir.path) {
            try fileManager.removeItem(at: partialDir)
        }
        state?.models.hasPartialDownload[engine.rawValue] = false
    }

    /// Check if a model is fully downloaded.
    func isModelDownloaded(engine: STTEngine) -> Bool {
        let dir = modelDirectory(for: engine)
        guard fileManager.fileExists(atPath: dir.path) else { return false }
        for file in engine.requiredFiles {
            let url = dir.appendingPathComponent(file)
            if !fileManager.fileExists(atPath: url.path) {
                return false
            }
        }
        return true
    }

    /// Check if partial (resumable) download files exist on disk.
    func hasPartialFiles(engine: STTEngine) -> Bool {
        let partialDir = partialDirectory(for: engine)
        guard fileManager.fileExists(atPath: partialDir.path) else { return false }
        // Any non-empty file in partial dir means we can resume
        if let files = try? fileManager.contentsOfDirectory(atPath: partialDir.path) {
            return files.contains { file in
                let path = partialDir.appendingPathComponent(file)
                let size = (try? fileManager.attributesOfItem(atPath: path.path))?[.size] as? Int64 ?? 0
                return size > 0
            }
        }
        return false
    }

    /// Refresh partial-download state for all engines (call on init / view appear).
    func refreshPartialState() {
        for engine in STTEngine.allCases {
            state?.models.hasPartialDownload[engine.rawValue] = hasPartialFiles(engine: engine)
        }
    }

    /// Check which engines have all required model files on disk and update state.
    /// Called on app startup to restore download state from disk.
    func checkDownloadedModelsOnDisk() {
        for engine in STTEngine.allCases {
            if isModelDownloaded(engine: engine) {
                state?.models.downloadedEngines.insert(engine.rawValue)
                AppLogger.shared.info("Found downloaded model on disk: \(engine.rawValue)")
            }
        }
    }

    /// Path to the model directory (downloaded).
    func modelDirectory(for engine: STTEngine) -> URL {
        supportDir.appendingPathComponent("models/\(engine.repoFolderName)")
    }

    /// Check current disk space.
    func refreshDiskSpace() {
        let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        guard let path = paths.first else {
            state?.models.availableDiskSpace = "Unknown"
            return
        }
        do {
            let attrs = try fileManager.attributesOfFileSystem(forPath: path)
            let freeBytes = attrs[.systemFreeSize] as? UInt64 ?? 0
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            state?.models.availableDiskSpace = formatter.string(fromByteCount: Int64(freeBytes))
        } catch {
            state?.models.availableDiskSpace = "Unknown"
        }
    }

    // MARK: - Internal

    private func _startDownload(engine: STTEngine, source: ModelSource) async {
        let repoID: String
        switch source {
        case .huggingface, .huggingfaceMirror: repoID = engine.hfRepoID
        case .modelscope: repoID = engine.modelscopeRepoID
        }
        AppLogger.shared.info("▶️ Start download: engine=\(engine.rawValue) source=\(source) repo=\(repoID)")

        // Cancel any previous download
        cancel(engine: engine)

        // Reset stats
        downloadStartTime = Date()
        sessionDownloadedBytes = 0
        lastSpeedUpdate = Date()
        lastSpeedBytes = 0

        state?.models.downloadPhases[engine.rawValue] = .fetching
        state?.models.downloadProgress[engine.rawValue] = 0
        state?.models.fileProgress[engine.rawValue] = [:]
        state?.models.downloadErrors[engine.rawValue] = nil
        state?.models.downloadSpeed[engine.rawValue] = ""
        state?.models.downloadedBytes[engine.rawValue] = 0
        state?.models.totalBytes[engine.rawValue] = 0
        state?.models.downloadETA[engine.rawValue] = ""

        activeTasks[engine.rawValue] = Task { [weak self] in
            guard let self else { return }
            // Auto-retry up to 10 times
            let maxRetries = 10
            for attempt in 1...maxRetries {
                try Task.checkCancellation()

                do {
                    try await performDownload(engine: engine, source: source)

                    // Success
                    await MainActor.run {
                        self.activeTasks[engine.rawValue] = nil
                        self.state?.models.downloadPhases[engine.rawValue] = .completed
                        self.state?.models.downloadedEngines.insert(engine.rawValue)
                        self.state?.models.hasPartialDownload[engine.rawValue] = false
                        self.state?.models.downloadErrors[engine.rawValue] = nil
                        // Load the model now that download is complete
                        self.state?.loadModelAfterDownload(engine: engine)
                    }
                    return
                } catch {
                    guard !Task.isCancelled else {
                        AppLogger.shared.info("⏹️ Download cancelled: engine=\(engine.rawValue)")
                        await MainActor.run {
                            self.activeTasks[engine.rawValue] = nil
                            self.state?.models.hasPartialDownload[engine.rawValue] = hasPartialFiles(engine: engine)
                        }
                        return
                    }

                    AppLogger.shared.warn("⚠️ Download attempt \(attempt)/\(maxRetries) failed: \(error.localizedDescription)")

                    if attempt < maxRetries {
                        // Show retry status
                        await MainActor.run {
                            self.state?.models.downloadPhases[engine.rawValue] = .retrying(attempt, error.localizedDescription)
                        }
                        // Exponential backoff: 2^attempt sec, capped at 60s
                        let delay = min(pow(2.0, Double(attempt)), 60.0)
                        try await Task.sleep(for: .seconds(delay))
                    } else {
                        // All retries exhausted
                        AppLogger.shared.error("❌ Download failed after \(maxRetries) attempts: \(error.localizedDescription)")
                        await MainActor.run {
                            self.activeTasks[engine.rawValue] = nil
                            self.state?.models.downloadPhases[engine.rawValue] = .failed(error.localizedDescription)
                            self.state?.models.downloadErrors[engine.rawValue] = error.localizedDescription
                            self.state?.models.hasPartialDownload[engine.rawValue] = hasPartialFiles(engine: engine)
                        }
                    }
                }
            }
        }

        // Wait for the task result to propagate (the retry loop handles its own success/failure reporting)
        _ = try? await activeTasks[engine.rawValue]?.value
    }

    // MARK: - Download Engine

    private func performDownload(engine: STTEngine, source: ModelSource) async throws {
        let repoID: String
        switch source {
        case .huggingface, .huggingfaceMirror:
            repoID = engine.hfRepoID
        case .modelscope:
            repoID = engine.modelscopeRepoID
        }

        let baseURL = source.resolveBaseURL(repoID: repoID)
        AppLogger.shared.info("BaseURL: \(baseURL)")

        // Gather file list from repo API
        let files = try await gatherFileList(engine: engine, source: source, repoID: repoID)
        AppLogger.shared.info("File list gathered: \(files.count) files")
        AppLogger.shared.debug("Files: \(files.joined(separator: ", "))")

        let targetDir = modelDirectory(for: engine)
        let partialDir = partialDirectory(for: engine)

        try fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: partialDir, withIntermediateDirectories: true)

        // Transition to downloading phase
        await MainActor.run {
            state?.models.downloadPhases[engine.rawValue] = .downloading
        }

        let totalFiles = files.count

        // Pre-fetch total expected size via HEAD requests (best-effort, non-fatal)
        let expectedTotalBytes = await fetchTotalSize(files: files, baseURL: baseURL)
        await MainActor.run {
            state?.models.totalBytes[engine.rawValue] = expectedTotalBytes
        }

        // Initialize progress with existing partial files for accurate resume display
        let existingBytes = calculateExistingBytes(engine: engine, files: files)
        sessionDownloadedBytes = existingBytes
        await MainActor.run {
            state?.models.downloadedBytes[engine.rawValue] = existingBytes
        }
        if expectedTotalBytes > 0 {
            let initialProgress = min(Double(existingBytes) / Double(expectedTotalBytes), 1.0)
            await MainActor.run {
                state?.models.downloadProgress[engine.rawValue] = initialProgress
            }
        }

        for (index, file) in files.enumerated() {
            try Task.checkCancellation()

            let fileURL = URL(string: "\(baseURL)/\(file)")!
            let partialFile = partialDir.appendingPathComponent(file)
            let finalFile = targetDir.appendingPathComponent(file)

            // Skip if already fully downloaded
            if fileManager.fileExists(atPath: finalFile.path) {
                let fileSize = (try? fileManager.attributesOfItem(atPath: finalFile.path))?[.size] as? UInt64 ?? 0
                AppLogger.shared.info("⏭️  Skipping \(file) (already exists, \(fileSize) bytes)")
                sessionDownloadedBytes += Int64(fileSize)
                let overall = Double(index + 1) / Double(totalFiles)
                await updateProgress(engine: engine, overall: overall, fileName: file, fileProgress: 1.0,
                                     bytesDownloaded: sessionDownloadedBytes)
                continue
            }

            AppLogger.shared.info("⬇️  Downloading [\(index+1)/\(totalFiles)] \(file)")
            AppLogger.shared.debug("URL: \(fileURL.absoluteString)")

            // Download file
            try await downloadFile(
                url: fileURL,
                to: partialFile,
                engine: engine,
                file: file,
                fileIndex: index,
                totalFiles: totalFiles
            )

            // Move from partial to final
            if fileManager.fileExists(atPath: finalFile.path) {
                try fileManager.removeItem(at: finalFile)
            }
            try fileManager.moveItem(at: partialFile, to: finalFile)

            let finalSize = (try? fileManager.attributesOfItem(atPath: finalFile.path))?[.size] as? UInt64 ?? 0
            sessionDownloadedBytes += Int64(finalSize)
            AppLogger.shared.info("✅  Done \(file) (\(finalSize) bytes)")
        }

        // Verify
        await MainActor.run {
            state?.models.downloadPhases[engine.rawValue] = .verifying
        }

        try Task.checkCancellation()
        AppLogger.shared.info("🔍 Verifying download...")
        try verifyDownload(engine: engine, at: targetDir)
        AppLogger.shared.info("✅ Verify passed — all required files present")

        // Clean up partial
        if fileManager.fileExists(atPath: partialDir.path) {
            try fileManager.removeItem(at: partialDir)
        }

        // Mark complete
        await MainActor.run {
            state?.models.downloadPhases[engine.rawValue] = .completed
            state?.models.downloadProgress[engine.rawValue] = 1.0
            state?.models.downloadedEngines.insert(engine.rawValue)
            state?.models.currentFileName = nil
        }
    }

    // MARK: - File Listing

    private func gatherFileList(
        engine: STTEngine,
        source: ModelSource,
        repoID: String
    ) async throws -> [String] {
        switch source {
        case .huggingface, .huggingfaceMirror:
            return try await fetchHFFileList(source: source, repoID: repoID, requiredFiles: engine.requiredFiles)
        case .modelscope:
            return try await fetchModelScopeFileList(repoID: repoID, requiredFiles: engine.requiredFiles)
        }
    }

    private func fetchHFFileList(source: ModelSource, repoID: String, requiredFiles: [String]) async throws -> [String] {
        let encoded = repoID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? repoID
        let urlStr = "\(source.apiBaseURL)/\(encoded)"
        guard let url = URL(string: urlStr) else {
            AppLogger.shared.error("Invalid HF API URL: \(urlStr)")
            throw ModelDownloadError.invalidResponse
        }
        AppLogger.shared.info("🔍 Fetching HF file list: \(urlStr)")

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            AppLogger.shared.error("HF API: no HTTP response")
            throw ModelDownloadError.invalidResponse
        }
        AppLogger.shared.info("HF API status: \(httpResponse.statusCode)")
        guard httpResponse.statusCode == 200 else {
            AppLogger.shared.error("HF API failed: HTTP \(httpResponse.statusCode)")
            throw ModelDownloadError.repoNotFound(repoID: repoID, source: "HuggingFace")
        }
        AppLogger.shared.info("HF API response: \(data.count) bytes")

        struct HFResponse: Decodable {
            struct Sibling: Decodable {
                let rfilename: String
            }
            let siblings: [Sibling]
        }

        let decoded: HFResponse
        do {
            decoded = try JSONDecoder().decode(HFResponse.self, from: data)
        } catch {
            AppLogger.shared.error("HF API JSON decode failed: \(error.localizedDescription)")
            if let preview = String(data: data.prefix(500), encoding: .utf8) {
                AppLogger.shared.debug("HF API response preview: \(preview)")
            }
            throw error
        }
        let allFiles = decoded.siblings.map(\.rfilename)
        AppLogger.shared.info("HF API returned \(allFiles.count) files total")

        let relevant = filterRelevantFiles(allFiles, requiredFiles: requiredFiles)
        AppLogger.shared.info("After filtering: \(relevant.count) files")
        AppLogger.shared.debug("Filtered files: \(relevant.joined(separator: ", "))")
        return relevant
    }

    private func fetchModelScopeFileList(repoID: String, requiredFiles: [String]) async throws -> [String] {
        // ModelScope API v1: GET /api/v1/models/{repoID}
        let encoded = repoID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? repoID
        let urlStr = "https://modelscope.cn/api/v1/models/\(encoded)"
        guard let url = URL(string: urlStr) else {
            AppLogger.shared.error("Invalid ModelScope API URL: \(urlStr)")
            throw ModelDownloadError.invalidResponse
        }
        AppLogger.shared.info("🔍 Fetching ModelScope file list: \(urlStr)")

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            AppLogger.shared.error("ModelScope API: no HTTP response")
            throw ModelDownloadError.invalidResponse
        }
        AppLogger.shared.info("ModelScope API status: \(httpResponse.statusCode)")
        guard httpResponse.statusCode == 200 else {
            AppLogger.shared.error("ModelScope API failed: HTTP \(httpResponse.statusCode)")
            throw ModelDownloadError.repoNotFound(repoID: repoID, source: "ModelScope")
        }
        AppLogger.shared.info("ModelScope API response: \(data.count) bytes")
        if let preview = String(data: data.prefix(300), encoding: .utf8) {
            AppLogger.shared.debug("ModelScope API preview: \(preview)")
        }

        // ModelScope returns files in a nested structure; try multiple formats
        // Format 1: {"Data": {"ModelInfos": {"safetensor": {"files": [{"name": "..."}]}}}}
        struct MSFormat3: Decodable {
            struct Data: Decodable {
                struct ModelInfos: Decodable {
                    struct Safetensor: Decodable {
                        struct File: Decodable {
                            let name: String
                        }
                        let files: [File]?
                    }
                    let safetensor: Safetensor?
                }
                let ModelInfos: ModelInfos?
            }
            let Data: Data?
        }
        if let parsed = try? JSONDecoder().decode(MSFormat3.self, from: data),
           let files = parsed.Data?.ModelInfos?.safetensor?.files {
            let fileNames = files.map(\.name)
            AppLogger.shared.info("ModelScope Format3 (safetensor.files) parsed: \(fileNames.count) files")
            var paths = fileNames
            // Add required metadata files that might not appear in the API response
            for reqFile in requiredFiles where !paths.contains(reqFile) {
                paths.append(reqFile)
                AppLogger.shared.debug("Added required file not in API: \(reqFile)")
            }
            if !paths.isEmpty {
                return filterRelevantFiles(paths, requiredFiles: requiredFiles)
            }
        } else {
            AppLogger.shared.debug("ModelScope Format3 (safetensor.files) did not match")
        }

        // Format 2: {"Data": {"Files": [{"Path": "..."}]}}
        struct MSFormat1: Decodable {
            struct Data: Decodable {
                struct FileEntry: Decodable {
                    let Path: String?
                }
                let Files: [FileEntry]?
            }
            let Data: Data?
        }

        if let parsed = try? JSONDecoder().decode(MSFormat1.self, from: data),
           let files = parsed.Data?.Files {
            let paths = files.compactMap(\.Path)
            AppLogger.shared.info("ModelScope Format1 (Data.Files) parsed: \(paths.count) files")
            if !paths.isEmpty {
                return filterRelevantFiles(paths, requiredFiles: requiredFiles)
            }
        } else {
            AppLogger.shared.debug("ModelScope Format1 (Data.Files) did not match")
        }

        // Format 2: HF-compatible sibling structure
        struct SiblingEntry: Decodable {
            let rfilename: String?
            let path: String?
        }
        struct HFCompat: Decodable {
            let siblings: [SiblingEntry]?
        }
        if let parsed = try? JSONDecoder().decode(HFCompat.self, from: data),
           let siblings = parsed.siblings {
            let paths = siblings.compactMap { $0.rfilename ?? $0.path }
            AppLogger.shared.info("ModelScope Format2 (siblings) parsed: \(paths.count) files")
            if !paths.isEmpty {
                return filterRelevantFiles(paths, requiredFiles: requiredFiles)
            }
        } else {
            AppLogger.shared.debug("ModelScope Format2 (siblings) did not match")
        }

        // Fallback: return required files directly
        AppLogger.shared.warn("⚠️  ModelScope parsing failed: using requiredFiles fallback (\(requiredFiles.count) files)")
        AppLogger.shared.debug("Fallback files: \(requiredFiles.joined(separator: ", "))")
        return requiredFiles
    }

    private func filterRelevantFiles(_ files: [String], requiredFiles: [String]) -> [String] {
        let relevantExtensions = Set(["json", "safetensors", "bin", "py", "txt", "md"])

        // Start with files matching required names exactly or as suffix
        var result: [String] = []
        for file in files {
            let lower = file.lowercased()
            // Always include required files
            if requiredFiles.contains(where: { file == $0 || file.hasSuffix("/" + $0) }) {
                result.append(file)
                continue
            }
            // Include model weight files (.safetensors, .bin)
            if lower.hasSuffix(".safetensors") || lower.hasSuffix(".bin") {
                result.append(file)
                continue
            }
            // Include metadata files
            if let ext = lower.split(separator: ".").last, relevantExtensions.contains(String(ext)) {
                // Only include if it's likely a model file (not random junk)
                let configKeywords = ["config", "tokenizer", "model", "generation", "preprocessor",
                                      "vocab", "special", "added", "merges", "normalizer"]
                let filename = lower.split(separator: "/").last?.lowercased() ?? lower
                if configKeywords.contains(where: { filename.hasPrefix($0) }) {
                    result.append(file)
                }
            }
        }

        return Array(Set(result)).sorted()
    }

    // MARK: - File Download

    private func downloadFile(
        url: URL,
        to destination: URL,
        engine: STTEngine,
        file: String,
        fileIndex: Int,
        totalFiles: Int
    ) async throws {
        // Create intermediate directories
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)

        // Check for existing partial download
        var resumeOffset: UInt64 = 0
        if fileManager.fileExists(atPath: destination.path) {
            let attrs = try fileManager.attributesOfItem(atPath: destination.path)
            resumeOffset = attrs[.size] as? UInt64 ?? 0
        }

        await MainActor.run {
            state?.models.currentFileName = file
        }

        // Build request with optional Range header for resume
        var request = URLRequest(url: url)
        request.timeoutInterval = 120
        if resumeOffset > 0 {
            request.setValue("bytes=\(resumeOffset)-", forHTTPHeaderField: "Range")
        }
        AppLogger.shared.debug("Download request: \(url.absoluteString) resumeOffset=\(resumeOffset)")

        // Chunked download via delegate — URLSession delivers data in large chunks (32-64KB),
        // not byte-by-byte. The old AsyncBytes loop did 857M async iterations for a 857MB file;
        // this does ~13K. Bottleneck moves from CPU to network, so source selection matters.
        let delegate = FileDownloadDelegate(
            destination: destination,
            resumeOffset: resumeOffset,
            onChunk: { [weak self] cumulativeBytes, deltaBytes, expectedTotal in
                guard let self else { return }
                Task { @MainActor in
                    self.sessionDownloadedBytes += deltaBytes
                    if expectedTotal > 0 {
                        let fileProgress = min(Double(cumulativeBytes) / Double(expectedTotal), 1.0)
                        let overall = (Double(fileIndex) + fileProgress) / Double(totalFiles)
                        await self.updateProgress(engine: engine, overall: overall, fileName: file,
                                                  fileProgress: fileProgress,
                                                  bytesDownloaded: self.sessionDownloadedBytes)
                    }
                }
            }
        )

        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let dataTask = session.dataTask(with: request)

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                delegate.setContinuation(continuation)
                dataTask.resume()
            }
        } onCancel: {
            dataTask.cancel()
        }

        // Check response after download completes
        guard let httpResponse = delegate.response else {
            AppLogger.shared.error("Download: no HTTP response for \(file)")
            throw ModelDownloadError.invalidResponse
        }
        AppLogger.shared.debug("Download response: HTTP \(httpResponse.statusCode) expected=\(httpResponse.expectedContentLength)")

        if httpResponse.statusCode == 404 {
            AppLogger.shared.warn("⚠️  File not found (404): \(file)")
            throw ModelDownloadError.fileNotFound(file: file)
        }
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 206 else {
            AppLogger.shared.error("Download failed for \(file): HTTP \(httpResponse.statusCode)")
            throw ModelDownloadError.downloadFailed(file: file, statusCode: httpResponse.statusCode)
        }

        // Verify file is not empty
        let attrs = try fileManager.attributesOfItem(atPath: destination.path)
        let finalSize = attrs[.size] as? UInt64 ?? 0
        guard finalSize > 0 else {
            throw ModelDownloadError.emptyFile(file: file)
        }
    }

    // MARK: - Verification

    private func verifyDownload(engine: STTEngine, at directory: URL) throws {
        for file in engine.requiredFiles {
            let url = directory.appendingPathComponent(file)
            guard fileManager.fileExists(atPath: url.path) else {
                throw ModelDownloadError.missingFile(file: file)
            }
            let attrs = try fileManager.attributesOfItem(atPath: url.path)
            let size = attrs[.size] as? UInt64 ?? 0
            guard size > 0 else {
                throw ModelDownloadError.emptyFile(file: file)
            }
        }
    }

    // MARK: - Progress Updates

    private func updateProgress(
        engine: STTEngine,
        overall: Double,
        fileName: String,
        fileProgress: Double,
        bytesDownloaded: Int64? = nil
    ) async {
        let now = Date()
        let bytes = bytesDownloaded ?? sessionDownloadedBytes

        // Calculate speed every ~0.5s to avoid jitter
        var speedStr = ""
        var etaStr = ""
        if let lastUpdate = lastSpeedUpdate, now.timeIntervalSince(lastUpdate) >= 0.5 {
            let elapsed = now.timeIntervalSince(lastUpdate)
            let bytesInInterval = bytes - lastSpeedBytes
            let bytesPerSec = Double(bytesInInterval) / elapsed
            speedStr = formatSpeed(bytesPerSec)

            // ETA from overall progress
            let total = state?.models.totalBytes[engine.rawValue] ?? 0
            if total > 0 && bytes > 0 && bytes < total {
                let remainingBytes = total - bytes
                let etaSec = Double(remainingBytes) / max(bytesPerSec, 1)
                etaStr = formatETA(etaSec)
            }
            lastSpeedUpdate = now
            lastSpeedBytes = bytes
        }

        await MainActor.run {
            state?.models.downloadProgress[engine.rawValue] = overall
            state?.models.currentFileName = fileName
            var fileProg = state?.models.fileProgress[engine.rawValue] ?? [:]
            fileProg[fileName] = fileProgress
            state?.models.fileProgress[engine.rawValue] = fileProg
            state?.models.downloadedBytes[engine.rawValue] = bytes
            if !speedStr.isEmpty {
                state?.models.downloadSpeed[engine.rawValue] = speedStr
            }
            if !etaStr.isEmpty {
                state?.models.downloadETA[engine.rawValue] = etaStr
            }
        }
    }

    // MARK: - Stats Helpers

    /// Calculate total bytes already on disk (partial + final files) for an engine.
    private func calculateExistingBytes(engine: STTEngine, files: [String]) -> Int64 {
        let targetDir = modelDirectory(for: engine)
        let partialDir = partialDirectory(for: engine)
        var total: Int64 = 0
        for file in files {
            let finalFile = targetDir.appendingPathComponent(file)
            let partialFile = partialDir.appendingPathComponent(file)
            if let size = (try? fileManager.attributesOfItem(atPath: finalFile.path))?[.size] as? Int64 {
                total += size
            } else if let size = (try? fileManager.attributesOfItem(atPath: partialFile.path))?[.size] as? Int64 {
                total += size
            }
        }
        return total
    }

    /// Best-effort total size via HEAD requests. Non-fatal — returns 0 on failure.
    private func fetchTotalSize(files: [String], baseURL: String) async -> Int64 {
        var total: Int64 = 0
        for file in files {
            guard let url = URL(string: "\(baseURL)/\(file)") else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 10
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse {
                    let len = http.expectedContentLength
                    if len > 0 { total += len }
                }
            } catch {
                // Non-fatal — we'll just not show total size
            }
        }
        AppLogger.shared.info("Total expected size: \(total) bytes across \(files.count) files")
        return total
    }

    private func formatSpeed(_ bytesPerSec: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.includesActualByteCount = false
        if bytesPerSec < 1 { return "" }
        return "\(formatter.string(fromByteCount: Int64(bytesPerSec)))/s"
    }

    private func formatETA(_ seconds: Double) -> String {
        if seconds < 1 { return "" }
        if seconds < 60 { return "~\(Int(seconds))s" }
        if seconds < 3600 { return "~\(Int(seconds / 60))min" }
        return "~\(Int(seconds / 3600))h"
    }

    // MARK: - Directories

    private var supportDir: URL {
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("com.vocaltype.app")
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func partialDirectory(for engine: STTEngine) -> URL {
        supportDir.appendingPathComponent("partial/\(engine.repoFolderName)")
    }
}

// MARK: - Chunked Download Delegate

/// URLSession data delegate that writes data chunks directly to a file.
/// Replaces byte-by-byte AsyncBytes iteration — 10-100x faster for large files.
private final class FileDownloadDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let destination: URL
    private let resumeOffset: UInt64
    private let onChunk: @Sendable (Int64, Int64, Int64) -> Void  // (cumulative, delta, expectedTotal)
    private var handle: FileHandle?
    private var cumulative: Int64 = 0
    private var continuation: CheckedContinuation<Void, Error>?

    /// Set by didReceive(response:) — read by caller after download completes.
    var response: HTTPURLResponse?
    private var expectedTotal: Int64 = 0

    init(destination: URL, resumeOffset: UInt64,
         onChunk: @escaping @Sendable (Int64, Int64, Int64) -> Void) {
        self.destination = destination
        self.resumeOffset = resumeOffset
        self.onChunk = onChunk
        super.init()
    }

    func setContinuation(_ cont: CheckedContinuation<Void, Error>) {
        self.continuation = cont
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let httpResponse = response as? HTTPURLResponse else {
            continuation?.resume(throwing: ModelDownloadError.invalidResponse)
            completionHandler(.cancel)
            return
        }
        self.response = httpResponse

        if httpResponse.statusCode == 404 {
            continuation?.resume(throwing: ModelDownloadError.fileNotFound(file: destination.lastPathComponent))
            completionHandler(.cancel)
            return
        }
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 206 else {
            continuation?.resume(throwing: ModelDownloadError.downloadFailed(
                file: destination.lastPathComponent, statusCode: httpResponse.statusCode))
            completionHandler(.cancel)
            return
        }

        // Determine expected total size
        if let contentRange = httpResponse.allHeaderFields["Content-Range"] as? String,
           let total = contentRange.split(separator: "/").last.flatMap({ Int64($0) }) {
            expectedTotal = total
        } else {
            expectedTotal = httpResponse.expectedContentLength
        }

        // Open file handle
        if !FileManager.default.fileExists(atPath: destination.path) {
            FileManager.default.createFile(atPath: destination.path, contents: nil)
        }
        do {
            handle = try FileHandle(forWritingTo: destination)
            if resumeOffset > 0 && httpResponse.statusCode == 206 {
                try handle?.seekToEnd()
                cumulative = Int64(resumeOffset)
            } else {
                if resumeOffset > 0 && httpResponse.statusCode == 200 {
                    AppLogger.shared.warn("⚠️  Server doesn't support Range resume for \(destination.lastPathComponent) — restarting from 0")
                }
                try handle?.truncate(atOffset: 0)
                cumulative = 0
            }
        } catch {
            continuation?.resume(throwing: error)
            completionHandler(.cancel)
            return
        }

        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        do {
            try handle?.write(contentsOf: data)
            let delta = Int64(data.count)
            cumulative += delta
            onChunk(cumulative, delta, expectedTotal)
        } catch {
            dataTask.cancel()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        try? handle?.close()
        if let error {
            continuation?.resume(throwing: error)
        } else {
            continuation?.resume()
        }
    }
}

// MARK: - STTEngine extension

extension STTEngine {
    /// Folder name for storing model files on disk (mirrors the HF repo name after the slash).
    var repoFolderName: String {
        // Use the last path component of the repo ID as the folder name
        hfRepoID.components(separatedBy: "/").last ?? hfRepoID
    }
}

// MARK: - Errors

enum ModelDownloadError: LocalizedError {
    case repoNotFound(repoID: String, source: String)
    case noFilesFound(repoID: String, source: String)
    case fileNotFound(file: String)
    case downloadFailed(file: String, statusCode: Int)
    case emptyFile(file: String)
    case missingFile(file: String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .repoNotFound(let repo, let source):
            return "Model repository not found on \(source): \(repo)"
        case .noFilesFound(let repo, let source):
            return "No model files found in \(source)/\(repo)"
        case .fileNotFound(let file):
            return "File not found on server: \(file)"
        case .downloadFailed(let file, let code):
            return "Download failed for \(file) (HTTP \(code))"
        case .emptyFile(let file):
            return "Downloaded file is empty: \(file)"
        case .missingFile(let file):
            return "Required file missing after download: \(file)"
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
}
