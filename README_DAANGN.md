# 당근 비즈프로필 '소식' 자동 게시 - 사용 가이드

## 먼저 알아둘 것

**1. 당근에는 글 등록용 공개 API가 없어요.**
네이버처럼 "API로 글 올리기"가 안 되기 때문에, Playwright(크롬 자동조작)로
당근 비즈니스 웹을 사람 대신 클릭하는 방식입니다.

**2. 올라가는 곳은 '비즈프로필 소식'입니다.**
학원 홍보를 동네생활이나 중고거래에 올리면 신고·삭제 대상이에요.
사업자용 채널인 비즈프로필의 **소식** 기능이 정상 경로이고 무료입니다.
아직 비즈프로필이 없다면 당근 앱에서 먼저 만들어주세요.

**3. 도배는 계정 정지로 이어집니다.**
당근은 매크로·도배를 명시적으로 금지하고, 심한 경우 영구정지 후 해제도 안 해줍니다.
그래서 이 도구는 **하루 1건 / 최소 20시간 간격**을 코드로 강제합니다.
주 1~2회 정도가 안전하고, 실제로도 그 정도가 반응이 제일 좋습니다.

**4. 집 PC에서 실행해야 합니다.**
Streamlit Cloud에서는 앱이 잠들 때 로그인 세션 파일이 날아가고,
데이터센터 IP라 로그인이 막힐 가능성이 높아요.

---

## 처음 한 번만: QR 로그인

당근 로그인은 폰으로 QR을 스캔하는 방식이라 완전 무인 로그인이 불가능합니다.
대신 **한 번 로그인해두면 그 세션(쿠키)을 저장**해서 이후로는 자동으로 씁니다.

```
cd C:\Users\Master\Desktop\blog_setter\streamlit_app
pip install -r requirements.txt
playwright install chromium
python daangn_poster.py login
```

크롬 창이 열리면 폰 당근 앱으로 QR을 스캔해 로그인하세요.
로그인이 확인되면 `.daangn/session_state.json` 에 세션이 저장되고 창이 닫힙니다.

세션이 살아있는지 확인:

```
python daangn_poster.py status
```

> 세션은 영구적이지 않아요. 몇 주 뒤 만료되면 `login`을 다시 실행하면 됩니다.
> `.daangn/` 폴더는 `.gitignore`에 들어있어서 GitHub에 올라가지 않습니다.

---

## 게시하기 (웹앱)

`streamlit run streamlit_app.py` → **🥕 당근 소식** 탭

1. **당근 로그인** — 세션 상태 확인, 필요하면 QR 로그인 버튼
2. **소식 문구** — 만들어둔 결과 폴더를 고르고 "당근용 문구 생성"
   블로그 글을 당근 소식 톤(300~550자, 동네 이웃에게 말 걸듯)으로 다시 씁니다.
   생성된 제목·본문·해시태그는 그 자리에서 수정하고 저장할 수 있어요.
3. **첨부 이미지** — 카드뉴스 중 올릴 것만 선택 (최대 10장)
4. **게시** — 발행 방식 선택 후 "당근에 올리기"

**발행 방식 두 가지**

| | 확인 모드 (기본) | 완전 자동 |
|---|---|---|
| 브라우저 | 눈에 보이게 열림 | 백그라운드 |
| 발행 버튼 | 내가 직접 누름 | 자동 클릭 |
| 추천 | 처음 몇 번 | 익숙해진 뒤 |

처음에는 **확인 모드**로 몇 번 돌려서 내용이 제대로 들어가는지 눈으로 보세요.
확인 모드는 내용을 다 채운 뒤 최대 5분간 기다리며, 발행이 감지되면 기록에 남깁니다.

---

## 게시하기 (터미널)

```
# 문구만 미리 만들어보기
python daangn_poster.py generate --keyword "중2 서술형 대비" --dir generated/중2_서술형_대비

# 확인 모드로 게시 (브라우저 열림, 발행은 직접)
python daangn_poster.py post --dir generated/중2_서술형_대비

# 완전 자동 발행
python daangn_poster.py post --dir generated/중2_서술형_대비 --auto

# 하루 1건 제한을 무시 (꼭 필요할 때만)
python daangn_poster.py post --dir generated/중2_서술형_대비 --auto --force
```

---

## 자동 게시가 실패할 때

당근이 페이지 구조를 바꾸면 "본문 입력칸을 못 찾았어요" 같은 오류가 납니다.
코드를 고치지 않고 설정 파일로 대응할 수 있어요.

**1) 실제 페이지 구조 덤프**

```
python daangn_poster.py probe
```

`.daangn/probe_*.json` 에 입력칸·버튼 목록이, `probe_*.png` 에 화면이 저장됩니다.

**2) 셀렉터 수정**

```
copy daangn_selectors.example.json daangn_selectors.json
```

덤프에서 본 실제 `placeholder`/버튼 글자에 맞춰 값을 고칩니다.
예를 들어 본문칸의 placeholder가 "우리 동네에 알려요"였다면:

```json
"body_input": ["textarea[placeholder*='우리 동네']", "div[contenteditable='true']"]
```

각 항목은 후보 목록이라 위에서부터 차례로 시도합니다. 확실한 걸 맨 위에 두세요.

---

## 파일 설명

| 파일 | 역할 |
|---|---|
| `daangn_poster.py` | 로그인·문구생성·게시 전체 로직 + CLI |
| `daangn_selectors.example.json` | 셀렉터 설정 템플릿 (복사해서 `daangn_selectors.json`으로 사용) |
| `.daangn/session_state.json` | 저장된 로그인 세션 (git 제외) |
| `.daangn/post_history.json` | 게시 기록 — 하루 1건 제한 판정에 사용 (git 제외) |
| `generated/<키워드>/daangn_post.json` | 생성된 당근 소식 문구 |
