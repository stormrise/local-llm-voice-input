#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
swift test 2>&1
