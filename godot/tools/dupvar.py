# -*- coding: utf-8 -*-
# 같은 함수 안에서 var 를 두 번 선언하면 GDScript 는 파싱 에러를 낸다
import sys, os, re, io
bad = 0
for fn in sorted(os.listdir(sys.argv[1])):
    if not fn.endswith('.gd'): continue
    lines = io.open(os.path.join(sys.argv[1], fn), encoding='utf-8').read().split('\n')
    func, seen = None, {}
    for n, ln in enumerate(lines, 1):
        st = ln.strip()
        if st.startswith('func '):
            func = st[5:].split('(')[0]; seen = {}
            continue
        if func is None: continue
        for m in re.finditer(r'(?:^|[;:(]\s*)var\s+([A-Za-z_]\w*)', ln.strip()):
            v = m.group(1)
            if v in seen:
                print('  ! %s  func %s: var %s 중복 (%d행, 먼저 %d행)' % (fn, func, v, n, seen[v]))
                bad += 1
            else:
                seen[v] = n
print('중복 선언 %d건' % bad)
