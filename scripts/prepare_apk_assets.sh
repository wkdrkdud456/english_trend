#!/usr/bin/env bash
# 레포 루트의 게임 HTML을 안드로이드 assets 폴더로 복사한다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSETS="$ROOT/android/app/src/main/assets"

mkdir -p "$ASSETS"
cp "$ROOT/android/launcher/index.html" "$ASSETS/index.html"   # 게임 선택 메뉴
cp "$ROOT/index.html"                  "$ASSETS/potion.html"  # 물약 퍼즐
cp "$ROOT/shooter.html"                "$ASSETS/shooter.html"
cp "$ROOT/shooter3d.html"              "$ASSETS/shooter3d.html"
cp "$ROOT/screw.html"                  "$ASSETS/screw.html"
cp "$ROOT/screw3d.html"                "$ASSETS/screw3d.html"

echo "assets 준비 완료:"
ls -la "$ASSETS"
