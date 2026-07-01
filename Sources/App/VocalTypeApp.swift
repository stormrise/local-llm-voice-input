//
// VocalTypeApp.swift
// LocalVoice
//
// SwiftUI app entry point and scene definitions
//
// Copyright © 2025 LocalVoice. All rights reserved.
// Licensed under the Apache License 2.0 — see LICENSE file for details.
// Author: LocalVoice Team
//

import SwiftUI

// MARK: - LocalVoice App Entry Point

@main
struct LocalVoiceApp: App {
    @State private var state = AppState()
    @State private var themeManager = ThemeManager.shared

    var body: some Scene {
        // Main menu bar entry
        MenuBarExtra {
            MenuBarExtraContent(state: state)
                .preferredColorScheme(themeManager.swiftUIColorScheme)
        } label: {
            Image(systemName: state.menuBarState.sfSymbol)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(state.menuBarState.tintColor)
        }
        .menuBarExtraStyle(.window)

        // Settings
        Window("Preferences", id: "settings") {
            SettingsView(state: state)
                .frame(width: 560, height: 440)
                .modifier(WindowTitleModifier(title: state.locale.settingsTitle))
                .preferredColorScheme(themeManager.swiftUIColorScheme)
        }
        .windowResizability(.contentSize)

        // Welcome / Onboarding
        Window("Welcome to LocalVoice", id: "welcome") {
            WelcomeView(state: state)
                .modifier(WindowTitleModifier(title: state.locale.welcomeWindowTitle))
                .preferredColorScheme(themeManager.swiftUIColorScheme)
        }
        .defaultSize(width: 600, height: 560)
        .windowResizability(.contentSize)

        // Permissions
        Window("Permissions", id: "permissions") {
            PermissionsView(state: state)
                .modifier(WindowTitleModifier(title: state.locale.permissionsWindowTitle))
                .preferredColorScheme(themeManager.swiftUIColorScheme)
        }
        .defaultSize(width: 520, height: 480)
        .windowResizability(.contentSize)

    }
}

// MARK: - Window Title Modifier

/// Updates window title dynamically when locale changes.
struct WindowTitleModifier: ViewModifier {
    let title: String

    func body(content: Content) -> some View {
        content.background(WindowTitleAccessor(title: title))
    }
}

struct WindowTitleAccessor: NSViewRepresentable {
    let title: String

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            if window.title != title {
                window.title = title
            }
            // Enable liquid glass window — transparent for glass effect
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titlebarAppearsTransparent = true
        }
    }
}

// MARK: - Menu Bar Extra Content Wrapper

struct MenuBarExtraContent: View {
    @Bindable var state: AppState
    @Environment(\.openWindow) private var openWindow

    @State private var hasInitialized = false

    var body: some View {
        MenuBarView(state: state)
            .onAppear {
                initializeOnce()
            }
            .onChange(of: state.showWelcome) { _, show in
                if show {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(100))
                        openWindow(id: "welcome")
                    }
                }
            }
    }

    private func initializeOnce() {
        guard !hasInitialized else { return }
        hasInitialized = true

        state.checkFirstLaunch()
        state.permissions.microphone = PermissionChecker.checkMicrophone()
        state.permissions.accessibility = PermissionChecker.checkAccessibility()
        // NOTE: AppState.init() already schedules a delayed initializeServices() call.
        // We do NOT call it again here to avoid double-registration of hotkey tap,
        // duplicate permission requests, etc.

        // On first launch, open the welcome window
        if state.appPhase == .firstLaunch {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                openWindow(id: "welcome")
            }
        }
    }
}
