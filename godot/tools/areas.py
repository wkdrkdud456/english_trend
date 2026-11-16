#!/usr/bin/env python3
"""세부 구역 설계 데이터 + 검증 + GDScript/JS 내보내기.
   좌표는 월드 (x, z). 사각형은 [x, z, 너비, 깊이] (왼쪽 위 기준).
   실행:  python3 -I godot/tools/areas.py   → src/area_data.gd, mock/areas.js 생성"""
import json, os, sys, collections

SOLID = {"stall": (2.2, 1.2), "fountain": (2.0, 2.0), "column": (0.7, 0.7), "arch": (2.4, 0.8), "rock": (1.4, 1.0), "tent": (2.0, 1.6),
         "windmill": (1.6, 1.6), "phonebox": (0.7, 0.7), "bus": (3.0, 1.3), "wheel": (3.0, 1.0), "bush": (0.9, 0.7), "camel": (1.4, 0.8)}
GATE_ALLEY = [11.2, 0.0]; GATE_PARK = [0.0, -11.6]

def H(x, z, w, d, wall, roof, title="", dome="", spire=False):
    return {"x": x, "z": z, "w": w, "d": d, "wall": wall, "roof": roof, "title": title, "dome": dome, "spire": spire}

A = {}
# ───────── 파리 ─────────
A["0_1"] = dict(name="몽마르트 골목", gate=GATE_ALLEY,
  zones=[[3.4, 1.6, 6, 4, "p1"]],
  roads=[[-10, -1, 21.6, 2], [-1, -7, 2, 6], [-10, -1, 2, 9], [-10, 6, 13, 2], [1, 1, 2, 5]], water=[], bridges=[],
  houses=[H(0, -9.2, 5.4, 3.2, "f4efe6", "d9d4c8", "사크레쾨르", dome="e9e4d8"), H(-5.5, -4.2, 3.2, 2.6, "e9bb97", "a85e50", "카페"), H(5.5, -4.4, 3.4, 2.6, "e7d9b7", "527b74"),
          H(-5.4, 3.4, 3.4, 2.4, "f0d9c0", "8a5a6a"), H(-6, 9.8, 3.2, 2.2, "e9c9a0", "a85e50")],
  trees=[[-8, -9.6, "tree"], [10.8, -3.6, "tree"], [10.5, 9.4, "tree"], [-2.5, 10.6, "tree"]],
  decor=[["easel", 4.6, 3.0, ""], ["easel", 6.4, 4.4, ""], ["easel", 8.2, 3.0, ""], ["windmill", 8.6, -8.0, "c85068"], ["lamp", -3, -2, ""], ["lamp", 3, -2, ""], ["bench", 6.4, 2.2, ""]],
  chests=[[-10.6, -10.4], [10.6, 10.8]], npc=[2.3, -3.0], egg=[-11.3, 5.0])
A["0_2"] = dict(name="센강 둔치", gate=GATE_PARK, zones=[],
  roads=[[-1, -12, 2, 7.6], [-11, -5.4, 22, 2], [-11, 3.4, 22, 2], [-1, 5.4, 2, 3]], water=[[-13.4, -3, 26.8, 6]], bridges=[], ferry=[[-6, -3.7], [-6, 3.8]],
  houses=[H(0, 10, 6, 3, "cfc8b8", "8f8a80", "노트르담", spire=True)],
  trees=[[-11, -10, "tree"], [-6, -10, "tree"], [6, -10, "tree"], [11, -9.5, "tree"], [-9, 8, "tree"], [9, 7.5, "tree"], [-6, 11, "tree"], [6.5, 11, "tree"]],
  decor=[["stall", -9, -6.6, "3f6a4c"], ["stall", -4.5, -6.6, "3f6a4c"], ["stall", 3.5, -6.6, "3f6a4c"], ["stall", 8, -6.6, "3f6a4c"], ["boat", -10, 0, "c85068"], ["boat", 0, -0.5, "4a8fb8"], ["boat", 9.5, 0.8, "e5b33c"],
         ["bench", -4, 6.3, ""], ["bench", 4, 6.3, ""], ["lamp", -9, 2.9 + 3.0, ""], ["lamp", 9, 5.9, ""]],
  chests=[[10.9, -7.9], [-10.8, 10.6]], shard=[10.6, 10.4], egg=[-11.4, -7.9])
# ───────── 교토 ─────────
MW, MR = "9a7a58", "4a4440"
A["1_1"] = dict(name="기온 뒷골목", gate=GATE_ALLEY, zones=[],
  roads=[[-10, -1, 21.6, 2], [-6, -9, 1.6, 18], [0, -9, 1.6, 18], [6, -9, 1.6, 18]], water=[], bridges=[],
  houses=[H(x, z, 3.0, 2.2, MW, MR) for x in (-2.2, 3.8) for z in (-6.6, -3.4, 3.4, 6.6)] + [H(9.6, -5, 2.6, 2.4, "b08a60", MR, "찻집"), H(9.6, 5, 2.6, 2.4, MW, MR), H(-8.6, -7, 2.6, 2, "c6ae86", "5e4a3b", "신사")],
  trees=[[-11, 6, "cherry"], [-8.5, 9.6, "cherry"], [10.5, 9.8, "cherry"], [-11, -10.5, "cherry"]],
  decor=[["torii", -8.6, -4.4, ""], ["lantern", -4.0, -1.6, ""], ["lantern", 2.0, -1.6, ""], ["lantern", 8.0, 1.6, ""], ["lantern", -4.0, 1.6, ""]],
  chests=[[-8.6, 3.4], [3.8, -9.8]], npc=[-8.2, 1.9], egg=[9.6, -9.4])
A["1_2"] = dict(name="대나무 숲", gate=GATE_PARK, zones=[],
  roads=[[-1, -12, 2, 5.6], [-6, -8, 5, 1.6], [-6, -8, 1.6, 10], [-6, 0.4, 12.6, 1.6], [5, 0.4, 1.6, 6], [5, 9, 1.6, 2.6]], water=[[-13.4, 6, 26.8, 3]], bridges=[], ferry=[[5.8, 5.5], [5.8, 9.6]],
  houses=[H(9.8, -10.2, 2.6, 2, "c6ae86", "5e4a3b", "다실")],
  trees=[[x, z, "bamboo"] for x, z in [(-3, -10), (2.4, -9), (-7.6, -9.6), (-2.8, -5), (-7.8, -5.5), (-3, -2.5), (-7.8, -2), (-7.8, 1.6), (-3, 3.4), (0, 3.6), (3, 3.6), (0, -1), (3, -1), (7.8, -0.8), (8, 3), (2.8, -4.5),
         (6, -5), (9.5, -7.4), (10.6, -3), (10.6, 4), (-10.6, -8), (-10.6, 0), (-10.6, 4.4), (-9, 10.6), (-3, 10.6), (10, 10.8)]],
  decor=[["torii", 5.8, 9.4, ""], ["lantern", 3.6, 5.2, ""]],
  chests=[[9.6, 1.2], [-9.2, 2.8]], shard=[5.8, 11.0], egg=[-0.5, 10.8])
# ───────── 카이로 ─────────
A["2_1"] = dict(name="시장 골목", gate=GATE_ALLEY, zones=[],
  roads=[[-10, -1, 21.6, 2], [-6, -9, 2, 8], [-6, -9, 10, 2], [2, -9, 2, 8], [3, 1, 2, 8], [-9, 7, 14, 2]], water=[], bridges=[],
  houses=[H(8, -6, 4, 3.4, "e8d3a6", "c9a66b", "모스크", dome="4a8fb8", spire=True), H(-9.6, -5.5, 2.4, 3, "e1c08a", "b08a59"), H(-5, 10.7, 3, 1.9, "edcf9a", "c59a63"), H(1, 10.7, 3, 1.9, "e1c08a", "b08a59")],
  trees=[[-11, -10.5, "palm"], [11, -10.5, "palm"], [-11.2, 4, "palm"], [10.8, 10.4, "palm"]],
  decor=[["stall", -1, -5.6, "c85068"], ["stall", -1, -3.2, "e5b33c"], ["stall", -6.5, 2.8, "4a8fb8"], ["stall", -3, 2.8, "e8974d"], ["stall", 0.4, 2.8, "8a5fc0"], ["stall", 7.6, 3.6, "5fa55a"], ["stall", 7.6, 6.2, "c85068"],
         ["lantern", -7, -1.7, ""], ["lantern", 4.6, -1.6, ""]],
  chests=[[-8.8, -10.4], [-10.8, 10.6]], npc=[6.2, -2.0], egg=[10.6, 8.4])
A["2_2"] = dict(name="오아시스", gate=GATE_PARK, zones=[],
  roads=[[-1, -12, 2, 6.8], [-7, -6.8, 14, 1.6], [-7, -6.8, 1.6, 13.6], [5.4, -6.8, 1.6, 13.6], [-7, 5.2, 14, 1.6]], water=[[-4, -3, 8, 6]], bridges=[],
  houses=[],
  trees=[[x, z, "palm"] for x, z in [(-4.6, -4.2), (4.6, -4.2), (-4.9, 4.1), (4.9, 4.1), (0, 4.2), (-11, 5), (11, 7), (3.5, -10), (-4, -10.5), (0, 9.8)]],
  decor=[["tent", -10, -9.6, "c85068"], ["tent", 10, -9.6, "e5b33c"], ["tent", -9.8, 9.6, "4a8fb8"], ["camel", 9.4, 2, "c9a66b"], ["camel", 8.6, 9.8, "c9a66b"], ["rock", -10.5, 0, "b9a57c"], ["rock", 10.6, -3, "b9a57c"]],
  chests=[[0, -4.1], [10.8, 10.9]], shard=[4.8, 10.4], egg=[11.2, 0.4])
# ───────── 로마 ─────────
A["3_1"] = dict(name="트라스테베레 골목", gate=GATE_ALLEY,
  zones=[[-3.5, -3.5, 7, 7, "p1"]],
  roads=[[3.5, -1, 8.1, 2], [-1, -9.5, 2, 6], [-1, 3.5, 2, 7], [-10.5, -1, 7, 2], [-10.5, -9.5, 2, 9], [-10.5, -9.5, 11.5, 2]], water=[], bridges=[],
  houses=[H(5.5, -5.5, 3.6, 2.8, "e2a878", "a5533a", "트라토리아"), H(5.5, 5.5, 3.6, 2.8, "e9c98a", "a5533a"), H(-5.5, 5.5, 3.6, 2.8, "d98a5a", "8a4a34"), H(-6, -5, 3, 2.6, "e9c98a", "a5533a"),
          H(9.6, -8.6, 2.6, 2.4, "e2a878", "8a4a34"), H(5, 10.4, 3, 2, "d98a5a", "a5533a"), H(-5.4, 10.2, 3, 2.2, "e2a878", "a5533a")],
  trees=[[-11, 10.5, "tree"], [10.8, 10.6, "tree"], [10.8, 3.4, "tree"], [-11.2, 3.5, "tree"]],
  decor=[["fountain", 0, 0, ""], ["parasol", 2.6, 2.6, "c85068"], ["parasol", -2.6, 2.6, "e5b33c"], ["lamp", -2.8, -2.8, ""], ["lamp", 2.8, -2.8, ""]],
  chests=[[9.4, -4.6], [-9, 8]], npc=[2.3, -1.9], egg=[0, 11.4])
A["3_2"] = dict(name="아피아 가도", gate=GATE_PARK, zones=[],
  roads=[[-1, -12, 2, 23.6], [1, -3, 9.6, 1.6], [-9.6, 4, 8.6, 1.6]], water=[], bridges=[],
  houses=[H(9.2, 0.6, 2.6, 2, "cfc0a0", "8a7a5c", "카타콤")],
  trees=[[x, z, "tree"] for x, z in [(-10.5, -3), (-7.5, 1.5), (-10.8, 8.5), (-5.5, 9.8), (5, -5.5), (9.8, -5.4), (10.6, 6), (4.8, 4.4), (10.2, 10.6)]],
  decor=[["column", x, z, ""] for x, z in [(-2.2, -9), (2.2, -9), (-2.2, -6), (2.2, -6), (-2.2, 0.5), (2.2, 1), (2.2, 7), (-2.2, 8.5), (2.2, 10)]] +
        [["arch", x, -8, ""] for x in (-9.6, -7.0, -4.4, 5.0, 7.6, 10.2)] + [["rock", 8, 3.6, "b5ab98"], ["rock", -6, -2, "b5ab98"], ["rock", 6.5, 8.5, "b5ab98"]],
  chests=[[10.9, -2.2], [-10.8, 4.8]], shard=[-8.8, 10.8], egg=[-10.4, -10.6])
# ───────── 뉴욕 ─────────
BW, BR = "9a5a48", "5a4038"
A["4_1"] = dict(name="브루클린 골목", gate=GATE_ALLEY,
  zones=[[-3.6, 2, 5.2, 3.2, "c86a4a"]],
  roads=[[-10, -1, 21.6, 2], [-7, -7, 2, 15], [3, -7, 2, 15], [-10, 6, 20, 2], [-7, -7, 12, 1.6]], water=[[-13.4, -13, 26.8, 4.4]], bridges=[],
  houses=[H(-2, -3.6, 3.4, 2.4, BW, BR), H(-10.2, -4, 2.4, 3, "8a6258", BR), H(7.6, -4, 3.4, 2.8, BW, BR), H(7.6, 3.6, 3.4, 2.8, "8a6258", BR), H(-10.2, 3.4, 2.4, 2.8, BW, BR),
          H(-2, 10.2, 3.6, 2.2, "b8684a", BR, "피자집"), H(6, 10.2, 3.4, 2.2, BW, BR)],
  trees=[[-11, 9.8, "tree"], [10.8, 9.8, "tree"], [-11.2, -7.4, "tree"]],
  decor=[["bus", 8.6, -7.3, "e5b33c"], ["arch", -3, -10.2, ""], ["arch", 0, -10.2, ""], ["arch", 3, -10.2, ""], ["lamp", -4.6, -1.7, ""], ["lamp", 5.6, 1.7, ""]],
  chests=[[-1, 3.6], [10.8, -2.2]], npc=[1.2, -2.0], egg=[-8.6, 10.8])
A["4_2"] = dict(name="센트럴 파크", gate=GATE_PARK, zones=[],
  roads=[[-1, -12, 2, 4.6], [-9, -9, 18, 1.6], [-9, -9, 1.6, 18], [7.4, -9, 1.6, 18], [-9, 7.4, 18, 1.6], [-0.8, -7.4, 1.6, 4.4], [-0.8, 3, 1.6, 4.4]],
  water=[[-5.5, -3, 11, 6]], bridges=[[-0.8, -3.4, 1.6, 6.8]], houses=[],
  trees=[[x, z, "tree"] for x, z in [(-11, -10.5), (11, -10.5), (-11, -3), (11, -2), (-11, 4), (11, 5), (-11, 10.8), (11, 10.8), (6.4, -0.5), (-6.5, 0.5), (5.2, -5.4)]],
  decor=[["rock", -4, -5.4, "9a9a92"], ["rock", 5, 5.2, "9a9a92"], ["bus", 3.4, 10.0, "c85068"], ["fountain", -4.4, 5.2, ""], ["bench", 2.8, -6.0, ""], ["bench", 3.2, 6.2, ""]],
  chests=[[-10.8, 0.6], [6.3, 2.6]], shard=[0, 10.6], egg=[10.9, -6.5])
# ───────── 아이슬란드 ─────────
IR = "3a3f4a"
A["5_1"] = dict(name="어촌 골목", gate=GATE_ALLEY, zones=[],
  roads=[[-5, -1, 16.6, 2], [-5, -9, 2, 18], [-5, -9, 11, 1.8], [4.2, -9, 1.8, 8], [-5, 7, 12, 2]], water=[[-13.4, -13, 8, 26]], bridges=[[-10, -0.8, 5.2, 1.6]],
  houses=[H(-0.5, -5, 3, 2.6, "c8553d", IR), H(8.4, -5.6, 3, 2.6, "4a8fb8", IR), H(1, 3.8, 3, 2.6, "e5b33c", IR), H(6.5, 3.8, 3, 2.6, "5fa55a", IR),
          H(9.6, 9.6, 2.6, 2.6, "f4f4f0", "8a2c2c", "교회", spire=True), H(0, 10.4, 3, 1.8, "c8553d", IR)],
  trees=[[10.8, -2.6, "snow"], [11, 2.6, "snow"], [-2.2, -10.6, "snow"], [6, -10.8, "snow"]],
  decor=[["boat", -9, -6, "c85068"], ["boat", -11, 4, "e5b33c"], ["boat", -8, 8, "4a8fb8"], ["rock", 10.8, -10.4, "8a8f96"], ["rock", -3.4, 10.9, "8a8f96"], ["lamp", -2.4, 1.6, ""]],
  chests=[[-9.4, 0], [10.6, 5.8]], npc=[-2.2, -2.0], egg=[3.5, -10.9])
A["5_2"] = dict(name="빙하 호수", gate=GATE_PARK,
  zones=[[-13.4, 6.6, 26.8, 7.8, "4a4a52"], [-13.4, -14.4, 26.8, 3.4, "dfe9ee"]],
  roads=[[-1, -12, 2, 6.4], [-11, -6.2, 22, 1.6], [-11, -6.2, 1.6, 12.4], [9.4, -6.2, 1.6, 12.4], [-11, 4.6, 22, 1.6]], water=[[-9, -4, 18, 7.5]], bridges=[], houses=[],
  trees=[[-11.5, -10, "snow"], [11.5, -10, "snow"], [3, -9.6, "snow"]],
  decor=[["ice", x, z, ""] for x, z in [(-6, -2), (-2, 0.5), (3, -1.5), (6.5, 1.5), (0, 2.4), (-5, 2)]] + [["rock", -6, 9, "3a3a42"], ["rock", 4, 10.5, "3a3a42"], ["rock", 9.5, 8.5, "3a3a42"],
        ["tent", -6.2, -9.4, "e8974d"], ["tent", 6.4, -9.6, "4a8fb8"]],
  chests=[[-0.2, 8.6], [10.6, -8.4]], shard=[10.6, 10.8], egg=[-11.4, 9.6])
# ───────── 산토리니 ─────────
SW, SB = "fcf8ee", "5688b6"
A["6_1"] = dict(name="이아 골목", gate=GATE_ALLEY, zones=[],
  roads=[[-10, -1, 21.6, 2], [-8, -8, 1.8, 7], [-8, -8, 10, 1.6], [0.4, -8, 1.6, 7], [4, 1, 1.6, 5.2], [-9, 4.6, 14.6, 1.6]], water=[[-13.4, 8, 26.8, 6.4]], bridges=[],
  houses=[H(-4, -4.4, 3.2, 2.4, SW, SB, dome=SB), H(5, -5, 3.4, 2.8, SW, "e9e2d2", dome=SB), H(9.4, -8.6, 2.6, 2.4, SW, SB), H(-3.4, 2.8, 3, 1.6, SW, "e9e2d2"),
          H(8.4, 3.4, 3, 2.4, SW, SB, "교회", dome=SB, spire=True), H(-10.6, -4.6, 1.8, 3, SW, "e9e2d2")],
  trees=[],
  decor=[["windmill", -10.4, -9.6, "fcf8ee"], ["windmill", 10.2, 6.3, "fcf8ee"], ["bush", -6.6, 6.9, "d977a8"], ["bush", 2.8, -2.0, "d977a8"], ["bush", 1.4, 3.2, "d977a8"], ["bush", -1.6, -9.2, "d977a8"], ["camel", -0.8, 7.0, "9a948a"]],
  chests=[[-10.8, 2.4], [5.2, 7.2]], npc=[2.4, 2.4], egg=[10.9, -4.6])
A["6_2"] = dict(name="절벽 아래 해변", gate=GATE_PARK,
  zones=[[-13.4, -1.4, 26.8, 5.4, "e8d3a6"]],
  roads=[[-1, -12, 2, 9], [-10, -3, 20, 1.6]], water=[[-13.4, 4, 26.8, 10.4]], bridges=[[3, 3.6, 1.6, 5.4]],
  houses=[H(-6.5, -5.6, 3.6, 2.4, SW, SB, "타베르나")],
  trees=[],
  decor=[["rock", x, z, "a8523c"] for x, z in [(-10, -9.5), (-6.5, -10.2), (-3.4, -9), (3.6, -9.4), (7, -10), (10.6, -8.6), (-10.6, -5.6), (10.8, -4.6)]] +
        [["parasol", -8, 1, "c85068"], ["parasol", -4.5, 1.6, "4a8fb8"], ["parasol", 0.5, 1.2, "e5b33c"], ["parasol", 7.5, 1.4, "c85068"], ["parasol", 10, 0.6, "4a8fb8"],
         ["boat", -8, 6.5, "4a8fb8"], ["boat", 8.5, 7, "c85068"], ["boat", -2, 9.5, "fcf8ee"]],
  chests=[[-10.8, 2.6], [10.8, -6.6]], shard=[3.8, 8.4], egg=[6, -6.2])
# ───────── 런던 ─────────
LW, LR = "9a4a3a", "4a3a34"
A["7_1"] = dict(name="소호 골목", gate=GATE_ALLEY, zones=[],
  roads=[[-10, -1, 21.6, 2], [-7, -9, 1.8, 8], [-7, -9, 12, 1.8], [3.2, -9, 1.8, 17], [-10, 6.2, 13.2, 1.8]], water=[], bridges=[],
  houses=[H(-2.5, -4.6, 3.6, 2.6, LW, LR, "펍"), H(-10, -5, 2, 3, "8a5a4a", LR), H(8, -5.2, 4, 3, "7a2c3c", "2a2a30", "극장"), H(-3.2, 3.4, 3.4, 2.4, "8a5a4a", LR), H(-8.4, 3.4, 3.2, 2.4, LW, LR),
          H(8, 4.6, 3.6, 2.8, LW, LR), H(-3, 10.2, 3.4, 2, "8a5a4a", LR), H(8.6, 10.2, 3, 2, LW, LR)],
  trees=[[10.8, -9.8, "tree"], [-11, 10.6, "tree"], [1, 10.8, "tree"]],
  decor=[["phonebox", -4.9, 1.7, ""], ["phonebox", 5.7, 1.7, ""], ["phonebox", 1.4, 5.4, ""], ["bus", 8.2, 2.1 - 0.2, "c8323a"], ["torii", 4.1, 7.6, ""], ["lamp", 0.4, -1.7, ""], ["lamp", -8.6, -1.7, ""]],
  chests=[[1, -5], [-10.8, 9.4]], npc=[1.5, 2.2], egg=[10.9, 8])
A["7_2"] = dict(name="템스 강변 공원", gate=GATE_PARK, zones=[],
  roads=[[-1, -12, 2, 10.4], [-11, -3.6, 22, 1.6], [-11, 4, 22, 1.6], [6, 5.6, 1.6, 5.4]], water=[[-13.4, -1.5, 26.8, 5]], bridges=[], ferry=[[0, -2.1], [0, 4.1]],
  houses=[H(8.6, -8, 2.4, 2.4, "cdbf9c", "586373", "빅벤", spire=True), H(4, -8.2, 5, 2.6, "cdbf9c", "586373")],
  trees=[[x, z, "tree"] for x, z in [(-11, -9), (-7.5, -9.5), (-4, -8.5), (-11, 7.5), (-2.6, 9.5), (2.6, 10.6), (10.6, 7.8), (10.8, -5.2)]],
  decor=[["wheel", -6, 8.4, ""], ["boat", -8, 1, "c8323a"], ["boat", 7, 0.5, "4a8fb8"], ["bench", -6, -4.6, ""], ["bench", 5, -4.6, ""], ["lamp", -9, -4.4, ""], ["lamp", 9, -4.4, ""], ["lamp", -3.5, 6.2, ""], ["lamp", 3.5, 6.2, ""]],
  chests=[[-10.6, -6.4], [9.6, 10.4]], shard=[6.8, 10.6], egg=[-10.9, 10.9])
# ───────── 시드니 ─────────
YW, YR = "d3b98c", "8a6a4c"
A["8_1"] = dict(name="더 록스 골목", gate=GATE_ALLEY,
  zones=[[-5.6, -5.4, 9.4, 4.2, "p1"]],
  roads=[[-10, -1, 21.6, 2], [-8, -7.4, 2, 13.4], [-8, -7.4, 14, 1.8], [4.2, -7.4, 1.8, 13.4], [-8, 4.2, 14, 1.8]], water=[[-13.4, -13, 26.8, 4.2]], bridges=[],
  houses=[H(-3.6, 2.6, 3.2, 1.8, YW, YR), H(1, 2.6, 3.2, 1.8, "c9a878", YR, "펍"), H(8.6, -4.6, 3, 2.8, YW, YR), H(8.6, 4, 3, 2.8, "c9a878", YR), H(-10.6, -5, 1.6, 3, YW, YR),
          H(-3, 8.6, 3.4, 2.2, "c9a878", YR), H(2.5, 8.6, 3.4, 2.2, YW, YR)],
  trees=[[-11, 9.8, "palm"], [10.8, 9.8, "palm"], [10.8, -7.8, "palm"]],
  decor=[["stall", -4, -3.6, "e8974d"], ["stall", -0.8, -3.6, "4a8fb8"], ["stall", 2.4, -3.6, "5fa55a"], ["arch", -4, -10.4, ""], ["arch", 0, -10.4, ""], ["arch", 4, -10.4, ""], ["boat", -9, -11, "fcf8ee"], ["boat", 9, -10.5, "c85068"]],
  chests=[[-10.8, 2.6], [7.4, 9.6]], npc=[-0.8, -1.9], egg=[-10.6, -7.9])
A["8_2"] = dict(name="유칼립투스 숲", gate=GATE_PARK, zones=[],
  roads=[[-1, -12, 2, 6], [-1, -7.6, 9, 1.6], [6.4, -7.6, 1.6, 8.4], [-8, -0.8, 16, 1.6], [-8, -0.8, 1.6, 9.2], [-8, 6.8, 12, 1.6]], water=[[-13.4, 2.6, 26.8, 1.4]], bridges=[], ferry=[[-7.2, 2.0], [-7.2, 4.6]],
  houses=[],
  trees=[[x, z, "tree"] for x, z in [(-10.5, -10), (-6, -10.5), (-4, -4.5), (3, -10.4), (3.5, -4), (10.6, -4), (10.8, 1.4), (-10.8, -3), (-4.5, 1.9), (1.5, 1.9), (5.5, 1.8), (-11, 6.5), (-4.5, 5.4),
         (1, 5.6), (6, 5.6), (10.5, 6.5), (-10.6, 10.8), (-3, 10.6), (6.5, 10.4), (10.6, 10.6)]],
  decor=[["rock", 8.6, -10.2, "c9a878"], ["rock", 10.4, -10.2, "c9a878"], ["rock", 9.6, -11.6, "c9a878"], ["bush", -2.4, -9.6, "7fa878"], ["bush", 9, 3.2 + 1.6, "7fa878"]],
  chests=[[10.8, -6.6], [9.6, 8.8]], shard=[3.2, 7.6], egg=[-11.3, 0.9])
# ───────── 서울 ─────────
HW, HR = "d5c4a7", "4f565c"
A["9_1"] = dict(name="익선동 골목", gate=GATE_ALLEY, zones=[],
  roads=[[-10, -1, 21.6, 2], [-8, -8.6, 1.6, 16.6], [-3, -8.6, 1.6, 7.6], [2, -8.6, 1.6, 16.6], [7, -8.6, 1.6, 7.6], [-8, -8.6, 16.6, 1.6], [-8, 6.4, 11.6, 1.6]], water=[], bridges=[],
  houses=[H(-4.7, -4.4, 2.8, 2.6, HW, HR, "카페"), H(0.3, -4.4, 2.8, 2.6, "c9b594", HR), H(5.3, -4.4, 2.8, 2.6, HW, HR, "찻집"), H(10.2, -4.6, 2.4, 2.8, "c9b594", HR),
          H(-4.4, 3.6, 3, 2.6, "c9b594", HR), H(-0.6, 3.6, 3, 2.6, HW, HR), H(6.6, 3.6, 3.4, 2.6, HW, HR), H(6.6, 8, 3.4, 2.4, "c9b594", HR), H(-10.4, 4, 1.8, 3, HW, HR)],
  trees=[[-10.8, -10.4, "cherry"], [10.8, -10.4, "cherry"], [10.8, 9.8, "cherry"], [-10.9, -3.5, "cherry"]],
  decor=[["stall", -5, 9.8, "e8974d"], ["stall", -1.4, 9.8, "e8974d"], ["lantern", -5.9, -1.6, ""], ["lantern", 4.1, -1.6, ""], ["lantern", -0.9, 1.6, ""]],
  chests=[[10.4, -8.4], [-10.6, 9.6]], npc=[4.6, 1.9], egg=[5.4, -10.4])
A["9_2"] = dict(name="한강 공원", gate=GATE_PARK,
  zones=[[-4, -1.2, 2, 1.4, "c85068"], [1.5, 0.6, 2, 1.4, "4a8fb8"]],
  roads=[[-1, -12, 2, 7.4], [-11, -4.6, 22, 1.6], [-11, 4.4, 22, 1.6], [-9, -3, 1.6, 7.4], [7.4, -3, 1.6, 7.4]], water=[[-13.4, 7.6, 26.8, 6.8]], bridges=[],
  houses=[H(-5, -8, 3.6, 2.4, "f4f4f0", "5fa55a", "편의점"), H(6, -8.2, 3.2, 2.4, "f4f4f0", "c85068", "치킨집")],
  trees=[[-11.2, -9.8, "cherry"], [2.4, -9.6, "cherry"], [-11.4, -1, "cherry"], [11.2, -1.4, "cherry"], [11, 2.6, "cherry"]],
  decor=[["tent", -5.6, 1.8, "e8974d"], ["tent", 5.2, -1.2, "5fa55a"], ["tent", 4.6, 2.4, "8a5fc0"], ["bus", 9.6, -7.6, "5fa55a"], ["arch", -6, 9.6, ""], ["arch", 0, 9.6, ""], ["arch", 6, 9.6, ""],
         ["bench", -3, 6.7, ""], ["bench", 3, 6.7, ""], ["lamp", -10, 6.6, ""], ["lamp", 10, 6.6, ""]],
  chests=[[11, 6.8], [-11.2, 2.6]], shard=[7.2, 6.9], egg=[-1.6, 0.9])

# ───────── 검증 ─────────
def inr(r, x, z, grow=0.0):
    return r[0] - grow <= x <= r[0] + r[2] + grow and r[1] - grow <= z <= r[1] + r[3] + grow
def solids(a):
    out = []
    for h in a["houses"]: out.append([h["x"] - h["w"] / 2, h["z"] - h["d"] / 2, h["w"], h["d"]])
    for t in a["trees"]: out.append([t[0] - 0.3, t[1] - 0.3, 0.6, 0.6])
    for d in a["decor"]:
        if d[0] in SOLID and not any(inr(w, d[1], d[2]) for w in a["water"]):
            w, h = SOLID[d[0]]; out.append([d[1] - w / 2, d[2] - h / 2, w, h])
    return out
def walk(a, sol, x, z):
    if abs(x) > 12 or abs(z) > 12.5: return False
    for w in a["water"]:
        if inr(w, x, z) and not any(inr(b, x, z, -0.26) for b in a["bridges"]): return False
    return not any(inr(s, x, z, 0.26) for s in sol)
def check(key, a):
    sol = solids(a); errs = []
    pts = {"gate": a["gate"], "chest0": a["chests"][0], "chest1": a["chests"][1], "egg": a["egg"]}
    if "npc" in a: pts["npc"] = a["npc"]
    if "shard" in a: pts["shard"] = a["shard"]
    for n, p in pts.items():
        if not walk(a, sol, p[0], p[1]): errs.append("%s (%s,%s) 걸을 수 없음" % (n, p[0], p[1]))
    step = 0.25; seen = set(); q = collections.deque()
    g = (round(a["gate"][0] / step), round(a["gate"][1] / step)); q.append(g); seen.add(g)
    while q:
        cx, cz = q.popleft()
        for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (cx + dx, cz + dz)
            if n in seen or not walk(a, sol, n[0] * step, n[1] * step): continue
            seen.add(n); q.append(n)
    if "ferry" in a:
        for f in a["ferry"]:
            if not walk(a, sol, f[0], f[1]): errs.append("나루터 (%s,%s) 걸을 수 없음" % (f[0], f[1]))
        other = (round(a["ferry"][1][0] / step), round(a["ferry"][1][1] / step))
        if (round(a["ferry"][0][0] / step), round(a["ferry"][0][1] / step)) not in seen: errs.append("나루터 북쪽에 갈 수 없음")
        if other in seen: errs.append("나루터 없이도 건너갈 수 있음")
        seen.add(other); q.append(other)
        while q:
            cx, cz = q.popleft()
            for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n2 = (cx + dx, cz + dz)
                if n2 in seen or not walk(a, sol, n2[0] * step, n2[1] * step): continue
                seen.add(n2); q.append(n2)
    for n, p in pts.items():
        if (round(p[0] / step), round(p[1] / step)) not in seen: errs.append("%s (%s,%s) 문에서 갈 수 없음" % (n, p[0], p[1]))
    for i, s in enumerate(sol):
        cx, cz = s[0] + s[2] / 2, s[1] + s[3] / 2
        for r in a["roads"]:
            if s[0] < r[0] + r[2] and s[0] + s[2] > r[0] and s[1] < r[1] + r[3] and s[1] + s[3] > r[1]:
                if not any(inr(w, cx, cz) for w in a["water"]): errs.append("구조물 (%.1f,%.1f) 이 길 %s 과 겹침" % (cx, cz, r))
        for j, t in enumerate(sol):
            if j > i and s[0] < t[0] + t[2] and s[0] + s[2] > t[0] and s[1] < t[1] + t[3] and s[1] + s[3] > t[1]:
                errs.append("구조물 (%.1f,%.1f) 과 (%.1f,%.1f) 겹침" % (cx, cz, t[0] + t[2] / 2, t[1] + t[3] / 2))
    return errs

def pick_legend(a, small=False):
    """자연 구역에서 전설 괴물이 잠든 자리: 문에서 갈 수 있고, 길·물건과 떨어진 넓은 빈터."""
    sol = solids(a); step = 0.25; seen = set(); q = collections.deque()
    g = (round(a["gate"][0] / step), round(a["gate"][1] / step)); q.append(g); seen.add(g)
    if "ferry" in a:
        g2 = (round(a["ferry"][1][0] / step), round(a["ferry"][1][1] / step)); q.append(g2); seen.add(g2)
    while q:
        cx, cz = q.popleft()
        for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (cx + dx, cz + dz)
            if n in seen or not walk(a, sol, n[0] * step, n[1] * step): continue
            seen.add(n); q.append(n)
    pts = [a["gate"], a["egg"]] + a["chests"] + ([a["shard"]] if "shard" in a else []) + ([a["npc"]] if "npc" in a else []) + a.get("ferry", [])
    reach = (-0.5, 0, 0.5) if small else (-1.25, -0.5, 0, 0.5, 1.25)
    best = None; score = -1
    for ix in range(-20, 21):
        for iz in range(-20, 21):
            x, z = ix * 0.5, iz * 0.5
            if any((round((x + ox) / step), round((z + oz) / step)) not in seen for ox in reach for oz in reach): continue
            if not small and any(inr(r, x, z, 0.9) for r in a["roads"]): continue
            near = min(((x - p[0]) ** 2 + (z - p[1]) ** 2) ** 0.5 for p in pts)
            if near < 3.0: continue
            far = ((x - a["gate"][0]) ** 2 + (z - a["gate"][1]) ** 2) ** 0.5 + near * 0.5
            if far > score: score = far; best = [x, z]
    return best

if __name__ == "__main__":
    for k in sorted(A):
        if k.endswith("_2"):
            A[k]["legend"] = pick_legend(A[k])
            if A[k]["legend"] is None: print("!! 전설 자리 없음:", k, A[k]["name"])
            else: print("   전설", k, A[k]["name"], A[k]["legend"])
        else:
            A[k]["lost"] = pick_legend(A[k], True)
            if A[k]["lost"] is None: print("!! 잃어버린 물건 자리 없음:", k)
            else: print("   분실물", k, A[k]["name"], A[k]["lost"])
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    bad = 0
    for k in sorted(A):
        e = check(k, A[k])
        if e:
            bad += len(e); print(k, A[k]["name"])
            for line in e: print("   !", line)
    print("구역 %d곳 · 문제 %d건" % (len(A), bad))
    body = json.dumps(A, ensure_ascii=False, indent=1)
    open(os.path.join(root, "src", "area_data.gd"), "w", encoding="utf-8").write("extends RefCounted\n# tools/areas.py 가 만든 파일 — 직접 고치지 말고 areas.py 를 고친 뒤 다시 생성할 것\nconst SOLID = %s\nconst AREAS = %s\n" % (json.dumps({k: list(v) for k, v in SOLID.items()}), body))
    open(os.path.join(root, "mock", "areas.js"), "w", encoding="utf-8").write("const AREAS=%s;\nconst SOLID=%s;\n" % (json.dumps(A, ensure_ascii=False), json.dumps(SOLID)))
    sys.exit(1 if bad else 0)
