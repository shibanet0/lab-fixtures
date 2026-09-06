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
