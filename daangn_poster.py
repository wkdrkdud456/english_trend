"""
당근 비즈프로필 '소식' 자동 게시 모듈
=====================================
블로그 자동화로 만든 글/카드뉴스를 당근 비즈프로필 '소식'으로 올립니다.

동작 방식
---------
당근은 글 등록용 공개 API가 없습니다. 그래서 Playwright(chromium)로 당근 비즈니스
웹(business.daangn.com)을 사람 대신 조작합니다. 로그인은 폰 QR 스캔 방식이라
무인 로그인이 불가능하므로, **최초 1회만 사람이 QR로 로그인**하고 그때 만들어진
세션(쿠키)을 파일로 저장해 이후 자동 게시에 재사용합니다.

  1) python daangn_poster.py login   → 창이 열리면 폰으로 QR 스캔해서 로그인
  2) python daangn_poster.py post --dir generated/키워드   → 자동 게시

안전장치
--------
- 하루 1건 / 최소 20시간 간격 (당근은 도배·매크로를 제재합니다. 계정 영구정지 사례 있음)
- 기본값은 '확인 모드': 브라우저를 눈에 보이게 띄우고 내용만 채운 뒤 사람이 발행 버튼을
  누르게 합니다. 완전 자동 발행은 auto_submit=True 를 명시해야만 동작합니다.
- 세션 파일과 게시 기록은 .daangn/ 에 저장되며 git에 올라가지 않습니다.

셀렉터
------
당근 페이지 구조가 바뀌면 daangn_selectors.json 을 고쳐서 대응할 수 있습니다.
구조를 모를 때는 `python daangn_poster.py probe` 로 실제 페이지의 입력칸/버튼 목록을
덤프해서 확인하세요.
"""

import json
import random
import re
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path

import pipeline_core as core

BASE_DIR = Path(__file__).resolve().parent
DAANGN_DIR = BASE_DIR / ".daangn"
STATE_PATH = DAANGN_DIR / "session_state.json"
HISTORY_PATH = DAANGN_DIR / "post_history.json"
SELECTORS_PATH = BASE_DIR / "daangn_selectors.json"

# 당근 운영정책상 도배는 제재 대상. 사람이 올리는 것과 비슷한 빈도를 강제한다.
MAX_POSTS_PER_DAY = 1
MIN_HOURS_BETWEEN_POSTS = 20
MAX_IMAGES = 10
SESSION_WARN_DAYS = 21  # 이 정도 지나면 세션 만료 가능성 안내

DEFAULT_SELECTORS = {
    "urls": {
        "home": "https://business.daangn.com/",
        "post_write": "https://business.daangn.com/business-profile/posts/new",
    },
    # 로그인 상태를 판별하는 표식 (하나라도 보이면 로그인된 것으로 간주)
    "logged_in": [
        "a[href*='/business-profile']",
        "button:has-text('소식')",
        "a:has-text('소식')",
        "text=비즈프로필 관리",
    ],
    # 로그아웃 상태 표식
    "logged_out": [
        "button:has-text('로그인')",
        "a:has-text('로그인')",
        "text=QR",
    ],
    # 소식 작성 화면으로 들어가는 버튼 (post_write URL이 안 먹을 때 대체 경로)
    "write_entry": [
        "button:has-text('소식 쓰기')",
        "button:has-text('소식 작성')",
        "a:has-text('소식 쓰기')",
        "button:has-text('새 소식')",
        "[role=button]:has-text('소식')",
    ],
    # 제목 입력칸 (당근 소식은 제목칸이 없을 수도 있음 → 없으면 본문 첫 줄로 합침)
    "title_input": [
        "input[placeholder*='제목']",
        "textarea[placeholder*='제목']",
        "input[name='title']",
    ],
    # 본문 입력칸
    "body_input": [
        "textarea[placeholder*='내용']",
        "textarea[placeholder*='소식']",
        "textarea[name='content']",
        "div[contenteditable='true']",
        "textarea",
    ],
    "image_input": [
        "input[type='file'][accept*='image']",
        "input[type='file']",
    ],
    "submit": [
        "button:has-text('등록')",
        "button:has-text('발행')",
        "button:has-text('게시')",
        "button:has-text('올리기')",
        "button[type='submit']",
    ],
    # 발행 성공 판별 표식
    "posted": [
        "text=소식이 등록",
        "text=등록되었",
        "text=게시되었",
    ],
}


# ---------------------------------------------------------------
# 설정 / 기록
# ---------------------------------------------------------------
def load_selectors():
    """기본 셀렉터에 daangn_selectors.json 내용을 덮어씌워 반환"""
    sel = json.loads(json.dumps(DEFAULT_SELECTORS))  # deep copy
    if SELECTORS_PATH.exists():
        try:
            user_sel = json.loads(SELECTORS_PATH.read_text(encoding="utf-8"))
        except json.JSONDecodeError as e:
            raise RuntimeError(f"daangn_selectors.json 형식이 잘못됐어요: {e}")
        for key, value in user_sel.items():
            if isinstance(value, dict) and isinstance(sel.get(key), dict):
                sel[key].update(value)
            else:
                sel[key] = value
    return sel


def _load_history():
    if not HISTORY_PATH.exists():
        return []
    try:
        return json.loads(HISTORY_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return []


def _save_history(history):
    DAANGN_DIR.mkdir(parents=True, exist_ok=True)
    HISTORY_PATH.write_text(
        json.dumps(history[-100:], ensure_ascii=False, indent=2), encoding="utf-8"
    )


def load_history():
    """게시 기록 (최신이 뒤). UI에서 표로 보여줄 때 사용"""
    return _load_history()


def record_post(title, keyword="", url=""):
    history = _load_history()
    history.append(
        {
            "at": datetime.now().isoformat(timespec="seconds"),
            "title": title,
            "keyword": keyword,
            "url": url,
        }
    )
    _save_history(history)


def check_rate_limit():
    """도배 방지. 반환: (게시 가능 여부, 사유 문구)"""
    history = _load_history()
    if not history:
        return True, ""

    now = datetime.now()
    recent = []
    for item in history:
        try:
            recent.append(datetime.fromisoformat(item["at"]))
        except (KeyError, ValueError):
            continue
    if not recent:
        return True, ""

    today_count = sum(1 for t in recent if t.date() == now.date())
    if today_count >= MAX_POSTS_PER_DAY:
        return False, f"오늘 이미 {today_count}건 올렸어요. 당근 도배 제재를 피하려고 하루 {MAX_POSTS_PER_DAY}건으로 제한합니다."

    last = max(recent)
    gap = now - last
    if gap < timedelta(hours=MIN_HOURS_BETWEEN_POSTS):
        left = timedelta(hours=MIN_HOURS_BETWEEN_POSTS) - gap
        hours = int(left.total_seconds() // 3600)
        minutes = int((left.total_seconds() % 3600) // 60)
        return False, f"마지막 게시 후 {MIN_HOURS_BETWEEN_POSTS}시간이 지나야 해요. {hours}시간 {minutes}분 남았습니다."

    return True, ""


def session_status():
    """세션 파일 상태. 반환: dict(exists, age_days, stale, path)"""
    if not STATE_PATH.exists():
        return {"exists": False, "age_days": None, "stale": True, "path": str(STATE_PATH)}
    age = datetime.now() - datetime.fromtimestamp(STATE_PATH.stat().st_mtime)
    age_days = age.days
    return {
        "exists": True,
        "age_days": age_days,
        "stale": age_days >= SESSION_WARN_DAYS,
        "path": str(STATE_PATH),
    }


# ---------------------------------------------------------------
# 브라우저 헬퍼
# ---------------------------------------------------------------
def _pause(low=0.6, high=1.8):
    """사람처럼 보이도록 동작 사이에 약간 쉬기"""
    time.sleep(random.uniform(low, high))


def _new_context(playwright, headless=True, use_session=True):
    browser = playwright.chromium.launch(headless=headless, args=["--no-sandbox"])
    kwargs = {
        "locale": "ko-KR",
        "timezone_id": "Asia/Seoul",
        "viewport": {"width": 1280, "height": 900},
    }
    if use_session and STATE_PATH.exists():
        kwargs["storage_state"] = str(STATE_PATH)
    context = browser.new_context(**kwargs)
    context.set_default_timeout(15000)
    return browser, context


def _first_visible(page, candidates, timeout=4000):
    """후보 셀렉터를 순서대로 시도해서 처음 보이는 요소를 반환 (없으면 None)"""
    for sel in candidates:
        try:
            locator = page.locator(sel).first
            locator.wait_for(state="visible", timeout=timeout)
            return locator
        except Exception:
            continue
    return None


def _any_present(page, candidates, timeout=2000):
    return _first_visible(page, candidates, timeout=timeout) is not None


def _fill_field(locator, text):
    """input/textarea는 fill, contenteditable은 클릭 후 타이핑"""
    tag = (locator.evaluate("el => el.tagName") or "").lower()
    if tag in ("input", "textarea"):
        locator.fill(text)
    else:
        locator.click()
        locator.evaluate("el => { el.innerHTML = '' }")
        locator.type(text, delay=8)


def _is_logged_in(page, sel):
    if _any_present(page, sel["logged_in"], timeout=3000):
        return True
    if _any_present(page, sel["logged_out"], timeout=1500):
        return False
    # 표식을 못 찾으면 로그인 페이지로 튕겼는지 URL로 판단
    return "login" not in page.url.lower()


# ---------------------------------------------------------------
# 1단계: 최초 로그인 (사람이 QR 스캔) → 세션 저장
# ---------------------------------------------------------------
def login_and_save_session(timeout_minutes=5, progress_callback=None):
    """브라우저를 띄워 사람이 QR 로그인하게 하고, 끝나면 세션을 파일로 저장한다."""
    from playwright.sync_api import sync_playwright

    def report(msg):
        if progress_callback:
            progress_callback(msg)
        else:
            print(msg, flush=True)

    sel = load_selectors()
    core.ensure_chromium()
    DAANGN_DIR.mkdir(parents=True, exist_ok=True)

    with sync_playwright() as p:
        browser, context = _new_context(p, headless=False, use_session=False)
        page = context.new_page()
        page.goto(sel["urls"]["home"], wait_until="domcontentloaded")

        report("브라우저 창이 열렸어요. 당근 비즈니스에 폰으로 QR 로그인해주세요.")
        report(f"최대 {timeout_minutes}분 기다립니다. 로그인되면 자동으로 저장돼요.")

        deadline = time.time() + timeout_minutes * 60
        logged_in = False
        while time.time() < deadline:
            try:
                if _is_logged_in(page, sel):
                    logged_in = True
                    break
            except Exception:
                pass  # 페이지 전환 중이면 다음 루프에서 다시 확인
            time.sleep(2)

        if not logged_in:
            browser.close()
            raise RuntimeError(
                f"{timeout_minutes}분 안에 로그인이 확인되지 않았어요. 다시 시도해주세요."
            )

        _pause()
        context.storage_state(path=str(STATE_PATH))
        browser.close()

    report(f"로그인 세션을 저장했어요: {STATE_PATH}")
    return STATE_PATH


def verify_session(progress_callback=None):
    """저장된 세션으로 실제 로그인이 유지되는지 확인. 반환: (bool, 메시지)"""
    from playwright.sync_api import sync_playwright

    if not STATE_PATH.exists():
        return False, "저장된 세션이 없어요. 먼저 로그인해주세요."

    sel = load_selectors()
    core.ensure_chromium()
    with sync_playwright() as p:
        browser, context = _new_context(p, headless=True)
        page = context.new_page()
        try:
            page.goto(sel["urls"]["home"], wait_until="domcontentloaded")
            ok = _is_logged_in(page, sel)
        except Exception as e:
            browser.close()
            return False, f"확인 중 오류: {e}"
        browser.close()

    if ok:
        return True, "세션이 살아있어요. 바로 게시할 수 있습니다."
    return False, "세션이 만료됐어요. `python daangn_poster.py login` 으로 다시 로그인해주세요."


# ---------------------------------------------------------------
# 2단계: 소식 문구 생성 (블로그 글 → 당근 소식 톤으로 재구성)
# ---------------------------------------------------------------
def _daangn_prompts(academy, keyword, blog_text):
    system = f"""당신은 {academy['name']}의 당근 비즈프로필 '소식'을 쓰는 담당자입니다.
오늘 날짜는 {core._today_str()}입니다. 연도·시기는 반드시 이 날짜 기준으로 정확하게 쓰세요.
말투: {academy['tone']}

당근 소식은 블로그 글과 성격이 다릅니다. 반드시 아래를 지키세요:
- 동네 이웃에게 말 거는 느낌. 광고 문구처럼 딱딱하면 안 됩니다.
- 본문 300~550자. 길면 아무도 안 읽습니다.
- 짧은 문단 3~4개로 나누고 문단 사이는 빈 줄로 띄웁니다.
- 이모지는 문단 시작에 1개 정도만. 남발 금지.
- 과장·단정 표현 금지 ("무조건", "1등", "보장" 등). 실제 성과만 사실 그대로 인용.
- 마지막 문단에 위치와 상담 연락처를 자연스럽게 넣습니다.
- 해시태그는 본문에 섞지 말고 따로 5~8개.

{academy['name']} 정보 (이번 주제와 관련된 것만 1~2개 골라 쓰세요. 전부 나열 금지):
[강점]
{chr(10).join('- ' + h for h in academy.get('highlights', []))}
[실제 성과 (사실 그대로만, 과장 금지)]
{chr(10).join('- ' + a for a in academy.get('achievements', []))}
[기본 정보]
- 원장: {academy['instructor']}
- 위치: {academy['location']}
- 상담 문의: {academy['phone']}
- 타겟: {academy['target']}
- 주변 학교: {', '.join(academy.get('nearby_schools', []))}

출력은 아래 JSON만. 설명·코드블록 없이 JSON만 출력하세요.
{{"title": "소식 제목 (25자 이내)", "body": "본문", "hashtags": ["#태그1", "#태그2"]}}"""

    source = f"\n\n[참고할 블로그 원문]\n{blog_text[:3000]}" if blog_text else ""
    user = f"""다음 소재로 당근 비즈프로필 소식을 써주세요.

키워드: {keyword}

블로그 원문이 있다면 그 내용을 요약·재구성하되, 문장은 당근 소식 톤으로 새로 쓰세요.
원문을 그대로 잘라 붙이지 마세요.{source}"""
    return system, user


def generate_daangn_post(keyword, blog_text=None, out_dir=None, progress_callback=None):
    """당근 소식용 제목/본문/해시태그 생성. out_dir을 주면 daangn_post.json으로 저장."""
    academy = core.load_academy_profile()

    if progress_callback:
        progress_callback("당근 소식 문구 생성 중...")

    if blog_text is None and out_dir:
        blog_file = Path(out_dir) / "blog_text.txt"
        if blog_file.exists():
            blog_text = blog_file.read_text(encoding="utf-8")

    sys_p, usr_p = _daangn_prompts(academy, keyword, blog_text)
    raw = core.call_claude(sys_p, usr_p, max_tokens=2000)
    cleaned = re.sub(r"```json|```", "", raw).strip()
    try:
        data = json.loads(cleaned)
    except json.JSONDecodeError as e:
        raise RuntimeError(f"소식 문구 JSON 파싱 실패: {e}\n받은 내용: {cleaned[:300]}")

    data.setdefault("title", keyword)
    data.setdefault("body", "")
    data.setdefault("hashtags", [])
    data["keyword"] = keyword

    if out_dir:
        out_path = Path(out_dir) / "daangn_post.json"
        out_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    return data


def load_daangn_post(out_dir):
    path = Path(out_dir) / "daangn_post.json"
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def save_daangn_post(out_dir, data):
    path = Path(out_dir) / "daangn_post.json"
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    return path


def compose_body(data):
    """본문 + 해시태그를 실제 올릴 한 덩어리 텍스트로 합치기"""
    body = (data.get("body") or "").strip()
    tags = data.get("hashtags") or []
    if tags:
        body = body + "\n\n" + " ".join(tags)
    return body


# ---------------------------------------------------------------
# 3단계: 소식 게시
# ---------------------------------------------------------------
def _open_write_page(page, sel, report):
    """소식 작성 화면으로 이동. URL이 안 먹으면 버튼을 눌러서 들어간다."""
    write_url = sel["urls"].get("post_write")
    if write_url:
        try:
            page.goto(write_url, wait_until="domcontentloaded")
            _pause()
            if _any_present(page, sel["body_input"], timeout=5000):
                return True
        except Exception as e:
            report(f"작성 URL 직접 이동 실패 ({e}). 버튼으로 시도할게요.")

    report("소식 쓰기 버튼을 찾는 중...")
    page.goto(sel["urls"]["home"], wait_until="domcontentloaded")
    _pause()
    entry = _first_visible(page, sel["write_entry"], timeout=6000)
    if entry:
        entry.click()
        _pause(1.0, 2.2)
    return _any_present(page, sel["body_input"], timeout=6000)


def post_news(
    title,
    body,
    image_paths=(),
    auto_submit=False,
    headless=None,
    confirm_wait_minutes=5,
    force=False,
    keyword="",
    progress_callback=None,
):
    """당근 비즈프로필에 소식을 올린다.

    auto_submit=False (기본): 브라우저를 띄워 내용만 채우고, 발행 버튼은 사람이 누름.
    auto_submit=True: 발행까지 자동. headless 기본값도 True가 된다.

    반환: dict(submitted, mode, url, screenshot, warnings)
    """
    from playwright.sync_api import sync_playwright

    def report(msg):
        if progress_callback:
            progress_callback(msg)
        else:
            print(msg, flush=True)

    body = (body or "").strip()
    if not body:
        raise ValueError("본문이 비어 있어요.")

    ok, reason = check_rate_limit()
    if not ok and not force:
        raise RuntimeError(reason)
    if not ok:
        report(f"[경고] 빈도 제한을 무시하고 진행합니다: {reason}")

    if not STATE_PATH.exists():
        raise RuntimeError(
            "저장된 로그인 세션이 없어요. 먼저 `python daangn_poster.py login` 으로 QR 로그인해주세요."
        )

    if headless is None:
        headless = bool(auto_submit)

    sel = load_selectors()
    core.ensure_chromium()
    DAANGN_DIR.mkdir(parents=True, exist_ok=True)

    images = [str(Path(p).resolve()) for p in list(image_paths)[:MAX_IMAGES]]
    warnings = []
    result = {"submitted": False, "mode": "auto" if auto_submit else "confirm",
              "url": "", "screenshot": "", "warnings": warnings}

    with sync_playwright() as p:
        browser, context = _new_context(p, headless=headless)
        page = context.new_page()
        try:
            page.goto(sel["urls"]["home"], wait_until="domcontentloaded")
            _pause()
            if not _is_logged_in(page, sel):
                raise RuntimeError(
                    "세션이 만료됐어요. `python daangn_poster.py login` 으로 다시 로그인해주세요."
                )

            report("소식 작성 화면 여는 중...")
            if not _open_write_page(page, sel, report):
                raise RuntimeError(
                    "소식 작성 화면의 본문 입력칸을 못 찾았어요.\n"
                    "`python daangn_poster.py probe` 로 실제 페이지 구조를 덤프한 뒤 "
                    "daangn_selectors.json 을 수정해주세요."
                )

            full_body = body
            title_field = _first_visible(page, sel["title_input"], timeout=2500)
            if title_field and title:
                report("제목 입력 중...")
                _fill_field(title_field, title)
                _pause()
            elif title:
                # 당근 소식에 제목칸이 없는 화면이면 본문 첫 줄로 넣는다
                full_body = f"{title}\n\n{body}"
                warnings.append("제목 입력칸이 없어서 제목을 본문 첫 줄로 넣었어요.")

            report("본문 입력 중...")
            body_field = _first_visible(page, sel["body_input"], timeout=5000)
            _fill_field(body_field, full_body)
            _pause()

            if images:
                report(f"이미지 {len(images)}장 업로드 중...")
                file_input = None
                for candidate in sel["image_input"]:
                    try:
                        file_input = page.locator(candidate).first
                        file_input.wait_for(state="attached", timeout=4000)
                        break
                    except Exception:
                        file_input = None
                if file_input is None:
                    warnings.append("이미지 업로드 칸을 못 찾아서 글만 올립니다.")
                else:
                    file_input.set_input_files(images)
                    _pause(2.0, 4.0)  # 업로드 완료 대기

            shot = DAANGN_DIR / f"preview_{datetime.now():%Y%m%d_%H%M%S}.png"
            page.screenshot(path=str(shot), full_page=True)
            result["screenshot"] = str(shot)

            if auto_submit:
                report("발행 버튼 클릭...")
                submit = _first_visible(page, sel["submit"], timeout=6000)
                if submit is None:
                    raise RuntimeError(
                        "발행 버튼을 못 찾았어요. daangn_selectors.json 의 submit 항목을 확인해주세요.\n"
                        f"화면 스크린샷: {shot}"
                    )
                submit.click()
                _pause(2.5, 4.0)
                posted = _any_present(page, sel["posted"], timeout=8000) or "new" not in page.url
                result["submitted"] = bool(posted)
                result["url"] = page.url
                if posted:
                    report("발행 완료!")
                    record_post(title, keyword=keyword, url=page.url)
                else:
                    warnings.append("발행 버튼은 눌렀는데 완료 표시를 못 봤어요. 당근 앱에서 확인해주세요.")
            else:
                report(
                    f"내용을 다 채웠어요. 열린 브라우저 창에서 확인하고 발행 버튼을 눌러주세요. "
                    f"(최대 {confirm_wait_minutes}분 대기)"
                )
                deadline = time.time() + confirm_wait_minutes * 60
                start_url = page.url
                while time.time() < deadline:
                    try:
                        if _any_present(page, sel["posted"], timeout=1000) or page.url != start_url:
                            result["submitted"] = True
                            result["url"] = page.url
                            record_post(title, keyword=keyword, url=page.url)
                            report("발행이 확인됐어요!")
                            break
                    except Exception:
                        break  # 사람이 창을 닫은 경우
                    time.sleep(2)
                if not result["submitted"]:
                    warnings.append(
                        "대기 시간 안에 발행이 확인되지 않았어요. 직접 발행하셨다면 무시해도 됩니다."
                    )
        finally:
            try:
                browser.close()
            except Exception:
                pass

    return result


# ---------------------------------------------------------------
# 진단: 실제 페이지 구조 덤프 (셀렉터가 안 맞을 때)
# ---------------------------------------------------------------
def probe(url=None, headless=False, progress_callback=None):
    """소식 작성 페이지의 입력칸/버튼 목록과 HTML을 .daangn/probe_* 로 저장한다."""
    from playwright.sync_api import sync_playwright

    def report(msg):
        if progress_callback:
            progress_callback(msg)
        else:
            print(msg, flush=True)

    sel = load_selectors()
    core.ensure_chromium()
    DAANGN_DIR.mkdir(parents=True, exist_ok=True)
    target = url or sel["urls"].get("post_write") or sel["urls"]["home"]

    with sync_playwright() as p:
        browser, context = _new_context(p, headless=headless)
        page = context.new_page()
        page.goto(target, wait_until="domcontentloaded")
        _pause(2.0, 3.0)

        info = page.evaluate(
            """() => {
              const grab = (nodes) => Array.from(nodes).slice(0, 60).map(el => ({
                tag: el.tagName.toLowerCase(),
                type: el.getAttribute('type') || '',
                name: el.getAttribute('name') || '',
                id: el.id || '',
                cls: (el.getAttribute('class') || '').slice(0, 120),
                placeholder: el.getAttribute('placeholder') || '',
                ariaLabel: el.getAttribute('aria-label') || '',
                text: (el.innerText || '').trim().slice(0, 60),
              }));
              return {
                url: location.href,
                title: document.title,
                inputs: grab(document.querySelectorAll('input, textarea, [contenteditable="true"]')),
                buttons: grab(document.querySelectorAll('button, [role="button"], a[href]')),
              };
            }"""
        )

        stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        json_path = DAANGN_DIR / f"probe_{stamp}.json"
        html_path = DAANGN_DIR / f"probe_{stamp}.html"
        shot_path = DAANGN_DIR / f"probe_{stamp}.png"
        json_path.write_text(json.dumps(info, ensure_ascii=False, indent=2), encoding="utf-8")
        html_path.write_text(page.content(), encoding="utf-8")
        page.screenshot(path=str(shot_path), full_page=True)
        browser.close()

    report(f"덤프 저장: {json_path}")
    report(f"HTML: {html_path}")
    report(f"스크린샷: {shot_path}")
    return {"json": str(json_path), "html": str(html_path), "screenshot": str(shot_path)}


# ---------------------------------------------------------------
# CLI
# ---------------------------------------------------------------
def _cli():
    args = sys.argv[1:]
    cmd = args[0] if args else "status"

    def opt(flag, default=None):
        return args[args.index(flag) + 1] if flag in args and args.index(flag) + 1 < len(args) else default

    if cmd == "login":
        login_and_save_session(timeout_minutes=int(opt("--timeout", 5)))
        return

    if cmd == "status":
        s = session_status()
        if not s["exists"]:
            print("세션 없음. `python daangn_poster.py login` 을 먼저 실행하세요.")
        else:
            print(f"세션 파일: {s['path']} ({s['age_days']}일 전 저장)")
            ok, msg = verify_session()
            print(("OK: " if ok else "만료: ") + msg)
        ok, reason = check_rate_limit()
        print("게시 가능" if ok else f"게시 제한: {reason}")
        return

    if cmd == "probe":
        probe(url=opt("--url"), headless="--headless" in args)
        return

    if cmd == "generate":
        keyword = opt("--keyword") or opt("--kw")
        out_dir = opt("--dir")
        if not keyword and out_dir:
            keyword = Path(out_dir).name
        if not keyword:
            print("사용법: python daangn_poster.py generate --keyword '중2 서술형' [--dir generated/xxx]")
            return
        data = generate_daangn_post(keyword, out_dir=out_dir)
        print(json.dumps(data, ensure_ascii=False, indent=2))
        return

    if cmd == "post":
        out_dir = opt("--dir")
        if not out_dir:
            print("사용법: python daangn_poster.py post --dir generated/키워드 [--auto] [--force]")
            return
        out_dir = Path(out_dir)
        data = load_daangn_post(out_dir)
        if data is None:
            print("daangn_post.json 이 없어서 먼저 생성할게요...")
            data = generate_daangn_post(out_dir.name, out_dir=out_dir)
        images = sorted(
            out_dir.glob("slide*.png"),
            key=lambda p: int("".join(filter(str.isdigit, p.stem)) or 0),
        )
        res = post_news(
            data.get("title", ""),
            compose_body(data),
            image_paths=images,
            auto_submit="--auto" in args,
            force="--force" in args,
            keyword=data.get("keyword", out_dir.name),
        )
        print(json.dumps(res, ensure_ascii=False, indent=2))
        return

    print(__doc__)
    print("명령: login | status | probe | generate | post")


if __name__ == "__main__":
    _cli()
