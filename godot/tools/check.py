# -*- coding: utf-8 -*-
import sys, os, re, io
bad = 0
def err(*a):
    global bad; bad += 1; print('  !', *a)
for fn in sorted(os.listdir(sys.argv[1])):
    if not fn.endswith('.gd'): continue
    lines = io.open(os.path.join(sys.argv[1], fn), encoding='utf-8').read().split('\n')
    depth = 0
    for n, ln in enumerate(lines, 1):
        if not ln.strip(): continue
        at_top = (depth == 0)
        ind = len(ln) - len(ln.lstrip(' '))
        if '\t' in ln: err(fn, n, '탭 섞임')
        if at_top and ind % 4: err(fn, n, '들여쓰기 %d칸' % ind, ln.strip()[:50])
        code = re.sub(r'"(\\.|[^"\\])*"', '""', ln)
        code = re.sub(r"'(\\.|[^'\\])*'", "''", code)
        code = code.split('#')[0]
        if code.count('"') % 2: err(fn, n, '따옴표 홀수', ln.strip()[:60])
        depth += code.count('(') - code.count(')') + code.count('[') - code.count(']') + code.count('{') - code.count('}')
        if depth < 0: err(fn, n, '괄호 과다 닫힘', ln.strip()[:50]); depth = 0
    if depth != 0: err(fn, '파일 끝 괄호 불균형', depth)
print('괄호/들여쓰기 문제 %d건\n' % bad)

# main.gd 안에서 내가 부른 이름들이 실제로 있는지
src = io.open(os.path.join(sys.argv[1], 'main.gd'), encoding='utf-8').read()
funcs = set(re.findall(r'^func (\w+)', src, re.M))
members = set(re.findall(r'^(?:var|const) (\w+)', src, re.M))
need_f = ['exp_needed','party_max','pet','pet_bonus','pet_name','gain_exp','befriend',
          'cycle_pet','spawn_pet','move_pet','dish_damage','salary_damage','candy_heal',
          'toast','chime','burst','finish_wild_battle','claim_battle_win','save_progress','restart']
need_v = ['level','xp','pets','pet_active','pet_node','pet_path','PET_ROLE','LEVEL_MAX','PARTY_HP','creatures']
print('main.gd 함수 누락:', [f for f in need_f if f not in funcs] or '없음')
print('main.gd 변수 누락:', [v for v in need_v if v not in members] or '없음')
w = io.open(os.path.join(sys.argv[1], 'world.gd'), encoding='utf-8').read()
wf = set(re.findall(r'^func (\w+)', w, re.M))
print('world.gd 필요 함수:', {f: (f in wf) for f in ['creature','can_walk','surface_height']})
print('pets/level 참조 횟수:', len(re.findall(r'\bpet_bonus\(', src)), len(re.findall(r'\blevel\b', src)))
