#!/usr/bin/env python3
# SPDX-License-Identifier: CC0-1.0
"""Overwrite one EBML element's value in place, keeping its byte width.

Matroska states a picture's display size four ways and ffmpeg writes two of them
(a bare ratio in .mkv, a pixel box in .webm). The other two — a size in
centimetres, and a box with one side left to default — need a byte edit, and an
in-place one of the same width needs no length fixups anywhere above it. Build
the file with `-write_crc32 0` so no checksum covers what is edited.

Usage: patch-ebml-value.py <in> <out> <id-hex>=<value> [...]
       e.g. patch-ebml-value.py a.mkv b.mkv 54B2=1 54B0=40 54BA=30
"""
import sys


def edit(buf, ident, value):
    key = bytes.fromhex(ident)
    hits = [i for i in range(len(buf) - len(key)) if buf[i:i + len(key)] == key]
    # An element header is the identifier, then a one-byte length with its
    # marker bit set (0x80 | n): every field patched here is a few bytes long.
    hits = [i for i in hits if 0x80 < buf[i + len(key)] <= 0x88]
    if len(hits) != 1:
        raise SystemExit("%s occurs %d times, not once" % (ident, len(hits)))
    off = hits[0] + len(key)
    width = buf[off] & 0x7F
    buf[off + 1:off + 1 + width] = value.to_bytes(width, "big")


src, dst = sys.argv[1], sys.argv[2]
buf = bytearray(open(src, "rb").read())
for arg in sys.argv[3:]:
    ident, value = arg.split("=")
    edit(buf, ident, int(value))
open(dst, "wb").write(bytes(buf))
