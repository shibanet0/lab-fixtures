#!/usr/bin/env python3
# SPDX-License-Identifier: CC0-1.0
"""Emit the lab-fixtures Lottie set. Standard library only; Python 3.9+.

Every file is byte-reproducible: compact separators, sorted keys, a pinned ZIP
timestamp and a pinned deflate level. Run it twice, get the same sha256 --
which matters, because a metafile records sha256 over the master and a build
refuses a source that drifted from it.

Usage: python3 make-lottie-fixtures.py [outdir]
"""
import hashlib
import json
import pathlib
import sys
import zipfile

OUT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "animation/lottie")

# 1980-01-01 is the earliest a DOS timestamp can express. Pinning it is what
# makes the archive's sha256 the same on every machine.
EPOCH = (1980, 1, 1, 0, 0, 0)

# The palettes. Nothing here depicts anything anyone else drew: three flat
# rectangles on a coloured ground.
GROUND_BLOCK_BAR = ("#14201a", "#e07a3c", "#ffffff")  # ink / orange / white
FOREST_GREEN_WHITE = ("#1b3a30", "#3f9e6b", "#ffffff")  # a visibly different locale


def dumps(obj):
    return json.dumps(obj, separators=(",", ":"), sort_keys=True).encode("utf-8")


def solid(name, index, colour, width, height, ip, op, fade_to, position):
    """A solid-colour layer: invisible at `ip`, fully opaque at `fade_to`, rotating to `op`."""
    return {
        "ao": 0, "bm": 0, "ddd": 0, "ind": index, "ip": ip, "nm": name, "op": op,
        "sc": colour, "sh": height, "sr": 1, "st": 0, "sw": width, "ty": 1,
        "ks": {
            "a": {"a": 0, "k": [width / 2, height / 2, 0]},
            "o": {"a": 1, "k": [
                {"t": ip, "s": [0], "i": {"x": [0.5], "y": [1]}, "o": {"x": [0.5], "y": [0]}},
                {"t": fade_to, "s": [100]},
            ]},
            "p": {"a": 0, "k": position},
            "r": {"a": 1, "k": [
                {"t": ip, "s": [0], "i": {"x": [0.5], "y": [1]}, "o": {"x": [0.5], "y": [0]}},
                {"t": op, "s": [180]},
            ]},
            "s": {"a": 0, "k": [100, 100, 100]},
        },
    }


def pulse(w=512, h=512, fr=60, ip=30, op=90, palette=GROUND_BLOCK_BAR, nm="pulse"):
    """The reference scene: blank at its in-point, fully painted at the placeholder frame.

    The opacity ramp ends exactly at round((op - ip) * 0.1) frames past the in
    point, which is where a placeholder generator that samples 10% into a scene
    lands. So frame 0 is empty and the sampled frame is the finished picture:
    the fixture proves a renderer is not simply grabbing frame zero.
    """
    ground, block, bar = palette
    fade_to = ip + round((op - ip) * 0.1)
    return {
        "v": "5.7.4", "nm": nm, "ddd": 0, "fr": fr, "ip": ip, "op": op,
        "w": w, "h": h, "assets": [],
        "layers": [
            solid("bar", 1, bar, w // 8, h // 2, ip, op, fade_to, [w * 0.66, h * 0.34, 0]),
            solid("block", 2, block, w // 2, h // 2, ip, op, fade_to, [w * 0.34, h * 0.34, 0]),
            solid("ground", 3, ground, w, h, ip, op, fade_to, [w / 2, h / 2, 0]),
        ],
    }


def tiny(w=20, h=40, fr=30, ip=0, op=30):
    """The smallest scene both readers accept: a header and no layers."""
    return {"v": "5.7.4", "fr": fr, "h": h, "ip": ip, "layers": [], "op": op, "w": w}


def write_zip(path, members, method, manifest=None):
    with zipfile.ZipFile(path, "w") as z:
        entries = ([("manifest.json", dumps(manifest))] if manifest is not None else []) + [
            ("animations/%s.json" % name, body) for name, body in members
        ]
        for name, body in entries:
            info = zipfile.ZipInfo(name, EPOCH)
            info.compress_type = method
            info.create_system = 3          # Unix, so the file is not host-dependent
            info.external_attr = 0o644 << 16
            z.writestr(info, body, compresslevel=9)   # pinned: zlib's default is host policy


OUT.mkdir(parents=True, exist_ok=True)

# 1. The reference scene, and the two container shapes of the same bytes.
scene = dumps(pulse())
(OUT / "pulse-512.json").write_bytes(scene)
write_zip(OUT / "pulse-512.lottie", [("pulse", scene)], zipfile.ZIP_DEFLATED,
          {"animations": [{"id": "pulse"}], "generator": "lab-fixtures", "version": "1.0.0"})
write_zip(OUT / "pulse-no-manifest.lottie", [("only", scene)], zipfile.ZIP_DEFLATED)

# 2. STORED rather than DEFLATED, and a non-square box so a w/h swap is caught.
write_zip(OUT / "tiny-stored.lottie", [("tiny", dumps(tiny()))], zipfile.ZIP_STORED,
          {"animations": [{"id": "tiny"}], "version": "1.0.0"})

# 3. Two animations; the archive's own manifest.json names the one a
#    conventional-layout fallback would NOT pick.
write_zip(OUT / "two-animations.lottie",
          [("first", dumps(pulse(w=320, h=240, fr=30, ip=0, op=30, nm="first"))),
           ("second", dumps(pulse(w=640, h=360, fr=25, ip=0, op=50, nm="second")))],
          zipfile.ZIP_DEFLATED,
          {"animations": [{"id": "second"}, {"id": "first"}], "version": "1.0.0"})

# 4. Valid JSON, states a box, names no frame rate: Skottie refuses to load it.
(OUT / "no-framerate.json").write_bytes(
    dumps({"v": "5.7.4", "h": 512, "ip": 0, "layers": [], "op": 30, "w": 512}))

# 5. The localized trio: identical box, different bytes, different duration.
(OUT / "caption.json").write_bytes(
    dumps(pulse(w=512, h=512, fr=60, ip=0, op=60, palette=GROUND_BLOCK_BAR, nm="caption")))
(OUT / "caption.es.json").write_bytes(
    dumps(pulse(w=512, h=512, fr=60, ip=0, op=90, palette=FOREST_GREEN_WHITE, nm="caption-es")))
(OUT / "caption.bad-box.es.json").write_bytes(
    dumps(pulse(w=640, h=512, fr=60, ip=0, op=60, palette=FOREST_GREEN_WHITE, nm="caption-es")))

for p in sorted(OUT.iterdir()):
    if p.is_file():
        print("%-28s %6d  %s" % (p.name, p.stat().st_size, hashlib.sha256(p.read_bytes()).hexdigest()))
