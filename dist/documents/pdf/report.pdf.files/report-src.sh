#!/usr/bin/env sh
# The authored input report.pdf was exported from. Attachments are stored,
# never served: this file is here so next month's edit starts from a source.
python3 ../../tools/mkpdf.py report.pdf \
  "595x842::Report EN p1 A4" \
  "595x842::Report EN p2 A4" \
  "842x595::Report EN p3 A4 landscape"
