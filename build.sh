#!/bin/bash
# ============================================================================
# LocalVoice 本地语音 — Build & Install Script
# Usage:
#   ./build.sh              # Build + install to ~/Applications
#   ./build.sh --release    # Build + install to /Applications (needs sudo)
#   ./build.sh --dmg        # Build + create DMG for distribution
#   ./build.sh --build-only # Just build, don't install
#   ./build.sh --install-only  # Re-install from existing build
# ============================================================================
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="LocalVoice"
CONFIGURATION="${1:-debug}"
DMG_MODE=false

# --- Parse flags ---
BUILD=true
INSTALL=true
INSTALL_DIR="$HOME/Applications"

if [[ "$CONFIGURATION" == "--build-only" ]]; then
    BUILD=true; INSTALL=false; CONFIGURATION="debug"
elif [[ "$CONFIGURATION" == "--install-only" ]]; then
    BUILD=false; INSTALL=true; CONFIGURATION="debug"
elif [[ "$CONFIGURATION" == "--release" ]]; then
    CONFIGURATION="release"; INSTALL_DIR="/Applications"
    BUILD=true; INSTALL=true
elif [[ "$CONFIGURATION" == "--dmg" ]]; then
    CONFIGURATION="release"; DMG_MODE=true; INSTALL=false
    BUILD=true
elif [[ "$CONFIGURATION" == "--help" ]]; then
    echo "Usage: $0 [--release|--dmg|--build-only|--install-only|--help]"
    echo "  (default)     Build debug + install to ~/Applications"
    echo "  --release     Build release + install to /Applications"
    echo "  --dmg         Build release + create DMG at Desktop/LocalVoice.dmg"
    echo "  --build-only  Build only, no install"
    echo "  --install-only  Re-install from existing build"
    exit 0
fi

echo "╔══════════════════════════════════════════════╗"
echo "║  LocalVoice 本地语音 — Build & Install   ║"
echo "║  Configuration: $CONFIGURATION"
echo "╚══════════════════════════════════════════════╝"

# ---- Step 1: Build ----
if $BUILD; then
    echo ""
    echo "🔨 Building $APP_NAME ($CONFIGURATION)..."
    swift build --configuration "$CONFIGURATION"
    echo "   ✅ Build complete"
fi

# ---- Step 2: Prepare paths ----
BUILD_DIR="$(swift build --configuration "$CONFIGURATION" --show-bin-path)"
BINARY_PATH="$BUILD_DIR/$APP_NAME"
RESOURCE_BUNDLE_PATH="$BUILD_DIR/${APP_NAME}_${APP_NAME}.bundle"

if [[ ! -f "$BINARY_PATH" ]]; then
    echo "❌ Binary not found at: $BINARY_PATH"
    echo "   Build first with: $0"
    exit 1
fi

# ---- Step 3: Create .app bundle ----
echo ""
echo "📦 Creating $APP_NAME.app bundle..."
APP_BUNDLE_DIR="/tmp/${APP_NAME}.app"
rm -rf "$APP_BUNDLE_DIR"

CONTENTS_DIR="$APP_BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Binary
cp "$BINARY_PATH" "$MACOS_DIR/$APP_NAME"

# Info.plist (with LSUIElement=true for menu bar app)
cat > "$CONTENTS_DIR/Info.plist" <<- PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleDisplayName</key>
    <string>LocalVoice 本地语音</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.vocaltype.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>LocalVoice needs microphone access to capture your voice for local dictation transcription. All processing stays on your device.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>LocalVoice needs accessibility access to insert transcribed text into your active application.</string>
    <key>NSInputMonitoringUsageDescription</key>
    <string>LocalVoice needs input monitoring to detect your hotkey (Fn/Globe key) for push-to-talk dictation.</string>
    <key>CFBundleSupportedPlatforms</key>
    <array><string>MacOSX</string></array>
    <key>NSHumanReadableCopyright</key>
    <string>Open source — MIT License</string>
</dict>
</plist>
PLIST
echo "   ✅ Info.plist created"

# PkgInfo
echo "APPL????" > "$CONTENTS_DIR/PkgInfo"

# Assets (compile the asset catalog if it exists)
ASSETS_PATH="$PROJECT_DIR/Sources/Assets.xcassets"
if [ -d "$ASSETS_PATH" ]; then
    echo "   🖼️  Compiling Assets.xcassets..."
    ACTOOL_LOG=$(mktemp)
    xcrun actool \
        "$ASSETS_PATH" \
        --compile "$RESOURCES_DIR" \
        --platform macosx \
        --minimum-deployment-target 26.0 \
        --output-format human-readable-text \
        --app-icon AppIcon \
        --output-partial-info-plist "$RESOURCES_DIR/assetcatalog.plist" \
        2>&1 || echo "   ⚠️  actool warning: asset compilation skipped (app icon may not be set)"
    rm -f "$ACTOOL_LOG"
    echo "   ✅ Assets compiled"
fi

# SwiftPM resource bundle (images, config files, etc.)
if [ -d "$RESOURCE_BUNDLE_PATH" ]; then
    cp -R "$RESOURCE_BUNDLE_PATH" "$RESOURCES_DIR/"
    echo "   ✅ Copied resource bundle: $(basename "$RESOURCE_BUNDLE_PATH")"
fi

# MLX Metal shaders — compile .metal files into mlx.metallib
# MLX looks for mlx.metallib next to the binary (MacOS/) via dladdr
MLX_SOURCE_DIR=""
for checkout in "$PROJECT_DIR"/.build/checkouts/mlx-swift/Source/Cmlx/mlx; do
    if [ -d "$checkout" ]; then
        MLX_SOURCE_DIR="$checkout"
        break
    fi
done
MLX_KERNELS_DIR="$MLX_SOURCE_DIR/mlx/backend/metal/kernels"
if [ -n "$MLX_SOURCE_DIR" ] && [ -d "$MLX_KERNELS_DIR" ]; then
    # Compile metallib to persistent cache so it survives app bundle rebuilding
    CACHED_METALLIB="$PROJECT_DIR/.build/mlx.metallib"
    
    # Skip recompilation if cached metallib is newer than all .metal source files
    if [ -f "$CACHED_METALLIB" ]; then
        NEWEST_METAL=$(find "$MLX_KERNELS_DIR" -name "*.metal" -type f -exec stat -f "%m" {} \; | sort -rn | head -1)
        CACHED_MTIME=$(stat -f "%m" "$CACHED_METALLIB")
        if [ "$CACHED_MTIME" -ge "$NEWEST_METAL" ]; then
            echo "   ✅ MLX metallib cached (newer than sources, skipping recompilation)"
            METAL_CACHED=true
        fi
    fi
    
    if [ "${METAL_CACHED:-false}" != true ]; then
    echo "   🔨 Compiling MLX Metal shaders (parallel)..."
    METAL_AIR_DIR=$(mktemp -d)
    # Same flags as MLX's CMakeLists.txt — notably NO -std flag (uses SDK default)
    METAL_FLAGS=(-x metal -Wall -Wextra -fno-fast-math -Wno-c++17-extensions -Wno-c++20-extensions)
    
    # Compile each .metal file to .air in parallel
    METAL_SUCCESS=true
    METAL_PID_FILE=$(mktemp)
    FAILED_FILE=$(mktemp)
    
    while IFS= read -r metal_file; do
        rel_path="${metal_file#$MLX_KERNELS_DIR/}"
        air_file="$METAL_AIR_DIR/${rel_path%.metal}.air"
        mkdir -p "$(dirname "$air_file")"
        # -I points to MLX source root (so includes like "mlx/backend/metal/kernels/utils.h" resolve)
        (
            if ! xcrun -sdk macosx metal "${METAL_FLAGS[@]}" -I"$MLX_SOURCE_DIR" -c "$metal_file" -o "$air_file" 2>"$air_file.err"; then
                echo "FAIL:$rel_path" >> "$FAILED_FILE"
            fi
        ) &
        echo $! >> "$METAL_PID_FILE"
    done < <(find "$MLX_KERNELS_DIR" -name "*.metal" -type f)
    
    # Wait for all background compilations
    TOTAL_JOBS=$(wc -l < "$METAL_PID_FILE")
    echo "   ⏳ Waiting for $TOTAL_JOBS parallel compilations..."
    wait
    
    # Check for failures
    if [ -s "$FAILED_FILE" ]; then
        METAL_SUCCESS=false
        echo "   ⚠️  MLX metal compilation FAILED on:"
        while IFS= read -r line; do
            failed_file="${line#FAIL:}"
            echo "       - $failed_file"
            cat "$METAL_AIR_DIR/${failed_file%.metal}.air.err" | head -5
        done < "$FAILED_FILE"
    fi
    
    rm -f "$METAL_PID_FILE" "$FAILED_FILE"
    
    if $METAL_SUCCESS; then
        # Link all .air files into mlx.metallib
        # MLX's current_binary_dir() uses dladdr on the statically-linked Cmlx code,
        # which resolves to Contents/MacOS/ — so compile directly there.
        echo "   🔗 Linking mlx.metallib..."
        if xcrun -sdk macosx metallib $(find "$METAL_AIR_DIR" -name "*.air") -o "$CACHED_METALLIB"; then
            echo "   ✅ MLX metallib compiled ($(stat -f%z "$CACHED_METALLIB") bytes)"
        else
            echo "   ⚠️  MLX metallib linking failed — MLX will fail at runtime"
        fi
    else
        echo "   ⚠️  MLX metal compilation failed — MLX will fail at runtime"
    fi
    rm -rf "$METAL_AIR_DIR"
    fi  # end of cached check
else
    echo "   ⚠️  MLX kernels directory not found — skipping metallib"
    echo "   (Looked for: $MLX_KERNELS_DIR)"
fi

# Copy cached metallib into app bundle
if [ -f "$CACHED_METALLIB" ]; then
    cp "$CACHED_METALLIB" "$MACOS_DIR/mlx.metallib"
    echo "   ✅ Copied mlx.metallib to MacOS/ ($(stat -f%z "$CACHED_METALLIB") bytes)"
fi

# ---- Code Signing ----
# Signed binaries keep a stable code identity (certificate-based) across rebuilds,
# so macOS TCC (permission system) recognizes the app every time.
# Ad-hoc signed binaries get a new CDHash on every build → TCC resets permissions.
echo "   🔏 Signing..."
ENTITLEMENTS="$PROJECT_DIR/Sources/VocalType.entitlements"
SIGNING_IDENTITY=""

# Look for available signing identities.
# Use -v to only match VALID identities (trusted certs).
# Priority: Apple Development → any other valid cert found.
DEV_CERT=$(security find-identity -v -p codesigning 2>/dev/null | grep "Apple Development" | head -1 | sed 's/.*"\(.*\)"/\1/')
ANY_VALID=$(security find-identity -v -p codesigning 2>/dev/null | grep -v "CSSMERR" | head -1 | sed 's/.*"\(.*\)"/\1/')

if [ -n "$DEV_CERT" ]; then
    SIGNING_IDENTITY="$DEV_CERT"
elif [ -n "$ANY_VALID" ]; then
    SIGNING_IDENTITY="$ANY_VALID"
fi

sign_bundle() {
    local bundle="$1"
    local identity="$2"
    local entitlements="$3"

    if [ -z "$identity" ]; then
        # No cert found — ad-hoc fallback (TCC won't persist)
        codesign --force --sign - --entitlements "$entitlements" "$bundle"
        echo "   ⚠️  Signed (ad-hoc — permissions will NOT persist across rebuilds)"
        echo "   💡 Create an Apple Development certificate via Xcode Settings → Accounts"
        return
    fi

    # Pre-sign any nested code objects that codesign auto-detects.
    # mlx.metallib is a fat Metal library that codesign treats as Mach-O.
    # In DMG mode, use ad-hoc signing for all nested objects.
    while IFS= read -r -d '' f; do
        if $DMG_MODE; then
            codesign --force --sign - "$f" 2>/dev/null || true
        else
            codesign --force --sign "$identity" "$f" 2>/dev/null || true
        fi
    done < <(find "$bundle/Contents/MacOS" -type f -name "*.metallib" -print0)

    # Sign the inner binary
    local binary="$bundle/Contents/MacOS/$APP_NAME"
    if [ -f "$binary" ]; then
        if $DMG_MODE; then
            codesign --force --sign - --entitlements "$entitlements" "$binary"  # ad-hoc for DMG
        else
            codesign --force --sign "$identity" --options runtime --entitlements "$entitlements" "$binary"
        fi
    fi

    # Sign the bundle wrapper (re-signs all nested code)
    if $DMG_MODE; then
        codesign --force --sign - --entitlements "$entitlements" "$bundle"  # ad-hoc for DMG
    else
        codesign --force --sign "$identity" --options runtime --entitlements "$entitlements" "$bundle"
    fi

    echo "   ✅ Signed with: $identity"
}

# Sign with whatever cert we have
sign_bundle "$APP_BUNDLE_DIR" "$SIGNING_IDENTITY" "$ENTITLEMENTS"

# Verify signature
echo "   🔍 Verifying signature..."
if codesign -dvvv "$APP_BUNDLE_DIR" 2>&1 | grep "Authority=Apple Development\|Authority=Developer ID\|flags=0x10000" > /dev/null; then
    echo "   ✅ Signature verified (hardened runtime, stable TCC identity)"
else
    echo "   ⚠️  Signature is ad-hoc — permissions will reset on rebuild"
fi

echo "   ✅ Bundle created at: $APP_BUNDLE_DIR"

# ---- Step 4: Install ----
if $INSTALL; then
    echo ""
    echo "📋 Installing to $INSTALL_DIR..."
    mkdir -p "$INSTALL_DIR"

    # Remove old version if present
    if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
        rm -rf "$INSTALL_DIR/$APP_NAME.app"
    fi

    cp -R "$APP_BUNDLE_DIR" "$INSTALL_DIR/$APP_NAME.app"

    # Remove quarantine attribute (important for unsigned apps)
    xattr -dr com.apple.quarantine "$INSTALL_DIR/$APP_NAME.app" 2>/dev/null || true

    echo "   ✅ Installed to: $INSTALL_DIR/$APP_NAME.app"
    echo ""
    echo "🚀 You can now run: open \"$INSTALL_DIR/$APP_NAME.app\""
    echo ""
    echo "📋 Next steps:"
    echo "   1. Grant microphone permission when prompted"
    echo "   2. Grant accessibility permission (for text injection)"
    echo "   3. Grant input monitoring (for global hotkey)"
    echo "   4. Press Fn/Globe key to start dictation!"
    echo ""
    echo "💡 To add to Login Items:"
    echo "   System Settings → General → Login Items → Add LocalVoice.app"
fi

# --- DMG Creation ---
if $DMG_MODE; then
    DMG_NAME="LocalVoice"
    DMG_FILE="$HOME/Desktop/$DMG_NAME.dmg"
    STAGING_DIR="/tmp/localvoice_dmg"
    
    echo ""
    echo "📦 Creating DMG..."
    
    # Clean up any previous DMG
    rm -f "$DMG_FILE"
    rm -rf "$STAGING_DIR"
    mkdir -p "$STAGING_DIR"
    
    # Copy app to staging
    cp -R "$APP_BUNDLE_DIR" "$STAGING_DIR/$APP_NAME.app"
    
    # Create Applications symlink
    ln -s /Applications "$STAGING_DIR/Applications"
    
    # Create DMG
    hdiutil create \
        -volname "$DMG_NAME" \
        -srcfolder "$STAGING_DIR" \
        -ov -format UDZO \
        "$DMG_FILE" \
        -imagekey zlib-level=9 \
        -scrub
    
    # Clean up staging
    rm -rf "$STAGING_DIR"
    
    # Sign the DMG (if we have a cert)
    if [ -n "${CODE_SIGN_IDENTITY:-}" ]; then
        codesign --sign "$CODE_SIGN_IDENTITY" "$DMG_FILE" --timestamp 2>/dev/null || true
        echo "   ✅ DMG signed"
    fi
    
    DMG_SIZE=$(du -sh "$DMG_FILE" | cut -f1)
    echo "   ✅ DMG created: $DMG_FILE ($DMG_SIZE)"
    echo ""
    echo "📤 You can share: $DMG_FILE"
fi

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  Done!                                       ║"
if $INSTALL; then
    echo "║  Installed at: $INSTALL_DIR/$APP_NAME.app   ║"
fi
echo "╚══════════════════════════════════════════════╝"
