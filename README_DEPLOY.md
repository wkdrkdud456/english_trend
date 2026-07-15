# 대치앨리영어 블로그 자동화 - Streamlit 배포 가이드

## 이 앱이 하는 일
브라우저(폰/PC)로 접속해서:
1. **트렌드 스캔** — 네이버 데이터랩에서 학부모 검색 트렌드 확인
2. **카드뉴스 제작** — 후보 선택 또는 직접 키워드 입력 → 글+카드뉴스+제목+태그 자동 생성
3. **결과 받기** — ZIP 다운로드 또는 텔레그램 전송

> ⚠️ 참고: 매주 월요일 자동 스캔은 PC의 텔레그램 봇(start_bot.bat)이 담당해요.
> 이 웹앱은 "접속했을 때만" 동작하는 수동 조작용이에요. 둘은 같이 써도 충돌 없어요.

---

## 로컬에서 실행 (내 PC)

```
cd C:\Users\Master\Desktop\blog_setter\streamlit_app
pip install -r requirements.txt
playwright install chromium
streamlit run streamlit_app.py
```
→ 브라우저에 http://localhost:8501 열림

---

## 온라인 배포 (Streamlit Community Cloud, 무료)

### 1. GitHub에 올리기
1. https://github.com 가입/로그인
2. **New repository** → 이름 예: `allie-blog-app` → **⚠️ 반드시 Private 선택** → Create
3. "uploading an existing file" 링크 클릭 → 이 폴더(`streamlit_app`) 안의 파일 전부 드래그해서 업로드
   - `streamlit_app.py`, `pipeline_core.py`, `academy_profile.json`, `requirements.txt`, `packages.txt`, `assets/allie_profile.png`
   - **`.streamlit/secrets.toml`은 절대 올리지 마세요!** (API 키가 들어있음)
4. Commit changes

### 2. Streamlit Cloud에 연결
1. https://share.streamlit.io 접속 → **GitHub 계정으로 로그인**
2. **New app** → 방금 만든 repo 선택
   - Branch: `main`
   - Main file path: `streamlit_app.py`
3. **Advanced settings → Secrets** 에 아래 내용 붙여넣기
   (로컬 `.streamlit/secrets.toml` 파일 내용 그대로):

```toml
NAVER_CLIENT_ID = "..."
NAVER_CLIENT_SECRET = "..."
ANTHROPIC_API_KEY = "..."
TELEGRAM_BOT_TOKEN = "..."
TELEGRAM_CHAT_ID = "..."
```

4. **Deploy** 클릭

### 3. 첫 실행
- 첫 배포는 5~10분 걸려요 (chromium 브라우저 다운로드 포함)
- 이후 `https://<앱이름>.streamlit.app` 주소로 폰에서도 접속 가능
- 한동안 접속이 없으면 앱이 잠들어요 → 다시 접속하면 몇십 초 후 깨어남 (정상)

### 주의사항
- repo는 꼭 **Private**으로 (Public이면 학원 정보가 공개됨)
- API 키는 **Secrets에만** — 코드/repo에 직접 쓰지 않기
- 앱 URL을 아는 사람은 누구나 쓸 수 있으니 URL은 가족끼리만 공유
