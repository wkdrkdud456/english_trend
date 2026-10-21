#!/usr/bin/env bash
# Android Gradle Plugin 없이 APK를 직접 빌드·서명한다(Gradle 빌드가 기본, 이 스크립트는 SDK 서버에 접근할 수 없는 환경용).
#
# 필요 도구(Ubuntu 24.04 기준):
#   sudo apt-get install aapt apksigner zipalign dalvik-exchange android-sdk-platform-23 openjdk-21-jdk-headless
#   + API 36 컴파일용 프레임워크 jar (Maven Central: org.robolectric:android-all-instrumented:16-robolectric-13921718-i7)
#
# 사용:
#   COMPILE_JAR=/path/android-all-instrumented-16-....jar tools/build-apk.sh
# 환경 변수:
#   COMPILE_JAR  API 36 클래스 jar (javac -classpath)                [필수]
#   RES_JAR      aapt 리소스 링크용 android.jar (기본: platform 23)
#   KEYSTORE     서명 키스토어(없으면 테스트 키를 새로 만든다)      [기본: build/test-signing.p12]
#   KS_PASS      키스토어 비밀번호                                   [기본: 임의 생성 후 build/test-signing.pass에 저장]
#   OUT          결과 APK 경로                                       [기본: build/jangvis-callrelay.apk]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/app/src/main"
B="$ROOT/build/manual"
COMPILE_JAR="${COMPILE_JAR:?COMPILE_JAR(API 36 android-all jar) 경로가 필요합니다}"
RES_JAR="${RES_JAR:-/usr/lib/android-sdk/platforms/android-23/android.jar}"
KEYSTORE="${KEYSTORE:-$ROOT/build/test-signing.p12}"
OUT="${OUT:-$ROOT/build/jangvis-callrelay.apk}"
VERSION_CODE="${VERSION_CODE:-1}"
VERSION_NAME="${VERSION_NAME:-0.1.0}"
DX="$(command -v dalvik-exchange || command -v dx)"

rm -rf "$B"
mkdir -p "$B/gen" "$B/classes" "$B/dex" "$(dirname "$OUT")"

echo "[1/6] 리소스 링크 (aapt)"
# 소스 매니페스트에는 package가 없으므로(AGP namespace 사용) 직접 빌드용 사본에 넣는다.
sed 's|<manifest xmlns:android="http://schemas.android.com/apk/res/android">|<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="kr.jangvis.callrelay">|' \
  "$APP/AndroidManifest.xml" > "$B/AndroidManifest.xml"
grep -q 'package="kr.jangvis.callrelay"' "$B/AndroidManifest.xml"
aapt package -f -m \
  -J "$B/gen" \
  -M "$B/AndroidManifest.xml" \
  -S "$APP/res" \
  -I "$RES_JAR" \
  --min-sdk-version 30 --target-sdk-version 36 \
  --version-code "$VERSION_CODE" --version-name "$VERSION_NAME" \
  -0 arsc \
  -F "$B/res.apk"

echo "[2/6] 자바 컴파일 (javac --release 8, classpath=API 36)"
find "$APP/java" "$B/gen" -name '*.java' > "$B/sources.txt"
javac -encoding UTF-8 --release 8 -Xlint:-options -Xlint:deprecation \
  -classpath "$COMPILE_JAR" \
  -d "$B/classes" @"$B/sources.txt"

echo "[3/6] DEX 변환 (dx)"
"$DX" --dex --min-sdk-version=26 --output="$B/dex/classes.dex" "$B/classes"

echo "[4/6] APK 조립"
cp "$B/res.apk" "$B/unsigned.apk"
(cd "$B/dex" && aapt add -k "$B/unsigned.apk" classes.dex >/dev/null)

echo "[5/6] 정렬 (zipalign)"
zipalign -p -f 4 "$B/unsigned.apk" "$B/aligned.apk"

echo "[6/6] 서명 (apksigner, v2/v3)"
if [ ! -f "$KEYSTORE" ]; then
  KS_PASS="${KS_PASS:-$(head -c 18 /dev/urandom | base64 | tr -d '/+=')}"
  keytool -genkeypair -keystore "$KEYSTORE" -storetype PKCS12 -storepass "$KS_PASS" \
    -alias test -keyalg RSA -keysize 3072 -validity 3650 \
    -dname "CN=Jangvis Call Relay Test, O=Test, C=KR" >/dev/null 2>&1
  umask 077
  printf '%s' "$KS_PASS" > "${KEYSTORE%.p12}.pass"
  echo "  새 테스트 서명 키 생성: $KEYSTORE (비밀번호: ${KEYSTORE%.p12}.pass)"
fi
KS_PASS="${KS_PASS:-$(cat "${KEYSTORE%.p12}.pass")}"
apksigner sign --ks "$KEYSTORE" --ks-pass "pass:$KS_PASS" --ks-key-alias test \
  --min-sdk-version 30 --v1-signing-enabled false --v2-signing-enabled true --v3-signing-enabled true \
  --out "$OUT" "$B/aligned.apk"
apksigner verify --min-sdk-version 30 --verbose "$OUT" | head -6
zipalign -c -p 4 "$OUT" && echo "  정렬 확인 OK"
echo "완료: $OUT"
