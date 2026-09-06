#!/usr/bin/env python3
# SPDX-License-Identifier: CC0-1.0
"""Emit a byte-reproducible, user-password-protected PDF (RC4-40, /V 1 /R 2).

A reader that passes no `password` option -- pdfjs, for one -- refuses it with
PasswordException: No password given.  That is the point: the file is
structurally valid and still unopenable, which is the real-world case a corrupt
file cannot reproduce.  The user password is "lab-fixtures", documented in the
README so nobody mistakes it for a secret.
"""
import hashlib
import sys

PAD = bytes([
    0x28, 0xBF, 0x4E, 0x5E, 0x4E, 0x75, 0x8A, 0x41, 0x64, 0x00, 0x4E, 0x56,
    0xFF, 0xFA, 0x01, 0x08, 0x2E, 0x2E, 0x00, 0xB6, 0xD0, 0x68, 0x3E, 0x80,
    0x2F, 0x0C, 0xA9, 0xFE, 0x64, 0x53, 0x69, 0x7A,
])
FILE_ID = bytes.fromhex("00112233445566778899aabbccddeeff")  # static: no randomness
PERMS = -4


def rc4(key, data):
    s, j, out = list(range(256)), 0, bytearray()
    for i in range(256):
        j = (j + s[i] + key[i % len(key)]) & 0xFF
        s[i], s[j] = s[j], s[i]
    i = j = 0
    for byte in data:
        i = (i + 1) & 0xFF
        j = (j + s[i]) & 0xFF
        s[i], s[j] = s[j], s[i]
        out.append(byte ^ s[(s[i] + s[j]) & 0xFF])
    return bytes(out)


def pad(pw):
    return (pw.encode("latin-1") + PAD)[:32]


def obj_key(key, num, gen):
    ext = key + num.to_bytes(3, "little") + gen.to_bytes(2, "little")
    return hashlib.md5(ext).digest()[: min(len(key) + 5, 16)]


def build(user_pw="lab-fixtures", owner_pw="lab-fixtures-owner", width=595, height=842):
    o_entry = rc4(hashlib.md5(pad(owner_pw)).digest()[:5], pad(user_pw))
    md5 = hashlib.md5()
    md5.update(pad(user_pw))
    md5.update(o_entry)
    md5.update((PERMS & 0xFFFFFFFF).to_bytes(4, "little"))
    md5.update(FILE_ID)
    key = md5.digest()[:5]
    u_entry = rc4(key, PAD)

    stream = b"BT /F1 24 Tf 48 720 Td (Locked fixture) Tj ET\n"
    enc = rc4(obj_key(key, 4, 0), stream)
    objs = {
        1: b"<< /Type /Catalog /Pages 2 0 R >>",
        2: b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        3: (f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {width} {height}] "
            f"/Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>").encode(),
        4: b"<< /Length " + str(len(enc)).encode() + b" >>\nstream\n" + enc + b"\nendstream",
        5: b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
        # /O and /U inside the encryption dictionary are NOT themselves encrypted.
        6: (b"<< /Filter /Standard /V 1 /R 2 /O <" + o_entry.hex().encode()
            + b"> /U <" + u_entry.hex().encode() + b"> /P " + str(PERMS).encode() + b" >>"),
    }

    out = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
    offsets = {}
    for num in sorted(objs):
        offsets[num] = len(out)
        out += f"{num} 0 obj\n".encode() + objs[num] + b"\nendobj\n"
    xref_at = len(out)
    count = max(objs) + 1
    out += f"xref\n0 {count}\n".encode() + b"0000000000 65535 f \n"
    for num in range(1, count):
        out += f"{offsets[num]:010d} 00000 n \n".encode()
    idh = FILE_ID.hex()
    out += (f"trailer\n<< /Size {count} /Root 1 0 R /Encrypt 6 0 R "
            f"/ID [<{idh}> <{idh}>] >>\nstartxref\n{xref_at}\n%%EOF\n").encode()
    return bytes(out)


if __name__ == "__main__":
    with open(sys.argv[1], "wb") as fh:
        fh.write(build())
