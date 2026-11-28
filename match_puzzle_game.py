import streamlit as st
import random
import numpy as np
from collections import deque
import time

st.set_page_config(
    page_title="Match Puzzle - For 소현",
    page_icon="🎮",
    layout="centered",
    initial_sidebar_state="collapsed"
)

st.markdown("""
    <style>
        body {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        .title-text {
            text-align: center;
            color: #fff;
            font-size: 2.5em;
            font-weight: bold;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        .subtitle-text {
            text-align: center;
            color: #ffd700;
            font-size: 1.2em;
            font-weight: bold;
            margin-bottom: 20px;
        }
    </style>
""", unsafe_allow_html=True)

st.markdown('<div class="title-text">🎮 Match Puzzle</div>', unsafe_allow_html=True)
st.markdown('<div class="subtitle-text">소현(앨리, 야)을 위한 게임 by 동훈</div>', unsafe_allow_html=True)

COLORS = ['🔴', '🟡', '🔵', '🟢', '🟣', '🟠']
GRID_SIZE = 5

def initialize_game():
    if 'grid' not in st.session_state:
        st.session_state.grid = [[random.choice(COLORS) for _ in range(GRID_SIZE)] for _ in range(GRID_SIZE)]
        st.session_state.score = 0
        st.session_state.level = 1
        st.session_state.moves = 0
        st.session_state.selected = None
        st.session_state.game_over = False
        st.session_state.start_time = time.time()

def get_connected_group(grid, row, col, color):
    visited = set()
    queue = deque([(row, col)])
    visited.add((row, col))

    while queue:
        r, c = queue.popleft()
        for dr, dc in [(0, 1), (0, -1), (1, 0), (-1, 0)]:
            nr, nc = r + dr, c + dc
            if 0 <= nr < GRID_SIZE and 0 <= nc < GRID_SIZE and (nr, nc) not in visited:
                if grid[nr][nc] == color:
                    visited.add((nr, nc))
                    queue.append((nr, nc))

    return visited if len(visited) >= 3 else set()

def remove_tiles(grid, positions):
    for row, col in positions:
        grid[row][col] = None

    for col in range(GRID_SIZE):
        tiles = [grid[row][col] for row in range(GRID_SIZE) if grid[row][col] is not None]
        for row in range(GRID_SIZE):
            grid[row][col] = tiles.pop(0) if tiles else None

def has_moves(grid):
    for row in range(GRID_SIZE):
        for col in range(GRID_SIZE):
            if grid[row][col] is not None:
                connected = get_connected_group(grid, row, col, grid[row][col])
                if connected:
                    return True
    return False

def display_game():
    col1, col2, col3 = st.columns(3)
    with col1:
        st.metric("점수", st.session_state.score)
    with col2:
        st.metric("레벨", st.session_state.level)
    with col3:
        st.metric("이동", st.session_state.moves)

    st.write("")

    grid_html = '<div style="display: grid; grid-template-columns: repeat(5, 1fr); gap: 8px; max-width: 400px; margin: 0 auto;">'

    for row in range(GRID_SIZE):
        for col in range(GRID_SIZE):
            tile = st.session_state.grid[row][col]
            if tile is not None:
                color_style = "background-color: rgba(255,255,255,0.1); border: 2px solid rgba(255,255,255,0.3);"
                if st.session_state.selected == (row, col):
                    color_style = "background-color: rgba(255,255,255,0.3); border: 3px solid #ffd700; box-shadow: 0 0 10px rgba(255,215,0,0.5);"

                grid_html += f'''
                <button onclick="document.getElementById('tile_{row}_{col}').click()"
                    style="
                        {color_style}
                        font-size: 2.5em;
                        padding: 15px;
                        border-radius: 10px;
                        cursor: pointer;
                        transition: all 0.2s;
                    ">
                    {tile}
                </button>
                '''

    grid_html += '</div>'
    st.markdown(grid_html, unsafe_allow_html=True)

    col1, col2 = st.columns(2)
    with col1:
        if st.button("🔄 새로운 게임", key="new_game"):
            st.session_state.clear()
            st.rerun()
    with col2:
        st.write("")

def handle_tile_click(row, col):
    if st.session_state.grid[row][col] is None:
        return

    color = st.session_state.grid[row][col]
    connected = get_connected_group(st.session_state.grid, row, col, color)

    if connected:
        st.session_state.score += len(connected) * 10
        st.session_state.level = min(10, st.session_state.score // 100 + 1)
        st.session_state.moves += 1
        remove_tiles(st.session_state.grid, connected)
        st.session_state.selected = None
    else:
        st.session_state.selected = (row, col) if st.session_state.selected != (row, col) else None

initialize_game()

if not has_moves(st.session_state.grid):
    st.markdown("""
        <div style='text-align: center; padding: 20px; background-color: rgba(255,215,0,0.1); border-radius: 10px; border: 2px solid #ffd700;'>
            <h2 style='color: #ffd700;'>🎉 게임 오버!</h2>
            <h3 style='color: white;'>최종 점수: """ + str(st.session_state.score) + """</h3>
            <p style='color: white;'>총 """ + str(st.session_state.moves) + """번 이동</p>
        </div>
    """, unsafe_allow_html=True)
else:
    st.write("")

    col1, col2, col3, col4, col5 = st.columns(5)
    for col_idx in range(GRID_SIZE):
        for row_idx in range(GRID_SIZE):
            if st.session_state.grid[row_idx][col_idx] is not None:
                with st.columns(GRID_SIZE)[col_idx]:
                    if st.button(
                        st.session_state.grid[row_idx][col_idx],
                        key=f"tile_{row_idx}_{col_idx}",
                        use_container_width=True,
                        help=f"Row {row_idx}, Col {col_idx}"
                    ):
                        handle_tile_click(row_idx, col_idx)
                        st.rerun()

    st.write("")
    col1, col2 = st.columns(2)
    with col1:
        if st.button("🔄 새로운 게임", key="new_game_button"):
            st.session_state.clear()
            st.rerun()
    with col2:
        st.write("")

    st.markdown("""
    ### 게임 규칙
    - 같은 색 타일 3개 이상이 연결되어 있으면 클릭해서 터뜨리기
    - 터트린 타일은 점수 획득 (타일 개수 × 10)
    - 더 이상 이동할 수 없으면 게임 오버
    - 레벨은 점수가 높을수록 올라감 🎯
    """)
