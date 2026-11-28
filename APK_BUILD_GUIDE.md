# 🎮 Match Puzzle APK 빌드 가이드

Match Puzzle 게임의 APK 파일을 만드는 방법입니다.

## 옵션 1: 온라인 빌드 서비스 (가장 간단) ⭐

### PhoneGap Build 사용 (권장)
1. https://build.phonegap.com 접속
2. GitHub 계정으로 로그인
3. `wkdrkdud456/english_trend` 리포지토리 연결
4. `MatchPuzzleApp` 폴더 선택해서 빌드
5. 5분 내에 APK 다운로드 가능

### 다른 온라인 빌드 서비스
- **Cordova Cloud Build**: https://build.cordova.io
- **AppMobi XDK**: https://www.intel.com/content/www/us/en/developer/tools/xdk/overview.html

---

## 옵션 2: 로컬 환경에서 빌드

### 필요한 것:
- JDK (Java Development Kit) ✓ 이미 설치됨
- Android SDK
- Android Build Tools
- Gradle

### 설치 단계:

```bash
# 1. MatchPuzzleApp 폴더로 이동
cd MatchPuzzleApp

# 2. 필요한 의존성 설치 (처음 한 번만)
npm install

# 3. APK 빌드 (릴리스 버전)
cordova build android --release

# 4. 완성된 APK 위치
# MatchPuzzleApp/platforms/android/app/build/outputs/apk/release/app-release.apk
```

### 서명 처리 (Play Store 배포용):
```bash
# 키스토어 생성
keytool -genkey -v -keystore match_puzzle.jks -keyalg RSA -keysize 2048 -validity 10000 -alias match_puzzle

# 빌드 프로세스가 서명키를 요청하면 위에서 생성한 match_puzzle.jks 사용
```

---

## 옵션 3: GitHub Actions로 자동 빌드

`.github/workflows/build-apk.yml` 파일을 생성해서 자동화 가능:

```yaml
name: Build APK

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Set up Node
        uses: actions/setup-node@v2
        with:
          node-version: '18'
      - name: Install dependencies
        run: |
          npm install -g cordova
          cd MatchPuzzleApp
          npm install
      - name: Build APK
        run: |
          cd MatchPuzzleApp
          cordova build android --release
      - name: Upload APK
        uses: actions/upload-artifact@v2
        with:
          name: app-release
          path: MatchPuzzleApp/platforms/android/app/build/outputs/apk/release/
```

---

## 설치 방법

### APK 파일 얻은 후:

**Android 폰에 설치:**
1. APK 파일을 Android 폰으로 전송
2. 파일 관리자에서 APK 찾기
3. 탭해서 설치
4. "알 수 없는 출처의 앱 설치" 허용 (필요시)

또는 adb 사용:
```bash
adb install app-release.apk
```

---

## 문제 해결

### "Android SDK not found" 에러
```bash
# Android SDK 설치 (Linux/Mac)
wget https://dl.google.com/android/repository/commandlinetools-linux-*.zip
unzip commandlinetools-linux-*.zip
export PATH=$PATH:$(pwd)/cmdline-tools/bin

# Android SDK 컴포넌트 설치
sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0"
```

### Gradle 에러
```bash
# Gradle 버전 업데이트
cd MatchPuzzleApp
cordova platform update android
```

---

## 게임 정보

- **앱명**: Match Puzzle
- **패키지명**: com.sohyun.matchpuzzle
- **버전**: 1.0.0
- **제작자**: Donghun
- **대상**: Sohyun (Ally, Ya) ❤️

---

**궁금한 점이 있으면 물어봐주세요!** 🎮
