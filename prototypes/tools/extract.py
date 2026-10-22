import sys, os, re, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from docparse import parse
D = sys.argv[1]
SUBJ = {
 "kor": {"일반": ["화법과 언어","독서와 작문","문학"], "진로": ["주제 탐구 독서","문학과 영상","직무 의사소통"], "융합": ["독서 토론과 글쓰기","매체 의사소통","언어생활 탐구"]},
 "math": {"일반": ["대수","미적분I","확률과 통계"], "진로": ["기하","미적분II","경제 수학","인공지능 수학","직무 수학"], "융합": ["수학과 문화","실용 통계","수학과제 탐구"]},
 "eng": {"일반": ["영어I","영어II","영어 독해와 작문"], "진로": ["영미 문학 읽기","영어 발표와 토론","심화 영어","심화 영어 독해와 작문","직무 영어"], "융합": ["실생활 영어 회화","미디어 영어","세계 문화와 영어"]},
 "soc": {"일반": ["세계시민과 지리","세계사","사회와 문화","현대사회와 윤리"], "진로": ["한국지리 탐구","도시의 미래 탐구","동아시아 역사 기행","정치","법과 사회","경제","윤리와 사상","인문학과 윤리","국제 관계의 이해"], "융합": ["여행지리","역사로 탐구하는 현대 세계","사회문제 탐구","금융과 경제생활","윤리문제 탐구","기후변화와 지속가능한 세계"]},
 "sci": {"일반": ["물리학","화학","생명과학","지구과학"], "진로": ["역학과 에너지","전자기와 양자","물질과 에너지","화학 반응의 세계","세포와 물질대사","생물의 유전","지구시스템과학","행성우주과학"], "융합": ["과학의 역사와 문화","기후변화와 환경생태","융합과학 탐구"]},
 "info": {"일반": ["정보"], "진로": ["인공지능 기초","데이터 과학"], "융합": ["소프트웨어와 생활"]},
}
def norm(s):
    s = s.replace('Ⅰ','I').replace('Ⅱ','II').replace('Ⅲ','III').replace('ⅰ','I')
    return re.sub(r'[\s·ㆍ・,./()\[\]]', '', s)
NAMES = []
for k, cats in SUBJ.items():
    for cat, lst in cats.items():
        for n in lst: NAMES.append((norm(n), n, k, cat))
NAMES.sort(key=lambda x: -len(x[0]))
def find_subjects(text):
    t = norm(text); found = []
    for nn, n, k, cat in NAMES:
        i = t.find(nn)
        while i >= 0:
            # avoid "물리학" inside "물리학I" (2015) is fine; avoid substring of longer already matched
            found.append(n); t = t[:i] + '#' * len(nn) + t[i+len(nn):]
            i = t.find(nn)
    return found

SEM_RE = re.compile(r'^([123])\s*[-–]\s*([12])$')
SEM2_RE = re.compile(r'^([123])\s*학년\s*([12])\s*학기$')
def sem_ranges(cells):
    out = []
    for r, c, rs, cs, t in cells:
        tt = t.replace(' ', '')
        m = SEM_RE.match(tt) or SEM2_RE.match(tt)
        if m: out.append((int(m.group(1)), c, c + cs, r))
    if len({g for g, *_ in out}) >= 2: return out
    # grade header + semester sub-header
    grades = []
    for r, c, rs, cs, t in cells:
        m = re.match(r'^([123])학년$', t.replace(' ', ''))
        if m: grades.append((int(m.group(1)), c, c + cs, r))
    out = []
    for g, c0, c1, r0 in grades:
        for r, c, rs, cs, t in cells:
            if r > r0 and r <= r0 + 2 and c0 <= c < c1 and re.match(r'^[12]학기$', t.replace(' ', '')):
                out.append((g, c, c + cs, r))
    return out

def analyze(cells):
    sr = sem_ranges(cells)
    if not sr: return None
    hdr_row = max(r for *_, r in sr)
    res = {}
    byrow = {}
    for cell in cells: byrow.setdefault(cell[0], []).append(cell)
    for r, c, rs, cs, t in cells:
        if r <= hdr_row: continue
        subs = find_subjects(t)
        if not subs: continue
        g_in = [g for g, c0, c1, _ in sr if c0 <= c < c1]
        if g_in:
            grades = {g_in[0]}
        else:
            grades = set()
            for rr in range(r, r + rs):
                for r2, c2, rs2, cs2, t2 in byrow.get(rr, []):
                    for g, c0, c1, _ in sr:
                        if c0 <= c2 < c1 and t2.strip() and re.search(r'[0-9OoＯ○●◯√]', t2):
                            grades.add(g)
        if not grades and not g_in:
            # inherit from a 택N group cell spanning this row
            for r2, c2, rs2, cs2, t2 in cells:
                if rs2 > 1 and r2 <= r < r2 + rs2 and '택' in t2 and c2 > c:
                    for rr in range(r2, r2 + rs2):
                        for r3, c3, rs3, cs3, t3 in byrow.get(rr, []):
                            for g, c0, c1, _ in sr:
                                if c0 <= c3 < c1 and re.search(r'[0-9]', t3): grades.add(g)
        for s in subs:
            res.setdefault(s, set()).update(grades)
    return res


YR = re.compile(r'(202[3-7])\s*학년도?\s*(?:입학생|신입생|입학자)|(202[3-7])\s*입학생|(202[3-7])\s*학년도\s*1\s*학년\b|1학년\s*\(\s*(202[3-7])')
out = {}
for line in open(os.path.join(D, 'ids.txt'), encoding='utf-8').read().splitlines():
    sid, nm = line.split(None, 1)
    files = sorted(f for f in os.listdir(os.path.join(D, 'dl')) if f.startswith(sid) and not f.endswith('.html'))
    tabs = []
    for f in files:
        try: blocks = parse(os.path.join(D, 'dl', f))
        except Exception as e:
            print(nm, f, 'PARSE ERR', e); continue
        sec = None
        for b in blocks:
            text = b[1] if b[0] == 'p' else ' '.join(x[4] for x in b[1])
            if b[0] == 'p' or len(b[1]) < 6 or len(text) < 200:
                m = YR.search(text)
                if m: sec = int(next(g for g in m.groups() if g))
                continue
            if re.search(r'안전|교육시간|평가 ?방법|수행평가', text): continue
            a = analyze(b[1])
            if not a: continue
            twenty22 = any(k in a for k in ('대수','미적분I','영어I','물리학','세계시민과 지리','역학과 에너지','화법과 언어'))
            if not twenty22: continue
            tabs.append((sec, f, a))
    if not tabs:
        print(nm, 'NO TABLE'); continue
    pick = [t for t in tabs if t[0] == 2026]
    mode = '2026'
    if not pick:
        mode = 'fallback-last'; pick = [tabs[-1]]
    merged = {}
    for _, f, a in pick:
        for k, v in a.items(): merged.setdefault(k, set()).update(v)
    out[nm] = {'mode': mode, 'files': sorted({t[1] for t in pick}), 'secs': [t[0] for t in tabs],
               'subjects': {k: sorted(v) for k, v in merged.items()}}
    g2 = sorted(k for k, v in merged.items() if 2 in v); g3 = sorted(k for k, v in merged.items() if 3 in v)
    print(f"{nm}: mode={mode} tabs={[t[0] for t in tabs]} n={len(merged)} g2={len(g2)} g3={len(g3)} nograde={[k for k,v in merged.items() if not v]}")
json.dump(out, open(os.path.join(D, 'subjects.json'), 'w'), ensure_ascii=False, indent=1)
