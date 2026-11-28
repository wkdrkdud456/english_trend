#!/usr/bin/env python3
"""경마장 말·기수 그림 (옆모습, 오른쪽을 본다).
글자 칸: C 털 · M 갈기·꼬리 · D 발굽·코 · S 안장천 · J 기수 옷 · K 모자 · W 바지 · B 장화 · O 외곽선
실행: python3 tools/race_sprites.py [PNG 폴더]  →  src/race_sprite_data.gd"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sprites import Canvas, write_png

def body():
    c = Canvas(42, 30)
    c.tri([(8, 11), (1, 12), (3, 18)], 'M')                         # 꼬리
    c.ell(18, 14, 11, 5, 'C')                                         # 몸통
    c.tri([(24, 11), (31, 3), (31, 14)], 'C'); c.tri([(24, 11), (31, 14), (26, 17)], 'C')   # 목
    c.ell(34, 6, 4.5, 2.6, 'C'); c.rect(36, 5, 3, 4, 'C')            # 머리
    c.rect(38, 6, 2, 3, 'D'); c.rect(34, 5, 1, 1, 'O')                # 코 · 눈
    c.tri([(30, 3), (31, 0), (32, 3)], 'C')                           # 귀
    c.line(25, 10, 30, 3, 'M', 2)                                     # 갈기
    c.rect(13, 9, 9, 5, 'S'); c.rect(13, 9, 9, 1, 'W')                # 안장천
    c.rect(15, 6, 6, 2, 'W'); c.line(20, 7, 18, 11, 'W', 2); c.rect(17, 10, 3, 2, 'B')   # 구부린 다리 · 장화
    c.tri([(14, 6), (22, 2), (23, 6)], 'J'); c.rect(14, 4, 8, 3, 'J') # 상체(앞으로 숙임)
    c.line(21, 5, 27, 8, 'J', 1)                                      # 팔 · 고삐
    c.ell(23.5, 2, 2.2, 1.8, 'K'); c.rect(25, 2, 2, 1, 'K')           # 모자
    c.outline('O'); return c

LEGS = [
    [((30, 16), (36, 24)), ((27, 17), (31, 26)), ((10, 17), (4, 24)), ((13, 18), (8, 26))],
    [((29, 17), (28, 26)), ((26, 17), (24, 26)), ((11, 17), (14, 26)), ((14, 17), (17, 25))],
    [((29, 17), (32, 26)), ((26, 17), (28, 26)), ((10, 17), (8, 26)), ((13, 18), (12, 26))],
    [((29, 16), (34, 21)), ((27, 17), (31, 22)), ((11, 17), (6, 22)), ((14, 17), (10, 23))],
]
def legs(frame):
    c = Canvas(42, 30)
    for (a, b) in LEGS[frame]:
        c.line(a[0], a[1], b[0], b[1], 'C', 2)
        c.rect(b[0], b[1], 2, 2, 'D')
    c.outline('O'); return c

PAL = {'C': '8a5a3c', 'M': '3a2a22', 'D': '2a2020', 'S': 'c8323c', 'J': '3f7fc0', 'K': 'ffd84a', 'W': 'f4f4f4', 'B': '2a2a30', 'O': '1f1a22'}
if __name__ == '__main__':
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
    shapes = {'body': body()}
    for f in range(4): shapes['legs%d' % f] = legs(f)
    out = ['extends RefCounted', '# tools/race_sprites.py 가 만든 파일', '', 'const PARTS = {']
    for k, c in shapes.items():
        out.append('    "%s": [%s],' % (k, ', '.join('[%d, %d, %d, %d, "%s"]' % tuple(p) for p in c.parts())))
    out.append('}')
    open(os.path.join(root, 'src', 'race_sprite_data.gd'), 'w').write('\n'.join(out) + '\n')
    if len(sys.argv) > 1:
        grid = []
        for f in range(4):
            g = [[None] * 42 for _ in range(30)]
            for layer in (shapes['legs%d' % f], shapes['body']):
                for y in range(30):
                    for x in range(42):
                        v = layer.px[y][x]
                        if v is not None: g[y][x] = PAL[v]
            grid.append(g)
        sheet = [sum((grid[f][y] + [None] * 4 for f in range(4)), []) for y in range(30)]
        write_png(os.path.join(sys.argv[1], 'horse.png'), sheet, 8)
        print('ok')
