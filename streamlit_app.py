"""
대치앨리영어 블로그 자동화 - Streamlit 웹 앱
============================================
폰/PC 어디서든 브라우저로 접속해서:
1. 트렌드 스캔 → 후보 확인 → 클릭으로 제작
2. 직접 키워드 입력해서 바로 제작
3. 결과(카드뉴스 이미지, 제목 후보, 태그) 확인 + 다운로드 + 텔레그램 전송

실행 (로컬): streamlit run streamlit_app.py
배포: README_DEPLOY.md 참고 (Streamlit Community Cloud)
"""

import io
import json
import zipfile
from pathlib import Path

import streamlit as st

import pipeline_core as core

st.set_page_config(page_title="대치앨리영어 블로그 자동화", page_icon="📚", layout="wide")

st.title("📚 대치앨리영어 블로그 자동화")
st.caption("트렌드 스캔 → 소재 선택 → 카드뉴스 제작 → 다운로드/텔레그램 전송")

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


tab_scan, tab_direct, tab_history = st.tabs(["🔍 트렌드 스캔", "✍️ 직접 키워드", "📂 지난 결과"])

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
                    "상승배율": r["spike_score"],
                    "z-score": r["z_score"],
                    "검색량지수": r["volume_index"],
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
                ("🔥 " if r["is_spike"] else "") + f"{kw}  (배율 {r['spike_score']}, 검색량 {r['volume_index']})"
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

# ---------------- 탭 3: 지난 결과 ----------------
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
