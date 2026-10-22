import subprocess, re, sys, os, time, json, urllib.parse
D = sys.argv[1]  # scratchpad dir
S = "https://www.schoolinfo.go.kr"
CJ = os.path.join(D, "cj.txt")
OUT = os.path.join(D, "dl")
os.makedirs(OUT, exist_ok=True)

def curl(args, out, tries=4):
    for i in range(tries):
        r = subprocess.run(["curl", "-sS", "-m", "25", "-A", "Mozilla/5.0", "-b", CJ, "-c", CJ, "-o", out, *args], capture_output=True)
        if r.returncode == 0 and os.path.getsize(out) > 0:
            return True
        time.sleep(2 * (i + 1))
    return False

def dec(b):
    for e in ("utf-8", "cp949"):
        try: return b.decode(e)
        except Exception: pass
    return b.decode("utf-8", "ignore")

schools = [l.split(None, 1) for l in open(os.path.join(D, "ids.txt"), encoding="utf-8").read().splitlines()]
res = {}
for sid, nm in schools:
    page = os.path.join(OUT, sid + ".b14.html")
    form = {"GS_HANGMOK_CD": "14", "GS_HANGMOK_NO": "2-가", "GS_HANGMOK_NM": "학교교육과정 편성ㆍ운영 및 평가에 관한 사항",
            "GS_BURYU_CD": "JG100", "JG_BURYU_CD": "JG020", "JG_HANGMOK_CD": "05", "JG_GUBUN": "1", "JG_YEAR2": "2026",
            "SHL_IDF_CD": sid, "GS_TYPE": "Y", "JG_YEAR": "2026", "CHOSEN_JG_YEAR": "2026", "PRE_JG_YEAR": "2026"}
    ok = curl(["-X", "POST", S + "/ei/pp/Pneipp_b14_s0p.do", "--data", urllib.parse.urlencode(form)], page)
    if not ok:
        print(nm, "PAGE FAIL", flush=True); continue
    h = dec(open(page, "rb").read())
    ch = re.search(r'name="JG_CHASU" value="(\d+)"', h)
    files = re.findall(r"getEiFile14\('(\d+)'\);\"[^>]*>\s*([^<]+?)\s*<", h)
    if not files:
        files = [(m, "") for m in re.findall(r"getEiFile14\('(\d+)'\)", h)]
    names = re.findall(r'>\s*([^<>]+?\.(?:hwpx|hwp|pdf|xlsx|docx|zip))\s*\(', h)
    got = []
    for idx, (seq, _) in enumerate(dict.fromkeys(files)):
        fn = names[idx] if idx < len(names) else f"file{seq}"
        ext = fn.rsplit(".", 1)[-1] if "." in fn else "bin"
        dst = os.path.join(OUT, f"{sid}.{seq}.{ext}")
        q = urllib.parse.urlencode({"SHL_IDF_CD": sid, "JG_BURYU_CD": "JG020", "JG_HANGMOK_CD": "05", "JG_GUBUN": "1",
                                    "JG_YEAR": "2026", "JG_CHASU": ch.group(1) if ch else "1", "USE_YN": "Y", "FILE_SEQ": seq})
        if curl([S + "/servlets/EiFileDownLoad.do?" + q], dst):
            got.append((fn, dst, os.path.getsize(dst)))
    res[sid] = {"name": nm, "files": got}
    print(nm, got, flush=True)
    time.sleep(1)
json.dump(res, open(os.path.join(D, "files.json"), "w"), ensure_ascii=False, indent=1)
