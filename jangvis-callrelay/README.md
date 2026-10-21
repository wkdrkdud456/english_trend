# 장비스 통화 연결 (`kr.jangvis.callrelay`)

삼성 전화 앱이 만든 **통화 녹취 텍스트**를 받아 휴대폰에서 **Dynalist HTTPS API로 직접** 전용 문서에 저장하는 Android 앱.
녹음·STT는 하지 않고, 녹음 원본은 휴대폰에 남기며 변환된 텍스트만 보낸다. PC·같은 Wi-Fi·별도 서버가 필요 없다.

- 대상: Galaxy S25 Ultra / One UI 8.5 (Android 16), minSdk 30 · targetSdk 36 · compileSdk 36
- 외부 라이브러리 없음(Android 프레임워크만 사용). 전송은 JobScheduler.

## 구조

| 클래스 | 역할 |
|---|---|
| `MainActivity` | 설정(토큰·문서), 자동 전송 ON/OFF(기본 OFF), 권한 설정 열기, 진단, 연결 시험, 상태·대기열 건수, 오류 재시도 |
| `ShareActivity` | 공유 수신(`ACTION_SEND`, `text/*`, `EXTRA_STREAM` 또는 `EXTRA_TEXT`) → SQLite 대기열에 먼저 저장 |
| `Policy` | 인코딩·크기·MIME 검사, SHA-256 항목 ID, 문서 ID 파싱, 알림 분류, 화면 라벨 규칙 (순수 Java) |
| `State` | 설정, Android Keystore AES/GCM 토큰 암호화, 진단 기록(본문 없음) |
| `Queue` | SQLite 대기열: `pending / sending / sent / error / uncertain`, 조건부 UPDATE 선점 |
| `Dynalist` | `doc/read`, `doc/edit` 호출과 `_code`·`new_node_ids` 해석 |
| `UploadJob` | 전송 작업(JobScheduler, 네트워크 조건, 재부팅 유지, 요청 제한 백오프, 배치 반복) |
| `SamsungListener` | 허용한 삼성 앱 알림만 보고 ‘텍스트 변환 완료’ 신호를 감지 |
| `SamsungAutomation` | 접근성 서비스: 더보기 → 공유 → 텍스트 파일 → 장비스 통화 연결 (라벨 정확 일치만, 좌표 없음) |
| `BootReceiver` | 재부팅·앱 업데이트 후 전송 작업 재예약 |

## 빌드

### A. 표준 Gradle (Android Studio 또는 명령줄) — 권장

JDK 21(Robolectric의 SDK 36 검사에 필요), Android SDK(platform 36)가 있는 PC에서:

```bash
cd jangvis-callrelay
./gradlew testCoreDebugUnitTest testFullDebugUnitTest lintCoreDebug lintFullDebug assembleCoreDebug assembleFullDebug
# 결과: app/build/outputs/apk/core/debug/app-core-debug.apk, app/build/outputs/apk/full/debug/app-full-debug.apk
```

AGP 8.13.0 / Gradle 8.14.3. 같은 서명으로 계속 업데이트하려면 `keystore.properties`(저장소에 올리지 않음)에
`storeFile, storePassword, keyAlias, keyPassword`를 적는다. 없으면 Android 기본 디버그 키로 서명된다.

GitHub에서는 `.github/workflows/callrelay-android.yml`이 같은 명령을 실행하고 APK와 검사 보고서를 아티팩트로 올린다.

### B. SDK 다운로드 없이 직접 빌드 (`tools/build-apk.sh`)

Google SDK 서버에 접근할 수 없는 환경용. Ubuntu 24.04 패키지와 Maven Central만 쓴다.

```bash
sudo apt-get install aapt apksigner zipalign dalvik-exchange android-sdk-platform-23 openjdk-21-jdk-headless
curl -O https://repo.maven.apache.org/maven2/org/robolectric/android-all/16-robolectric-13921718/android-all-16-robolectric-13921718.jar
COMPILE_JAR=$PWD/android-all-16-robolectric-13921718.jar FLAVOR=core tools/build-apk.sh
COMPILE_JAR=$PWD/android-all-16-robolectric-13921718.jar FLAVOR=full tools/build-apk.sh
# 결과: build/jangvis-callrelay-core.apk, build/jangvis-callrelay-full.apk (처음 실행 시 build/test-signing.p12 테스트 키 생성)

# 순수 JVM 단위 검사(Policy, Dynalist 응답 해석·HTTP)
gradle -p tools/jvm-test test -PandroidJar=$PWD/android-all-16-robolectric-13921718.jar
```

- 리소스는 aapt(1)로 API 23 리소스 표에 링크한다(앱이 쓰는 속성은 모두 API 23 이하).
- 코드는 API 36 프레임워크 jar로 컴파일하고 dx로 DEX를 만든다. dx는 람다를 변환하지 못하므로 **소스에 람다를 쓰지 않는다.**
- Robolectric 검사(Queue·UploadJob·ShareActivity)는 Google Maven의 androidx.test가 필요해 A 경로에서만 실행된다.

## 두 가지 판

| 판 | 포함 기능 | 설치 |
|---|---|---|
| **core** (`0.1.0-core`) | 공유 수신 → 대기열 → Dynalist 전송 | 파일 관리자·브라우저로 일반 설치 |
| **full** (`0.1.0-full`) | core + 삼성 완료 알림 감지·공유 자동화 | 아래 참고 |

패키지·서명이 같아 core 위에 full을 덮어 설치하면 설정·대기열이 유지된다.

**full이 'Google Play 프로텍트: 기기 보호를 위해 앱 차단됨'으로 막히는 이유**:
Play 프로텍트의 강화된 사기 방지는 브라우저·메신저·파일 관리자로 설치하는 앱이 알림 접근
(`NotificationListenerService`)이나 접근성(`AccessibilityService`)을 선언하면 설치를 막는다.
full은 자동화에 두 서비스가 꼭 필요하므로 이 방식으로는 설치할 수 없다. 이 앱에서 피할 방법은 없다.
가능한 경로(실기기에서 확인 필요):
- PC에서 USB 디버깅으로 한 번 설치: `adb install -r jangvis-callrelay-full.apk`
  (이 차단은 인터넷 사이드로드 경로 대상이라 adb 설치는 해당하지 않는 것으로 알려져 있다. Samsung '자동 차단'이 켜져 있으면 USB 명령이 막히므로 설치하는 동안만 끈다)
- 또는 Play 스토어 → 프로필 → Play 프로텍트 → 설정에서 검사를 잠시 끄고 설치한 뒤 다시 켠다(기기 정책에 따라 막힐 수 있음).

## 설치·설정

1. core APK 설치(출처를 알 수 없는 앱 허용). 테스트 서명이 다른 APK로는 덮어쓸 수 없으니 먼저 삭제 후 설치.
2. 앱 실행 → 알림 권한 허용.
3. Dynalist 웹 → Settings → Developer에서 개인 API 토큰 발급 → 앱에 입력.
4. 전용 수집 문서 URL(`https://dynalist.io/d/<문서ID>`) 또는 문서 ID 입력 → **설정 저장 · 연결 확인**.
   `#z=…`는 노드 ID라 무시한다. 연결 확인은 `doc/read`로 문서 제목과 루트 노드 ID를 보여준다.

## 동작 규칙

- **가져오기 성공**(휴대폰 대기열 저장)과 **Dynalist 전송 성공**(노드 ID 확인)을 따로 표시한다.
- 파일 최대 2 MiB, 본문 최대 200,000자. UTF-8(BOM 유무), UTF-16LE/BE(BOM) 지원. 빈 텍스트·잘못된 인코딩·초과 크기·녹음/이미지는 거부.
- 항목 ID = SHA-256(정규화한 파일명 + 본문) 앞 24자리. 같은 통화의 재공유는 중복, 다른 통화의 같은 문장은 별도 항목.
  파일명이 없는 `EXTRA_TEXT` 공유는 본문만으로 판단한다(화면에 안내).
- Dynalist 항목: 제목 `통화 · 파일명`(없으면 시각), 노트 = 원본 녹취 + 마지막 줄 `[장비스 통화 #<id>]`.
- 전송 전 항상 `doc/read`로 루트 노드를 확인하고 문서 안의 식별자를 대조한다. 이미 있으면 보내지 않는다.
- 요청 본문을 보낸 뒤 응답이 끊기면 `uncertain` → 2분 뒤 식별자로 대조한 다음에만 재전송. 5회 넘으면 멈추고 사용자 재시도를 기다린다.
- `_code`: `Ok`(+`new_node_ids` 1개 확인), `TooManyRequests`/HTTP 429 → 백오프(30초→최대 30분),
  `InvalidToken`/`Unauthorized` → 오류(설정 수정 후 재시도), `NotFound`/`NodeNotFound` → 오류, `LockFail` → 재시도.
  요청 간격은 조회 2.5초·추가 1.2초 이상으로 유지한다.
- 목적지 문서는 **수집 당시 값으로 고정**. 설정을 바꿔도 기존 항목은 원래 문서로만 간다(문서 설정 전 수집분만 처음 설정한 문서로 지정).
- 배치(20건)보다 많아도 한 번 실행에서 반복 처리하고, 시간 예산을 넘으면 즉시 다시 예약한다.
- 토큰과 녹취는 로그에 쓰지 않는다. 진단 기록에는 상태 단어만 남기고 나머지 단어는 `▢글자수`로 가린다.
  전송 완료 30일 후 휴대폰 사본의 본문을 지운다(ID는 중복 방지용으로 유지). `allowBackup=false`.

## 자동화(완료 알림 → 공유) — full 전용, 실기기 확인 필요

**먼저 core로 수동 공유가 Dynalist에 도착하는지 확인한 뒤** full을 설치해 진행한다.

1. **알림 접근 권한 설정 열기**, **접근성 권한 설정 열기**에서 ‘장비스 통화 연결’ 허용.
2. **삼성 알림 진단** 켜기 → 실제 통화 1건 녹음 → 변환 완료까지 기다린 뒤 진단 기록 확인.
   - 기록 예: `알림 com.samsung.android.dialer id=… ch=… 판정=TRANSCRIPT_DONE 문구=[통화 녹음 / 텍스트 변환 완료]`
   - **완료 알림이 아예 없거나 판정이 `TRANSCRIPT_DONE`이 아니면 자동화는 시작되지 않는다.** 이 경우 진단 문구를 알려주면
     `Policy.classify` 규칙을 실제 문구에 맞추거나, 알림이 없다면 수동 공유를 유지해야 한다
     (공개된 삼성 녹취 API나 내부 DB 접근은 가정하지 않는다).
3. 완료 알림이 알림창에 있는 상태에서 **알림 연결 시험** → 실제 녹취가 전송됨을 확인하는 대화상자 후 실행.
   - 삼성 화면이 앞으로 열리고 메뉴를 누른다. 실패하면 이유가 알림·상태에 표시되고, 진단이 켜져 있으면
     화면 구조(view ID, 클래스, 짧은 설명; 일반 텍스트 제외)가 기록된다. 이 기록으로 `Policy.*_LABELS`를 맞춘다.
4. 성공하면 **자동 전송** 켜기.

안전장치: 삼성 3개 앱(`com.samsung.android.dialer`, `com.samsung.android.app.telephonyui`, `com.sec.android.app.voicenote`)과
공유 화면 후보(`android`, `com.android.intentresolver`, `com.samsung.android.intentresolver`)에서만 동작,
다른 앱이 앞에 오면 중단, 잠금 중엔 시작하지 않고 잠금 해제(USER_PRESENT) 후 시작(잠금을 풀거나 우회하지 않음),
45초·동작 10회 상한, 진행 알림의 ‘취소’, 같은 알림의 반복 이벤트 무시(알림 키+when+문구 서명),
연속 통화는 최대 10건 순차 처리, 지워진 알림의 대기 작업은 버림, 만료된 PendingIntent는 중단 사유로 표시.
성공 후에는 녹취 화면이 남지 않도록 홈 화면으로 돌아간다.

**통화 화면 열기(실기기 확인 결과 반영)**: S25 Ultra에서 완료 알림은 `com.samsung.android.incallui`가 보내며,
제목은 '통화 녹음 완료', 본문은 '통화 녹음이 저장되고 텍스트로 변환되었습니다…'였다. 이 앱이 알림의 열기 동작을 직접 보내도
삼성 화면이 열리지 않았다(중계 방식으로 추정). 그래서 3초 안에 화면이 안 열리면 알림창을 내리고 **제목이 정확히 같은 알림 하나만**
누른다. 사람이 알림을 누르는 것과 같은 경로다. 못 찾으면 알림창을 닫고 중단한다. 같은 제목의 알림이 여러 개면 맨 위(최신) 알림을 누른다.

## 검증 체크리스트(실기기)

| 항목 | 방법 | 기대 결과 |
|---|---|---|
| 수동 공유 1건 | 삼성 통화 텍스트 → 공유 → 텍스트 파일 → 장비스 통화 연결 | ‘가져오기 성공’, 잠시 후 상태 ‘Dynalist 전송 완료’, 문서 맨 위에 항목 |
| 잘못된 토큰 | 틀린 토큰으로 저장 시도 | 저장 거부. 기존 항목은 ‘오류’ → 토큰 수정 후 ‘오류 항목 재시도’ |
| 오프라인 | 비행기 모드에서 공유 | 가져오기 성공·대기. 네트워크 복구 후 자동 전송 |
| 응답 손실 | 전송 중 비행기 모드 전환 | ‘서버 대조 필요’ → 2분 뒤 대조, 중복 없이 완료 |
| 중복 공유 | 같은 통화를 다시 공유 | ‘이미 가져온 통화’, Dynalist 항목 1개 |
| 재부팅 | 대기 항목이 있는 상태로 재부팅 | 부팅 후 전송 재개 |
| 잠금 | 잠금 상태에서 변환 완료 | 잠금 해제 후 자동화 시작 |
| 연속 통화 | 통화 2건 연속 | 두 번째 완료 알림도 처리 |
