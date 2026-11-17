# -*- coding: utf-8 -*-
# 들여쓰기로 스코프를 추적한다. GDScript 4 는 "바깥 블록의 지역변수"를
# 안쪽 블록에서 다시 var 선언하면 에러(형제 분기끼리는 허용).
import sys, os, re, io
bad = 0
VAR = re.compile(r'(?:^|[;(]\s*)var\s+([A-Za-z_]\w*)')
for fn in sorted(os.listdir(sys.argv[1])):
    if not fn.endswith('.gd'): continue
    lines = io.open(os.path.join(sys.argv[1], fn), encoding='utf-8').read().split('\n')
    stack = []          # [(indent, {name: line})]
    func = None
    for n, ln in enumerate(lines, 1):
        if not ln.strip(): continue
        ind = len(ln) - len(ln.lstrip(' '))
        st = ln.strip()
        if st.startswith('func '):
            func = st[5:].split('(')[0]; stack = [(ind, {})]
            # 인자도 스코프에 넣는다
            args = re.findall(r'(\w+)\s*:', st[st.find('('):st.rfind(')')] if '(' in st else '')
            for a in args: stack[0][1][a] = n
            continue
        if func is None: continue
        while len(stack) > 1 and ind <= stack[-1][0]: stack.pop()
        for m in VAR.finditer(st):
            v = m.group(1)
            for lvl, names in stack:
                if v in names:
                    print('  ! %s  func %s · %d행: var %s — %d행 스코프와 충돌' % (fn, func, n, v, names[v]))
                    bad += 1; break
            else:
                stack[-1][1][v] = n
        if st.endswith(':') and not st.startswith(('func ','class ')):
            stack.append((ind, {}))
    # (for 루프 변수는 생략 — 원본에서 재사용이 흔하고 GDScript 가 허용)
print('스코프 충돌 %d건' % bad)
