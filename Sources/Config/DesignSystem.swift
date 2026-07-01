//
// DesignSystem.swift
// LocalVoice
//
// Design tokens, theme manager, glass effects
//
// Copyright © 2025 LocalVoice. All rights reserved.
// Licensed under the Apache License 2.0 — see LICENSE file for details.
// Author: LocalVoice Team
//

import SwiftUI
import AppKit

// MARK: - Theme Types

enum AppTheme: String, CaseIterable, Codable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "Follow System"
        case .light: return "Light (Avocado)"
        case .dark: return "Dark (Racing Red)"
        }
    }
}

enum ActiveColorScheme {
    case light
    case dark
}

// MARK: - Theme Manager

/// Manages the app's active color scheme. Reads/writes UserDefaults directly so
/// it works without touching AppSettings (which lives in UIState.swift).
///
/// REQUIRED WIRING (add in VocalTypeApp.swift by user):
///   .preferredColorScheme(ThemeManager.shared.swiftUIColorScheme)
/// on each Window/MenuBarExtra to force SwiftUI to re-render when theme changes.
///
/// REQUIRED WIRING (add in UIState.swift by user):
///   Optionally store appTheme in AppSettings for consistency, but ThemeManager
///   already persists to UserDefaults key "appTheme".
@Observable
final class ThemeManager: @unchecked Sendable {
    static let shared = ThemeManager()

    var appTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(appTheme.rawValue, forKey: "appTheme")
            refreshActiveScheme()
        }
    }

    private(set) var activeScheme: ActiveColorScheme = .dark

    var swiftUIColorScheme: ColorScheme {
        activeScheme == .dark ? .dark : .light
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: "appTheme") ?? AppTheme.system.rawValue
        appTheme = AppTheme(rawValue: raw) ?? .system
        refreshActiveScheme()

        // Listen for system appearance changes so .system theme stays current
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(systemAppearanceChanged),
            name: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
    }

    @objc private func systemAppearanceChanged() {
        if appTheme == .system {
            refreshActiveScheme()
        }
    }

    private func refreshActiveScheme() {
        switch appTheme {
        case .system:
            // Read system dark-mode state from UserDefaults (safe from any thread)
            let isDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
            activeScheme = isDark ? .dark : .light
        case .light:
            activeScheme = .light
        case .dark:
            activeScheme = .dark
        }
    }
}

// MARK: - Hex Color Helper

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Dynamic Color Tokens

extension Color {
    // Light palette — Avocado Meadow
    private static let avocadoGreen       = Color(hex: "#7CB342")
    private static let avocadoGreenDark   = Color(hex: "#558B2F")
    private static let lightBackground    = Color(hex: "#FAFAF5")
    private static let lightSurface       = Color(hex: "#F0F0E8")
    private static let lightSurfaceVariant = Color(hex: "#E8E8E0")
    private static let lightTextPrimary   = Color(hex: "#1A1A14")
    private static let lightTextSecondary = Color(hex: "#3A3A2E")
    private static let lightTextHint      = Color(hex: "#5A5A4E")
    private static let lightCardBorder    = Color(hex: "#7CB342").opacity(0.18)

    // Dark palette — Racing Red (existing)
    private static let darkBackground     = Color(red: 0.07, green: 0.07, blue: 0.08)
    private static let darkSurface        = Color(red: 0.12, green: 0.12, blue: 0.14)
    private static let darkSurfaceVariant = Color(red: 0.16, green: 0.16, blue: 0.18)
    private static let darkTextPrimary    = Color.white
    private static let darkTextSecondary  = Color.white
    private static let darkTextHint       = Color.white

    // MARK: Surfaces

    static var appBackground: Color {
        ThemeManager.shared.activeScheme == .dark ? darkBackground : lightBackground
    }

    static var appSurface: Color {
        ThemeManager.shared.activeScheme == .dark ? darkSurface : lightSurface
    }

    static var appSurfaceVariant: Color {
        ThemeManager.shared.activeScheme == .dark ? darkSurfaceVariant : lightSurfaceVariant
    }

    // MARK: Primary accent

    static var appPrimary: Color {
        ThemeManager.shared.activeScheme == .dark
            ? Color(red: 0.898, green: 0.243, blue: 0.243)
            : avocadoGreen
    }

    static var appPrimaryDark: Color {
        ThemeManager.shared.activeScheme == .dark
            ? Color(red: 0.773, green: 0.188, blue: 0.188)
            : avocadoGreenDark
    }

    static var appOnPrimary: Color {
        .white
    }

    // MARK: Semantic colors

    static var appSuccess: Color {
        ThemeManager.shared.activeScheme == .dark ? Color.green : Color(hex: "#2E7D32")
    }

    static var appWarning: Color {
        ThemeManager.shared.activeScheme == .dark ? Color.orange : Color(hex: "#F57C00")
    }

    static var appError: Color {
        ThemeManager.shared.activeScheme == .dark
            ? Color(red: 1.0, green: 0.25, blue: 0.25)
            : Color(hex: "#D32F2F")
    }

    // MARK: Text emphasis (dynamic)

    static var appTextPrimary: Color {
        ThemeManager.shared.activeScheme == .dark
            ? darkTextPrimary.opacity(contentPrimaryOpacity)
            : lightTextPrimary.opacity(contentPrimaryOpacity)
    }

    static var appTextSecondary: Color {
        ThemeManager.shared.activeScheme == .dark
            ? darkTextSecondary.opacity(contentSecondaryOpacity)
            : lightTextSecondary.opacity(contentSecondaryOpacity)
    }

    static var appTextHint: Color {
        ThemeManager.shared.activeScheme == .dark
            ? darkTextHint.opacity(contentHintOpacity)
            : lightTextHint.opacity(contentHintOpacity)
    }

    // MARK: Content opacity constants (keep for compatibility)

    static let contentPrimaryOpacity: Double   = 0.87
    static let contentSecondaryOpacity: Double = 0.60
    static let contentHintOpacity: Double      = 0.38

    // MARK: Card border

    static var appCardBorder: Color {
        ThemeManager.shared.activeScheme == .dark
            ? Color.white.opacity(0.08)
            : lightCardBorder
    }
}

// MARK: - Design System

enum DesignSystem {
    // MARK: Typography

    static func headline() -> Font {
        .system(size: 20, weight: .bold)
    }

    static func title() -> Font {
        .system(size: 16, weight: .semibold)
    }

    static func body() -> Font {
        .system(size: 13, weight: .regular)
    }

    static func caption() -> Font {
        .system(size: 11, weight: .regular)
    }

    // MARK: Gradients

    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [.appPrimary, .appPrimaryDark],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var primaryGradientWithOpacity: LinearGradient {
        LinearGradient(
            colors: [.appPrimary, .appPrimaryDark.opacity(0.8)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var primaryGradientReversed: LinearGradient {
        LinearGradient(
            colors: [.appPrimary, .appPrimaryDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Liquid Glass Background Modifiers

extension View {
    /// Standard liquid-glass background for windows and cards.
    func glassBackground(cornerRadius: CGFloat = 16) -> some View {
        self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
    }

    /// The most transparent glass — for the recording HUD.
    /// Uses NSGlassEffectView for the floating NSPanel (AppKit context).
    func hudGlassBackground(cornerRadius: CGFloat = 18) -> some View {
        self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
    }

    /// Subtle glass fill for small controls and badges.
    func glassBadge(cornerRadius: CGFloat = 8) -> some View {
        self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}
