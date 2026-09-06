#!/usr/bin/env python3
# SPDX-License-Identifier: CC0-1.0
"""Write the wav headers no encoder will write for you.

A recorder that is still running leaves the lengths it cannot know yet at zero
or at all-ones and fills them in when it stops; a file that never got that far
is the one a probe has to survive. ffmpeg always finishes its headers, so these
are assembled here from PCM it produced.

Usage: wav-traps.py <tone.wav> <outdir>
"""
import os
import struct
import sys

src, outdir = sys.argv[1], sys.argv[2]
raw = open(src, "rb").read()
assert raw[0:4] == b"RIFF" and raw[8:12] == b"WAVE", "not a wav"

# Pull the format chunk and the samples out of the source, in whatever order.
fmt = data = None
off = 12
while off + 8 <= len(raw):
    name = raw[off:off + 4]
    size = struct.unpack_from("<I", raw, off + 4)[0]
    body = raw[off + 8:off + 8 + size]
    if name == b"fmt " and fmt is None:
        fmt = body
    elif name == b"data" and data is None:
        data = body
    off += 8 + size + (size & 1)
assert fmt and data


def chunk(name, body, stated=None):
    size = len(body) if stated is None else stated
    return name + struct.pack("<I", size) + body + b"\x00" * (len(body) & 1)


def form(*chunks, stated=None):
    body = b"WAVE" + b"".join(chunks)
    return b"RIFF" + struct.pack("<I", len(body) if stated is None else stated) + body


half = data[:len(data) // 2]
fmtc = chunk(b"fmt ", fmt)

# A decoy inside the audio: bytes that read as a second format chunk at a
# quarter of the real rate, followed by bytes that read as a second data chunk.
decoy_fmt = (fmt[0:4]
             + struct.pack("<I", struct.unpack_from("<I", fmt, 4)[0] // 4)
             + struct.pack("<I", struct.unpack_from("<I", fmt, 8)[0] // 4)
             + fmt[12:])
decoy = chunk(b"fmt ", decoy_fmt) + chunk(b"data", b"\x00" * 512)
padded = decoy + data[len(decoy):]

files = {
    # The writer never came back to fill the length in: it is still zero.
    "wav-data-length-zero.wav": form(fmtc, chunk(b"data", data, stated=0)),
    # The same file whose samples spell the two chunk names the reader looks
    # for. Stepping over a zero-length chunk steps over nothing, so a walk that
    # did would describe the file from a rate found in its own noise: a reader
    # that let the last chunk win reports 4000 ms for one second of audio.
    "wav-data-length-zero-decoy.wav": form(fmtc, chunk(b"data", padded, stated=0)),
    # The other convention: all-ones until the recorder knows better.
    "wav-data-length-all-ones.wav": form(fmtc, chunk(b"data", half, stated=0xFFFFFFFF)),
    # A recorder killed mid-take: neither length was ever written.
    "wav-live-recorder.wav": form(fmtc, chunk(b"data", data, stated=0), stated=0),
}
for name, body in files.items():
    open(os.path.join(outdir, name), "wb").write(body)
