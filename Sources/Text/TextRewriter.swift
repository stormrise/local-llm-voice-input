//
// TextRewriter.swift
// LocalVoice
//
// Rule-based text post-processing (filler removal, tech terms)
//
// Copyright © 2025 LocalVoice. All rights reserved.
// Licensed under the Apache License 2.0 — see LICENSE file for details.
// Author: LocalVoice Team
//

import Foundation

/// Text rewriting service for post-processing ASR output.
/// Removes filler words, corrects common errors, and improves readability.
actor TextRewriter {
    /// Configuration for rewriting behavior
    struct Config {
        /// Remove filler words (嗯, 啊, 那个, 就是, um, uh, like, you know, etc.)
        var removeFillers: Bool = true
        /// Auto-correct common ASR errors using phonetic/context clues
        var autoCorrect: Bool = true
        /// Auto-format lists and structure (numbered, bulleted)
        var autoFormat: Bool = true
        /// Languages to process
        var languages: Set<String> = ["zh", "en"]
    }

    private let config: Config

    init(config: Config = Config()) {
        self.config = config
    }

    /// Rewrite transcription text for better readability and accuracy
    func rewrite(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if config.removeFillers {
            result = removeFillerWords(result)
        }

        if config.autoCorrect {
            result = autoCorrectCommonErrors(result)
            result = fixMixedLanguageSpacing(result)
        }

        if config.autoFormat {
            result = autoFormatText(result)
        }

        if result != text {
            AppLogger.shared.info("✏️ Rewrote: \"\(text.prefix(30))\" → \"\(result.prefix(30))\"")
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Filler Word Removal

    private let chineseFillerPattern: [(String, String)] = [
        ("(^|[,，。！？\\s])嗯([,，。！？\\s]|$)", "$1$2"),
        ("(^|[,，。！？\\s])啊([,，。！？\\s]|$)", "$1$2"),
        ("(^|[,，。！？\\s])哦([,，。！？\\s]|$)", "$1$2"),
        ("那个[，,]?", ""),
        ("就是说[，,]?", ""),
        ("然后[，,]?", ""),
        ("反正[，,]?", ""),
        ("怎么说[呢]?[？?]?", ""),
    ]

    private func removeFillerWords(_ text: String) -> String {
        var result = text

        // Chinese filler words with punctuation context
        for (pattern, replacement) in chineseFillerPattern {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: replacement)
            }
        }

        // English filler words (word-boundary aware)
        let englishFillers = ["um", "uh", "er", "ah", "like", "you know", "i mean", "sort of", "kind of"]
        for filler in englishFillers {
            if let regex = try? NSRegularExpression(pattern: "\\b\(NSRegularExpression.escapedPattern(for: filler))\\b", options: [.caseInsensitive]) {
                result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
            }
        }

        // Clean up extra spaces/punctuation from filler removal
        result = result.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: "，,", with: "，")
        result = result.replacingOccurrences(of: "。。", with: "。")

        return result
    }

    // MARK: - Common ASR Error Correction

    private let techTermCorrections: [String: String] = [
        // API / Protocols
        "rest api": "REST API",
        "restful": "RESTful",
        "graphql": "GraphQL",
        "grpc": "gRPC",
        "web socket": "WebSocket",
        "t c p": "TCP",
        "u d p": "UDP",
        "h t t p": "HTTP",
        "h t t p s": "HTTPS",
        "s s l": "SSL",
        "t l s": "TLS",
        "i p": "IP",
        "d n s": "DNS",
        "c d n": "CDN",
        "j s o n": "JSON",
        "x m l": "XML",
        "c s v": "CSV",
        "y a m l": "YAML",
        "s q l": "SQL",
        "my sql": "MySQL",
        "postgresql": "PostgreSQL",
        "redis": "Redis",
        "mongo db": "MongoDB",
        "elastic search": "Elasticsearch",
        "cassandra": "Cassandra",
        "rabbet m q": "RabbitMQ",
        "apache kafka": "Apache Kafka",
        // Docker / K8s
        "docker": "Docker",
        "kubernetes": "Kubernetes",
        "helm": "Helm",
        "terra form": "Terraform",
        "ansible": "Ansible",
        // Languages
        "java script": "JavaScript",
        "type script": "TypeScript",
        "python": "Python",
        "rust": "Rust",
        "golang": "Go",
        "swift": "Swift",
        "c plus plus": "C++",
        "c sharp": "C#",
        "dot net": ".NET",
        "note dot j s": "Node.js",
        "react": "React",
        "vue": "Vue",
        "next dot j s": "Next.js",
        "nuxt": "Nuxt",
        "svelte": "Svelte",
        "flutter": "Flutter",
        "swift ui": "SwiftUI",
        "u i kit": "UIKit",
        // Cloud / DevOps
        "a w s": "AWS",
        "g c p": "GCP",
        "azure": "Azure",
        "cicd": "CI/CD",
        "gitlab": "GitLab",
        "github": "GitHub",
        "bitbucket": "Bitbucket",
        "git": "Git",
        // Data / AI
        "machine learning": "Machine Learning",
        "deep learning": "Deep Learning",
        "n l p": "NLP",
        "l l m": "LLM",
        "rag": "RAG",
        "fine tuning": "fine-tuning",
        "g p u": "GPU",
        "c p u": "CPU",
        "n p u": "NPU",
        "t p u": "TPU",
        "tensor processing unit": "TPU",
        "mlx": "MLX",
        "core ml": "Core ML",
        "metal": "Metal",
        "opengl": "OpenGL",
        "vulkan": "Vulkan",
        // General tech
        "api": "API",
        "sdk": "SDK",
        "cli": "CLI",
        "gui": "GUI",
        "ui": "UI",
        "ux": "UX",
        "devops": "DevOps",
        "agile": "Agile",
        "scrum": "Scrum",
        "sprint": "Sprint",
        "j i r a": "JIRA",
        "confluence": "Confluence",
        "excel": "Excel",
        "powerpoint": "PowerPoint",
        "word": "Word",
        // OS
        "linux": "Linux",
        "ubuntu": "Ubuntu",
        "debian": "Debian",
        "windows": "Windows",
        "macos": "macOS",
        "ios": "iOS",
        "android": "Android",
        // Package managers
        "home brew": "Homebrew",
        "n p m": "npm",
        "pip": "pip",
        "pip install": "pip install",
        "composer": "Composer",
        "cocoapods": "CocoaPods",
        "spm": "SPM",
    ]

    private func autoCorrectCommonErrors(_ text: String) -> String {
        var result = text

        // Common Chinese ASR phonetic confusions
        let chineseCorrections: [String: String] = [
            "新单": "新的",    // xin dan → xin de
            "处肉干": "出肉干",
            "等于处": "等于 true",
            "无 ": "补 ",
        ]
        for (wrong, correct) in chineseCorrections {
            if result.contains(wrong) {
                result = result.replacingOccurrences(of: wrong, with: correct)
            }
        }

        // English context correction: common ASR mistakes
        let englishCorrections: [String: String] = [
            "equal to": "equals",
            "dot com": ".com",
            "at the rate": "@",
        ]
        for (wrong, correct) in englishCorrections {
            result = result.replacingOccurrences(of: wrong, with: correct, options: [.caseInsensitive])
        }

        // Tech term casing/spacing corrections (case-insensitive, regex)
        for (wrong, correct) in techTermCorrections {
            result = result.replacingOccurrences(of: wrong, with: correct, options: [.caseInsensitive, .regularExpression])
        }

        return result
    }

    // MARK: - Mixed Language Spacing

    private func fixMixedLanguageSpacing(_ text: String) -> String {
        var result = text
        // Add space between Chinese char and English word start
        if let regex = try? NSRegularExpression(pattern: "([\\u4e00-\\u9fff])([a-zA-Z])") {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "$1 $2")
        }
        // Add space between English word end and Chinese char
        if let regex = try? NSRegularExpression(pattern: "([a-zA-Z])([\\u4e00-\\u9fff])") {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "$1 $2")
        }
        return result
    }

    // MARK: - Auto Formatting

    private func autoFormatText(_ text: String) -> String {
        var result = text

        // Detect numbered lists: "1 xxx 2 yyy 3 zzz" → "\n1. xxx\n2. yyy\n3. zzz"
        if let regex = try? NSRegularExpression(pattern: "(?<=\\s|^|。)(\\d+)\\s+(?=[^。，,]+(?:[。，,]|$))") {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "\n$1. ")
        }

        // Clean up excessive whitespace/newlines
        result = result.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
