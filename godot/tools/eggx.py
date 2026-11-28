import sys, zlib, bz2, lzma, struct, os
v1, v2, out = sys.argv[1], sys.argv[2], sys.argv[3]
d1 = open(v1,'rb').read(); d2 = open(v2,'rb').read()
# vol1: EGG hdr(14) + SPLIT(15) + ENDHDR(4) + FILE(16) + FILENAME(24) + WINFILE(16) + ENDHDR(4) + BLOCK(22)
blk = d1.index(bytes.fromhex('130cb502'))
method = d1[blk+4]; hint = d1[blk+5]
usz = struct.unpack_from('<I', d1, blk+6)[0]
csz = struct.unpack_from('<I', d1, blk+10)[0]
crc = struct.unpack_from('<I', d1, blk+14)[0]
end = struct.unpack_from('<I', d1, blk+18)[0]
start = blk + 22
print('method=%d hint=%d un=%d cmp=%d crc=%08x endmark=%08x data@%d' % (method,hint,usz,csz,crc,end,start))
# vol2 데이터는 EGG헤더 + SPLIT + ENDHDR 뒤부터
s2 = 0x21
payload = d1[start:] + d2[s2:]
print('payload bytes =', len(payload), 'declared =', csz)
payload = payload[:csz]
cands = [
 ('raw deflate', lambda b: zlib.decompressobj(-15).decompress(b)),
 ('zlib',        lambda b: zlib.decompressobj(15).decompress(b)),
 ('store',       lambda b: b),
 ('bzip2',       lambda b: bz2.decompress(b)),
 ('lzma raw',    lambda b: lzma.decompress(b, format=lzma.FORMAT_ALONE)),
]
for name, fn in cands:
    try:
        r = fn(payload)
    except Exception as e:
        print('%-12s FAIL %s' % (name, str(e)[:70])); continue
    ok = (len(r) == usz)
    c = zlib.crc32(r) & 0xffffffff
    print('%-12s -> %d bytes (expect %d) %s  crc=%08x %s' % (name, len(r), usz, 'LEN-OK' if ok else 'len-mismatch', c, 'CRC-OK' if c==crc else ''))
    if len(r) > 1000:
        open(out,'wb').write(r)
        print('   head:', r[:8].hex(), repr(r[:4]))
        print('   wrote', out)
        break
