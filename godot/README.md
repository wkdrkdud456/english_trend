# 가라! 동훈! — paris-journey (Godot 4, 2D)

원본 APK(`base/paris-journey-base.apk`)의 스크립트만 교체해서 다시 서명하는 방식으로 빌드한다.
Android SDK도 Godot 에디터도 필요 없다.

## 구조
- `src/*.gd` — 게임 스크립트 전부 (APK의 `assets/scripts/` 로 들어감)
  - `main.gd` 게임 상태·전투·성장·장비·펫 / `hud.gd` 모든 UI / `flat_art.gd` 2D 탐험 화면
  - `battle_art.gd`·`battle_props.gd`·`regional_battle.gd` 전투 화면 / `legacy_pixels.gd` 몬스터 픽셀아트
  - `world.gd`·`tour_world.gd` 맵 데이터(좌표·충돌) / `tour.gd`·`tour_hud.gd` 도시 미션·상점 / `city_data.gd` 10개 도시
- `tools/build.sh` — 검사 → 재패킹 → v1 서명 → 정렬 → v2 서명
- `tools/check.py`, `scope.py` — 괄호/들여쓰기, 지역변수 가림 검사 (Godot 없이 돌리는 최소 안전망)
- `mock/` — 화면을 브라우저로 미리 그려 보는 시뮬레이터 (Playwright 로 캡처)

## 빌드
```bash
# 서명키 3개를 godot/keys/ 에 둔다 (public 레포라 커밋하지 않음)
#   paris.keystore  key.pem  cert.der
bash godot/tools/build.sh godot/out/paris-journey.apk
```
**서명키가 바뀌면 기존에 설치한 앱 위에 업데이트가 안 된다**(삭제 후 재설치 → 세이브 삭제). 키 파일을 꼭 보관할 것.

## 알아둘 것
- 탐험·전투·메뉴는 전부 2D(`Control._draw`)로 그린다. 3D 씬은 기념사진/엔딩 화면에서만 보인다.
- Godot 4에서는 바깥 지역변수와 같은 이름을 안쪽 블록에서 다시 선언하면 파싱 오류 → 스크립트 로드 실패 → 흰 화면.
  `tools/scope.py` 가 이걸 잡는다. 빌드 전에 항상 통과시킬 것.
- `var exp` 같은 내장 함수 이름은 변수로 쓰지 말 것 (`exp()` 가 가려짐).
- Godot 실행 파일로 직접 검증하려면 `--headless --check-only` 를 쓸 수 있다.

## 생성 파일 (직접 고치지 말 것)
- `src/area_data.gd` ← `python3 -I tools/areas.py` (세부 구역 20곳 + 전설 자리, 검증 포함)
- `src/sprite_data.gd` ← `python3 -I tools/sprites.py [PNG 출력 폴더]` (전설 괴물 10 · 랜드마크 11)
- `audio/*.wav` ← `python3.13 -I tools/music.py` (numpy 필요. 직접 작곡한 배경음 12곡 · 효과음 14개, 빌드 때 `assets/audio/` 로 들어간다)
