#!/usr/bin/env bash
# Authenticator.app 번들을 빌드한다.
# 사용법: scripts/build-app.sh [debug|release]
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "▶︎ Swift 빌드 (configuration: $CONFIG)"
swift build -c "$CONFIG"

BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
BIN="$BIN_DIR/Authenticator"
if [[ ! -x "$BIN" ]]; then
    echo "✗ 실행 파일을 찾지 못함: $BIN" >&2
    exit 1
fi

APP="$ROOT/build/Authenticator.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/Authenticator"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

echo "▶︎ ad-hoc 코드 서명"
codesign --force --sign - --options=runtime "$APP" >/dev/null

echo "✓ 빌드 완료: $APP"
echo "  실행: open \"$APP\""
