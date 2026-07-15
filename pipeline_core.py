"""
대치앨리영어 블로그 자동화 - 파이프라인 코어 (Streamlit용 파이썬 포팅판)
=====================================================================
로컬 PC의 Node.js 파이프라인(Generate_slides_html.js 등)과 동일한 로직을
파이썬만으로 구현한 버전. Streamlit Cloud에는 Node.js가 없어서 필요함.

- 트렌드 스캔: 네이버 데이터랩 + 앵커 키워드("영어학원") 대비 검색량 지수
- 콘텐츠 생성: Claude API (블로그 글 → 카드뉴스 HTML → 캡션/제목/태그)
- 렌더링: Playwright(chromium)로 HTML → PNG, Pillow로 PNG → PDF
- 전송: 텔레그램 Bot API (HTTP)

API 키는 st.secrets 또는 환경변수에서 읽음 (코드에 하드코딩 금지).
"""

import base64
import json
import os
import random
import re
import statistics
import subprocess
import sys
from datetime import date, datetime, timedelta
from pathlib import Path

import requests

BASE_DIR = Path(__file__).resolve().parent
GENERATED_DIR = BASE_DIR / "generated"
PROFILE_PATH = BASE_DIR / "academy_profile.json"
PROFILE_PHOTO_PATH = BASE_DIR / "assets" / "allie_profile.png"

SLIDE_WIDTH = 1200
SLIDE_HEIGHT = 675

CLAUDE_MODEL = "claude-sonnet-4-6"
CLAUDE_URL = "https://api.anthropic.com/v1/messages"
DATALAB_URL = "https://openapi.naver.com/v1/datalab/search"


# ---------------------------------------------------------------
# 설정/시크릿
# ---------------------------------------------------------------
def get_secret(name, default=""):
    """st.secrets → 환경변수 순으로 조회"""
    try:
        import streamlit as st

        if name in st.secrets:
            return st.secrets[name]
    except Exception:
        pass
    return os.environ.get(name, default)


def load_academy_profile():
    with open(PROFILE_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


# ---------------------------------------------------------------
# 1단계: 네이버 데이터랩 트렌드 스캔
# ---------------------------------------------------------------
SEED_KEYWORDS = {
    "내신/평가": ["영어 수행평가", "영어 서술형", "중학교 내신", "영어 내신", "중학교 시험공부"],
    "입시/진학": ["고교학점제", "내신 5등급제", "외고 입시", "특목고 입시", "고입 내신"],
    "공부법/학습법": ["초등 영어 공부", "중학생 영어 공부", "영어 문법 공부", "영어 단어 외우기", "영어 독해"],
    "트렌드/시즌": ["여름방학 특강", "영어 캠프", "AI 영어 학습", "원서 읽기", "문해력"],
}
ANCHOR_KEYWORD = "영어학원"
SPIKE_THRESHOLD = 1.5
Z_THRESHOLD = 1.3
MIN_VOLUME_INDEX = 0.05
RECENT_WEEKS = 2
BATCH_SIZE = 4  # 앵커 1 + 씨앗 4 = 5그룹 (데이터랩 호출당 최대치)


def _calc_spike(ratio_data):
    if len(ratio_data) < RECENT_WEEKS + 3:
        latest = ratio_data[-1]["ratio"] if ratio_data else 0.0
        return {"score": 0.0, "z_score": 0.0, "recent_avg": latest, "baseline_avg": 0.0}

    recent = [d["ratio"] for d in ratio_data[-RECENT_WEEKS:]]
    baseline = [d["ratio"] for d in ratio_data[:-RECENT_WEEKS]]
    recent_avg = sum(recent) / len(recent)
    baseline_avg = sum(baseline) / len(baseline)
    baseline_std = statistics.pstdev(baseline) if len(baseline) > 1 else 0.0

    score = (recent_avg / baseline_avg) if baseline_avg > 0 else recent_avg
    z = ((recent_avg - baseline_avg) / baseline_std) if baseline_std > 0 else 0.0
    return {
        "score": round(score, 2),
        "z_score": round(z, 2),
        "recent_avg": round(recent_avg, 2),
        "baseline_avg": round(baseline_avg, 2),
    }


def run_trend_scan(progress_callback=None):
    """전체 씨앗 키워드 스캔. 반환: 정렬된 결과 리스트 (dict)"""
    headers = {
        "X-Naver-Client-Id": get_secret("NAVER_CLIENT_ID"),
        "X-Naver-Client-Secret": get_secret("NAVER_CLIENT_SECRET"),
        "Content-Type": "application/json",
    }
    end = date.today()
    start = end - timedelta(days=90)

    flat = [(cat, kw) for cat, kws in SEED_KEYWORDS.items() for kw in kws]
    results = []

    total_batches = (len(flat) + BATCH_SIZE - 1) // BATCH_SIZE
    for bi in range(0, len(flat), BATCH_SIZE):
        batch = flat[bi : bi + BATCH_SIZE]
        if progress_callback:
            progress_callback((bi // BATCH_SIZE) + 1, total_batches, [kw for _, kw in batch])

        groups = [{"groupName": ANCHOR_KEYWORD, "keywords": [ANCHOR_KEYWORD]}]
        groups += [{"groupName": kw, "keywords": [kw]} for _, kw in batch]
        body = {
            "startDate": start.isoformat(),
            "endDate": end.isoformat(),
            "timeUnit": "week",
            "keywordGroups": groups,
        }
        res = requests.post(DATALAB_URL, headers=headers, data=json.dumps(body), timeout=30)
        res.raise_for_status()
        group_results = res.json().get("results", [])
        if not group_results:
            continue

        anchor_ratios = [d["ratio"] for d in group_results[0].get("data", [])]
        anchor_avg = sum(anchor_ratios) / len(anchor_ratios) if anchor_ratios else 0.0

        for j, gr in enumerate(group_results[1:]):
            category, keyword = batch[j]
            stats = _calc_spike(gr.get("data", []))
            volume_index = round(stats["recent_avg"] / anchor_avg, 3) if anchor_avg > 0 else 0.0
            rising = stats["score"] >= SPIKE_THRESHOLD or stats["z_score"] >= Z_THRESHOLD
            results.append(
                {
                    "category": category,
                    "keyword": keyword,
                    "spike_score": stats["score"],
                    "z_score": stats["z_score"],
                    "volume_index": volume_index,
                    "is_spike": rising and volume_index >= MIN_VOLUME_INDEX,
                }
            )

    results.sort(
        key=lambda r: (r["is_spike"], r["volume_index"] >= MIN_VOLUME_INDEX, r["spike_score"]),
        reverse=True,
    )
    return results


# ---------------------------------------------------------------
# Claude API
# ---------------------------------------------------------------
def call_claude(system_prompt, user_prompt, max_tokens=4000):
    res = requests.post(
        CLAUDE_URL,
        headers={
            "Content-Type": "application/json",
            "x-api-key": get_secret("ANTHROPIC_API_KEY"),
            "anthropic-version": "2023-06-01",
        },
        json={
            "model": CLAUDE_MODEL,
            "max_tokens": max_tokens,
            "system": system_prompt,
            "messages": [{"role": "user", "content": user_prompt}],
        },
        timeout=300,
    )
    data = res.json()
    if "error" in data:
        raise RuntimeError(f"Claude API 에러: {data['error']}")
    return next((b["text"] for b in data["content"] if b["type"] == "text"), "")


# ---------------------------------------------------------------
# 2단계: 콘텐츠 생성 (블로그 글 → HTML → 캡션/제목/태그)
# ---------------------------------------------------------------
def _today_str():
    now = datetime.now()
    return f"{now.year}년 {now.month}월 {now.day}일"


def _blog_text_prompts(academy, keyword, context, slide_count):
    system = f"""당신은 {academy['name']}의 블로그 작가입니다.
오늘 날짜는 {_today_str()}입니다. 연도·시기를 언급할 때는 반드시 이 날짜를 기준으로 정확하게 쓰세요 (다른 연도를 지어내지 마세요).
타겟 독자는 {academy['target']} 학부모입니다.
말투: {academy['tone']}

{academy['name']} 실제 정보 (아래에서 이번 주제와 관련 있는 것만 골라서 자연스럽게 녹여 쓰세요.
전부 다 나열하지 말고, 매번 2~3개 정도만 문맥에 맞게 어필하면 됩니다):
[학원 강점]
{chr(10).join('- ' + h for h in academy.get('highlights', []))}
[실제 성과 (사실 그대로만 인용 가능, 과장 금지)]
{chr(10).join('- ' + a for a in academy.get('achievements', []))}
[프로그램]
{chr(10).join(f'- {k}: {v}' for k, v in academy.get('programs', {}).items())}
[기본 정보]
- 원장: {academy['instructor']} ({' / '.join(academy.get('instructor_career', []))})
- 위치: {academy['location']}
- 상담 문의: {academy['phone']}
- 주변 학교: {', '.join(academy.get('nearby_schools', []))}
[글쓰기 스타일 참고]
{chr(10).join('- ' + n for n in academy.get('blog_style_notes', []))}

저작권 규칙: 직접 인용은 최소화하고, 통계·사실은 출처를 자연스럽게 언급하되 문장은 반드시 새로 씁니다.
분량: 정확히 {slide_count}개 섹션 (상담 안내/연락처 슬라이드는 별도로 자동 추가되니 여기서는 만들지 마세요)."""

    user = f"""다음 소재로 학부모 대상 블로그 글을 작성해주세요.

키워드: {keyword}
배경/맥락: {context}

정확히 {slide_count}개 섹션으로 구성해주세요:
1. 타이틀/도입 (왜 이게 중요한지)
2~{slide_count - 1}. 핵심 변화/현황, 학부모가 알아야 할 이유, 우리 학원이 도와드릴 수 있는 부분 등을 나눠서 설명
{slide_count}. 마무리 요약 (상담/연락처 안내는 뒤에 별도 슬라이드로 자동 추가되니 여기선 안 써도 됩니다)

각 섹션은 카드뉴스 한 장 분량(짧고 임팩트 있게)으로 작성해주세요. 섹션은 반드시 {slide_count}개여야 합니다."""
    return system, user


def _html_prompts(academy, keyword, blog_text, slide_count):
    system = f"""당신은 카드뉴스 HTML/CSS 코드를 생성하는 전문가입니다.
다음 디자인 규칙을 반드시 지켜주세요:
- 표지에만 브랜딩 요소(로고, 페이지 번호) 배치. 브랜딩 문구는 반드시 정확히 "{academy['name']}"를 그대로 쓰세요 (영문으로 번역하거나 임의로 바꾸지 마세요)
- 이모지 대신 도형/숫자 배지 사용 (폰트 깨짐 방지)
- 정적 이미지이므로 버튼 요소 넣지 않기 (텍스트로 자연스럽게 CTA 전달)
- 주제 톤에 맞는 색감 사용
- Tailwind CSS 사용 (CDN: https://cdn.tailwindcss.com)
- 각 슬라이드는 <section class="slide-page"> 로 감싸기
- 슬라이드 크기: {SLIDE_WIDTH}x{SLIDE_HEIGHT}px (가로형 16:9 프레젠테이션 비율). 세로형(portrait)으로 만들지 마세요.
- <section class="slide-page"> 는 반드시 정확히 {slide_count}개여야 합니다 (더 많거나 적으면 안 됨)
- 가로형이므로 텍스트/요소를 좌우로 넓게 배치하고, 한 슬라이드 안에서 세로로 텍스트가 넘치지 않게 폰트 크기를 조절하세요
- 인라인 스타일/CSS는 간결하게 작성하세요 (장황한 스타일은 출력 길이를 늘려 슬라이드가 잘리는 원인이 됩니다)
- 출력은 완전한 하나의 HTML 파일만. 설명 없이 코드만 출력."""

    user = f"""아래 블로그 글 내용으로 정확히 {slide_count}장짜리 카드뉴스 HTML을 만들어주세요. (슬라이드 개수를 절대 임의로 줄이거나 늘리지 마세요. 마지막 슬라이드까지 반드시 완성하세요)
주제: {keyword}

블로그 글:
{blog_text}"""
    return system, user


def _captions_prompts(academy, keyword, blog_text, slide_count):
    schools = " ".join("#" + s + "영어" for s in academy.get("nearby_schools", [])[:4])
    captions_placeholder = ", ".join(['"슬라이드 캡션"'] * slide_count)
    system = f"""당신은 네이버 블로그 SEO에 능한 편집자입니다.
반드시 아래 JSON 형식으로만 출력하세요 (설명, 코드블록 마크다운 없이 순수 JSON만).
"captions" 배열은 반드시 정확히 {slide_count}개의 문자열이어야 합니다:
{{
  "captions": [{captions_placeholder}],
  "closing_text": "글 맨 마지막에 붙일 마무리 문단 (상담 안내 포함, 3~4문장)",
  "titles": ["제목 후보 1", "제목 후보 2", "제목 후보 3"],
  "tags": ["#태그1", "#태그2", "..."]
}}

각 필드 작성 규칙:
- captions: 1~2문장, 자연스러운 문장, 이모지 사용 금지
- titles: 네이버 블로그/카페 검색 노출용 제목 후보 3개.
  * 학부모가 실제로 검색할 핵심 키워드를 제목 맨 앞쪽에 배치
  * 25~35자 내외, 궁금증을 유발하되 낚시성 과장 금지
  * 3개 중 1개는 지역 키워드 포함 버전으로 (예: "[김포 운양동 영어] ..." 또는 "김포 학부모라면...")
- tags: 정확히 20개.
  * 주제 관련 검색 태그 10개 내외 (학부모가 검색할 법한 단어 조합)
  * 지역 태그 필수 포함: #김포영어학원 #운양동영어학원 #김포영어 #운양동영어
  * 학교 태그 2~3개: {schools} 중에서
  * 학원 태그: #{academy['name']}
  * 모든 태그는 띄어쓰기 없이 붙여 쓰기 (네이버 태그 규칙)"""

    user = f"주제: {keyword}\n\n블로그 글:\n{blog_text}"
    return system, user


def _add_watermarks(html, academy_name):
    """모든 슬라이드 우측 하단에 반투명 학원명 워터마크를 코드로 강제 삽입"""
    style = """
<style>
  .ally-watermark {
    position: absolute; bottom: 14px; right: 18px;
    font-size: 13px; font-weight: 600; letter-spacing: 0.5px;
    color: rgba(255,255,255,0.6); mix-blend-mode: difference;
    pointer-events: none; z-index: 999;
  }
</style>"""
    out = html.replace("</head>", style + "\n</head>") if "</head>" in html else style + html

    def repl(m):
        attrs = m.group(1)
        if re.search(r'style\s*=\s*"', attrs):
            attrs = re.sub(r'style\s*=\s*"', 'style="position:relative;', attrs, count=1)
        else:
            attrs = attrs + ' style="position:relative;"'
        return (
            f"<section {attrs}>\n"
            f'  <div class="ally-watermark">{academy_name}</div>'
        )

    return re.sub(r'<section\s+([^>]*\bclass="[^"]*\bslide-page\b[^"]*"[^>]*)>', repl, out)


def _closing_slide(academy):
    """마지막 '상담 안내 + 원장님 사진' 슬라이드 (사진은 base64로 직접 삽입)"""
    img_tag = ""
    if PROFILE_PHOTO_PATH.exists():
        b64 = base64.b64encode(PROFILE_PHOTO_PATH.read_bytes()).decode()
        img_tag = (
            f'<img src="data:image/png;base64,{b64}" '
            'style="height:92%; object-fit:contain; object-position:bottom;" />'
        )
    return f"""
  <section class="slide-page" style="position:relative; background:#12213f; display:flex; align-items:center; justify-content:space-between; padding:0 60px; overflow:hidden;">
    <div style="max-width:600px; color:#ffffff;">
      <div style="display:inline-block; background:rgba(255,255,255,0.14); border-radius:999px; padding:6px 18px; font-size:13px; font-weight:700; letter-spacing:1px; margin-bottom:22px;">{academy['name']}</div>
      <h2 style="font-size:32px; font-weight:800; line-height:1.45; margin-bottom:18px;">{academy['instructor']}과 함께<br/>제대로 된 방향을 잡아보세요.</h2>
      <p style="font-size:15px; line-height:1.8; color:#c9d6ee; margin-bottom:26px;">대치동·목동·서초 강남 8학군에서 10년 이상 쌓아온 노하우로,<br/>운양동에서 소수정예 관리형 수업을 진행합니다.</p>
      <div style="font-size:14px; color:#ffffff; line-height:2;">
        {academy['location']}<br/>
        상담 문의 {academy['phone']}
      </div>
    </div>
    {img_tag}
    <div class="ally-watermark">{academy['name']}</div>
  </section>"""


def generate_content(keyword, context, progress_callback=None):
    """블로그 글 + 카드뉴스 HTML + 캡션/제목/태그 생성. 반환: 출력 폴더 Path"""
    academy = load_academy_profile()
    slide_count = random.randint(5, 7)

    def report(msg):
        if progress_callback:
            progress_callback(msg)

    report(f"블로그 글 생성 중... (슬라이드 {slide_count}장 예정)")
    sys_p, usr_p = _blog_text_prompts(academy, keyword, context, slide_count)
    blog_text = call_claude(sys_p, usr_p)

    report("카드뉴스 HTML 생성 중...")
    sys_p, usr_p = _html_prompts(academy, keyword, blog_text, slide_count)
    html = call_claude(sys_p, usr_p, max_tokens=16000)
    html = re.sub(r"```html|```", "", html).strip()

    ai_slide_count = len(re.findall(r'class="[^"]*\bslide-page\b[^"]*"', html))

    # 마지막 상담 슬라이드(사진 포함) 코드로 고정 추가 + 전 슬라이드 워터마크
    closing = _closing_slide(academy)
    html = html.replace("</body>", closing + "\n</body>") if "</body>" in html else html + closing
    html = _add_watermarks(html, academy["name"])

    report("캡션 / 제목 후보 / 태그 생성 중...")
    sys_p, usr_p = _captions_prompts(academy, keyword, blog_text, slide_count)
    raw = call_claude(sys_p, usr_p)
    caption_data = json.loads(re.sub(r"```json|```", "", raw).strip())

    captions = caption_data.get("captions", [])
    while len(captions) < ai_slide_count:
        captions.append("")
    captions = captions[:ai_slide_count]
    captions.append(
        f"{academy['name']} {academy['instructor']}과 함께 방향을 잡아보세요. 상담 문의 {academy['phone']}"
    )
    caption_data["captions"] = captions

    safe_name = re.sub(r"[^\w가-힣]", "_", keyword)
    out_dir = GENERATED_DIR / safe_name
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "blog_text.txt").write_text(blog_text, encoding="utf-8")
    (out_dir / "slides.html").write_text(html, encoding="utf-8")
    (out_dir / "captions.json").write_text(
        json.dumps(caption_data, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    return out_dir


# ---------------------------------------------------------------
# 3단계: 렌더링 (Playwright HTML → PNG, Pillow PNG → PDF)
# ---------------------------------------------------------------
def ensure_chromium():
    """Playwright chromium이 없으면 설치 (Streamlit Cloud 첫 실행 대응)"""
    from playwright.sync_api import sync_playwright

    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(args=["--no-sandbox"])
            browser.close()
        return
    except Exception:
        subprocess.run(
            [sys.executable, "-m", "playwright", "install", "chromium"],
            check=True,
            capture_output=True,
        )


def render_slides(out_dir, progress_callback=None):
    """slides.html → slide1.png ~ slideN.png + 카드뉴스.pdf. 반환: PNG 경로 리스트"""
    from playwright.sync_api import sync_playwright
    from PIL import Image

    out_dir = Path(out_dir)
    html_path = out_dir / "slides.html"

    ensure_chromium()

    png_paths = []
    with sync_playwright() as p:
        browser = p.chromium.launch(args=["--no-sandbox"])
        page = browser.new_page(viewport={"width": SLIDE_WIDTH, "height": SLIDE_HEIGHT})
        page.goto(html_path.resolve().as_uri(), wait_until="networkidle")
        slides = page.query_selector_all(".slide-page")
        for i, el in enumerate(slides, start=1):
            path = out_dir / f"slide{i}.png"
            el.screenshot(path=str(path))
            png_paths.append(path)
            if progress_callback:
                progress_callback(f"slide{i}.png 저장됨 ({i}/{len(slides)})")
        browser.close()

    if png_paths:
        images = [Image.open(p).convert("RGB") for p in png_paths]
        images[0].save(
            out_dir / "카드뉴스.pdf", save_all=True, append_images=images[1:], format="PDF"
        )
    return png_paths


# ---------------------------------------------------------------
# 4단계: 텔레그램 전송 (Bot API HTTP 직접 호출)
# ---------------------------------------------------------------
def send_package_to_telegram(out_dir, progress_callback=None):
    token = get_secret("TELEGRAM_BOT_TOKEN")
    chat_id = get_secret("TELEGRAM_CHAT_ID")
    if not token or not chat_id:
        raise RuntimeError("TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID 시크릿이 없어요.")

    api = f"https://api.telegram.org/bot{token}"
    out_dir = Path(out_dir)

    with open(out_dir / "captions.json", "r", encoding="utf-8") as f:
        caption_data = json.load(f)
    captions = caption_data.get("captions", [])
    slide_files = sorted(out_dir.glob("slide*.png"), key=lambda p: int(re.search(r"\d+", p.stem).group()))

    def report(msg):
        if progress_callback:
            progress_callback(msg)

    requests.post(
        f"{api}/sendMessage",
        data={
            "chat_id": chat_id,
            "text": f"📦 완성된 카드뉴스 패키지예요 ({len(slide_files)}장)\n"
            "이미지는 저장, 캡션은 복사해서 블로그에 순서대로 붙여넣으시면 돼요.",
        },
        timeout=30,
    )

    for i, slide in enumerate(slide_files):
        caption = captions[i] if i < len(captions) else ""
        with open(slide, "rb") as img:
            requests.post(
                f"{api}/sendPhoto",
                data={"chat_id": chat_id, "caption": caption},
                files={"photo": img},
                timeout=60,
            )
        report(f"전송됨: {slide.name}")

    closing_text = caption_data.get("closing_text", "")
    if closing_text:
        requests.post(
            f"{api}/sendMessage",
            data={"chat_id": chat_id, "text": f"📝 마무리 문단 (블로그 맨 끝에 붙이기)\n\n{closing_text}"},
            timeout=30,
        )

    titles = caption_data.get("titles", [])
    if titles:
        lines = "\n".join(f"{i}. {t}" for i, t in enumerate(titles, start=1))
        requests.post(
            f"{api}/sendMessage",
            data={"chat_id": chat_id, "text": f"🏷 제목 후보 (마음에 드는 것 하나 골라서 쓰세요)\n\n{lines}"},
            timeout=30,
        )

    tags = caption_data.get("tags", [])
    if tags:
        requests.post(
            f"{api}/sendMessage",
            data={"chat_id": chat_id, "text": "#️⃣ 태그 (아래 줄 전체를 복사해서 태그란에 붙여넣기)\n\n" + " ".join(tags)},
            timeout=30,
        )

    pdf_path = out_dir / "카드뉴스.pdf"
    if pdf_path.exists():
        with open(pdf_path, "rb") as pdf:
            requests.post(
                f"{api}/sendDocument",
                data={"chat_id": chat_id},
                files={"document": ("카드뉴스.pdf", pdf)},
                timeout=120,
            )
        report("전송됨: 카드뉴스.pdf")
