#!/usr/bin/env python3
# SPDX-License-Identifier: CC0-1.0
"""Pad an MP4 with N empty `free` boxes, to exhaust a probe's box budget.

A box may legally carry no payload, so a file of nothing but eight-byte headers
is well-formed and endless. A header-only reader has to stop somewhere; this is
the file that makes it stop, in two shapes — the movie before the storm, and
after it, which answer differently.

Usage: box-storm.py <in.mp4> <out.mp4> <count> [before|after]
"""
import struct
import sys

src, dst, count = sys.argv[1], sys.argv[2], int(sys.argv[3])
where = sys.argv[4] if len(sys.argv) > 4 else "before"
free = (struct.pack(">I", 8) + b"free") * count
movie = open(src, "rb").read()
open(dst, "wb").write(free + movie if where == "before" else movie + free)
