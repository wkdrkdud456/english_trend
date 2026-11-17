# -*- coding: utf-8 -*-
"""APK Signature Scheme v2 서명기 (순수 파이썬).
targetSdk 30 이상은 v1만으로는 설치를 거부하므로 v2가 필요하다."""
import sys, struct, hashlib
from cryptography.hazmat.primitives import serialization, hashes
from cryptography.hazmat.primitives.asymmetric import padding

MAGIC = b'APK Sig Block 42'
ALGO_RSA_PKCS1_SHA256 = 0x0103
CHUNK = 1048576

def lp(b):                      # length-prefixed
    return struct.pack('<I', len(b)) + b
def seq(items):                 # 길이 접두 요소들의 나열
    return b''.join(lp(i) for i in items)

def find_eocd(b):
    for p in range(len(b) - 22, max(-1, len(b) - 22 - 65536), -1):
        if b[p:p+4] == b'PK\x05\x06':
            return p
    raise ValueError('EOCD 없음')

def chunk_digests(sections):
    digests, count = [], 0
    for data in sections:
        for o in range(0, len(data), CHUNK):
            c = data[o:o+CHUNK]
            h = hashlib.sha256()
            h.update(b'\xa5'); h.update(struct.pack('<I', len(c))); h.update(c)
            digests.append(h.digest()); count += 1
    top = hashlib.sha256()
    top.update(b'\x5a'); top.update(struct.pack('<I', count))
    for d in digests: top.update(d)
    return top.digest()

def sign(apk_in, apk_out, key_pem, cert_der):
    b = open(apk_in, 'rb').read()
    eocd_off = find_eocd(b)
    cd_off = struct.unpack_from('<I', b, eocd_off + 16)[0]
    cd_size = struct.unpack_from('<I', b, eocd_off + 12)[0]
    entries, cd, eocd = b[:cd_off], b[cd_off:cd_off+cd_size], bytearray(b[eocd_off:])

    key = serialization.load_pem_private_key(open(key_pem, 'rb').read(), password=None)

    # 자리를 차지할 블록 크기를 먼저 정해야 EOCD의 CD 오프셋이 확정된다 → 두 번 돌린다
    block = b'\x00' * 4096
    for _ in range(4):
        new_cd_off = cd_off + (len(block) - 0) if False else cd_off
        # EOCD의 CD 오프셋을 '서명 블록 시작'으로 바꾼 사본으로 다이제스트를 계산한다
        eocd_for_digest = bytearray(eocd)
        struct.pack_into('<I', eocd_for_digest, 16, cd_off)
        digest = chunk_digests([entries, cd, bytes(eocd_for_digest)])

        signed_data = (lp(seq([struct.pack('<I', ALGO_RSA_PKCS1_SHA256) + lp(digest)]))
                       + lp(seq([cert_der]))
                       + lp(b''))
        sig = key.sign(signed_data, padding.PKCS1v15(), hashes.SHA256())
        signatures = lp(seq([struct.pack('<I', ALGO_RSA_PKCS1_SHA256) + lp(sig)]))
        pub = key.public_key().public_bytes(serialization.Encoding.DER,
                                            serialization.PublicFormat.SubjectPublicKeyInfo)
        # signer 안에서는 signed_data 도 길이 접두로 감싼다 (서명 자체는 raw 에 건다)
        signer = lp(signed_data) + signatures + lp(pub)
        v2value = lp(seq([signer]))                       # signers 나열

        pairs = struct.pack('<Q', len(v2value) + 4) + struct.pack('<I', 0x7109871a) + v2value
        # 4096 정렬용 패딩 쌍
        total = 8 + len(pairs) + 8 + 16
        pad = (-(cd_off + total)) % 4096
        if pad:
            if pad < 12: pad += 4096
            pairs += struct.pack('<Q', pad - 8) + struct.pack('<I', 0x42726577) + b'\x00' * (pad - 12)
        body = pairs + struct.pack('<Q', len(pairs) + 8 + 16) + MAGIC
        block = struct.pack('<Q', len(pairs) + 8 + 16) + body
        break

    out = entries + block + cd + bytes(eocd)
    # EOCD의 CD 오프셋을 블록만큼 밀어준다
    out = bytearray(out)
    new_eocd = len(entries) + len(block) + len(cd)
    struct.pack_into('<I', out, new_eocd + 16, cd_off + len(block))
    open(apk_out, 'wb').write(bytes(out))
    return len(block), cd_off, cd_off + len(block)

if __name__ == '__main__':
    n, old, new = sign(sys.argv[1], sys.argv[2], sys.argv[3], open(sys.argv[4], 'rb').read())
    print('서명 블록 %d바이트 · CD 오프셋 %d -> %d' % (n, old, new))
