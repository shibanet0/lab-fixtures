#!/usr/bin/env bash
# SPDX-License-Identifier: CC0-1.0
#
# lab-fixtures — generate every fixture a command can produce.
#
# PROVENANCE, NOT A BUILD STEP. The committed bytes are the artifact: a consuming
# project records sha256 over each master and refuses the whole project when it
# drifts. Re-running this on a different ImageMagick / ffmpeg / FreeType will
# produce different bytes. If a fixture must change, change its NAME.
#
#   ./src/generate.sh              write every fixture into dist/
#   ./src/generate.sh --check      verify SHA256SUMS, write nothing
#   ./src/generate.sh images       one domain only
#                                  (images|vector|media|lottie|rive|pdf|web|data|fonts)
#
# Nothing is written outside dist/ and SHA256SUMS, so `rm -rf dist` followed by a full run is a
# complete test of these recipes.
#
# Rive is not part of the current fixture set. The optional demo font also
# remains out of scope when fontTools is unavailable.
set -euo pipefail

# SRC holds the hand-written generators; everything this script produces goes to DIST and nowhere
# else, so `rm -rf dist && ./src/generate.sh` is a complete end-to-end test of the recipes.
SRC="$(cd "$(dirname "$0")" && pwd)"
REPO="${LAB_FIXTURES_ROOT:-$(cd "$SRC/.." && pwd)}"
DIST="$REPO/dist"
ROOT="$DIST"
if [ -z "${IM:-}" ]; then
  if command -v magick > /dev/null 2>&1; then
    IM=magick
  else
    IM=convert
  fi
fi
if [ -z "${FONT:-}" ]; then
  for candidate in \
    /usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf \
    "${HOME:-}/Library/Fonts/NerdFonts/DejaVuSansMNerdFont-Bold.ttf" \
    /usr/local/share/fonts/DejaVuSans-Bold.ttf \
    /Library/Fonts/DejaVuSans-Bold.ttf; do
    if [ -f "$candidate" ]; then
      FONT="$candidate"
      break
    fi
  done
fi
MADE=0

say() { printf '  %s\n' "$*"; }
head_() { printf '\n== %s\n' "$*"; }
made() { MADE=$((MADE + 1)); }

# --------------------------------------------------------------------------
# preflight — fail with the package to install, not with a stack trace
# --------------------------------------------------------------------------
preflight() {
  local missing=0
  need() { command -v "$1" > /dev/null 2>&1 || {
    echo "missing: $1 ($2)" >&2
    missing=1
  }; }
  need ffmpeg "apt install ffmpeg / brew install ffmpeg — needs libx264, libvpx-vp9, libopus, libvorbis, libmp3lame, flac, aac"
  need "$IM" "apt install imagemagick / brew install imagemagick (on IM7 run with IM=magick)"
  need python3 "python >= 3.9"
  python3 -c 'import PIL' 2> /dev/null || {
    echo "missing: Pillow (pip install Pillow) — needed for the 65536px strips and the EXIF tag" >&2
    missing=1
  }
  [ -n "$FONT" ] && [ -f "$FONT" ] || {
    echo "missing: no usable DejaVu font found (set FONT=/path/to/DejaVuSans-Bold.ttf)" >&2
    missing=1
  }
  [ "$missing" = 0 ] && say "using font: $FONT"
  [ "$missing" = 0 ] || exit 1
}

# --------------------------------------------------------------------------
# 1. images/raster — 27 files
#
# Deterministic PNG: png:include-chunk=none leaves IHDR/IDAT/IEND only, so no
# tIME and no `tEXt date:timestamp` (ImageMagick writes both by default, and two
# runs a second apart would differ). It strips gAMA/sRGB/cHRM too, which is also
# the point: every PNG here is untagged sRGB and the pipeline has no colour
# decision to make. Palette files need the exclude-chunk form instead, because
# include-chunk=none also removes PLTE.
# --------------------------------------------------------------------------
gen_images() {
  head_ "images/raster"
  local OUT="$ROOT/images/raster"
  mkdir -p "$OUT"
  local PNGDET=(-define png:include-chunk=none)
  # shellcheck disable=SC2054 # the commas belong to ImageMagick's chunk list, not to the array
  local PALDET=(+set date:timestamp +set date:create +set date:modify
    -define png:exclude-chunk=date,time,tEXt)
  local GUIDES="line 0,150 1600,150 line 0,1050 1600,1050 line 800,0 800,1200 line 0,600 1600,600"

  # A — the hero pair. 1600x1200 so a 16:9 crop is a real crop; the guide lines
  # make the authored crop visible as a band.
  $IM -size 1600x1200 gradient:'#2f7d54-#e07a3c' \
    \( -size 1600x1200 xc:none -stroke 'rgba(255,255,255,0.30)' -strokewidth 2 -draw "$GUIDES" \) \
    -compose over -composite \
    -font "$FONT" -pointsize 96 -fill white -gravity center -annotate +0+0 'HERO 1600x1200' \
    -gravity northwest -pointsize 40 -annotate +32+32 'lab-fixtures / en' \
    -colorspace sRGB "${PNGDET[@]}" -define png:color-type=2 \
    PNG24:"$OUT/hero-1600x1200.png"
  made
  $IM -size 1600x1200 gradient:'#1f6b6b-#f2a570' \
    \( -size 1600x1200 xc:none -stroke 'rgba(255,255,255,0.30)' -strokewidth 2 -draw "$GUIDES" \) \
    -compose over -composite \
    -font "$FONT" -pointsize 96 -fill white -gravity center -annotate +0+0 'HÉROE 1600x1200' \
    -gravity northwest -pointsize 40 -annotate +32+32 'lab-fixtures / es' \
    -colorspace sRGB "${PNGDET[@]}" -define png:color-type=2 \
    PNG24:"$OUT/hero-1600x1200.es.png"
  made
  # One pixel short, on the axis the error message prints second.
  $IM -size 1600x1199 gradient:'#1f6b6b-#f2a570' \
    -font "$FONT" -pointsize 90 -fill white -gravity center -annotate +0+0 'WRONG BOX 1600x1199' \
    -colorspace sRGB "${PNGDET[@]}" -define png:color-type=2 \
    PNG24:"$OUT/hero-1600x1199.es.png"
  made
  $IM "$OUT/hero-1600x1200.png" -strip -quality 85 -sampling-factor 4:2:0 -interlace none \
    "$OUT/hero-1600x1200.jpg"
  made

  # B — badge. The RGB base beside the RGBA sibling is the deliberate asymmetry
  # (jpeg fallback beside png fallback); badge-alpha is the matched case.
  $IM -size 96x96 gradient:'#4f9e75-#2f7d54' -font "$FONT" -pointsize 44 -fill white \
    -gravity center -annotate +0+0 'LF' -colorspace sRGB \
    "${PNGDET[@]}" -define png:color-type=2 PNG24:"$OUT/badge-96x96.png"
  made
  $IM -size 96x96 xc:none -fill '#c85a2f' -draw 'circle 48,48 48,6' \
    -font "$FONT" -pointsize 40 -fill white -gravity center -annotate +0+0 'ES' \
    "${PNGDET[@]}" -define png:color-type=6 PNG32:"$OUT/badge-96x96.es.png"
  made
  $IM -size 96x96 xc:none -fill '#4f9e75' -draw 'circle 48,48 48,6' \
    -font "$FONT" -pointsize 40 -fill white -gravity center -annotate +0+0 'LF' \
    "${PNGDET[@]}" -define png:color-type=6 PNG32:"$OUT/badge-alpha-96x96.png"
  made
  # Colour type 3 with and without tRNS: the only HasAlpha branch that is a
  # whole-file scan rather than a single byte read.
  $IM -size 96x96 xc:'#2f7d54' -fill '#e07a3c' -draw 'roundrectangle 12,12 84,84 12,12' \
    -colors 8 -type Palette "${PALDET[@]}" -define png:color-type=3 \
    PNG8:"$OUT/badge-palette-96x96.png"
  made
  $IM -size 96x96 xc:none -fill '#e07a3c' -draw 'roundrectangle 12,12 84,84 12,12' \
    -colors 8 -type PaletteMatte "${PALDET[@]}" -define png:color-type=3 \
    PNG8:"$OUT/badge-palette-alpha-96x96.png"
  made

  # C — the encoder side limits. 8px tall because the limit is per SIDE, not per
  # area: a 16385x8 strip trips the same path a 16385x4000 image would, at 513 B.
  for w in 16383 16384 16385; do
    $IM -size "${w}x8" gradient:'#14201a-#eef2ee' -colorspace sRGB \
      "${PNGDET[@]}" -define png:color-type=2 PNG24:"$OUT/strip-${w}x8.png"
    made
  done
  $IM -size 8x16385 gradient:'#14201a-#eef2ee' -colorspace sRGB \
    "${PNGDET[@]}" -define png:color-type=2 PNG24:"$OUT/strip-8x16385.png"
  made
  # ImageMagick 6 refuses a side past 65535 (-limit width does not lift it), so
  # these two go through Pillow.
  python3 - "$OUT" << 'PY'
import sys
from PIL import Image
out = sys.argv[1]
rgb = Image.new("RGB", (65536, 1))
px = rgb.load()
GREEN, ORANGE = (0x2F, 0x7D, 0x54), (0xE0, 0x7A, 0x3C)  # the repository palette
for x in range(65536):
    px[x, 0] = tuple(a + (b - a) * x // 65535 for a, b in zip(GREEN, ORANGE))
rgb.save(f"{out}/strip-65536x1.png", optimize=True)
rgb.convert("RGBA").save(f"{out}/strip-65536x1-alpha.png", optimize=True)
PY
  made
  made

  # D — framing, and the legacy aspectRatio clamps.
  $IM -size 1600x900 gradient:'#2f7d54-#e07a3c' -font "$FONT" -pointsize 90 -fill white \
    -gravity center -annotate +0+0 'LANDSCAPE 1600x900' -colorspace sRGB \
    "${PNGDET[@]}" -define png:color-type=2 PNG24:"$OUT/landscape-1600x900.png"
  made
  $IM -size 900x1600 gradient:'#2f7d54-#e07a3c' -font "$FONT" -pointsize 70 -fill white \
    -gravity center -annotate +0+0 'PORTRAIT 900x1600' -colorspace sRGB \
    "${PNGDET[@]}" -define png:color-type=2 PNG24:"$OUT/portrait-900x1600.png"
  made
  $IM -size 1000x300 gradient:'#2f7d54-#e07a3c' -colorspace sRGB \
    "${PNGDET[@]}" -define png:color-type=2 PNG24:"$OUT/collapse-1000x300.png"
  made
  $IM -size 100x50 gradient:'#2f7d54-#e07a3c' -colorspace sRGB \
    "${PNGDET[@]}" -define png:color-type=2 PNG24:"$OUT/clamp-100x50.png"
  made
  $IM -size 16x12 gradient:'#2f7d54-#e07a3c' -colorspace sRGB \
    "${PNGDET[@]}" -define png:color-type=2 PNG24:"$OUT/clamp-16x12.png"
  made

  # E — geometry edges.
  $IM -size 4000x3 gradient:'#2f7d54-#e07a3c' -colorspace sRGB \
    "${PNGDET[@]}" -define png:color-type=2 PNG24:"$OUT/panorama-4000x3.png"
  made
  $IM -size 8x8 xc:'#4f9e75' -colorspace sRGB \
    "${PNGDET[@]}" -define png:color-type=2 PNG24:"$OUT/tiny-8x8.png"
  made

  # F — the 8K master. testsrc2, not a gradient: a gradient encodes to AVIF
  # almost instantly and this file exists to cost something. -fflags +bitexact
  # so no encoder/version string lands in the JFIF.
  ffmpeg -hide_banner -loglevel error -nostdin -fflags +bitexact \
    -f lavfi -i testsrc2=size=7680x4320:rate=1 -frames:v 1 -q:v 5 -pix_fmt yuvj420p \
    "$OUT/pattern-7680x4320.jpg" -y
  made

  # G — the content-negotiation master. NO ALPHA: an RGBA replacement silently
  # turns an image/jpeg fallback into image/png, which moves every address a
  # pipeline derives from it.
  $IM -size 64x64 gradient:'#2f7d54-#e07a3c' -colorspace sRGB \
    "${PNGDET[@]}" -define png:color-type=2 PNG24:"$OUT/conformance-hero-64x64.png"
  made

  # H — the attachment stand-in.
  $IM -size 2048x2048 gradient:'#2f7d54-#e07a3c' -font "$FONT" -pointsize 160 -fill white \
    -gravity center -annotate +0+0 'BADGE MASTER 2048' -colorspace sRGB \
    "${PNGDET[@]}" -define png:color-type=2 PNG24:"$OUT/badge-master-2048x2048.png"
  made

  # P — the video poster. A video gets no placeholder ever, so an author who
  # wants one publishes an image asset at the video's exact box.
  $IM -size 320x180 gradient:'#2f7d54-#e07a3c' -font "$FONT" -pointsize 28 -fill white \
    -gravity center -annotate +0+0 'POSTER 320x180' -colorspace sRGB \
    "${PNGDET[@]}" -define png:color-type=2 PNG24:"$OUT/poster-320x180.png"
  made

  # X — the EXIF-orientation guard. IM6's -orient does not write an EXIF profile
  # onto a JPEG that has none (measured: orientation stays Undefined), so Pillow
  # sets the tag.
  $IM -size 1200x800 gradient:'#2f7d54-#e07a3c' -font "$FONT" -pointsize 96 -fill white \
    -gravity center -annotate +0+0 'EXIF 6 / 1200x800' -strip -quality 85 \
    -sampling-factor 4:2:0 "$OUT/_exif-base.jpg"
  python3 - "$OUT" << 'PY'
import sys
from PIL import Image
out = sys.argv[1]
im = Image.open(f"{out}/_exif-base.jpg")
ex = im.getexif(); ex[274] = 6          # IFD0 Orientation = rotate 90 CW
im.save(f"{out}/exif-orient6-1200x800.jpg", quality=85, subsampling="4:2:0", exif=ex)
PY
  rm -f "$OUT/_exif-base.jpg"
  made
  say "27 files"
}

# --------------------------------------------------------------------------
# 2. images/vector — 5 SVG + 2 attachments. The files ARE the recipe.
# --------------------------------------------------------------------------
gen_vector() {
  head_ "images/vector"
  local OUT="$ROOT/images/vector"
  mkdir -p "$OUT/mark.svg.files"

  # Every hostile URL uses example.invalid — RFC 2606 reserves it, so the
  # fixture can never resolve to a real host.
  cat > "$OUT/hazard-panel.svg" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!-- lab-fixtures: the active-content hazards the sanitizer strips, in one file. -->
<svg xmlns="http://www.w3.org/2000/svg"
     xmlns:xlink="http://www.w3.org/1999/xlink"
     xmlns:s="http://www.w3.org/2000/svg"
     width="128" height="128" viewBox="0 0 128 128">
  <title>Sanitizer hazard panel</title>
  <rect width="128" height="128" fill="#eef2ee"
        onload="hazard()" onclick="hazard()" onmouseover="hazard()"/>
  <script>hazard()</script>
  <s:script>hazard()</s:script>
  <foreignObject x="4" y="4" width="60" height="24">
    <div xmlns="http://www.w3.org/1999/xhtml">html escape hatch</div>
  </foreignObject>
  <s:foreignObject x="4" y="32" width="60" height="24">
    <div xmlns="http://www.w3.org/1999/xhtml">prefixed escape hatch</div>
  </s:foreignObject>
  <a xlink:href="javascript:hazard()"><text x="8" y="72">xlink js</text></a>
  <a href="java&#9;script:hazard()"><text x="8" y="86">tab js</text></a>
  <a href="https://example.invalid/exfil"><text x="8" y="100">external</text></a>
  <image href="//example.invalid/x.png" x="8" y="104" width="12" height="12"/>
  <a href="data:text/html;base64,PHA+aGF6YXJkPC9wPg=="><text x="8" y="118">data html</text></a>
  <image href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M8AAAMBAQDJ/pLvAAAAAElFTkSuQmCC"
         x="112" y="112" width="12" height="12"/>
  <circle cx="96" cy="40" r="24" fill="#2f7d54"/>
</svg>
EOF
  made
  # 48/48/"0 0 48 48" must agree: that is the condition removeViewBox needs.
  cat > "$OUT/mark.svg" << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
  <title>lab-fixtures mark</title>
  <rect width="48" height="48" rx="8" fill="#14201a"/>
  <path d="M14 30 L24 14 L34 30 Z" fill="#3f9e6b"/>
  <circle cx="24" cy="34" r="3" fill="#eef2ee"/>
</svg>
EOF
  made
  # Six decimals make `precision` visible; four nested redundant groups make
  # `multipass` visible. Three other candidate shapes moved zero bytes.
  cat > "$OUT/svgo-tuning.svg" << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
  <!-- lab-fixtures: this comment survives only with removeComments turned off -->
  <g opacity="1">
    <g fill="#2f7d54">
      <g stroke="none">
        <g>
          <path d="M6.123456 6.987654 L27.111111 6.987654 L27.111111 27.222222 L6.123456 27.222222 Z"/>
          <path d="M36.876544 36.012346 L57.888889 36.012346 L57.888889 57.777778 L36.876544 57.777778 Z"/>
        </g>
      </g>
    </g>
  </g>
</svg>
EOF
  made
  # Same box as mark.svg, TO THE PIXEL. Widen it and the whole catalog stops loading.
  cat > "$OUT/mark.es.svg" << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
  <title>Marca lab-fixtures</title>
  <rect width="48" height="48" rx="8" fill="#14201a"/>
  <path d="M14 30 L24 14 L34 30 Z" fill="#d2703a"/>
  <circle cx="24" cy="34" r="3" fill="#eef2ee"/>
</svg>
EOF
  made
  # Percentages are refused on purpose: a size the page decides is not a fact
  # about the file. With no viewBox to fall back on, the probe records a note.
  cat > "$OUT/unsized-icon.svg" << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="100%" height="100%">
  <path d="M2 8 L8 2 L14 8 L8 14 Z" fill="#3f9e6b"/>
</svg>
EOF
  made
  # The attachment: the unflattened working file. The lf: namespace is not
  # decoration — SVGO's removeEditorsNSData would strip it, which is exactly why
  # it survives only here.
  cat > "$OUT/mark.svg.files/mark.sketch.svg" << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" xmlns:lf="https://shibanet0.github.io/lab-fixtures/ns"
     width="48" height="48" viewBox="0 0 48 48">
  <metadata>lab-fixtures working file for mark.svg — CC0-1.0</metadata>
  <g id="guides" lf:locked="true" visibility="hidden">
    <line x1="24" y1="0" x2="24" y2="48" stroke="#ff00ff" stroke-width="0.5"/>
    <line x1="0" y1="24" x2="48" y2="24" stroke="#ff00ff" stroke-width="0.5"/>
  </g>
  <g id="bg" lf:layer="Background">
    <rect x="0" y="0" width="48" height="48" rx="8" fill="#14201a"/>
  </g>
  <g id="glyph" lf:layer="Mark">
    <path d="M14 30 L24 14 L34 30 Z" fill="#3f9e6b"/>
  </g>
  <g id="dot" lf:layer="Dot">
    <circle cx="24" cy="34" r="3" fill="#eef2ee"/>
  </g>
</svg>
EOF
  made
  cat > "$OUT/mark.svg.files/layers.meta.json" << 'EOF'
{
  "generator": "lab-fixtures working file",
  "layers": ["Background", "Mark", "Dot"],
  "note": "This file sits inside a .files/ directory and must never be collected as an asset."
}
EOF
  made
  say "7 files (5 SVG + 2 attachments)"
}

# --------------------------------------------------------------------------
# 3. media — delegated to the verified generator, unchanged.
# --------------------------------------------------------------------------
gen_media() {
  head_ "media"
  [ -x "$SRC/tools/make-media-fixtures.sh" ] || {
    echo "tools/make-media-fixtures.sh is missing — copy it from the plan repo" >&2
    exit 1
  }
  bash "$SRC/tools/make-media-fixtures.sh" "$ROOT/media" > /dev/null
  # The two that must never land in a buildable project.
  mkdir -p "$ROOT/media/localized/invalid"
  mv -f "$ROOT/media/localized/reel-wrong-box.de.mp4" \
    "$ROOT/media/localized/reel-unreadable.fr.mp4" "$ROOT/media/localized/invalid/"
  # The patchers belong with the other tools, not inside the fixture tree.
  mkdir -p "$ROOT/tools/patch" && mv -f "$ROOT/media/tools/"*.py "$ROOT/tools/patch/"
  rmdir "$ROOT/media/tools"
  MADE=$((MADE + 54))
  say "54 files (video 21, audio 15, localized 5, edge 13)"
}

# --------------------------------------------------------------------------
# 4. lottie — delegated. Python's zipfile ON PURPOSE: "a ZIP reader and a ZIP
# writer written by the same hand can share a misunderstanding of the format and
# still agree with each other." Do not port this to Node.
# --------------------------------------------------------------------------
gen_lottie() {
  head_ "animation/lottie"
  [ -f "$SRC/tools/make-lottie-fixtures.py" ] || {
    echo "tools/make-lottie-fixtures.py is missing — copy it from the plan repo" >&2
    exit 1
  }
  # The generator ends by iterating its output directory and reading every entry,
  # so `invalid/` has to be created AFTER it runs, not before.
  python3 "$SRC/tools/make-lottie-fixtures.py" "$ROOT/animation/lottie" > /dev/null
  mkdir -p "$ROOT/animation/lottie/invalid"
  mv -f "$ROOT/animation/lottie/caption.bad-box.es.json" "$ROOT/animation/lottie/invalid/"
  MADE=$((MADE + 9))
  say "9 files"
}

# --------------------------------------------------------------------------
# 5. documents — pure Python, no qpdf. Both writers are byte-reproducible: no
# timestamps, no random /ID.
# --------------------------------------------------------------------------
write_pdf_tools() {
  mkdir -p "$ROOT/tools"
  cat > "$ROOT/tools/mkpdf.py" << 'PY'
#!/usr/bin/env python3
# SPDX-License-Identifier: CC0-1.0
"""Emit a byte-reproducible PDF whose pages have exactly the sizes given.

Usage: mkpdf.py out.pdf "WxH[:rot][:label]" ...
   e.g. mkpdf.py mixed.pdf "595x842::A4 portrait" "842x595:90:rotated"
"""
import sys


def build(pages):
    objs = {}
    n_pages = len(pages)
    kids = " ".join(f"{4 + 2 * i} 0 R" for i in range(n_pages))
    objs[1] = b"<< /Type /Catalog /Pages 2 0 R >>"
    objs[2] = f"<< /Type /Pages /Kids [{kids}] /Count {n_pages} >>".encode("latin-1")
    objs[3] = b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"
    for i, (w, h, rot, label) in enumerate(pages):
        page_no = 4 + 2 * i
        content_no = page_no + 1
        rot_entry = f" /Rotate {rot}" if rot else ""
        objs[page_no] = (
            f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {w} {h}]{rot_entry} "
            f"/Contents {content_no} 0 R /Resources << /Font << /F1 3 0 R >> >> >>"
        ).encode("latin-1")
        stream = (
            f"BT /F1 18 Tf 24 {h - 48} Td ({label}) Tj ET\n"
            f"1 w 12 12 {w - 24} {h - 24} re S\n"
        ).encode("latin-1")
        objs[content_no] = (b"<< /Length " + str(len(stream)).encode() + b" >>\n"
                            b"stream\n" + stream + b"endstream")

    out = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
    offsets = {}
    for num in sorted(objs):
        offsets[num] = len(out)
        out += f"{num} 0 obj\n".encode("latin-1") + objs[num] + b"\nendobj\n"
    xref_at = len(out)
    count = max(objs) + 1
    out += f"xref\n0 {count}\n".encode("latin-1")
    out += b"0000000000 65535 f \n"
    for num in range(1, count):
        out += f"{offsets[num]:010d} 00000 n \n".encode("latin-1")
    out += (f"trailer\n<< /Size {count} /Root 1 0 R >>\n"
            f"startxref\n{xref_at}\n%%EOF\n").encode("latin-1")
    return bytes(out)


def parse(spec):
    parts = spec.split(":")
    w, h = parts[0].split("x")
    rot = int(parts[1]) if len(parts) > 1 and parts[1] else 0
    label = parts[2] if len(parts) > 2 else f"{w}x{h}pt"
    return int(w), int(h), rot, label


if __name__ == "__main__":
    dest, specs = sys.argv[1], sys.argv[2:]
    with open(dest, "wb") as fh:
        fh.write(build([parse(s) for s in specs]))
PY

  cat > "$ROOT/tools/mklocked.py" << 'PY'
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
PY
}

gen_pdf() {
  head_ "documents/pdf"
  write_pdf_tools
  local OUT="$ROOT/documents/pdf"
  mkdir -p "$OUT/invalid" "$OUT/report.pdf.files"
  local MK="python3 $ROOT/tools/mkpdf.py"

  # A4 makes the round-half-up in scalePoints visible; US Letter divides exactly
  # and is the control; page 5 carries /Rotate 90 and probes 842x595, so pages 2
  # and 5 land on the SAME box and must still get different addresses.
  $MK "$OUT/pages-mixed.pdf" \
    "595x842::Page 1 - A4 portrait 595x842pt" \
    "842x595::Page 2 - A4 landscape 842x595pt" \
    "612x792::Page 3 - US Letter 612x792pt" \
    "504x504::Page 4 - square 504x504pt" \
    "595x842:90:Page 5 - A4 portrait with Rotate 90"
  made

  # The KindDocument download pair. The label is ASCII on purpose: base-14
  # Helvetica is StandardEncoding and literal Cyrillic would render as mojibake.
  # The Cyrillic that matters is the downloadName, which lives in the metafile.
  $MK "$OUT/terms.pdf" "595x842::Terms of Service - lab-fixtures CC0 - EN"
  made
  $MK "$OUT/terms.es.pdf" "595x842::Terminos del servicio - lab-fixtures CC0 - ES"
  made

  # The KindPdf localized set. Only page 1's size in POINTS is pinned.
  $MK "$OUT/report.pdf" \
    "595x842::Report EN p1 A4" "595x842::Report EN p2 A4" "842x595::Report EN p3 A4 landscape"
  made
  $MK "$OUT/report.es.pdf" \
    "595x842::Report ES p1 A4" "595x842::Report ES p2 A4" "842x595::Report ES p3 A4 landscape"
  made
  $MK "$OUT/report.ja.pdf" \
    "595x842::Report JA p1 A4" "595x842::Report JA p2 A4"
  made
  # Says on the page that it is wrong, or somebody will "fix" it.
  $MK "$OUT/invalid/report.de.pdf" \
    "612x792::Report DE p1 US Letter - INTENTIONALLY THE WRONG BOX"
  made

  # 7864pt -> 16383px at dpi 150 (WebP's ceiling); 8192pt -> 16384px at dpi 144
  # (AVIF's ceiling). NEITHER DPI ALONE REACHES BOTH — import at both.
  $MK "$OUT/page-limits.pdf" \
    "7864x72::p1 7864x72pt - 16383px at 150dpi, WebP ceiling" \
    "8192x72::p2 8192x72pt - 16384px at 144dpi, AVIF ceiling" \
    "8193x72::p3 8193x72pt - over every modern format"
  made

  python3 "$ROOT/tools/mklocked.py" "$OUT/locked.pdf"
  made
  printf '%%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\n%%%%EOF\n' > "$OUT/truncated.pdf"
  made

  cat > "$OUT/report.pdf.files/report-src.sh" << 'EOF'
#!/usr/bin/env sh
# The authored input report.pdf was exported from. Attachments are stored,
# never served: this file is here so next month's edit starts from a source.
python3 ../../tools/mkpdf.py report.pdf \
  "595x842::Report EN p1 A4" \
  "595x842::Report EN p2 A4" \
  "842x595::Report EN p3 A4 landscape"
EOF
  made
  say "11 files (10 PDF + 1 attachment)"
}

# --------------------------------------------------------------------------
# 6. web/html — the files ARE the recipe. Do NOT add a conditional comment:
# html-minifier-terser preserves those and "exactly one comment survives" fails.
# --------------------------------------------------------------------------
gen_web() {
  head_ "web/html"
  local OUT="$ROOT/web/html"
  mkdir -p "$OUT"
  # The marker is PADDED on purpose: the recorded placeholder is the exact bytes
  # that survived, never DefaultEnvPlaceholder. One comment before it and one
  # after prove the scan walks past non-matching comments.
  cat > "$OUT/shell.html" << 'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>lab-fixtures shell</title>
    <!-- ordinary comment #1: the minifier must drop this one -->
    <style>
      :root {
        --ink: #14201a;
      }
      body {
        margin: 0px;
        color: var(--ink);
        font-family: system-ui, sans-serif;
      }
    </style>
  </head>
  <body>
    <!--   __ENV__   -->
    <main   id="root">
        <h1>lab-fixtures</h1>
        <!-- ordinary comment #2: after the marker, also dropped -->
        <p>Static shell for runtime ENV injection.</p>
    </main>
    <script>
      const el = document.getElementById("root");
      const env = window.__env || {};
      el.dataset.env = JSON.stringify(env);
    </script>
  </body>
</html>
EOF
  made
  # No marker anywhere: the only HTML shape a static export accepts.
  cat > "$OUT/page.html" << 'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <title>lab-fixtures static page</title>
    <!-- no ENV marker: this page is exportable to a static file tree -->
    <style>
      body {
        margin: 0px;
        font-family: system-ui, sans-serif;
      }
    </style>
  </head>
  <body>
    <h1>lab-fixtures</h1>
    <p>A plain HTML asset with no runtime ENV placeholder.</p>
  </body>
</html>
EOF
  made
  say "2 files"
}

# --------------------------------------------------------------------------
# 7. data + fonts
# --------------------------------------------------------------------------
gen_data() {
  head_ "data"
  local OUT="$ROOT/data"
  mkdir -p "$OUT"
  # kind: json. Keys deliberately unsorted; 1.50 stays literal under UseNumber;
  # <, > and & are escaped to < > & in the served body.
  cat > "$OUT/site-config.json" << 'EOF'
{
  "name": "lab-fixtures demo config",
  "schema": "https://shibanet0.github.io/lab-fixtures/config.schema.json",
  "featureFlags": {
    "newNav": true,
    "beta": false
  },
  "retries": 3,
  "timeoutSeconds": 1.50,
  "banner": "<b>Hello</b> & welcome",
  "locales": ["en", "ja", "es"],
  "empty": null
}
EOF
  made
  # kind: raw. SAME extension, other kind: 212 B in and out. Filed as json it
  # would be 192 B with every object key re-sorted.
  cat > "$OUT/signed-payload.json" << 'EOF'
{
  "note": "Filed as kind=raw: these exact bytes are the point.",
  "orderedKeys": ["z", "a", "m"],
  "amount": "1.50",
  "signature": "sha256:0000000000000000000000000000000000000000000000000000000000000000"
}
EOF
  made
  # The compressible raw asset: 16:1 under gzip, so the encoding matrix is
  # unmistakable. The complement of every PDF and every media container.
  local i=0
  : > "$OUT/notes.txt"
  while [ "$i" -lt 40 ]; do
    printf 'lab-fixtures CC0 sample text\n' >> "$OUT/notes.txt"
    i=$((i + 1))
  done
  made
  say "3 files"
}

gen_fonts() {
  head_ "fonts"
  mkdir -p "$ROOT/fonts"
  # NOT a font: a wOF2 magic number and 40 bytes of ASCII. Nothing in a delivery
  # pipeline parses a font, so a stub is enough to exercise every path a real one
  # would reach — and keeping these exact bytes keeps its sha256 stable.
  # bash, not fish: fish's printf does not take \xHH.
  printf 'wOF2\x00\x01\x00\x00brand-font-fixture-bytes-not-a-real-font' > "$ROOT/fonts/not-a-font.woff2"
  made
  say "1 file (a generated demo woff2 would need fontTools and is out of scope)"
}

# --------------------------------------------------------------------------
# animation/rive — the slot, not the artwork.
#
# No command can write a `.riv`: the format's value widths come from a property
# registry that moves every release, so only Rive's own editor can export one.
# The directory is generated rather than committed by hand, because dist/ is
# meant to be deletable — a hand-kept file here would vanish on the first wipe.
# --------------------------------------------------------------------------
gen_rive() {
  head_ "animation/rive"
  mkdir -p "$ROOT/animation/rive"
  cat > "$ROOT/animation/rive/README.md" << 'EOF'
# Rive fixtures

Planned, not shipped. A `.riv` can only be authored in the Rive editor, so no
command in this repository can produce one and none is faked here.

This directory is written by `src/generate.sh` so that it survives a `rm -rf dist`.
Its contents are documentation and stay outside `SHA256SUMS`.
EOF
  say "placeholder only — no .riv is generated or faked"
}

# --------------------------------------------------------------------------
# checksums + report
# --------------------------------------------------------------------------
# README.md and .gitkeep inside a fixture tree are prose and placeholders, not masters, and OS
# junk is not content at all. Hashing any of them makes a documentation edit — or a single Finder
# visit, which drops a .DS_Store — fail `--check` for everyone.
NOT_A_FIXTURE=(! -name SHA256SUMS ! -name README.md ! -name .gitkeep
  ! -name .DS_Store ! -name Thumbs.db)

# The asset trees, relative to the repository root. `dist/tools/` is generated provenance rather
# than fixture content, so it is deliberately absent.
FIXTURE_TREES=(dist/images dist/media dist/animation dist/documents dist/web dist/data dist/fonts)

checksums() {
  # Paths are recorded relative to the repository root, so `--check` runs from there and the
  # `dist/` prefix stays visible in the contract.
  (cd "$REPO" && find "${FIXTURE_TREES[@]}" -type f \
    "${NOT_A_FIXTURE[@]}" -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
}

report() {
  local n bytes
  n=$(cd "$REPO" && find "${FIXTURE_TREES[@]}" -type f "${NOT_A_FIXTURE[@]}" | wc -l)
  bytes=0
  while IFS= read -r -d '' file; do
    if size=$(stat -f%z "$file" 2> /dev/null); then
      :
    else
      size=$(stat -c%s "$file")
    fi
    bytes=$((bytes + size))
  done < <(find "${FIXTURE_TREES[@]/#/$REPO/}" -type f "${NOT_A_FIXTURE[@]}" -print0)
  printf '\n%s\n' "-------------------------------------------------------------"
  awk -v n="$n" -v b="$bytes" 'BEGIN { printf "wrote %d files, %d bytes (%.2f MiB)\n", n, b, b/1048576 }'
  printf 'SHA256SUMS written to %s/SHA256SUMS\n' "$REPO"
  cat << 'NOTE'

Rive is not part of the current fixture set.
fonts/labfixtures-demo.woff2 is optional and remains out of scope without fontTools.

Then: commit SHA256SUMS. The bytes are the artifact — never regenerate in place.
NOTE
}

# --------------------------------------------------------------------------
main() {
  case "${1:-all}" in
    --check)
      [ -f "$REPO/SHA256SUMS" ] || {
        echo "no SHA256SUMS to check against" >&2
        exit 1
      }
      (cd "$REPO" && sha256sum -c SHA256SUMS --quiet) && echo "OK — every fixture matches"
      exit $?
      ;;
    images)
      preflight
      gen_images
      ;;
    vector) gen_vector ;;
    media)
      preflight
      gen_media
      ;;
    lottie) gen_lottie ;;
    rive) gen_rive ;;
    pdf) gen_pdf ;;
    web) gen_web ;;
    data) gen_data ;;
    fonts) gen_fonts ;;
    all)
      preflight
      gen_images
      gen_vector
      gen_media
      gen_lottie
      gen_rive
      gen_pdf
      gen_web
      gen_data
      gen_fonts
      checksums
      report
      ;;
    *)
      echo "usage: $0 [all|--check|images|vector|media|lottie|rive|pdf|web|data|fonts]" >&2
      exit 2
      ;;
  esac
}
main "$@"
