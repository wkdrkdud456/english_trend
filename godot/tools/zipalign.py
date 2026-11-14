# -*- coding: utf-8 -*-
"""APK용 zip 재작성기. 파이썬 zipfile 은 data descriptor(0x08)를 붙이고 정렬을 못 맞춘다.
   엔트리 내용은 원본 그대로 두고 헤더만 다시 쓴다 → v1 서명(내용 다이제스트)은 그대로 유효."""
import sys, struct, zipfile

def build(src, dst):
    zin = zipfile.ZipFile(src)
    raw = open(src, 'rb').read()
    out = bytearray()
    central = []
    for it in zin.infolist():
        lh = it.header_offset
        nlen, elen = struct.unpack_from('<HH', raw, lh + 26)
        data_off = lh + 30 + nlen + elen
        comp = raw[data_off:data_off + it.compress_size]      # 압축된 바이트 그대로
        name = it.filename.encode('utf-8')
        # STORED 는 4바이트(.so 는 16KB) 정렬이 필요하다
        align = 0
        if it.compress_type == zipfile.ZIP_STORED:
            align = 16384 if it.filename.endswith('.so') else 4
        extra = b''
        if align:
            pos = len(out) + 30 + len(name)
            pad = (-pos) % align
            if pad:
                if pad < 4: pad += align        # extra 필드는 최소 4바이트 헤더가 필요
                extra = struct.pack('<HH', 0xd935, pad - 4) + b'\x00' * (pad - 4)
        hoff = len(out)
        out += struct.pack('<IHHHHHIIIHH', 0x04034b50, 20, 0, it.compress_type,
                           0, 0, it.CRC, it.compress_size, it.file_size,
                           len(name), len(extra))
        out += name + extra + comp
        central.append((it, name, hoff))
    cd_off = len(out)
    for it, name, hoff in central:
        out += struct.pack('<IHHHHHHIIIHHHHHII', 0x02014b50, 20, 20, 0, it.compress_type,
                           0, 0, it.CRC, it.compress_size, it.file_size,
                           len(name), 0, 0, 0, 0, it.external_attr, hoff)
        out += name
    cd_size = len(out) - cd_off
    out += struct.pack('<IHHHHIIH', 0x06054b50, 0, 0, len(central), len(central),
                       cd_size, cd_off, 0)
    open(dst, 'wb').write(bytes(out))
    return len(central), cd_off

n, cd = build(sys.argv[1], sys.argv[2])
print('엔트리 %d · CD@%d' % (n, cd))
