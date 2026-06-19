#!/bin/bash
set -e

# ── Configuration ────────────────────────────────────────────────
DEVICE="${1:-}"
MODEL_PATH="${2:-/tmp/sutra_models/tinyllama.gguf}"
PACKAGE="ai.sutra.app"
APP_MODELS_DIR="/data/user/0/${PACKAGE}/app_flutter/models"
LOCAL_TMP="/data/local/tmp/tinyllama.gguf"

# ── Helpers ──────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ── Device selection ─────────────────────────────────────────────
if [ -z "$DEVICE" ]; then
  DEVICE=$(flutter devices --machine 2>/dev/null | python3 -c "
import sys, json
devices = json.load(sys.stdin)
for d in devices:
    if d.get('platform') == 'android':
        print(d['id'])
        break
" 2>/dev/null || true)

  if [ -z "$DEVICE" ]; then
    error "No Android device found. Pass device ID as first argument."
  fi
fi

ADB="adb -s $DEVICE"
info "Using device: $DEVICE"

# ── Step 1: Build ────────────────────────────────────────────────
info "Building debug APK..."
cd "$(dirname "$0")"
flutter build apk --debug --no-pub 2>&1 | tail -3

APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"
if [ ! -f "$APK_PATH" ]; then
  error "Build failed — APK not found at $APK_PATH"
fi

# ── Step 2: Install ──────────────────────────────────────────────
info "Installing APK..."
$ADB install -r "$APK_PATH" 2>&1 | tail -1

# ── Step 3: Push model ──────────────────────────────────────────
if [ ! -f "$MODEL_PATH" ]; then
  error "Model not found at $MODEL_PATH. Download it first or pass the path as second argument."
fi

info "Pushing model ($(du -h "$MODEL_PATH" | cut -f1))..."
$ADB push "$MODEL_PATH" "$LOCAL_TMP" 2>&1 | tail -1

info "Copying to app directory..."
$ADB shell "run-as $PACKAGE mkdir -p $APP_MODELS_DIR" 2>&1
$ADB shell "run-as $PACKAGE sh -c \"cat $LOCAL_TMP > $APP_MODELS_DIR/tinyllama.gguf\"" 2>&1

# Verify
FILE_SIZE=$($ADB shell "run-as $PACKAGE ls -la $APP_MODELS_DIR/tinyllama.gguf" 2>&1 | awk '{print $5}')
EXPECTED_SIZE=$(stat -f%z "$MODEL_PATH" 2>/dev/null || stat --printf="%s" "$MODEL_PATH" 2>/dev/null)

if [ "$FILE_SIZE" = "$EXPECTED_SIZE" ]; then
  info "Model verified: $FILE_SIZE bytes ✓"
else
  warn "Size mismatch: device=$FILE_SIZE, local=$EXPECTED_SIZE (may still work)"
fi

# ── Step 4: Run test ────────────────────────────────────────────
info "Running integration tests..."
flutter test integration_test/model_response_test.dart -d "$DEVICE" --no-pub 2>&1

info "Done!"
