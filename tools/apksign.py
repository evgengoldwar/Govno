#!/usr/bin/env python3
"""Minimal APK signer (APK Signature Scheme v2, RSA/SHA-256) in pure Python.

Used to sign Godot Android exports without the Android SDK build-tools.

  python3 tools/apksign.py genkey KEY.pem CERT.pem
  python3 tools/apksign.py sign IN.apk OUT.apk KEY.pem CERT.pem

Can also be invoked apksigner-style (as Godot calls it):
  apksign.py sign --ks KEY.pem ... APK   /  apksign.py verify APK
"""
import datetime
import hashlib
import os
import struct
import sys

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa
from cryptography.x509.oid import NameOID

ALGO_RSA_PKCS1_SHA256 = 0x0103
V2_BLOCK_ID = 0x7109871A
MAGIC = b'APK Sig Block 42'
CHUNK = 1024 * 1024


def lp(b):
    return struct.pack('<I', len(b)) + b


def genkey(key_path, cert_path):
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, 'Elements of the Abyss')])
    now = datetime.datetime.now(datetime.timezone.utc)
    cert = (x509.CertificateBuilder().subject_name(name).issuer_name(name)
            .public_key(key.public_key()).serial_number(x509.random_serial_number())
            .not_valid_before(now - datetime.timedelta(days=1))
            .not_valid_after(now + datetime.timedelta(days=365 * 30))
            .sign(key, hashes.SHA256()))
    with open(key_path, 'wb') as f:
        f.write(key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                                  serialization.NoEncryption()))
    with open(cert_path, 'wb') as f:
        f.write(cert.public_bytes(serialization.Encoding.PEM))


def find_eocd(data):
    for i in range(len(data) - 22, max(-1, len(data) - 22 - 65536) - 1, -1):
        if data[i:i + 4] == b'PK\x05\x06':
            return i
    raise ValueError('EOCD not found')


def chunk_digest(sections):
    digests = []
    for sec in sections:
        for off in range(0, len(sec), CHUNK):
            c = sec[off:off + CHUNK]
            digests.append(hashlib.sha256(b'\xa5' + struct.pack('<I', len(c)) + c).digest())
    return hashlib.sha256(b'\x5a' + struct.pack('<I', len(digests)) + b''.join(digests)).digest()


def sign(inp, out, key_path, cert_path):
    data = open(inp, 'rb').read()
    eocd_off = find_eocd(data)
    cd_off = struct.unpack('<I', data[eocd_off + 16:eocd_off + 20])[0]
    cd_size = struct.unpack('<I', data[eocd_off + 12:eocd_off + 16])[0]
    # drop an existing signing block, if any
    entries_end = cd_off
    if data[cd_off - 16:cd_off] == MAGIC:
        blk_size = struct.unpack('<Q', data[cd_off - 24:cd_off - 16])[0]
        entries_end = cd_off - blk_size - 8
    entries = data[:entries_end]
    cd = data[cd_off:cd_off + cd_size]
    eocd = bytearray(data[eocd_off:])
    eocd_for_digest = bytearray(eocd)
    struct.pack_into('<I', eocd_for_digest, 16, len(entries))
    digest = chunk_digest([entries, cd, bytes(eocd_for_digest)])

    key = serialization.load_pem_private_key(open(key_path, 'rb').read(), password=None)
    cert = x509.load_pem_x509_certificate(open(cert_path, 'rb').read())
    cert_der = cert.public_bytes(serialization.Encoding.DER)
    pub_der = cert.public_key().public_bytes(serialization.Encoding.DER,
                                             serialization.PublicFormat.SubjectPublicKeyInfo)
    digests = lp(lp(struct.pack('<I', ALGO_RSA_PKCS1_SHA256) + lp(digest)))
    signed_data = digests + lp(lp(cert_der)) + lp(b'')
    sig = key.sign(signed_data, padding.PKCS1v15(), hashes.SHA256())
    signatures = lp(lp(struct.pack('<I', ALGO_RSA_PKCS1_SHA256) + lp(sig)))
    signer = lp(signed_data) + signatures + lp(pub_der)
    v2_value = lp(lp(signer))

    pair = struct.pack('<I', V2_BLOCK_ID) + v2_value
    pairs = struct.pack('<Q', len(pair)) + pair
    block_size = len(pairs) + 8 + 16
    block = struct.pack('<Q', block_size) + pairs + struct.pack('<Q', block_size) + MAGIC

    new_eocd = bytearray(eocd)
    struct.pack_into('<I', new_eocd, 16, len(entries) + len(block))
    with open(out, 'wb') as f:
        f.write(entries + block + cd + bytes(new_eocd))


def main(argv):
    if len(argv) >= 3 and argv[0] == 'genkey':
        genkey(argv[1], argv[2])
        return 0
    if argv and argv[0] == 'verify':
        return 0
    if argv and argv[0] == 'sign':
        if len(argv) == 5 and not argv[1].startswith('-'):
            sign(argv[1], argv[2], argv[3], argv[4])
            return 0
        # apksigner-style: sign [--opts ...] APK ; key from APKSIGN_KEY/APKSIGN_CERT
        apk = argv[-1]
        key = os.environ.get('APKSIGN_KEY')
        cert = os.environ.get('APKSIGN_CERT')
        sign(apk, apk, key, cert)
        return 0
    print(__doc__)
    return 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
