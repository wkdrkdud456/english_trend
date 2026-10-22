# Parse hwp / hwpx / pdf into a sequence of blocks: ('p', text) or ('t', cells) where cells=[(r,c,rs,cs,text)]
import re, struct, zlib, zipfile
import xml.etree.ElementTree as ET

def _ws(s): return re.sub(r'\s+', ' ', s).strip()

def parse_hwp(path):
    import olefile
    f = olefile.OleFileIO(path)
    hdr = f.openstream('FileHeader').read()
    flags = struct.unpack('<I', hdr[36:40])[0]
    if flags & 2: return []
    secs = sorted([p for p in f.listdir() if p[0] == 'BodyText'], key=lambda p: int(p[1][7:]))
    INL = {1,2,3,4,5,6,7,8,9,11,12,14,15,16,17,18,19,20,21,22,23}
    def para_text(b):
        out = []; i = 0; n = len(b) // 2
        while i < n:
            c = struct.unpack_from('<H', b, i*2)[0]
            if c < 32:
                if c in INL: i += 8; continue
                if c in (10, 13): out.append(' ')
                i += 1; continue
            out.append(chr(c)); i += 1
        return ''.join(out)
    def records(data):
        p = 0
        while p + 4 <= len(data):
            h = struct.unpack_from('<I', data, p)[0]; p += 4
            tag = h & 0x3ff; lvl = (h >> 10) & 0x3ff; size = h >> 20
            if size == 0xfff: size = struct.unpack_from('<I', data, p)[0]; p += 4
            yield tag, lvl, data[p:p+size]; p += size
    blocks = []
    for s in secs:
        data = f.openstream(s).read()
        if flags & 1: data = zlib.decompress(data, -15)
        stack = []
        for tag, lvl, d in records(data):
            while stack and lvl <= stack[-1]['lvl']:
                t = stack.pop(); blocks.append(('t', [tuple(c[:4]) + (_ws(c[4]),) for c in t['cells']]))
            if tag == 71 and d[:4][::-1] == b'tbl ':
                stack.append({'lvl': lvl, 'cells': []})
            elif tag == 72 and stack and lvl == stack[-1]['lvl'] + 1 and len(d) >= 16:
                c, r, cs, rs = struct.unpack_from('<HHHH', d, 8)
                stack[-1]['cells'].append([r, c, rs, cs, ''])
            elif tag == 67:
                t = para_text(d)
                if stack and stack[-1]['cells']: stack[-1]['cells'][-1][4] += ' ' + t
                elif t.strip(): blocks.append(('p', _ws(t)))
        while stack:
            t = stack.pop(); blocks.append(('t', [tuple(c[:4]) + (_ws(c[4]),) for c in t['cells']]))
    return blocks

def parse_hwpx(path):
    z = zipfile.ZipFile(path)
    secs = sorted((n for n in z.namelist() if re.match(r'Contents/section\d+\.xml', n)), key=lambda n: int(re.findall(r'\d+', n)[-1]))
    L = lambda t: t.rsplit('}', 1)[-1]
    blocks = []
    def ptext(p):
        out = []
        for e in p.iter():
            if L(e.tag) == 'tbl': break
            if L(e.tag) == 't' and e.text: out.append(e.text)
        return _ws(''.join(out))
    def walk(el):
        for ch in el:
            tag = L(ch.tag)
            if tag == 'tbl':
                cells = []
                for tr in ch:
                    if L(tr.tag) != 'tr': continue
                    for tc in tr:
                        if L(tc.tag) != 'tc': continue
                        a = next((x for x in tc if L(x.tag) == 'cellAddr'), None)
                        sp = next((x for x in tc if L(x.tag) == 'cellSpan'), None)
                        sub = next((x for x in tc if L(x.tag) == 'subList'), tc)
                        txt = ' '.join(ptext(p) for p in sub if L(p.tag) == 'p')
                        cells.append((int(a.get('rowAddr')), int(a.get('colAddr')),
                                      int(sp.get('rowSpan')) if sp is not None else 1, int(sp.get('colSpan')) if sp is not None else 1, _ws(txt)))
                        for p in sub: walk(p)  # nested tables
                blocks.append(('t', cells))
            elif tag == 'p':
                t = ptext(ch)
                if t: blocks.append(('p', t))
                walk(ch)
            else:
                walk(ch)
    for s in secs: walk(ET.fromstring(z.read(s)))
    return blocks

def parse_pdf(path):
    import pdfplumber
    blocks = []
    with pdfplumber.open(path) as pdf:
        for pg in pdf.pages:
            txt = pg.extract_text() or ''
            tables = pg.find_tables()
            # page text first (for context headings), then tables
            for line in txt.splitlines()[:400]:
                if line.strip(): blocks.append(('p', _ws(line)))
            for tb in tables:
                cells = []
                rows = tb.extract()
                for ri, row in enumerate(rows):
                    for ci, v in enumerate(row):
                        if v is not None: cells.append((ri, ci, 1, 1, _ws(v)))
                blocks.append(('t', cells))
    return blocks

def parse(path):
    if path.endswith('.hwp'): return parse_hwp(path)
    if path.endswith('.hwpx'): return parse_hwpx(path)
    if path.endswith('.pdf'): return parse_pdf(path)
    return []
