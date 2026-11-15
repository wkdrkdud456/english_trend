#!/usr/bin/env python3
"""전설 괴물 · 랜드마크 그림 데이터.
도형(사각형/타원/삼각형)으로 픽셀 격자에 그린 뒤 사각형 목록으로 바꿔
  src/sprite_data.gd  (const PARTS)
로 내보낸다.  확인용 PNG:  python3 tools/sprites.py <출력폴더>
"""
import sys, os, zlib, struct, math

OUT = '1f1a22'


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[None] * w for _ in range(h)]

    def set(self, x, y, c):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h: self.px[y][x] = c

    def rect(self, x, y, w, h, c):
        for j in range(int(y), int(y + h)):
            for i in range(int(x), int(x + w)): self.set(i, j, c)

    def ell(self, cx, cy, rx, ry, c):
        for j in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for i in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if ((i + 0.5 - cx) / rx) ** 2 + ((j + 0.5 - cy) / ry) ** 2 <= 1.0: self.set(i, j, c)

    def tri(self, pts, c):
        (x0, y0), (x1, y1), (x2, y2) = pts
        lo_x, hi_x = int(min(x0, x1, x2)) - 1, int(max(x0, x1, x2)) + 1
        lo_y, hi_y = int(min(y0, y1, y2)) - 1, int(max(y0, y1, y2)) + 1

        def side(ax, ay, bx, by, px, py): return (bx - ax) * (py - ay) - (by - ay) * (px - ax)
        for j in range(lo_y, hi_y + 1):
            for i in range(lo_x, hi_x + 1):
                px, py = i + 0.5, j + 0.5
                a = side(x0, y0, x1, y1, px, py); b = side(x1, y1, x2, y2, px, py); d = side(x2, y2, x0, y0, px, py)
                if (a >= 0 and b >= 0 and d >= 0) or (a <= 0 and b <= 0 and d <= 0): self.set(i, j, c)

    def line(self, x0, y0, x1, y1, c, t=1):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for s in range(n + 1):
            u = s / n
            self.rect(round(x0 + (x1 - x0) * u), round(y0 + (y1 - y0) * u), t, t, c)

    def mirror(self):
        """왼쪽 절반을 오른쪽에 비춘다."""
        for j in range(self.h):
            for i in range(self.w // 2):
                self.px[j][self.w - 1 - i] = self.px[j][i]

    def outline(self, c=OUT):
        add = []
        for j in range(self.h):
            for i in range(self.w):
                if self.px[j][i] is not None: continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    x, y = i + dx, j + dy
                    if 0 <= x < self.w and 0 <= y < self.h and self.px[y][x] is not None and self.px[y][x] != c:
                        add.append((i, j)); break
        for i, j in add: self.px[j][i] = c

    def parts(self):
        """가로로 이어 붙이고 세로로 합쳐 사각형 수를 줄인다."""
        runs = {}
        for j in range(self.h):
            i = 0
            while i < self.w:
                c = self.px[j][i]
                if c is None: i += 1; continue
                k = i
                while k < self.w and self.px[j][k] == c: k += 1
                runs.setdefault((i, k - i, c), []).append(j); i = k
        out = []
        for (x, w, c), rows in runs.items():
            rows.sort(); start = rows[0]; prev = rows[0]
            for r in rows[1:] + [None]:
                if r is not None and r == prev + 1: prev = r; continue
                out.append([x, start, w, prev - start + 1, c])
                if r is not None: start = r; prev = r
        out.sort(key=lambda p: (p[1], p[0]))
        return out


def shade(hexc, f):
    r, g, b = int(hexc[0:2], 16), int(hexc[2:4], 16), int(hexc[4:6], 16)
    if f >= 0: r, g, b = (int(v + (255 - v) * f) for v in (r, g, b))
    else: r, g, b = (int(v * (1 + f)) for v in (r, g, b))
    return '%02x%02x%02x' % (r, g, b)


S = {}
INFO = {}


def eyes(c, x, y, gap, col='ffe14a', w=3, h=3):
    for sx in (x, x + gap):
        c.rect(sx, y, w, h, col); c.rect(sx + w - 2, y + 1, 1, h - 1, OUT)


# ══ 전설 괴물 (정면, 가로 32 안팎) ══════════════════════════
def gargoyle():   # 파리 — 노트르담의 가고일
    c = Canvas(34, 30); b = '8f95a3'; d = shade(b, -0.25); l = shade(b, 0.3)
    c.tri([(1, 4), (12, 12), (3, 22)], d); c.tri([(1, 4), (10, 10), (2, 14)], b)      # 날개
    c.line(2, 6, 9, 14, l); c.line(2, 12, 8, 17, l)
    c.ell(17, 20, 8, 8, b); c.ell(17, 23, 6, 4, l)                                    # 몸
    c.rect(8, 24, 6, 5, d); c.rect(7, 27, 3, 2, l)                                    # 발
    c.ell(17, 10, 7, 6, b); c.tri([(10, 6), (12, 0), (14, 6)], d)                     # 머리·뿔
    c.rect(12, 9, 3, 2, 'ff5a4a'); c.rect(13, 9, 1, 2, OUT)                           # 눈
    c.rect(15, 15, 2, 2, 'fff4e0')                                                     # 송곳니
    c.mirror(); c.rect(14, 15, 6, 1, OUT); c.outline(); return c


def kitsune():    # 교토 — 천년 구미호
    c = Canvas(36, 30); b = 'fff4dc'; t = 'f09a3c'; d = shade(b, -0.14)
    for k, (dx, dy) in enumerate([(2, 16), (3, 9), (7, 4), (12, 1)]):
        c.ell(dx + 2, dy + 3, 3, 4.5, b if k % 2 else d); c.ell(dx + 1.5, dy + 1.5, 2, 2, t)
    c.ell(18, 2.5, 2.5, 3, t)                                                          # 가운데 꼬리 끝
    c.ell(18, 22, 7, 7, b); c.ell(18, 25, 4, 3, 'ffffff')
    c.rect(11, 26, 4, 3, d)
    c.ell(18, 13, 7, 5.5, b)
    c.tri([(10, 10), (11, 3), (15, 9)], b); c.tri([(11, 9), (11.5, 5), (14, 9)], 'f4a0a8')
    c.rect(13, 12, 3, 2, 'c8323c'); c.rect(14, 12, 1, 2, OUT)
    c.mirror()
    c.rect(17, 9, 2, 2, 'c8323c')                                                      # 이마 문양
    c.rect(17, 16, 2, 1, OUT); c.outline(); return c


def sphinx():     # 카이로 — 잠들지 않는 스핑크스
    c = Canvas(36, 28); s = 'e2b866'; d = shade(s, -0.2); bl = '3f6fb5'; gd = 'f5d04a'
    c.rect(4, 17, 28, 9, s); c.rect(4, 23, 28, 3, d)                                   # 몸통
    c.rect(2, 21, 9, 5, s); c.rect(2, 24, 9, 2, d)                                     # 앞발
    c.tri([(8, 16), (13, 1), (18, 16)], bl); c.rect(13, 1, 5, 15, bl)                  # 두건
    for y in (4, 8, 12): c.rect(9, y, 9, 1, gd)
    c.rect(13, 5, 5, 10, 'e9b78a')                                                     # 얼굴
    c.rect(14, 8, 3, 2, 'fff6dd'); c.rect(15, 8, 1, 2, OUT)
    c.mirror()
    c.rect(17, 0, 2, 3, gd); c.rect(16, 15, 4, 4, bl); c.rect(17, 12, 2, 1, 'a5553e')
    c.outline(); return c


def cerberus():   # 로마 — 케르베로스
    c = Canvas(38, 30); b = '4a3f4f'; d = shade(b, -0.3); l = shade(b, 0.25); f = 'ff7a2a'
    c.ell(19, 22, 11, 6, b); c.rect(9, 24, 4, 5, d); c.rect(14, 25, 3, 4, d)
    c.ell(7, 12, 5.5, 5, b); c.tri([(2, 9), (3, 3), (6, 8)], d); c.tri([(8, 8), (11, 3), (12, 9)], d)
    c.rect(4, 11, 2, 2, f); c.rect(8, 11, 2, 2, f); c.rect(4, 15, 6, 2, l); c.rect(5, 16, 1, 2, 'fff4e0'); c.rect(8, 16, 1, 2, 'fff4e0')
    c.rect(11, 15, 5, 6, b)
    c.mirror()
    c.ell(19, 9, 6.5, 6, b); c.tri([(13, 5), (14, -1), (17, 4)], d); c.tri([(21, 4), (24, -1), (25, 5)], d)
    c.rect(15, 8, 3, 2, f); c.rect(20, 8, 3, 2, f); c.rect(15, 12, 8, 3, l); c.rect(16, 14, 1, 2, 'fff4e0'); c.rect(21, 14, 1, 2, 'fff4e0')
    c.rect(17, 18, 4, 2, 'c8323c'); c.rect(18, 20, 2, 1, 'f5d04a')
    c.outline(); return c


def gator():      # 뉴욕 — 하수구의 악어왕
    c = Canvas(36, 28); b = '5f9a52'; d = shade(b, -0.28); l = 'c9dc8f'
    c.ell(18, 20, 12, 7, b); c.ell(18, 23, 9, 4, l)
    c.rect(4, 22, 6, 5, d); c.rect(3, 26, 2, 1, 'fff4e0'); c.rect(6, 26, 2, 1, 'fff4e0')
    c.rect(8, 9, 10, 9, b); c.rect(7, 13, 11, 5, b)                                    # 주둥이
    c.rect(8, 15, 10, 1, OUT)
    for x in (9, 12, 15): c.rect(x, 16, 1, 2, 'fff4e0')
    c.ell(11, 7, 3, 3, b); c.rect(10, 6, 3, 3, 'ffe14a'); c.rect(11, 6, 1, 3, OUT)      # 눈
    c.rect(10, 11, 1, 1, d)
    c.mirror()
    gd = 'f5d04a'
    c.rect(13, 1, 10, 3, gd); c.rect(13, -1 + 0, 2, 2, gd); c.rect(17, 0, 2, 1, gd); c.rect(21, 0, 2, 1, gd)
    c.tri([(13, 1), (14, -3 + 1), (15, 1)], gd)
    c.rect(17, 2, 2, 1, 'c8323c')
    c.outline(); return c


def frost():      # 아이슬란드 — 서리 거인
    c = Canvas(34, 32); b = 'a8dcec'; d = shade(b, -0.25); l = 'eefbff'
    c.rect(9, 12, 8, 13, b); c.rect(9, 12, 8, 3, l); c.rect(9, 22, 8, 3, d)             # 몸
    c.rect(2, 12, 6, 6, b); c.rect(1, 18, 6, 8, d); c.rect(1, 18, 6, 2, b)              # 팔
    c.rect(9, 25, 6, 6, d); c.rect(9, 29, 7, 2, b)
    c.rect(11, 3, 6, 9, b); c.rect(11, 3, 6, 2, l)
    c.tri([(10, 3), (12, -1 + 1), (14, 3)], l); c.tri([(5, 12), (7, 7), (9, 12)], l)
    c.rect(13, 6, 3, 2, 'ffffff'); c.rect(14, 6, 1, 2, '3a7fd0')
    c.rect(12, 16, 3, 3, l)
    c.mirror(); c.rect(15, 10, 4, 1, OUT); c.tri([(15, 3), (17, -2 + 1), (19, 3)], l)
    c.outline(); return c


def kraken():     # 산토리니 — 에게해의 크라켄
    c = Canvas(36, 30); b = '9a5fc0'; d = shade(b, -0.28); l = 'e3b9f0'
    c.ell(18, 9, 9, 8.5, b); c.ell(13, 5, 3, 2, shade(b, 0.25))
    for k, (x0, y0, x1, y1) in enumerate([(10, 15, 2, 19), (2, 19, 4, 26), (12, 16, 8, 27), (15, 17, 14, 28)]):
        c.line(x0, y0, x1, y1, b, 3)
    c.rect(1, 26, 4, 2, l); c.rect(7, 27, 3, 2, l); c.rect(13, 28, 3, 1, l)
    c.rect(12, 9, 4, 4, 'fff6dd'); c.rect(14, 10, 2, 3, OUT)
    c.mirror()
    c.rect(16, 14, 4, 2, d); c.outline(); return c


def nessie():     # 런던 — 템스의 네시
    c = Canvas(38, 30); b = '4f9a86'; d = shade(b, -0.28); l = 'bfe6c8'
    c.ell(22, 22, 13, 6, b); c.ell(22, 25, 10, 3, l)                                    # 몸
    for x in (17, 23, 29): c.tri([(x - 2, 17), (x, 13), (x + 2, 17)], d)                 # 등 지느러미
    c.rect(8, 6, 5, 18, b); c.rect(8, 6, 2, 18, l)                                      # 긴 목
    c.ell(9, 6, 6, 4.5, b); c.rect(2, 6, 6, 3, b)                                       # 머리
    c.rect(6, 4, 3, 2, 'fff6dd'); c.rect(7, 4, 1, 2, OUT); c.rect(3, 8, 5, 1, OUT)
    c.rect(5, -1 + 1, 8, 3, '2c2c34'); c.rect(3, 2, 12, 1, '2c2c34'); c.rect(5, 1, 8, 1, 'c8323c')   # 중절모
    c.rect(33, 18, 4, 3, b); c.rect(35, 15, 2, 4, d)
    c.rect(0, 27, 38, 3, '8fc8e0'); c.rect(3, 27, 5, 1, 'e7f5ff'); c.rect(20, 28, 7, 1, 'e7f5ff')
    c.outline(); return c


def serpent():    # 시드니 — 무지개뱀
    c = Canvas(36, 30); cols = ['d8483c', 'f09a3c', 'f5d04a', '5fae5a', '3f8fd0', '8a5fc0']
    pts = []
    for s in range(120):
        u = s / 119.0
        pts.append((18 + math.cos(u * 4.6 + 1.2) * (12 - u * 7), 23 - u * 15 + math.sin(u * 4.6 + 1.2) * 3))
    for k, (x, y) in enumerate(pts): c.ell(x, y, 2.6, 2.6, cols[(k // 6) % 6])
    hx, hy = pts[-1]
    c.ell(hx, hy - 1, 4.5, 4, '5fae5a'); c.rect(hx - 3, hy - 3, 2, 2, 'ffe14a'); c.rect(hx + 1, hy - 3, 2, 2, 'ffe14a')
    c.rect(hx - 2, hy - 3, 1, 2, OUT); c.rect(hx + 2, hy - 3, 1, 2, OUT)
    c.rect(hx - 0.5, hy + 2, 1, 3, 'c8323c'); c.rect(hx - 1.5, hy + 5, 1, 1, 'c8323c'); c.rect(hx + 0.5, hy + 5, 1, 1, 'c8323c')
    c.outline(); return c


def haetae():     # 서울 — 광화문의 해태
    c = Canvas(36, 30); b = '4fa7a0'; d = shade(b, -0.28); f = 'f09a3c'; l = 'f6e9c4'
    c.ell(18, 21, 10, 7, b); c.rect(8, 23, 5, 6, d); c.rect(7, 28, 6, 1, l)
    for k in range(4):                                                                 # 갈기 불꽃
        a = math.pi * (0.55 + k * 0.17)
        c.tri([(18 + math.cos(a) * 6, 11 + math.sin(a) * -6), (18 + math.cos(a) * 12, 11 - math.sin(a) * 11), (18 + math.cos(a + 0.3) * 7, 11 - math.sin(a + 0.3) * 6)], f)
    c.ell(18, 12, 8, 7, b)
    c.rect(12, 10, 4, 3, 'fff6dd'); c.rect(14, 10, 2, 3, OUT)
    c.rect(11, 8, 5, 1, d)
    c.rect(12, 16, 6, 3, l); c.rect(13, 16, 1, 2, 'ffffff'); c.rect(16, 15, 2, 1, d)
    c.mirror()
    c.tri([(16, 5), (18, -1 + 1), (20, 5)], 'f5d04a')                                   # 외뿔
    c.rect(17, 13, 2, 2, d); c.rect(15, 23, 6, 3, l); c.rect(17, 24, 2, 1, 'c8323c')
    c.outline(); return c


LEGENDS = [gargoyle, kitsune, sphinx, cerberus, gator, frost, kraken, nessie, serpent, haetae]
for n, fn in enumerate(LEGENDS): S['legend%d' % n] = fn()


# ══ 랜드마크 (정면 입면) ════════════════════════════════════
def pagoda():     # 교토 — 오층탑
    c = Canvas(40, 60); r = '4a3a36'; w = 'c2543e'; g = 'f0d49a'
    c.rect(19, 0, 2, 9, 'c9a04a'); c.rect(18, 3, 4, 1, 'c9a04a'); c.rect(18, 6, 4, 1, 'c9a04a')
    y = 9
    for k in range(5):
        half = 8 + k * 2.6
        c.tri([(20 - half - 3, y + 5), (20, y - 1), (20 + half + 3, y + 5)], r)
        c.rect(20 - half - 3, y + 4, 2, 1, 'c9a04a'); c.rect(20 + half + 1, y + 4, 2, 1, 'c9a04a')
        bw = 5 + k * 2.2
        c.rect(20 - bw, y + 5, bw * 2, 5, w); c.rect(20 - bw, y + 5, bw * 2, 1, shade(w, -0.3))
        for i in range(int(bw) // 2):
            c.rect(20 - bw + 1 + i * 4, y + 7, 2, 3, g)
        y += 10
    c.rect(4, 58, 32, 2, 'b9ad98'); c.rect(18, 54, 4, 4, '5e4034')
    c.outline(); return c


def pyramid():    # 카이로 — 피라미드
    c = Canvas(54, 34); a = 'e9ca8f'; b = 'd0a862'
    for j in range(34):
        half = (j + 1) * 27 / 34.0
        c.rect(27 - half, j, half, 1, a); c.rect(27, j, half, 1, b)
        if j % 4 == 3:
            c.rect(27 - half, j, half, 1, shade(a, -0.1)); c.rect(27, j, half, 1, shade(b, -0.12))
    c.rect(26, 0, 2, 2, 'fff0c0')
    c.outline(); return c


def sphinx_stone():
    c = Canvas(30, 24); s = 'dcb970'; d = shade(s, -0.22)
    c.rect(3, 14, 24, 8, s); c.rect(3, 19, 24, 3, d); c.rect(1, 17, 8, 5, s); c.rect(1, 20, 8, 2, d)
    c.tri([(7, 13), (11, 1), (15, 13)], d); c.rect(11, 1, 4, 12, d)
    for y in (4, 8): c.rect(8, y, 7, 1, s)
    c.rect(11, 4, 4, 9, s); c.rect(12, 7, 2, 1, OUT)
    c.mirror(); c.rect(14, 10, 2, 1, d); c.rect(0, 22, 30, 2, 'c9a55c')
    c.outline(); return c


def colosseum():  # 로마 — 콜로세움
    c = Canvas(100, 40); s = 'e4d2a8'; d = 'b79c70'; hole = '6b5846'
    for i in range(100):
        u = (i - 49.5) / 50.0
        top = 6 + int((u * u) * 5)
        if i > 62: top += int((i - 62) * 0.45)                                          # 무너진 쪽
        c.rect(i, top, 1, 38 - top, s)
    for row in range(3):
        y = 14 + row * 8
        for i in range(100):
            if c.px[y - 2][i] is not None: c.set(i, y - 2, d)
        for k in range(14):
            x = 4 + k * 6.8
            if c.px[y][int(x) + 1] is None: continue
            c.rect(x, y + 1, 4, 5, hole); c.rect(x + 1, y, 2, 1, hole)
    c.rect(0, 38, 100, 2, 'c8b68c')
    c.outline(); return c


def liberty():    # 뉴욕 — 자유의 여신상
    c = Canvas(26, 60); g = '7fb5a3'; d = shade(g, -0.25); st = 'cfc9b6'
    c.rect(5, 44, 16, 14, st); c.rect(3, 56, 20, 4, shade(st, -0.15)); c.rect(7, 40, 12, 4, shade(st, -0.1))
    c.rect(8, 22, 10, 18, g); c.rect(8, 22, 3, 18, d); c.tri([(6, 40), (8, 26), (10, 40)], d)
    c.ell(13, 17, 4, 4.5, g); c.rect(11, 16, 2, 1, OUT); c.rect(14, 16, 2, 1, OUT)
    for k in range(5):
        a = math.pi * (0.2 + k * 0.15)
        c.line(13 + math.cos(a) * 4, 14 - math.sin(a) * 3, 13 + math.cos(a) * 8, 14 - math.sin(a) * 7, d)
    c.rect(18, 8, 3, 16, g); c.rect(17, 4, 5, 4, 'e9c25a'); c.tri([(17, 4), (19.5, -1 + 1), (22, 4)], 'ffdf7a')
    c.rect(4, 27, 5, 7, shade(g, 0.2))
    c.outline(); return c


def church_ice():  # 레이캬비크 — 하들그림스키르캬
    c = Canvas(48, 60); s = 'dfe6ea'; d = 'aebcc6'
    for k in range(11):
        hgt = 14 + k * 4
        c.rect(2 + k * 2, 58 - hgt, 2, hgt, s if k % 2 else d)
        c.rect(44 - k * 2, 58 - hgt, 2, hgt, s if k % 2 else d)
    c.rect(20, 10, 8, 48, s); c.tri([(20, 10), (24, 0), (28, 10)], d)
    c.rect(23, 0, 2, 3, d); c.rect(22, 2, 4, 1, d)
    c.rect(22, 16, 4, 4, 'f6e9b0'); c.rect(22, 26, 4, 8, '8fa3b3'); c.rect(21, 48, 6, 10, '6b5846')
    c.rect(0, 58, 48, 2, 'c5d2da')
    c.outline(); return c


def dome_church():  # 산토리니 — 파란 돔 교회
    c = Canvas(44, 40); wh = 'fdfaf0'; sh = 'd9dfe6'; bl = '3f7fc0'
    c.rect(6, 20, 26, 18, wh); c.rect(6, 34, 26, 4, sh)
    c.ell(19, 20, 11, 10, bl); c.rect(8, 20, 22, 2, wh); c.ell(15, 14, 3, 2, shade(bl, 0.3))
    c.rect(18, 6, 2, 5, wh); c.rect(17, 8, 4, 1, wh)
    c.rect(33, 8, 9, 30, wh); c.rect(40, 8, 2, 30, sh)
    for y in (11, 19): c.rect(35, y, 5, 5, '8fb7d8'); c.rect(37, y + 2, 1, 3, 'c9a04a')
    c.tri([(33, 8), (37.5, 3), (42, 8)], bl)
    c.rect(16, 30, 6, 8, '8a5a3c'); c.rect(9, 26, 4, 4, '8fb7d8'); c.rect(25, 26, 4, 4, '8fb7d8')
    c.rect(2, 38, 42, 2, sh)
    c.outline(); return c


def bigben():     # 런던 — 빅벤
    c = Canvas(24, 64); s = 'c9b68a'; d = 'a08a60'; r = '4d5866'
    c.rect(11, 0, 2, 6, 'c9a04a'); c.tri([(5, 16), (12, 4), (19, 16)], r)
    c.rect(5, 16, 14, 14, s); c.rect(5, 16, 14, 1, d)
    c.ell(12, 23, 5, 5, 'fff8e0'); c.rect(11, 19, 1, 4, OUT); c.rect(12, 23, 3, 1, OUT)
    c.rect(4, 30, 16, 2, d); c.rect(6, 32, 12, 28, s)
    for x in (7, 10, 13, 16): c.rect(x, 33, 1, 26, d)
    c.rect(4, 60, 16, 4, d)
    c.outline(); return c


def opera():      # 시드니 — 오페라 하우스
    c = Canvas(80, 34); wh = 'f6f0de'; sh = 'd3cab2'; base = 'c9b99a'
    for k, (x, hgt, wid) in enumerate([(6, 20, 18), (20, 27, 22), (38, 24, 20), (54, 17, 16)]):
        c.tri([(x, 28), (x + wid * 0.75, 28 - hgt), (x + wid, 28)], wh)
        c.tri([(x + wid * 0.45, 28), (x + wid * 0.75, 28 - hgt), (x + wid, 28)], sh)
    c.rect(0, 28, 80, 4, base); c.rect(0, 32, 80, 2, shade(base, -0.2))
    for x in range(4, 76, 6): c.rect(x, 29, 3, 2, '6b8fa8')
    c.outline(); return c


def ntower():     # 서울 — 남산타워
    c = Canvas(26, 66); s = 'e0ded2'; d = 'b9bcb4'
    c.rect(12, 0, 2, 16, 'c4605a'); c.rect(11, 6, 4, 1, 'c4605a'); c.rect(11, 10, 4, 1, 'c4605a')
    c.rect(8, 16, 10, 3, d); c.rect(5, 19, 16, 7, s); c.rect(5, 21, 16, 2, '6b8fa8'); c.rect(7, 26, 12, 3, d)
    c.rect(11, 29, 4, 30, s); c.rect(11, 29, 1, 30, d)
    c.tri([(4, 62), (11, 50), (11, 62)], '7a9a68'); c.tri([(15, 62), (15, 50), (22, 62)], '7a9a68')
    c.rect(2, 62, 22, 4, '6f8f5f')
    c.outline(); return c


def eiffel():     # 파리 — 에펠탑
    c = Canvas(46, 68); a = '8f8068'; b = 'bfae8f'
    c.rect(22, 0, 2, 9, a)
    for j in range(9, 66):
        t = (j - 9) / 56.0; half = 1.5 + 20 * t * t
        c.rect(23 - half, j, half * 2, 1, a if j % 4 == 0 else b)
    for j in range(40, 66):                                        # 다리 사이 아치
        for i in range(46):
            if ((i + 0.5 - 23) / 11.0) ** 2 + ((j + 0.5 - 66) / 24.0) ** 2 <= 1.0: c.px[j][i] = None
    for y, half in ((27, 6), (43, 12)): c.rect(23 - half, y, half * 2, 2, a)
    c.rect(0, 66, 46, 2, 'a6bf87')
    c.outline(); return c


LANDMARKS = { 'lm_eiffel': eiffel, 'lm_pagoda': pagoda, 'lm_pyramid': pyramid, 'lm_sphinx': sphinx_stone, 'lm_colosseum': colosseum, 'lm_liberty': liberty,
              'lm_church': church_ice, 'lm_dome': dome_church, 'lm_bigben': bigben, 'lm_opera': opera, 'lm_ntower': ntower}
for name, fn in LANDMARKS.items(): S[name] = fn()


# ══ 내보내기 ════════════════════════════════════════════════
def write_png(path, grid, scale=6, bg=(166, 191, 135)):
    h, w = len(grid), len(grid[0])
    raw = bytearray()
    for j in range(h * scale):
        raw.append(0)
        row = grid[j // scale]
        for i in range(w * scale):
            c = row[i // scale]
            if c is None: raw += bytes(bg)
            else: raw += bytes((int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16)))

    def chunk(tag, data): return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w * scale, h * scale, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(bytes(raw), 9)) + chunk(b'IEND', b'')
    open(path, 'wb').write(png)


def sheet(names, cols):
    cw = max(S[n].w for n in names) + 2; ch = max(S[n].h for n in names) + 2
    rows = (len(names) + cols - 1) // cols
    grid = [[None] * (cw * cols) for _ in range(ch * rows)]
    for k, n in enumerate(names):
        ox = (k % cols) * cw + (cw - S[n].w) // 2; oy = (k // cols) * ch + (ch - S[n].h)
        for j in range(S[n].h):
            for i in range(S[n].w): grid[oy + j][ox + i] = S[n].px[j][i]
    return grid


if __name__ == '__main__':
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
    lines = ['extends RefCounted', '# tools/sprites.py 가 만든 파일 — 직접 고치지 말 것', '', 'const PARTS = {']
    total = 0
    for name, c in S.items():
        parts = c.parts(); total += len(parts)
        lines.append('    "%s": [%s],' % (name, ', '.join('[%d, %d, %d, %d, "%s"]' % tuple(p) for p in parts)))
    lines.append('}')
    open(os.path.join(root, 'src', 'sprite_data.gd'), 'w').write('\n'.join(lines) + '\n')
    print('그림 %d개 · 사각형 %d개' % (len(S), total))
    if len(sys.argv) > 1:
        os.makedirs(sys.argv[1], exist_ok=True)
        write_png(os.path.join(sys.argv[1], 'legends.png'), sheet(['legend%d' % n for n in range(10)], 5), 6)
        write_png(os.path.join(sys.argv[1], 'landmarks.png'), sheet(list(LANDMARKS.keys()), 5), 4, (200, 205, 180))
