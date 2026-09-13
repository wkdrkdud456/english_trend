"""
대치앨리영어 블로그 자동화 - Streamlit 웹 앱
============================================
폰/PC 어디서든 브라우저로 접속해서:
1. 트렌드 스캔 → 후보 확인 → 클릭으로 제작
2. 직접 키워드 입력해서 바로 제작
3. 결과(카드뉴스 이미지, 제목 후보, 태그) 확인 + 다운로드 + 텔레그램 전송
4. 당근 비즈프로필 '소식'으로 자동 게시 (앱이 실행 중인 PC에서만)

실행 (로컬): streamlit run streamlit_app.py
배포: README_DEPLOY.md 참고 (Streamlit Community Cloud)
"""

import io
import json
import zipfile
from pathlib import Path

import streamlit as st

import daangn_poster as daangn
import pipeline_core as core

st.set_page_config(page_title="대치앨리영어 블로그 자동화", page_icon="📚", layout="wide")

st.title("📚 대치앨리영어 블로그 자동화")
st.caption("트렌드 스캔 → 소재 선택 → 카드뉴스 제작 → 다운로드/텔레그램/당근 소식 게시")

# 시크릿 체크
missing = [
    k
    for k in ["NAVER_CLIENT_ID", "NAVER_CLIENT_SECRET", "ANTHROPIC_API_KEY"]
    if not core.get_secret(k)
]
if missing:
    st.error(
        "필수 시크릿이 없어요: " + ", ".join(missing)
        + "\n\nStreamlit Cloud라면 앱 설정 → Secrets에, 로컬이라면 .streamlit/secrets.toml에 넣어주세요."
    )
    st.stop()


def show_results(out_dir: Path):
    """생성 결과(이미지, 제목, 태그, 다운로드 버튼) 표시"""
    out_dir = Path(out_dir)
    captions_file = out_dir / "captions.json"
    if not captions_file.exists():
        st.warning("captions.json이 없어요. 생성이 완료되지 않았을 수 있어요.")
        return

    with open(captions_file, "r", encoding="utf-8") as f:
        caption_data = json.load(f)

    slide_files = sorted(
        out_dir.glob("slide*.png"), key=lambda p: int("".join(filter(str.isdigit, p.stem)))
    )

    titles = caption_data.get("titles", [])
    if titles:
        st.subheader("🏷 제목 후보")
        for i, t in enumerate(titles, start=1):
            st.code(t, language=None)

    tags = caption_data.get("tags", [])
    if tags:
        st.subheader("#️⃣ 태그 (한 줄 복사)")
        st.code(" ".join(tags), language=None)

    if slide_files:
        st.subheader(f"🖼 카드뉴스 ({len(slide_files)}장)")
        captions = caption_data.get("captions", [])
        cols = st.columns(2)
        for i, slide in enumerate(slide_files):
            with cols[i % 2]:
                st.image(str(slide), use_container_width=True)
                if i < len(captions) and captions[i]:
                    st.caption(captions[i])

    closing = caption_data.get("closing_text", "")
    if closing:
        st.subheader("📝 마무리 문단")
        st.code(closing, language=None)

    # 다운로드 (ZIP)
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as zf:
        for f_path in out_dir.iterdir():
            if f_path.is_file():
                zf.write(f_path, f_path.name)
    st.download_button(
        "📦 전체 패키지 다운로드 (ZIP)",
        data=buf.getvalue(),
        file_name=f"{out_dir.name}.zip",
        mime="application/zip",
        key=f"zip_{out_dir.name}",
    )

    # 텔레그램 전송
    if core.get_secret("TELEGRAM_BOT_TOKEN") and core.get_secret("TELEGRAM_CHAT_ID"):
        if st.button("✈️ 텔레그램으로 보내기", key=f"tg_{out_dir.name}"):
            with st.status("텔레그램 전송 중...") as status:
                core.send_package_to_telegram(out_dir, progress_callback=st.write)
                status.update(label="전송 완료!", state="complete")


def run_generation(keyword: str, context: str):
    """생성 → 렌더링 전체 실행 후 결과 표시"""
    with st.status(f"'{keyword}' 카드뉴스 제작 중... (2~3분 걸려요)", expanded=True) as status:
        st.write("1/2 글·HTML·캡션 생성 중...")
        out_dir = core.generate_content(keyword, context, progress_callback=st.write)
        st.write("2/2 이미지 렌더링 중...")
        core.render_slides(out_dir, progress_callback=st.write)
        status.update(label=f"'{keyword}' 제작 완료!", state="complete")
    st.session_state["last_result"] = str(out_dir)
    show_results(out_dir)


tab_scan, tab_direct, tab_daangn, tab_history = st.tabs(
    ["🔍 트렌드 스캔", "✍️ 직접 키워드", "🥕 당근 소식", "📂 지난 결과"]
)

# ---------------- 탭 1: 트렌드 스캔 ----------------
with tab_scan:
    st.write("네이버 데이터랩에서 학부모 검색 트렌드를 스캔해서 소재 후보를 찾아요.")

    if st.button("🔍 트렌드 스캔 실행", type="primary"):
        progress = st.progress(0.0, text="스캔 준비 중...")

        def on_batch(current, total, keywords):
            progress.progress(current / total, text=f"배치 {current}/{total}: {', '.join(keywords)}")

        results = core.run_trend_scan(progress_callback=on_batch)
        progress.progress(1.0, text="스캔 완료!")
        st.session_state["scan_results"] = results

    results = st.session_state.get("scan_results")
    if results:
        good = [r for r in results if r["volume_index"] >= core.MIN_VOLUME_INDEX]
        spikes = [r for r in good if r["is_spike"]]
        st.success(
            f"검색량 있는 키워드 {len(good)}개 / 급상승 {len(spikes)}개 감지"
            + (f" — 🔥 {', '.join(r['keyword'] for r in spikes)}" if spikes else "")
        )

        st.dataframe(
            [
                {
                    "급상승": "🔥" if r["is_spike"] else "",
                    "카테고리": r["category"],
                    "키워드": r["keyword"],
                    "기회점수": r.get("opportunity", 0),
                    "검색량(%)": round(r["volume_index"] * 100, 1),
                    "상승배율": r["spike_score"],
                    "z-score": r["z_score"],
                }
                for r in results
            ],
            use_container_width=True,
        )

        candidates = good[:8] if good else results[:3]
        choice = st.selectbox(
            "제작할 키워드 선택",
            [r["keyword"] for r in candidates],
            format_func=lambda kw: next(
                ("🔥 " if r["is_spike"] else "")
                + f"{kw}  (검색량 {round(r['volume_index'] * 100, 1)}%, 추세 {r['spike_score']}배)"
                for r in candidates
                if r["keyword"] == kw
            ),
        )
        if st.button("🚀 이 키워드로 카드뉴스 제작", type="primary", key="make_from_scan"):
            picked = next(r for r in candidates if r["keyword"] == choice)
            context = (
                f"최근 2주 검색량이 이전 대비 {picked['spike_score']}배 "
                f"(z-score {picked['z_score']}, 검색량 지수 {picked['volume_index']})"
                + (" - 급상승 감지됨" if picked["is_spike"] else "")
            )
            run_generation(choice, context)

# ---------------- 탭 2: 직접 키워드 ----------------
with tab_direct:
    st.write("트렌드 분석 없이, 원하는 키워드로 바로 카드뉴스를 만들어요.")
    kw = st.text_input("키워드", placeholder="예: 중2 서술형 대비")
    ctx = st.text_input("배경/맥락 (선택)", placeholder="예: 기말고사 서술형 비중 증가")
    if st.button("🚀 카드뉴스 제작", type="primary", key="make_direct", disabled=not kw.strip()):
        run_generation(kw.strip(), ctx.strip() or "원장님이 직접 지정한 소재")


# ---------------- 탭 3: 당근 소식 ----------------
def render_daangn_tab():
    st.write("만들어둔 글·카드뉴스를 당근 비즈프로필 **소식**으로 올려요.")
    st.caption(
        "⚠️ 당근은 도배·매크로를 제재해요 (심하면 영구정지). "
        f"그래서 하루 {daangn.MAX_POSTS_PER_DAY}건 / 최소 {daangn.MIN_HOURS_BETWEEN_POSTS}시간 간격으로 제한합니다. "
        "브라우저 창은 이 앱이 돌아가는 PC에서 열려요."
    )

    # --- 로그인 세션 ---
    st.subheader("1️⃣ 당근 로그인")
    status = daangn.session_status()
    col_a, col_b = st.columns([3, 1])
    with col_a:
        if not status["exists"]:
            st.warning("저장된 로그인 세션이 없어요. 오른쪽 버튼을 눌러 폰으로 QR 로그인해주세요.")
        elif status["stale"]:
            st.warning(f"세션을 저장한 지 {status['age_days']}일 됐어요. 만료됐을 수 있으니 확인해보세요.")
        else:
            st.success(f"세션 저장됨 ({status['age_days']}일 전). 바로 게시할 수 있어요.")
    with col_b:
        if st.button("🔑 QR 로그인", key="daangn_login"):
            with st.status("브라우저 창에서 QR 로그인해주세요...", expanded=True) as s:
                try:
                    daangn.login_and_save_session(progress_callback=st.write)
                    s.update(label="로그인 세션 저장 완료!", state="complete")
                except Exception as e:
                    s.update(label=f"로그인 실패: {e}", state="error")
        if status["exists"] and st.button("🔎 세션 확인", key="daangn_verify"):
            with st.spinner("확인 중..."):
                ok, msg = daangn.verify_session()
            (st.success if ok else st.error)(msg)

    # --- 소식 문구 ---
    st.subheader("2️⃣ 소식 문구")
    gen_dir = core.GENERATED_DIR
    folders = (
        sorted([d for d in gen_dir.iterdir() if d.is_dir()],
               key=lambda d: d.stat().st_mtime, reverse=True)
        if gen_dir.exists() else []
    )
    if not folders:
        st.info("먼저 '트렌드 스캔' 또는 '직접 키워드' 탭에서 카드뉴스를 만들어주세요.")
        return

    picked_name = st.selectbox("올릴 결과 선택", [d.name for d in folders], key="daangn_pick")
    out_dir = gen_dir / picked_name

    if st.button("✍️ 당근용 문구 생성 (블로그 글 → 소식 톤)", key="daangn_gen"):
        with st.spinner("생성 중... (30초 정도)"):
            try:
                daangn.generate_daangn_post(picked_name, out_dir=out_dir, progress_callback=st.write)
            except Exception as e:
                st.error(f"생성 실패: {e}")

    data = daangn.load_daangn_post(out_dir)
    if data is None:
        st.info("아직 이 결과의 당근 문구가 없어요. 위 버튼으로 생성해주세요.")
        return

    title = st.text_input("제목", value=data.get("title", ""), key="daangn_title")
    body = st.text_area("본문", value=data.get("body", ""), height=280, key="daangn_body")
    tags = st.text_input(
        "해시태그 (공백으로 구분)", value=" ".join(data.get("hashtags", [])), key="daangn_tags"
    )
    st.caption(f"본문 {len(body)}자 — 당근 소식은 300~550자가 적당해요.")

    if st.button("💾 수정 내용 저장", key="daangn_save"):
        data.update({"title": title, "body": body, "hashtags": tags.split()})
        daangn.save_daangn_post(out_dir, data)
        st.success("저장했어요.")

    # --- 이미지 ---
    st.subheader("3️⃣ 첨부 이미지")
    slides = sorted(
        out_dir.glob("slide*.png"),
        key=lambda f: int("".join(filter(str.isdigit, f.stem)) or 0),
    )
    if slides:
        chosen_names = st.multiselect(
            f"올릴 카드 선택 (최대 {daangn.MAX_IMAGES}장)",
            [f.name for f in slides],
            default=[f.name for f in slides[: min(5, daangn.MAX_IMAGES)]],
            key="daangn_imgs",
        )
        chosen = [out_dir / n for n in chosen_names]
        if chosen:
            cols = st.columns(min(4, len(chosen)))
            for i, img in enumerate(chosen[:4]):
                cols[i].image(str(img), use_container_width=True)
    else:
        chosen = []
        st.info("이 폴더에 카드뉴스 이미지가 없어요. 글만 올라갑니다.")

    # --- 게시 ---
    st.subheader("4️⃣ 게시")
    can_post, reason = daangn.check_rate_limit()
    if not can_post:
        st.warning(f"⏳ {reason}")

    mode = st.radio(
        "발행 방식",
        ["확인 모드 (내용만 채우고 발행은 내가)", "완전 자동 (발행까지)"],
        key="daangn_mode",
    )
    auto = mode.startswith("완전 자동")
    if auto:
        st.caption("브라우저가 백그라운드에서 열리고 발행까지 자동으로 끝냅니다.")

    if st.button("🥕 당근에 올리기", type="primary", key="daangn_post",
                 disabled=not can_post or not body.strip()):
        payload = {"title": title, "body": body, "hashtags": tags.split()}
        with st.status("당근 게시 중...", expanded=True) as s:
            try:
                res = daangn.post_news(
                    title,
                    daangn.compose_body(payload),
                    image_paths=chosen,
                    auto_submit=auto,
                    keyword=picked_name,
                    progress_callback=st.write,
                )
                for w in res["warnings"]:
                    st.warning(w)
                if res["screenshot"]:
                    st.image(res["screenshot"], caption="게시 화면", use_container_width=True)
                s.update(
                    label="발행 완료!" if res["submitted"] else "발행 확인 안 됨 — 당근 앱에서 확인해주세요",
                    state="complete" if res["submitted"] else "error",
                )
            except Exception as e:
                s.update(label=f"실패: {e}", state="error")

    # --- 기록 ---
    history = daangn.load_history()
    if history:
        st.subheader("📜 최근 게시 기록")
        st.dataframe(
            [{"시각": h["at"], "제목": h.get("title", ""), "키워드": h.get("keyword", "")}
             for h in reversed(history[-10:])],
            use_container_width=True,
        )


with tab_daangn:
    render_daangn_tab()

# ---------------- 탭 4: 지난 결과 ----------------
with tab_history:
    gen_dir = core.GENERATED_DIR
    if gen_dir.exists():
        folders = sorted(
            [d for d in gen_dir.iterdir() if d.is_dir()],
            key=lambda d: d.stat().st_mtime,
            reverse=True,
        )
    else:
        folders = []

    if not folders:
        st.info("아직 생성된 결과가 없어요.")
    else:
        picked = st.selectbox("결과 선택", [d.name for d in folders])
        show_results(gen_dir / picked)
