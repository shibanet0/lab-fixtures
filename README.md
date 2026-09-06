# lab-fixtures

Self-generated, openly licensed test and demo assets: images, video, audio,
PDFs, animations, SVG, HTML and raw data. Every shipped asset was produced by
a script or written from scratch by the author. Nothing here is derived from
third-party media.

**Licence: CC0-1.0.** Public-domain dedication — use these files for anything,
with no attribution, in any project, commercial or not. See [LICENSE](LICENSE).

**114 fixtures, 1,798,838 bytes (1.72 MiB)** under `dist/`, every one of them
listed in `SHA256SUMS`.

## Why this exists

Test suites need real files: a JPEG with an EXIF rotation tag, an MP4 whose
header lies about its duration, a PDF nothing can open, an SVG carrying XSS
vectors a sanitizer should strip, and a `.lottie` archive whose internal
`manifest.json` names an animation the conventional fallback would not pick.
These fixtures provide those cases without third-party media or licensing
baggage.

## Layout

Sources and outputs are kept apart, so `rm -rf dist` followed by one command is
a complete end-to-end test of the recipes.

```text
src/                    hand-written generators — the only place to edit
├── generate.sh         the single entry point
└── tools/              the media and Lottie generators it delegates to

dist/                   everything the generators produce; safe to delete
SHA256SUMS              the contract, covering dist/ only
```

| directory                                | contents                                                                                                           |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `dist/images/raster/`                    | 27 PNG and JPEG masters: gradients, test cards, encoder side-limit strips and an EXIF-rotation guard               |
| `dist/images/vector/`                    | 5 SVG masters and 2 attachment files: sanitizer hazards, clean/localized marks, an SVGO target and an unsized icon |
| `dist/media/video/`, `dist/media/audio/` | 21 video and 15 audio containers, including rotation, anamorphic, fragmented and duration cases                    |
| `dist/media/localized/`                  | 3 valid localized videos and 2 intentionally invalid ones under `invalid/`                                         |
| `dist/media/edge/`                       | 13 cut-short, hostile or mislabelled media files                                                                   |
| `dist/animation/lottie/`                 | 9 Lottie scenes and archives, including invalid and two-animation cases                                            |
| `dist/animation/rive/`                   | Planned only: a generated README, no `.riv` or `.rev` is shipped                                                   |
| `dist/documents/pdf/`                    | 10 PDFs and 1 source attachment under `report.pdf.files/`                                                          |
| `dist/web/html/`                         | 2 HTML masters                                                                                                     |
| `dist/data/`                             | 2 JSON files and 1 text file                                                                                       |
| `dist/fonts/`                            | `not-a-font.woff2`, a deliberate 48-byte WOFF2 stub                                                                |
| `dist/tools/`                            | byte-level patchers the run emits as provenance — generated, and not fixtures                                      |

Files under `**/invalid/` are meant to be rejected. Do not load them into a
project that is expected to build successfully.

## Reproducing them

```sh
rm -rf dist
./src/generate.sh          # writes dist/ and SHA256SUMS
./src/generate.sh --check  # verifies SHA256SUMS, writes nothing
```

The generator auto-selects `magick` when it is available and keeps `IM=`
overridable. It searches for Linux DejaVu Sans Bold first, then falls back to
`~/Library/Fonts/NerdFonts/DejaVuSansMNerdFont-Bold.ttf`, which is what this set
was rendered with; set `FONT=` to choose another compatible font. The font is a
build-time input and is not redistributed here. Rive files are not generated:
`.riv` can only be authored in the Rive editor.

## Build notes

This set was produced with ffmpeg 8.1.2, ImageMagick 7 and Pillow 12, rendering
text with DejaVu Sans Mono Nerd Font Bold. Change any of those and the bytes
change with them, which is why `SHA256SUMS` is committed rather than recomputed.

Two things could not be produced here and are documented rather than faked:

- **`tone-a440.ogg` is stereo.** This machine's ffmpeg has no `libvorbis`
  encoder, and the native Vorbis encoder supports two channels only, so a mono
  file was not reachable. The generator prefers `libvorbis`, falls back to
  `oggenc`, and only then to the stereo path — printing a warning when it does.
- **`animation/rive/` and a generated demo WOFF2 are absent.** The first needs
  the Rive editor, the second `fontTools`. Neither is faked.

## Design choices

**The locale is `es`.** Every localized master, its filename and its rendered
text are Spanish. Nothing in this repository contains Cyrillic.

**The palette is green and orange** — `#2f7d54` and `#e07a3c`, with `#1f6b6b`
and `#f2a570` for the localized siblings, `#14201a` and `#eef2ee` for ink and
paper. It is deliberately brand-neutral and carries no yellow.

Three colours are **not** part of the palette and should stay as they are,
because each one is load-bearing:

| where             | colour                                        | why                                                                                                      |
| ----------------- | --------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `media/` picture  | SMPTE bars with a white-and-red corner marker | a rotation fixture with a symmetric picture proves nothing to a human eye                                |
| `hero-*.png`      | white guide lines                             | they make the authored crop visible as a band                                                            |
| `mark.sketch.svg` | magenta strokes on a hidden layer             | magenta is the editor convention for guides, and that attachment exists to look like a real working file |

## The committed bytes are the artifact

`src/generate.sh` is provenance, not a build step. Its recipes are reproducible
on one machine, but ImageMagick's PNG writer, libjpeg, ffmpeg encoders and the
font rasterizer can change bytes between machines.

Downstream tools content-address these files. **If a fixture must change, add a
new name such as `-v2`; never change an existing fixture's bytes.**
`SHA256SUMS` is the contract.

Never let a formatter touch `dist/`. Four guards, each covering a different
tool's entry point:

| file                         | what it stops                                                                                         |
| ---------------------------- | ----------------------------------------------------------------------------------------------------- |
| `.datamitsuignore`           | every datamitsu-managed tool, via `dist/**: *`                                                        |
| `.prettierignore`            | prettier — and oxfmt, which honours the same file                                                     |
| `.editorconfig-checker.json` | the editorconfig checker, which runs repository-wide and so is not filtered by the ignore files above |
| `.gitattributes`             | `* -text`, so no checkout can rewrite a line ending inside a hashed file                              |

`.prettierignore` lists `dist/` rather than `*`: oxfmt reads it too, and a
blanket `*` leaves oxfmt with no files to format and a hard error.
`.editorconfig` marks `dist/**` as `insert_final_newline = false` so an editor
will not append a byte on save; the checker is pointed away from it instead,
because the fixtures are deliberately mixed on that point.

Documentation and OS junk are outside the checksum contract — the generated
`dist/animation/rive/README.md`, any `.gitkeep`, and any `.DS_Store` a Finder
visit leaves behind — so neither a prose edit nor an accidental browse can fail
`--check`.

## Notes

- The `locked.pdf` user password is `lab-fixtures`. It is a fixture, not a secret.
- Hostile URLs use `example.invalid`, so they cannot resolve to a real host.
- `fonts/not-a-font.woff2` is intentionally not a usable font.

## Provenance

Authored and generated by Alexander Svinarev, 2026.
