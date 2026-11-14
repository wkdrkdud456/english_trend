#!/usr/bin/env bash
# paris-journey APK 빌드 — Android SDK / Godot 없이 동작한다.
#   사용법:  bash godot/tools/build.sh [출력파일명]
#   필요한 것: python3, jarsigner(JDK), 그리고 godot/keys/ 에 서명키
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$ROOT/out/paris-journey.apk}"
KEYS="$ROOT/keys"
WORK="$ROOT/.work"
# cryptography 모듈이 동작하는 파이썬을 고른다
PY=python3
for cand in python3.13 python3.12 python3; do
  if command -v $cand >/dev/null 2>&1 && $cand -I -c "from cryptography.hazmat.primitives import hashes" >/dev/null 2>&1; then PY=$cand; break; fi
done
BASE="$ROOT/base/paris-journey-base.apk"

for f in "$KEYS/paris.keystore" "$KEYS/key.pem" "$KEYS/cert.der"; do
  [ -f "$f" ] || { echo "!! 서명키가 없습니다: $f"; echo "   (public 레포라 커밋하지 않음 — 보관해 둔 paris-keys.tar.gz 를 godot/keys/ 에 풀어주세요)"; exit 1; }
done

mkdir -p "$WORK" "$(dirname "$OUT")"

echo "== 1/5 정적 검사 =="
python3 -I "$ROOT/tools/check.py" "$ROOT/src" | head -1
python3 -I "$ROOT/tools/scope.py" "$ROOT/src" | tail -1

echo "== 2/5 .gd 교체해서 재패킹 =="
rm -f "$WORK"/unsigned.apk "$WORK"/v1.apk "$WORK"/aligned.apk "$OUT"
$PY -I - "$BASE" "$ROOT/src" "$WORK/unsigned.apk" <<'PY'
import sys, zipfile, os
src, gdir, out = sys.argv[1], sys.argv[2], sys.argv[3]
zin = zipfile.ZipFile(src)
gd = {f[:-3]: open(os.path.join(gdir, f), 'rb').read() for f in os.listdir(gdir) if f.endswith('.gd')}
zo = zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED)
for it in zin.infolist():
    n = it.filename
    if n.startswith('META-INF/') and n.rsplit('.', 1)[-1] in ('SF', 'RSA', 'DSA', 'EC', 'MF'): continue
    if n.startswith('assets/scripts/') and (n.endswith('.gdc') or n.endswith('.gd.remap')): continue
    zi = zipfile.ZipInfo(n, date_time=it.date_time)
    zi.compress_type = it.compress_type; zi.external_attr = it.external_attr
    zo.writestr(zi, zin.read(n))
for b, d in sorted(gd.items()):
    zo.writestr('assets/scripts/%s.gd' % b, d)
zo.close()
PY

echo "== 3/5 v1 서명 =="
cp "$WORK/unsigned.apk" "$WORK/v1.apk"
jarsigner -keystore "$KEYS/paris.keystore" -storepass parisjourney -keypass parisjourney \
  -sigalg SHA256withRSA -digestalg SHA-256 "$WORK/v1.apk" paris 2>&1 | grep -E "^jar signed"

echo "== 4/5 zip 정렬 (resources.arsc 4바이트 정렬 — targetSdk 35 필수) =="
$PY -I "$ROOT/tools/zipalign.py" "$WORK/v1.apk" "$WORK/aligned.apk"

echo "== 5/5 v2 서명 =="
$PY -I "$ROOT/tools/v2sign.py" "$WORK/aligned.apk" "$OUT" "$KEYS/key.pem" "$KEYS/cert.der"
jarsigner -verify "$OUT" 2>&1 | grep -E "^jar verified"
echo "완료: $OUT"
