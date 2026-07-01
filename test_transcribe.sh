#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

# Build the CLI tool
echo "🔨 Building LocalVoiceCLI..."
swift build --product LocalVoiceCLI 2>&1 | tail -5

# Find the latest debug recording
DEBUG_DIR="$HOME/Library/Application Support/com.vocaltype.app/debug_recordings"
LATEST=$(ls -t "$DEBUG_DIR"/*.wav 2>/dev/null | head -1)

if [ -z "$LATEST" ]; then
    echo "No debug recordings found. Run LocalVoice.app, press Fn to record, then retry."
    exit 1
fi

echo "🔬 Testing with: $(basename "$LATEST")"
echo ""

# Run the CLI tool
BIN_PATH=$(swift build --product LocalVoiceCLI --show-bin-path 2>/dev/null)/LocalVoiceCLI
"$BIN_PATH" "$LATEST"
