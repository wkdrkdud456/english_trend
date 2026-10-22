import subprocess, re, sys, os, time, json, urllib.parse
D = sys.argv[1]; S = "https://www.schoolinfo.go.kr"; CJ = os.path.join(D, "cj.txt")
def dec(b):
    for e in ("utf-8", "cp949"):
        try: return b.decode(e)
        except Exception: pass
    return b.decode("utf-8", "ignore")
res = {}
for line in open(os.path.join(D, "ids.txt"), encoding="utf-8").read().splitlines():
    sid, nm = line.split(None, 1)
    form = {"GS_HANGMOK_CD": "06", "GS_HANGMOK_NO": "13-다", "GS_HANGMOK_NM": "졸업생의 진로 현황", "GS_BURYU_CD": "JG040",
            "JG_BURYU_CD": "JG130", "JG_HANGMOK_CD": "52", "JG_GUBUN": "1", "JG_YEAR2": "2026", "SHL_IDF_CD": sid, "GS_TYPE": "Y",
            "JG_YEAR": "2026", "CHOSEN_JG_YEAR": "2026", "PRE_JG_YEAR": "2026"}
    out = os.path.join(D, "dl", sid + ".b06.html")
    for i in range(4):
        r = subprocess.run(["curl", "-sS", "-m", "25", "-A", "Mozilla/5.0", "-b", CJ, "-o", out, "-X", "POST", S + "/ei/pp/Pneipp_b06_s0p.do", "--data", urllib.parse.urlencode(form)], capture_output=True)
        if r.returncode == 0 and os.path.getsize(out) > 1000: break
        time.sleep(2 * (i + 1))
    h = dec(open(out, "rb").read())
    t = re.sub(r'<script.*?</script>', '', h, flags=re.S); t = re.sub(r'<[^>]+>', ' ', t); t = re.sub(r'&nbsp;', '', t); t = re.sub(r'\s+', ' ', t)
    ym = re.search(r'\((\d)차\) (\d{4})년 (\d\d)월', t)
    m = re.search(r'합계 ([\d,]+) ([\d,]+) ([\d,]+) ([\d,]+) ([\d,]+) ([\d,]+) ([\d,]+) ([\d,]+) ([\d,]+) 비율 ([\d.]+) ([\d.]+) ([\d.]+) ([\d.]+) ([\d.]+) ([\d.]+) ([\d.]+) ([\d.]+)', t)
    if m:
        g = m.groups()
        res[nm] = {"grads": int(g[0].replace(',', '')), "jc": float(g[9]), "univ": float(g[10]), "abroad": float(g[11]), "advance": float(g[14]), "job": float(g[15]), "etc": float(g[16]), "as_of": f"{ym.group(2)}.{ym.group(3)}" if ym else None}
    else:
        res[nm] = {"err": t[300:600]}
    print(nm, res[nm], flush=True); time.sleep(1)
json.dump(res, open(os.path.join(D, "grad.json"), "w"), ensure_ascii=False, indent=1)
