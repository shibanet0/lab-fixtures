#!/usr/bin/env python3
# SPDX-License-Identifier: CC0-1.0
"""Insert a movie-extends header (`mehd`) into a fragmented MP4's `mvex`.

A fragmented file's `moov` describes the first fragment, not the file, so the
only box it may state an overall duration in is `mehd` — and no muxer in common
use writes one (ffmpeg 7.1 writes none under any -movflags combination, nor for
-f ismv). Inserting one is the whole reason the file this produces exists.

Usage: add-mehd.py <in.mp4> <out.mp4> <duration in the movie timescale>
"""
import struct
import sys


def find(buf, start, end, path):
    off = start
    while off + 8 <= end:
        size = struct.unpack_from(">I", buf, off)[0]
        typ = buf[off + 4:off + 8]
        if size == 0:
            size = end - off
        if size < 8 or off + size > end:
            break
        if typ == path[0]:
            if len(path) == 1:
                return off, size
            return find(buf, off + 8, off + size, path[1:])
        off += size
    raise SystemExit("no %s" % b"/".join(path).decode())


src, dst, duration = sys.argv[1], sys.argv[2], int(sys.argv[3])
buf = bytearray(open(src, "rb").read())
moov_off, moov_size = find(buf, 0, len(buf), [b"moov"])
mvex_off, mvex_size = find(buf, moov_off + 8, moov_off + moov_size, [b"mvex"])
mehd = struct.pack(">I4s4sI", 16, b"mehd", b"\x00\x00\x00\x00", duration)
buf[mvex_off + 8:mvex_off + 8] = mehd
struct.pack_into(">I", buf, mvex_off, mvex_size + len(mehd))
struct.pack_into(">I", buf, moov_off, moov_size + len(mehd))
open(dst, "wb").write(bytes(buf))
