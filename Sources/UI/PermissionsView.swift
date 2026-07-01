//
// PermissionsView.swift
// LocalVoice
//
// Permission grant UI
//
// Copyright © 2025 LocalVoice. All rights reserved.
// Licensed under the Apache License 2.0 — see LICENSE file for details.
// Author: LocalVoice Team
//

import SwiftUI

// MARK: - Permissions View

struct PermissionsView: View {
    @Bindable var state: AppState
    @State private var animateIn = false
    @State private var permissionTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(.top, 32)
                .padding(.bottom, 24)

            // Permission checklist
            VStack(spacing: 16) {
                PermissionCheckRow(
                    icon: "mic.fill",
                    title: state.locale.microphoneAccess,
                    description: state.locale.microphoneAccessDesc,
                    detail: state.locale.permissionsPrivacy,
                    isGranted: state.permissions.microphone == .granted,
                    grantedText: state.locale.granted,
                    grantButtonText: state.locale.grantAccess,
                    onGrant: {
                        requestMicrophone()
                    }
                )

                PermissionCheckRow(
                    icon: "accessibility",
                    title: state.locale.accessibilityAccess,
                    description: state.locale.accessibilityAccessDesc,
                    detail: state.locale.permissionsAcc,
                    isGranted: state.permissions.accessibility == .granted,
                    grantedText: state.locale.granted,
                    grantButtonText: state.locale.grantAccess,
                    onGrant: {
                        requestAccessibility()
                    }
                )
            }
            .padding(.horizontal, 40)
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : 20)

            Spacer()

            // Info footer
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.appSuccess)

                Text("100% Private")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.appTextPrimary)
                }

                Text(state.locale.privacyPriority)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(16)
            .glassBackground(cornerRadius: 12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.appSuccess.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 60)
            .padding(.bottom, 16)

            // Continue Button
            Button {
                state.completeOnboarding()
            } label: {
                Text(state.permissions.allGranted ? state.locale.continue : state.locale.skipForNow)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.appOnPrimary)
                    .frame(width: 200, height: 42)
                    .background(
                        state.permissions.allGranted
                            ? AnyShapeStyle(LinearGradient(colors: [Color.appPrimary, Color.appPrimaryDark.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(.secondary)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: state.permissions.allGranted ? Color.appPrimary.opacity(0.25) : .clear, radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 24)
        }
        .frame(width: 520, height: 480)
        .background(
            LinearGradient(
                colors: [Color.appSurface.opacity(0.35), Color.appSurfaceVariant.opacity(0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .glassBackground()
        .onAppear {
            refreshPermissions()
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                animateIn = true
            }
        }
        .onAppear {
            // Poll permissions periodically since user may grant in System Settings
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                Task { @MainActor in refreshPermissions() }
            }
        }
        .onDisappear {
            permissionTimer?.invalidate()
            permissionTimer = nil
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.appPrimary.opacity(0.1))
                    .frame(width: 64, height: 64)

                Image(systemName: "shield.checkered")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(
                        LinearGradient(colors: [Color.appPrimary, Color.appPrimaryDark], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }

            Text(state.locale.permissionsSetupTitle)
                .font(.system(size: 22, weight: .bold, design: .rounded))

            Text(state.locale.permissionsSetupDesc2)
                .font(.system(size: 13))
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)
        }
    }

    private func requestMicrophone() {
        Task {
            let status = await PermissionChecker.requestMicrophone()
            await MainActor.run {
                state.permissions.microphone = status
                if status != .granted {
                    openMicrophoneSettings()
                }
            }
        }
    }

    private func requestAccessibility() {
        openAccessibilitySettings()
    }

    private func refreshPermissions() {
        state.permissions.microphone = PermissionChecker.checkMicrophone()
        state.permissions.accessibility = PermissionChecker.checkAccessibility()
    }

    private func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Permission Check Row

struct PermissionCheckRow: View {
    let icon: String
    let title: String
    let description: String
    let detail: String
    let isGranted: Bool
    let grantedText: String
    let grantButtonText: String
    let onGrant: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Status icon
            ZStack {
                Circle()
                    .fill(isGranted ? Color.appSuccess.opacity(0.12) : Color.appPrimary.opacity(0.1))
                    .frame(width: 48, height: 48)

                if isGranted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.appSuccess)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.appPrimary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))

                    if isGranted {
                        Text(grantedText)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.appSuccess)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.appSuccess.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }

                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appTextPrimary)

                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }

            Spacer()

            if !isGranted {
                Button(grantButtonText) {
                    onGrant()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(Color.appPrimary)
                .onHover { hovering in
                    isHovering = hovering
                }
            }
        }
        .padding(16)
        .glassBackground(cornerRadius: 12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isGranted
                        ? Color.appSuccess.opacity(0.2)
                        : isHovering
                            ? Color.appPrimary.opacity(0.2)
                            : Color.clear,
                    lineWidth: 1
                )
        )
    }
}
