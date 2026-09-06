#!/usr/bin/env python3
# SPDX-License-Identifier: CC0-1.0
"""Zero the height in every MP4 track header, leaving the width alone.

Half a box is not a box — a page that reserved 320x0 reflows exactly like one
that reserved nothing — and no muxer writes one, so the file that proves the
rule has to be made by hand. The edit is in place and changes no length.

Usage: zero-tkhd-height.py <in.mp4> <out.mp4>
"""
import struct
import sys


def walk(buf, start, end, want, hits):
    off = start
    while off + 8 <= end:
        size = struct.unpack_from(">I", buf, off)[0]
        typ = buf[off + 4:off + 8]
        if size == 0:
            size = end - off
        if size < 8 or off + size > end:
            return
        if typ == want:
            hits.append(off + 8)
        if typ in (b"moov", b"trak", b"mdia", b"minf", b"stbl"):
            walk(buf, off + 8, off + size, want, hits)
        off += size


src, dst = sys.argv[1], sys.argv[2]
buf = bytearray(open(src, "rb").read())
hits = []
walk(buf, 0, len(buf), b"tkhd", hits)
for body in hits:
    head = 20 if buf[body] == 0 else 32
    # version+flags (4), the head, two reserved words / layer / alternate group
    # / volume / one more reserved (16), the 3x3 matrix (36), then the box.
    box = body + 4 + head + 16 + 36
    struct.pack_into(">I", buf, box + 4, 0)
open(dst, "wb").write(bytes(buf))
