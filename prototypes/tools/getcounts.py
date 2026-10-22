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
    form = {"GS_HANGMOK_CD": "03", "GS_HANGMOK_NO": "3-가-3", "GS_HANGMOK_NM": "학년별·학급별 학생수", "GS_BURYU_CD": "JG010",
            "JG_BURYU_CD": "JG030", "JG_HANGMOK_CD": "09", "JG_GUBUN": "1", "JG_YEAR2": "2026", "SHL_IDF_CD": sid, "GS_TYPE": "Y",
            "JG_YEAR": "2026", "CHOSEN_JG_YEAR": "2026", "PRE_JG_YEAR": "2026"}
    out = os.path.join(D, "dl", sid + ".b03.html")
    for i in range(4):
        r = subprocess.run(["curl", "-sS", "-m", "25", "-A", "Mozilla/5.0", "-b", CJ, "-o", out, "-X", "POST", S + "/ei/pp/Pneipp_b03_s0p.do", "--data", urllib.parse.urlencode(form)], capture_output=True)
        if r.returncode == 0 and os.path.getsize(out) > 1000: break
        time.sleep(2 * (i + 1))
    h = dec(open(out, "rb").read())
    t = re.sub(r'<script.*?</script>', '', h, flags=re.S); t = re.sub(r'<[^>]+>', ' ', t); t = re.sub(r'\s+', ' ', t)
    m = re.search(r'전체학생 남학생 여학생 전체학생 남학생 여학생 전체학생 남학생 여학생 전체학생 남학생 여학생 전체학생 ([\d,]+) ([\d,]+) ([\d,]+) ([\d,]+) ([\d,]+) ([\d,]+) ([\d,]+) ([\d,]+) ([\d,]+)', t)
    cls = {g: len(set(re.findall(rf'\b{g}-\d\d', t))) for g in (1, 2, 3)}
    if m:
        v = [int(x.replace(',', '')) for x in m.groups()]
        res[nm] = {"g1": v[2], "g2": v[5], "g3": v[8], "g1m": v[0], "g1f": v[1], "classes": cls}
    else:
        res[nm] = {"err": t[:200]}
    print(nm, res[nm], flush=True); time.sleep(1)
json.dump(res, open(os.path.join(D, "counts.json"), "w"), ensure_ascii=False, indent=1)
