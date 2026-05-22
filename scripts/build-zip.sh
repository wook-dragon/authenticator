#!/usr/bin/env bash
# 동료 배포용 zip을 만든다. .app 하나가 들어있는 단순 zip.
#
# 동료는 zip 더블클릭으로 .app 압축 해제 → .app 더블클릭 → Gatekeeper 차단 → 시스템 설정에서
# "어쨌든 열기" → 비번 → 열기 → "Applications 폴더로 옮기시겠습니까?" dialog에서 "옮기기".
# 그 뒤로는 메뉴바에서 그대로 사용.
#
# 사용법: scripts/build-zip.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

"$ROOT/scripts/build-app.sh" release

APP="$ROOT/build/OTPBar.app"
ZIP="$ROOT/build/OTPBar.app.zip"

if [[ ! -d "$APP" ]]; then
    echo "✗ .app을 찾지 못함: $APP" >&2
    exit 1
fi

rm -f "$ZIP"
# ditto -c -k 는 macOS 리소스 보존하는 표준 압축
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

SIZE=$(ls -lh "$ZIP" | awk '{print $5}')
echo "✓ 빌드 완료: $ZIP ($SIZE)"
echo "  동료에게 이 파일을 전달하세요."
