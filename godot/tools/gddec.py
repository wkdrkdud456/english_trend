# Godot 4 .gdc (TOKENIZER_VERSION 101) -> .gd 복원
import sys, os, struct, zstandard

NAMES = ["Empty","Annotation","Identifier","Literal","<","<=",">",">=","==","!=",
"and","or","not","&&","||","!","&","|","~","^","<<",">>","+","-","*","**","/","%",
"=","+=","-=","*=","**=","/=","%=","<<=",">>=","&=","|=","^=",
"if","elif","else","for","while","break","continue","pass","return","match","when",
"as","assert","await","breakpoint","class","class_name","const","enum","extends","func",
"in","is","namespace","preload","self","signal","static","super","trait","var","void","yield",
"[","]","{","}","(",")",",",";",".","..","...",":","$","->","_",
"Newline","Indent","Dedent","PI","TAU","INF","NaN","VCS conflict marker","`","?","Error","EOF"]
T = {n: i for i, n in enumerate(NAMES)}
ANNOTATION, IDENTIFIER, LITERAL, ERROR = 1, 2, 3, T["Error"]

FLAG64 = 1 << 16
def dec_variant(b, o):
    hdr = struct.unpack_from('<I', b, o)[0]; o += 4
    t = hdr & 0xFF; fl = hdr
    if t == 0: return None, o
    if t == 1:
        v = struct.unpack_from('<I', b, o)[0]; return bool(v), o + 4
    if t == 2:
        if fl & FLAG64: return struct.unpack_from('<q', b, o)[0], o + 8
        return struct.unpack_from('<i', b, o)[0], o + 4
    if t == 3:
        if fl & FLAG64: return struct.unpack_from('<d', b, o)[0], o + 8
        return struct.unpack_from('<f', b, o)[0], o + 4
    if t in (4, 21, 22):                      # String / StringName / NodePath
        ln = struct.unpack_from('<I', b, o)[0]; o += 4
        s = b[o:o+ln].decode('utf-8', 'replace'); o += ln + ((4 - ln % 4) % 4)
        return s, o
    raise ValueError('variant type %d @%d' % (t, o))

def gdstr(s):
    out = s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\t', '\\t').replace('\r', '\\r')
    return '"' + out + '"'

def num(v):
    if v is None: return 'null'
    if isinstance(v, bool): return 'true' if v else 'false'
    if isinstance(v, int): return str(v)
    if isinstance(v, float):
        if v != v: return 'NAN'
        if v == int(v) and abs(v) < 1e16: return '%.1f' % v
        return repr(round(v, 6))
    return gdstr(v)

# 붙여 쓰는 게 자연스러운 자리
CLOSERS = {T[x] for x in [',', ')', ']', '}', ':', ';', '.']}
OPENERS = {T['('], T['[']}            # 앞이 값이면 호출/첨자라 붙이고, 아니면 띄운다
VALUE_END = {IDENTIFIER, LITERAL, T[')'], T[']'], T['self'] if 'self' in T else IDENTIFIER,
             T['super'] if 'super' in T else IDENTIFIER, T['}']}
NO_SPACE_AFTER = {T['('], T['['], T['.'], T['$']}

def load(path):
    b = open(path, 'rb').read()
    assert b[:4] == b'GDSC'
    dsz = struct.unpack_from('<I', b, 8)[0]
    raw = zstandard.ZstdDecompressor().decompress(b[12:], max_output_size=max(dsz, 1) * 4)
    idc, cc, tlc, tc = struct.unpack_from('<IIII', raw, 0)
    o = 16
    ids = []
    for _ in range(idc):
        ln = struct.unpack_from('<I', raw, o)[0]; o += 4
        cs = bytearray(raw[o:o+ln*4]); o += ln * 4
        for k in range(len(cs)): cs[k] ^= 0xB6
        ids.append(''.join(chr(struct.unpack_from('<I', cs, j*4)[0]) for j in range(ln)))
    consts = []
    for _ in range(cc):
        v, o = dec_variant(raw, o); consts.append(v)
    lines, cols = {}, {}
    for _ in range(tlc):
        i, v = struct.unpack_from('<II', raw, o); o += 8; lines[i] = v
    for _ in range(tlc):
        i, v = struct.unpack_from('<II', raw, o); o += 8; cols[i] = v
    toks = []
    for _ in range(tc):
        first = raw[o]
        if first & 0x80:
            tt = struct.unpack_from('<I', raw, o)[0]; o += 4
        else:
            tt = first; o += 1
        ln = struct.unpack_from('<I', raw, o)[0]; o += 4
        toks.append((tt & 0x7F, tt >> 8, ln))
    assert o == len(raw), (o, len(raw))
    return ids, consts, lines, cols, toks

def text(tt, idx, ids, consts):
    if tt in (IDENTIFIER, ANNOTATION): return ids[idx]
    if tt in (LITERAL, ERROR): return num(consts[idx])
    return NAMES[tt]

def decompile(path):
    ids, consts, lines, cols, toks = load(path)
    out, cur, curline, indent = [], [], None, 0
    for i, (tt, idx, ln) in enumerate(toks):
        if tt in (T['Newline'], T['Indent'], T['Dedent'], T['EOF']): continue
        if curline is None:
            curline = ln; indent = (cols.get(i, 1) - 1)
        elif ln != curline:
            out.append((indent, cur)); cur = []
            # 빈 줄 보존
            for _ in range(ln - curline - 1): out.append((0, []))
            curline = ln
            if i in cols: indent = cols[i] - 1
        cur.append((tt, text(tt, idx, ids, consts)))
    if cur: out.append((indent, cur))
    src = []
    for ind, row in out:
        if not row: src.append(''); continue
        s = ''
        for j, (tt, tx) in enumerate(row):
            if j == 0: s = tx; continue
            ptt, ptx = row[j-1]
            if tt in OPENERS:
                glue = ptt in VALUE_END
            elif tt in CLOSERS:
                glue = True
            else:
                glue = ptt in NO_SPACE_AFTER
            if ptt in (ANNOTATION,) and tt == T['(']: glue = True
            if ptx in (',', ':', ';'): glue = False
            if tt == T['.'] or ptt == T['.']: glue = True
            s += ('' if glue else ' ') + tx
        src.append(' ' * ind + s)
    return '\n'.join(src) + '\n'

srcdir, outdir = sys.argv[1], sys.argv[2]
os.makedirs(outdir, exist_ok=True)
for fn in sorted(os.listdir(srcdir)):
    if not fn.endswith('.gdc'): continue
    try:
        code = decompile(os.path.join(srcdir, fn))
    except Exception as e:
        print('%-22s FAIL %s' % (fn, e)); continue
    op = os.path.join(outdir, fn[:-4] + '.gd')
    open(op, 'w').write(code)
    print('%-22s -> %d lines, %d bytes' % (fn, code.count('\n'), len(code)))
