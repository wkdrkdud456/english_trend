import os
CYO=float(os.environ.get('CYO',3)); SB=float(os.environ.get('SB',1.0)); SL=float(os.environ.get('SL',0.09)); N3=1.3; U0=0.5; U1=0.0; ATK=[0,1,2,4,7]; GS4=60; LD=4; PH2=0.5; SKC=float(os.environ.get('SKC',0.5)); VB=float(os.environ.get('VB',1.0))
import math, sys, random
def sim(c, build, P, cyc=0, legend=False, seed=1):
    random.seed(seed)
    BH, BG, HG = P
    pos = c + CYO * cyc
    L = min(40, int(3 + 2.6 * c)) if not cyc else min(40, int(27 + 1.4 * c))
    ps = c + cyc * 10
    e = min(5, c // 2) if not cyc else 5
    rank = 0 if L < 10 else (3 if L >= 30 else 2 if L >= 20 else 1)
    job = 0 if rank == 0 else (1 if build == 'strike' else 2)
    sp = L - 1 + c + c // 2 + cyc * 25
    order = (['strike', 'strike', 'soap', 'coffee', 'guard'] if build == 'strike' else ['soak', 'soap', 'soak', 'strike', 'coffee'])
    sk = dict(strike=1, soak=1, soap=1, guard=1, coffee=1, team=1); need = dict(strike=1, guard=1, team=1, soak=3, soap=5, coffee=8)
    i = 0; guardn = 0
    while sp > 0 and guardn < 400:
        k = order[i % len(order)]; i += 1; guardn += 1
        if sk[k] < 10 and L >= need[k]: sk[k] += 1; sp -= 1
    tier = 0 if c == 0 and not cyc else 1 if c < 3 and not cyc else 2 if c < 6 and not cyc else 3
    enh = 1 + 0.2 * e
    atk = math.ceil(ATK[tier] * enh) if build == 'strike' else 0
    if cyc and build == 'strike': atk = math.ceil(ATK[4] * enh)
    gsoak = (math.ceil([0, 15, 30, 50][tier] * enh) if build == 'soak' else 0)
    if cyc and build == 'soak': gsoak = math.ceil(GS4 * enh)
    fuse = 1 if (build == 'soak' and (tier == 3 or rank >= 3)) else 2
    ghp = math.ceil(([0, 8, 18, 32][tier] + (6 if tier == 3 else 0)) * enh) if not cyc else math.ceil(67 * enh)
    team = min(6, 3 + ps // 5 + (1 if cyc >= 2 else 0)); petdish = 2 * (team // 2)
    crit = 0.08 + (0.10 if job == 1 else 0); cm = 1.8 if job == 1 and rank >= 2 else 1.5
    def dish(h): return [3, 3, 2, 2, 2][min(h, 4)] + ps // 3 + (L - 1) // LD + (petdish + 1) // 2 + atk + int(sk['strike'] * SKC) + (rank if job == 1 else 0)
    hits = (4 if sk['strike'] >= 10 else 3) + (1 if job == 1 and rank >= 3 else 0)
    def soakd(): return int((dish(0) + dish(1) + dish(2)) * (SB + SL * (sk['soak'] - 1)) * (1 + gsoak / 100 + (0.15 * rank if job == 2 else 0)))
    soapm = 1.4 + 0.04 * (sk['soap'] - 1); cofm = 2.0 + 0.1 * (sk['coffee'] - 1)
    maxhp = 36 + ps * 3 + (L - 1) * 2 + ghp + min(10, c + cyc * 10) * 3
    gheal = 3 + ps // 3 + sk['guard'] - 1 + 2
    ehp = BH * BG ** pos; heavy = 13 * HG ** pos; light = 6 * HG ** pos
    if cyc:
        CY0 = float(os.environ.get('CY0', 6.5)); CBG = float(os.environ.get('CBG', 1.13)); CHG = float(os.environ.get('CHG', 1.06))
        ehp = BH * BG ** (CY0 + cyc - 1) * CBG ** c; heavy = 13 * HG ** (CY0 + cyc - 1) * CHG ** c; light = 6 * HG ** (CY0 + cyc - 1) * CHG ** c
    if legend: ehp *= 1.7; heavy *= 1.2; light *= 1.2
    ehp = int(ehp)
    trait = '' if not cyc else ['hard', 'lid', 'rage', 'regen'][c % 4]
    full = ehp; phase = 0
    hp = maxhp; en = 1; bomb = 0; bmul = 1.0; vuln = 0; charge = False; candy = 5; turn = 0
    ult = lambda k: job > 0 and rank > k and sk[[['strike', 'soap', 'coffee'], ['soak', 'soap', 'coffee']][job - 1][k]] >= 10
    while hp > 0 and turn < 80:
        turn += 1; hv = turn % 3 == 0; guard = False; dmg = 0
        kick = bomb > 0 and turn % 2 == 0
        inc = (heavy if hv else light) * (1.4 if trait == 'rage' and ehp * 2 < full else 1) * (1.25 if phase else 1)
        boost = 1 + ((soapm - 1) if vuln > 0 else 0) + ((cofm - 1) if charge else 0)
        hard = 0.6 if trait == 'hard' else 1
        if hp < maxhp * 0.35 and candy > 0: candy -= 1; hp = min(maxhp, hp + 16 + ps + L - 1 + 6)
        elif (hv and hp < inc * 2) or kick: guard = True; en = min(3, en + 1); hp = min(maxhp, hp + gheal)
        elif ult(2) and en >= 3:
            en -= 3
            if job == 1: dmg = int(8 * (dish(1) + rank) * VB * hard * boost * cm)
            else: dmg = int(soakd() * N3 * boost)
            charge = False
        elif ult(0) and en >= 2:
            en -= 2
            if job == 1: dmg = int(5 * (dish(1) + rank) * VB * hard * boost * (1 + crit * (cm - 1)))
            else:
                dmg = int(soakd() * (U0 + U1 * rank) * boost) + (int(soakd() * bmul) if bomb > 0 else 0); bomb = 0
            charge = False
        elif L >= 5 and en >= 2 and vuln == 0 and bomb == 0 and sk['soap'] >= 4: en -= 1; vuln = 3
        elif build == 'soak' and L >= 3 and en >= 1 and bomb == 0: en -= 1; bomb = fuse; bmul = 1.0
        elif L >= 8 and en == 0 and not charge: charge = True; en = min(3, en + 2)
        else:
            dmg = int(sum(dish(h) for h in range(hits)) * hard * boost * (1 + crit * (cm - 1))); charge = False; en = min(3, en + 1)
        ehp -= dmg
        def dead():
            nonlocal ehp, full, phase, trait
            if ehp > 0: return False
            if cyc and not legend and phase == 0:
                phase = 1; full = int(full * PH2); ehp = full; return False
            return True
        if dead(): break
        if kick and not guard: bmul *= 0.5
        hp -= math.ceil(inc * 0.25) if guard else math.ceil(inc)
        vuln = max(0, vuln - 1)
        if bomb > 0:
            bomb -= 1
            if bomb == 0:
                ehp -= int(soakd() * bmul * (0.6 if trait == 'lid' else 1) * (soapm if vuln > 0 else 1)); bmul = 1.0
                if job == 2 and rank >= 2: hp = min(maxhp, hp + int(maxhp * 0.05))
                if dead(): break
        if trait == 'regen': ehp = min(full, ehp + int(full * 0.04))
    return L, int(BH * BG ** pos), turn, max(0, int(hp)), maxhp
P = tuple(float(x) for x in sys.argv[1:4]) if len(sys.argv) > 3 else (120, 1.31, 1.15)
for cyc in (0, 1):
    print('== %d회차 ==' % (cyc + 1))
    for c in range(10):
        row = '도시%d' % c
        for b in ('strike', 'soak'):
            r = sim(c, b, P, cyc); l = sim(c, b, P, cyc, True)
            row += ' | %s Lv%2d 보스 %2d턴 %3d/%3d 전설 %2d턴 %3d' % ('연타' if b == 'strike' else '냄비', r[0], r[2], r[3], r[4], l[2], l[3])
        print(row)
