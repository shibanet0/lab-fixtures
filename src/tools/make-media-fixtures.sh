#!/usr/bin/env bash
# SPDX-License-Identifier: CC0-1.0
#
# lab-fixtures — the media set (video + audio).
#
# Everything below is synthesised: ffmpeg's own `smptebars`, `gradients`, `sine`
# and `aevalsrc` sources, plus five byte-level patchers for the headers no muxer
# will write for you. No recorded material, no third-party file, nothing that
# could belong to anybody else. Re-running this reproduces the whole set.
#
# Requires: ffmpeg >= 7 (libx264, libvpx-vp9, libopus, libvorbis, libmp3lame,
# flac, aac), python3. Verified against ffmpeg 7.1.1.
#
# Usage: make-media-fixtures.sh [outdir]      (default: ./media)
set -euo pipefail

OUT="${1:-media}"
mkdir -p "$OUT"/{video,audio,edge,localized,tools}
Q=(-hide_banner -loglevel error -y)

# Reproducibility. `-fflags +bitexact -flags +bitexact` drops the writing-app
# strings, the muxing date, Matroska's random SegmentUID and Ogg's random stream
# serial. Without it the .mkv/.webm/.ogg/.opus files differ byte for byte on
# every run and no fixture can carry a checksum.
#
# Placement is load-bearing: both are per-file options, so they must sit
# *immediately before the output path*. In front of `-i` they configure the
# input and change nothing about what is written.
BE=(-fflags +bitexact -flags +bitexact)

# ---------------------------------------------------------------------------
# The subjects
#
# Picture: SMPTE bars with an L-shaped white/red marker in the top-left corner.
# The marker is not decoration — a rotation fixture whose picture is symmetric
# proves nothing — and bars compress to a couple of kilobytes where a moving
# pattern costs five times that.
#
# Sound: a 440 Hz sine (concert A), one second. `SWING` is the signal whose
# bitrate demand swings — a second of silence, a second of noise, a second of
# tone — which is what makes a VBR mp3 measurably VBR.
# ---------------------------------------------------------------------------
BARS="smptebars=size=320x180:rate=15:duration=1"
BARS2="smptebars=size=320x180:rate=15:duration=2"
BARS3="smptebars=size=320x180:rate=15:duration=3"
WIDE="smptebars=size=720x480:rate=15:duration=1"
NTSC="smptebars=size=320x180:rate=30000/1001:duration=1"
MARK="drawbox=x=0:y=0:w=40:h=20:color=white:t=fill,drawbox=x=0:y=0:w=8:h=60:color=red:t=fill"
TONE=(-f lavfi -i "sine=frequency=440:sample_rate=48000:duration=1")
SWING="aevalsrc='if(lt(t,1),0,if(lt(t,2),random(0)*2-1,sin(2*PI*440*t)))':s=44100:d=3"

# ---------------------------------------------------------------------------
# 1. video — one file per container the pipeline accepts
# ---------------------------------------------------------------------------
ffmpeg "${Q[@]}" -f lavfi -i "$BARS" "${TONE[@]}" -vf "$MARK" \
  -c:v libx264 -pix_fmt yuv420p -profile:v baseline -crf 32 -g 15 \
  -c:a aac -b:a 32k -shortest -movflags +faststart \
  "${BE[@]}" "$OUT/video/bars-320x180.mp4"
ffmpeg "${Q[@]}" -f lavfi -i "$BARS" -vf "$MARK" \
  -c:v libx264 -pix_fmt yuv420p -crf 32 -an "${BE[@]}" "$OUT/video/bars-320x180.m4v"
# The .mov is the one that matters: the QuickTime muxer writes a SECOND `hdlr`
# inside `minf` (the data handler, dhlr/url ). The .mp4/.m4v muxer does not.
ffmpeg "${Q[@]}" -f lavfi -i "$BARS" -vf "$MARK" \
  -c:v libx264 -pix_fmt yuv420p -crf 32 -an "${BE[@]}" "$OUT/video/bars-320x180.mov"
ffmpeg "${Q[@]}" -f lavfi -i "$BARS" "${TONE[@]}" -vf "$MARK" \
  -c:v libvpx-vp9 -crf 50 -b:v 0 -cpu-used 8 -c:a libopus -b:a 24k -shortest \
  "${BE[@]}" "$OUT/video/bars-320x180.webm"
ffmpeg "${Q[@]}" -f lavfi -i "$BARS" -vf "$MARK" \
  -c:v libx264 -pix_fmt yuv420p -crf 32 -an "${BE[@]}" "$OUT/video/bars-320x180.mkv"

# ---------------------------------------------------------------------------
# 2. video — the box traps
# ---------------------------------------------------------------------------
# A rotation matrix is only written on a REMUX: -display_rotation on a lavfi
# input rotates the pixels instead, which is the opposite of the fixture.
ffmpeg "${Q[@]}" -display_rotation 90 -i "$OUT/video/bars-320x180.mov" -c copy \
  "${BE[@]}" "$OUT/video/rotated-90.mov"
ffmpeg "${Q[@]}" -display_rotation -90 -i "$OUT/video/bars-320x180.mov" -c copy \
  "${BE[@]}" "$OUT/video/rotated-270.mov"
ffmpeg "${Q[@]}" -display_rotation 180 -i "$OUT/video/bars-320x180.mov" -c copy \
  "${BE[@]}" "$OUT/video/rotated-180.mov"
# Matroska states non-square pixels as a bare ratio (DisplayUnit=3); the WebM
# profile forbids that, so the same command writes a pixel box there instead.
# -write_crc32 0 so the two patched variants below are not covered by a checksum.
ffmpeg "${Q[@]}" -f lavfi -i "$WIDE" -c:v libx264 -pix_fmt yuv420p -crf 32 -an \
  -aspect 16:9 -write_crc32 0 "${BE[@]}" "$OUT/video/anamorphic-ratio-720x480.mkv"
ffmpeg "${Q[@]}" -f lavfi -i "$WIDE" -c:v libvpx-vp9 -crf 55 -b:v 0 -cpu-used 8 -an \
  -aspect 16:9 -write_crc32 0 "${BE[@]}" "$OUT/video/anamorphic-display-720x480.webm"
# A live muxer leaves the Segment's own length out.
ffmpeg "${Q[@]}" -f lavfi -i "$BARS" -vf "$MARK" \
  -c:v libvpx-vp9 -crf 55 -b:v 0 -cpu-used 8 -an -f webm -live 1 \
  "${BE[@]}" "$OUT/video/live-unsized-segment.webm"
# Sound in a video container: no picture track at all.
ffmpeg "${Q[@]}" "${TONE[@]}" -c:a libopus -b:a 24k -f webm \
  "${BE[@]}" "$OUT/video/sound-only.webm"
ffmpeg "${Q[@]}" "${TONE[@]}" -c:a aac -b:a 32k "${BE[@]}" "$OUT/video/sound-only.mp4"
# A 64-bit (version 1) media header: a track timescale of 2 GHz over 3 seconds
# does not fit 32 bits, so the muxer has to widen the box.
ffmpeg "${Q[@]}" -f lavfi -i "$BARS3" -vf "$MARK" -c:v libx264 -pix_fmt yuv420p -crf 32 -an \
  -video_track_timescale 2000000000 "${BE[@]}" "$OUT/video/version1-track-header.mp4"
# The broadcast rate that does not land on a whole millisecond.
ffmpeg "${Q[@]}" -f lavfi -i "$NTSC" -vf "$MARK" -c:v libx264 -pix_fmt yuv420p -crf 32 -an \
  -video_track_timescale 30000 "${BE[@]}" "$OUT/video/ntsc-2997fps.mp4"
ffmpeg "${Q[@]}" -f lavfi -i "$NTSC" -vf "$MARK" -c:v libx264 -pix_fmt yuv420p -crf 32 -an \
  -write_crc32 0 "${BE[@]}" "$OUT/video/ntsc-2997fps.mkv"

# ---------------------------------------------------------------------------
# 3. video — fragmented
# ---------------------------------------------------------------------------
# frag_keyframe ALONE is the dangerous one: the moov states 1000 ms and 15
# frames for a file that is 2000 ms and 30 frames.
ffmpeg "${Q[@]}" -f lavfi -i "$BARS2" -vf "$MARK" -c:v libx264 -pix_fmt yuv420p -crf 32 -g 15 -an \
  -movflags +frag_keyframe "${BE[@]}" "$OUT/video/fragmented-partial-header.mp4"
ffmpeg "${Q[@]}" -f lavfi -i "$BARS2" -vf "$MARK" -c:v libx264 -pix_fmt yuv420p -crf 32 -g 15 -an \
  -movflags +frag_keyframe+empty_moov+default_base_moof \
  "${BE[@]}" "$OUT/video/fragmented-empty-moov.mp4"

# ---------------------------------------------------------------------------
# 4. audio — one file per container
# ---------------------------------------------------------------------------
ffmpeg "${Q[@]}" "${TONE[@]}" -c:a aac -b:a 32k "${BE[@]}" "$OUT/audio/tone-a440.m4a"
ffmpeg "${Q[@]}" "${TONE[@]}" -c:a libmp3lame -b:a 64k -ar 44100 -ac 1 "${BE[@]}" "$OUT/audio/tone-a440.mp3"
ffmpeg "${Q[@]}" "${TONE[@]}" -c:a pcm_s16le -ar 11025 -ac 1 "${BE[@]}" "$OUT/audio/tone-a440.wav"
ffmpeg "${Q[@]}" "${TONE[@]}" -c:a flac -ar 44100 -ac 1 "${BE[@]}" "$OUT/audio/tone-a440.flac"
make_ogg() {
  if ffmpeg -hide_banner -encoders 2>&1 | grep -E '[[:space:]]libvorbis([[:space:]]|$)' > /dev/null; then
    ffmpeg "${Q[@]}" "${TONE[@]}" -c:a libvorbis -q:a 1 -ar 44100 -ac 1 "${BE[@]}" "$OUT/audio/tone-a440.ogg"
    printf '  tone-a440.ogg: ffmpeg libvorbis (mono, spec-exact)\n'
  elif command -v oggenc > /dev/null 2>&1; then
    local raw_wav
    raw_wav=$(mktemp "${TMPDIR:-/tmp}/lab-fixtures-ogg.XXXXXX.wav")
    ffmpeg "${Q[@]}" "${TONE[@]}" -c:a pcm_s16le -ar 44100 -ac 1 -f wav "$raw_wav"
    oggenc -q 1 -o "$OUT/audio/tone-a440.ogg" "$raw_wav"
    rm -f "$raw_wav"
    printf '  tone-a440.ogg: oggenc (mono, spec-exact)\n'
  else
    printf '%s\n' 'WARNING: ffmpeg has no libvorbis and oggenc is unavailable; using native Vorbis stereo fallback (channel-count deviation).' >&2
    ffmpeg "${Q[@]}" "${TONE[@]}" -c:a vorbis -strict -2 -q:a 1 -ar 44100 -ac 2 "${BE[@]}" "$OUT/audio/tone-a440.ogg"
    printf '  tone-a440.ogg: native ffmpeg vorbis fallback (stereo deviation)\n'
  fi
}
make_ogg
ffmpeg "${Q[@]}" "${TONE[@]}" -c:a libopus -b:a 24k "${BE[@]}" "$OUT/audio/tone-a440.opus"

# ---------------------------------------------------------------------------
# 5. audio — the duration traps
# ---------------------------------------------------------------------------
ffmpeg "${Q[@]}" -f lavfi -i "$SWING" -c:a libmp3lame -q:a 6 -ac 1 \
  "${BE[@]}" "$OUT/audio/vbr-with-xing.mp3"
ffmpeg "${Q[@]}" -f lavfi -i "$SWING" -c:a libmp3lame -q:a 6 -ac 1 -write_xing 0 \
  "${BE[@]}" "$OUT/audio/vbr-without-xing.mp3"
# A pair that differs only by a 128-byte ID3v1 trailer, with the Xing header
# suppressed so the duration is computed from the byte count and the trailer's
# exclusion is observable.
ffmpeg "${Q[@]}" "${TONE[@]}" -c:a libmp3lame -b:a 64k -ar 44100 -ac 1 -write_xing 0 \
  -metadata title="Lab tone" "${BE[@]}" "$OUT/audio/cbr-no-trailer.mp3"
ffmpeg "${Q[@]}" "${TONE[@]}" -c:a libmp3lame -b:a 64k -ar 44100 -ac 1 -write_xing 0 \
  -metadata title="Lab tone" -write_id3v1 1 "${BE[@]}" "$OUT/audio/cbr-id3v1-trailer.mp3"
# The cover: a generated two-stop gradient, nobody's photograph. seed= is not
# decoration — without one the filter picks its geometry at random and the .jpg,
# with the two files that embed it, differs on every run.
ffmpeg "${Q[@]}" -f lavfi \
  -i "gradients=size=600x600:duration=1:rate=1:c0=0x2f7d54:c1=0xe07a3c:seed=7" \
  -frames:v 1 -q:v 6 "${BE[@]}" "$OUT/audio/cover-600x600.jpg"
ffmpeg "${Q[@]}" "${TONE[@]}" -i "$OUT/audio/cover-600x600.jpg" -map 0:a -map 1:v \
  -c:a libmp3lame -b:a 64k -ar 44100 -ac 1 -c:v copy -id3v2_version 3 \
  -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)" \
  "${BE[@]}" "$OUT/audio/cover-art-id3v2.mp3"
# The ISO file that carries a picture track beside its sound. NOTE: ffmpeg's
# mov/mp4 muxer folds `-disposition:v attached_pic` into an `ilst`/`covr` atom
# and writes NO video track, so that flag does not produce this file — a still
# image muxed as an ordinary one-sample `vide` track does.
ffmpeg "${Q[@]}" "${TONE[@]}" -loop 1 -framerate 1 -i "$OUT/audio/cover-600x600.jpg" \
  -map 0:a -map 1:v -c:a aac -b:a 32k -c:v mjpeg -q:v 8 -frames:v 1 -shortest -f mp4 \
  "${BE[@]}" "$OUT/audio/cover-art-track.m4a"
# A FLAC encoded to a pipe never learns its own length: sample count stays 0.
ffmpeg "${Q[@]}" "${TONE[@]}" -c:a flac -ar 44100 -ac 1 -f flac "${BE[@]}" - \
  > "$OUT/audio/streamed-zero-samples.flac"
# An Ogg stream that is neither Opus nor Vorbis.
ffmpeg "${Q[@]}" "${TONE[@]}" -c:a flac -ar 44100 -ac 1 -f ogg "${BE[@]}" "$OUT/audio/oggflac.ogg"

# ---------------------------------------------------------------------------
# 6. localized — a dub set, pinned to one pixel box
# ---------------------------------------------------------------------------
reel() { # $1 out  $2 hue  $3 Hz  $4 size  $5 seconds
  ffmpeg "${Q[@]}" -f lavfi -i "smptebars=size=$4:rate=15:duration=$5" \
    -f lavfi -i "sine=frequency=$3:sample_rate=48000:duration=$5" \
    -vf "hue=h=$2,drawbox=x=0:y=0:w=40:h=20:color=white:t=fill" \
    -c:v libx264 -pix_fmt yuv420p -crf 32 -c:a aac -b:a 32k -shortest \
    -movflags +faststart "${BE[@]}" "$1"
}
reel "$OUT/localized/reel.mp4" 0 440 320x180 1
reel "$OUT/localized/reel.es.mp4" 120 523 320x180 1
reel "$OUT/localized/reel.ja.mp4" 240 659 320x180 1.6
reel "$OUT/localized/reel-wrong-box.de.mp4" 60 587 640x360 1
head -c 900 "$OUT/localized/reel.mp4" > "$OUT/localized/reel-unreadable.fr.mp4"

# ---------------------------------------------------------------------------
# 7. edge — cut short, hostile, mislabelled
# ---------------------------------------------------------------------------
ffmpeg "${Q[@]}" -f lavfi -i "smptebars=size=320x180:rate=15:duration=0.34" -vf "$MARK" \
  -c:v mpeg4 -q:v 10 -an "${BE[@]}" "$OUT/edge/bars-320x180.avi"
# 4000 lands inside the mdat: the moov (which ends at 1824 in this file) is
# whole, so the facts survive and only the note says the rest did not.
head -c 4000 "$OUT/video/bars-320x180.mp4" > "$OUT/edge/truncated-mdat.mp4"
head -c 1200 "$OUT/video/bars-320x180.mp4" > "$OUT/edge/truncated-moov.mp4"
python3 -c "import sys; d=open(sys.argv[1],'rb').read(); open(sys.argv[2],'wb').write(d[:-200])" \
  "$OUT/audio/tone-a440.opus" "$OUT/edge/truncated-tail.opus"
python3 -c "import sys; d=open(sys.argv[1],'rb').read(); open(sys.argv[2],'wb').write(d[:len(d)//2])" \
  "$OUT/video/bars-320x180.webm" "$OUT/edge/truncated.webm"
cp "$OUT/audio/cbr-no-trailer.mp3" "$OUT/edge/mp3-bytes-named.wav"

# ---------------------------------------------------------------------------
# 8. the byte-level patchers — headers no muxer writes
# ---------------------------------------------------------------------------
cat > "$OUT/tools/add-mehd.py" << 'PY'
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
PY

cat > "$OUT/tools/patch-ebml-value.py" << 'PY'
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
PY

cat > "$OUT/tools/zero-tkhd-height.py" << 'PY'
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
PY

cat > "$OUT/tools/box-storm.py" << 'PY'
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
PY

cat > "$OUT/tools/wav-traps.py" << 'PY'
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
PY
chmod +x "$OUT"/tools/*.py

# ---------------------------------------------------------------------------
# 9. apply the patchers
# ---------------------------------------------------------------------------
python3 "$OUT/tools/add-mehd.py" \
  "$OUT/video/fragmented-empty-moov.mp4" "$OUT/video/fragmented-with-mehd.mp4" 2000
python3 "$OUT/tools/patch-ebml-value.py" \
  "$OUT/video/anamorphic-ratio-720x480.mkv" "$OUT/video/display-centimetres-720x480.mkv" \
  54B2=1 54B0=40 54BA=30
python3 "$OUT/tools/patch-ebml-value.py" \
  "$OUT/video/anamorphic-display-720x480.webm" "$OUT/video/display-half-stated-720x480.webm" \
  54BA=0
python3 "$OUT/tools/patch-ebml-value.py" \
  "$OUT/video/bars-320x180.mkv" "$OUT/edge/half-a-box.mkv" BA=0
python3 "$OUT/tools/zero-tkhd-height.py" \
  "$OUT/video/bars-320x180.mov" "$OUT/edge/half-a-box.mov"
python3 "$OUT/tools/box-storm.py" \
  "$OUT/video/bars-320x180.mov" "$OUT/edge/box-storm-before.mov" 8200 before
python3 "$OUT/tools/wav-traps.py" "$OUT/audio/tone-a440.wav" "$OUT/edge"

echo "wrote $(find "$OUT" -type f | wc -l) files, $(du -sh "$OUT" | cut -f1)"
