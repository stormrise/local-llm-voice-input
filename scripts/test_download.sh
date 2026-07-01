#!/bin/bash
# Test script: verify model file downloads for all three sources
# Downloads a small test file (model.safetensors.index.json ~79KB) from each source

set -e

REPO_OWNER="mlx-community"
REPO_NAME="Qwen3-ASR-1.7B-5bit"
TEST_FILE="model.safetensors.index.json"  # 79KB — quick to download
TEST_DIR="/tmp/localvoice_test"
SUCCESS=0
FAIL=0

rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

echo "═══ LocalVoice Download Test ═══"
echo "Model: $REPO_OWNER/$REPO_NAME"
echo "Test file: $TEST_FILE"
echo ""

# Test 1: HuggingFace
echo "─── 1. HuggingFace ───"
URL="https://huggingface.co/$REPO_OWNER/$REPO_NAME/resolve/main/$TEST_FILE"
OUT="$TEST_DIR/hf_$TEST_FILE"
CODE=$(curl -sS -L -o "$OUT" -w "%{http_code}" --max-time 60 "$URL" 2>&1)
if [ "$CODE" = "200" ] && [ -s "$OUT" ]; then
  SIZE=$(stat -f%z "$OUT" 2>/dev/null || stat -c%s "$OUT" 2>/dev/null)
  echo "  ✅ HTTP $CODE  Size: $SIZE bytes"
  SUCCESS=$((SUCCESS + 1))
else
  echo "  ❌ HTTP $CODE"
  FAIL=$((FAIL + 1))
fi

# Test 2: ModelScope
echo "─── 2. ModelScope ───"
URL="https://modelscope.cn/models/$REPO_OWNER/$REPO_NAME/resolve/master/$TEST_FILE"
OUT="$TEST_DIR/ms_$TEST_FILE"
CODE=$(curl -sS -L -o "$OUT" -w "%{http_code}" --max-time 60 "$URL" 2>&1)
if [ "$CODE" = "200" ] && [ -s "$OUT" ]; then
  SIZE=$(stat -f%z "$OUT" 2>/dev/null)
  echo "  ✅ HTTP $CODE  Size: $SIZE bytes"
  SUCCESS=$((SUCCESS + 1))
else
  echo "  ❌ HTTP $CODE"
  FAIL=$((FAIL + 1))
fi

# Test 3: HF Mirror
echo "─── 3. HF Mirror ───"
URL="https://hf-mirror.com/$REPO_OWNER/$REPO_NAME/resolve/main/$TEST_FILE"
OUT="$TEST_DIR/mirror_$TEST_FILE"
CODE=$(curl -sS -L -o "$OUT" -w "%{http_code}" --max-time 60 "$URL" 2>&1)
if [ "$CODE" = "200" ] && [ -s "$OUT" ]; then
  SIZE=$(stat -f%z "$OUT" 2>/dev/null)
  echo "  ✅ HTTP $CODE  Size: $SIZE bytes"
  SUCCESS=$((SUCCESS + 1))
else
  echo "  ❌ HTTP $CODE"
  FAIL=$((FAIL + 1))
fi

# Test 4: Required files check (all important metadata files exist on HF)
echo ""
echo "─── 4. Required files on HuggingFace ───"
REQUIRED_FILES=("config.json" "tokenizer_config.json" "vocab.json" "merges.txt" "preprocessor_config.json")
ALL_OK=true
for f in "${REQUIRED_FILES[@]}"; do
  URL="https://huggingface.co/$REPO_OWNER/$REPO_NAME/resolve/main/$f"
  CODE=$(curl -sS -L -o /dev/null -w "%{http_code}" --max-time 30 "$URL" 2>&1)
  if [ "$CODE" != "200" ] && [ "$CODE" != "307" ]; then
    echo "  ❌ $f → HTTP $CODE"
    ALL_OK=false
  else
    echo "  ✅ $f → $CODE"
  fi
done

# Test 5: Required files on ModelScope
echo ""
echo "─── 5. Required files on ModelScope ───"
for f in "${REQUIRED_FILES[@]}"; do
  URL="https://modelscope.cn/models/$REPO_OWNER/$REPO_NAME/resolve/master/$f"
  CODE=$(curl -sS -L -o /dev/null -w "%{http_code}" --max-time 30 "$URL" 2>&1)
  if [ "$CODE" != "200" ]; then
    echo "  ❌ $f → HTTP $CODE"
    ALL_OK=false
  else
    echo "  ✅ $f → $CODE"
  fi
done

# Test 6: Required files on HF Mirror
echo ""
echo "─── 6. Required files on HF Mirror ───"
for f in "${REQUIRED_FILES[@]}"; do
  URL="https://hf-mirror.com/$REPO_OWNER/$REPO_NAME/resolve/main/$f"
  CODE=$(curl -sS -L -o /dev/null -w "%{http_code}" --max-time 30 "$URL" 2>&1)
  if [ "$CODE" != "200" ]; then
    echo "  ❌ $f → HTTP $CODE"
    ALL_OK=false
  else
    echo "  ✅ $f → $CODE"
  fi
done

# Summary
echo ""
echo "═══ Results ═══"
echo "Source downloads: $SUCCESS/3 passed, $FAIL failed"
if [ "$ALL_OK" = true ]; then
  echo "Required files: ✅ All present on all sources"
else
  echo "Required files: ❌ Some missing"
fi

# Cleanup
rm -rf "$TEST_DIR"
echo ""
exit $FAIL
