#!/usr/bin/env python3
"""Extract object sprites from the original PuzzleScript source.

Reads ../refs/enigmash-original/game.txt, parses the OBJECTS section,
and writes one PNG per object with a 5x5 glyph grid into
../assets/sprites/objects/<name>.png.

PuzzleScript object syntax inside OBJECTS:

    <name> [<glyph>]
    <color1> [<color2> ...]            # palette; PS color name OR #rrggbb
    <row0>                             # 5 chars from "0123456789." or empty
    <row1>
    ...
    <row4>
    <blank line>

Glyph row chars index into the palette (0 = first color). '.' or '0'
that doesn't fit the palette becomes transparent. Empty grid = no
sprite generated (entry is logic-only / hidden).

The output is upscaled NEAREST to 128x128 to match the engine's
expected source resolution and the renderer's POINT filter.
"""
from __future__ import annotations

import os
import re
import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "refs/enigmash-original/game.txt"
OUT_DIR = ROOT / "assets/sprites/objects"

# PuzzleScript named colors (subset that appears in the source). Hex
# literals (#rgb / #rrggbb) are handled separately.
PS_COLORS = {
    "black":      (0x00, 0x00, 0x00),
    "white":      (0xFF, 0xFF, 0xFF),
    "lightgray":  (0xC0, 0xC0, 0xC0),
    "gray":       (0x80, 0x80, 0x80),
    "darkgray":   (0x40, 0x40, 0x40),
    "red":        (0xD0, 0x40, 0x40),
    "darkred":    (0x80, 0x20, 0x20),
    "lightred":   (0xFF, 0x80, 0x80),
    "brown":      (0x80, 0x50, 0x20),
    "darkbrown":  (0x50, 0x30, 0x10),
    "lightbrown": (0xC0, 0x80, 0x40),
    "orange":     (0xE0, 0x90, 0x30),
    "yellow":     (0xE0, 0xD0, 0x40),
    "lightyellow":(0xFF, 0xF0, 0x80),
    "darkyellow": (0xA0, 0x90, 0x20),
    "green":      (0x40, 0xA0, 0x40),
    "darkgreen":  (0x20, 0x60, 0x20),
    "lightgreen": (0x80, 0xE0, 0x80),
    "blue":       (0x40, 0x60, 0xC0),
    "lightblue":  (0x80, 0xA0, 0xE0),
    "darkblue":   (0x20, 0x30, 0x80),
    "purple":     (0x90, 0x40, 0xC0),
    "pink":       (0xFF, 0xA0, 0xC0),
    "transparent":(0x00, 0x00, 0x00, 0x00),
}

SECTION_NAMES = {"objects", "legend", "sounds", "collisionlayers",
                 "rules", "winconditions", "levels"}


def parse_color(token: str) -> tuple[int, int, int, int] | None:
    t = token.strip().lower()
    if not t:
        return None
    if t.startswith("#"):
        h = t[1:]
        if len(h) == 3:
            r, g, b = (int(c * 2, 16) for c in h)
            return (r, g, b, 255)
        if len(h) == 6:
            r = int(h[0:2], 16); g = int(h[2:4], 16); b = int(h[4:6], 16)
            return (r, g, b, 255)
        return None
    rgb = PS_COLORS.get(t)
    if rgb is None:
        return None
    if len(rgb) == 3:
        return (*rgb, 255)
    return rgb  # transparent


def write_png(path: Path, w: int, h: int, pixels: list[tuple[int, int, int, int]]) -> None:
    # Tiny PNG writer so the script stays dependency-free.
    raw = bytearray()
    for y in range(h):
        raw.append(0)  # filter: None
        for x in range(w):
            r, g, b, a = pixels[y * w + x]
            raw += bytes((r, g, b, a))
    def chunk(typ: bytes, data: bytes) -> bytes:
        return (struct.pack(">I", len(data)) + typ + data
                + struct.pack(">I", zlib.crc32(typ + data) & 0xFFFFFFFF))
    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    idat = zlib.compress(bytes(raw), 9)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(sig + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b""))


def upscale(src_w: int, src_h: int, src: list[tuple[int, int, int, int]],
            scale: int) -> tuple[int, int, list[tuple[int, int, int, int]]]:
    out_w, out_h = src_w * scale, src_h * scale
    out: list[tuple[int, int, int, int]] = [(0, 0, 0, 0)] * (out_w * out_h)
    for y in range(out_h):
        sy = y // scale
        for x in range(out_w):
            sx = x // scale
            out[y * out_w + x] = src[sy * src_w + sx]
    return out_w, out_h, out


def parse_objects_section(text: str) -> list[tuple[str, list[str]]]:
    """Returns [(name, lines_after_name)] for each entry in OBJECTS."""
    lines = text.splitlines()
    # Find OBJECTS … <next section>.
    obj_start = obj_end = -1
    for i, ln in enumerate(lines):
        s = ln.strip().lower()
        if s == "objects" and obj_start < 0:
            obj_start = i + 1
            continue
        if obj_start >= 0 and s in SECTION_NAMES and s != "objects":
            obj_end = i
            break
    if obj_start < 0 or obj_end < 0:
        sys.exit("Could not locate OBJECTS … <next> sentinels.")
    body = lines[obj_start + 1:obj_end - 1]  # strip leading/trailing '====' bars

    entries: list[tuple[str, list[str]]] = []
    cur_name: str | None = None
    cur_buf: list[str] = []
    for raw in body:
        if not raw.strip():
            if cur_name is not None:
                entries.append((cur_name, cur_buf))
                cur_name = None
                cur_buf = []
            continue
        if cur_name is None:
            # First word is the object name; an optional one-char glyph
            # follows. Drop the glyph — names are what we key off.
            tok = raw.split()
            cur_name = tok[0].lower()
        else:
            cur_buf.append(raw)
    if cur_name is not None:
        entries.append((cur_name, cur_buf))
    return entries


def render_entry(name: str, body: list[str]) -> tuple[int, int, list[tuple[int, int, int, int]]] | None:
    # First non-empty line in the body is the palette. Subsequent lines
    # of digits form the 5x5 grid.
    if not body:
        return None
    palette_line = body[0]
    grid = body[1:]
    # Tokens may be space-separated; the original format also allows
    # trailing comments after the palette but those are rare.
    palette: list[tuple[int, int, int, int]] = []
    for tok in palette_line.split():
        c = parse_color(tok)
        if c is None:
            print(f"  ! {name}: unknown color token '{tok}'", file=sys.stderr)
            return None
        palette.append(c)
    if not palette:
        return None
    # Filter pixel rows: must be 5 chars of digits or '.' (allow '|', '~' to be skipped).
    rows = [r for r in grid if r and re.match(r"^[0-9.]{1,5}$", r)]
    if len(rows) != 5:
        return None
    pixels: list[tuple[int, int, int, int]] = [(0, 0, 0, 0)] * 25
    for y, row in enumerate(rows):
        row = row.ljust(5, ".")[:5]
        for x, ch in enumerate(row):
            if ch == ".":
                pixels[y * 5 + x] = (0, 0, 0, 0)
            else:
                idx = int(ch)
                if idx < len(palette):
                    pixels[y * 5 + x] = palette[idx]
                else:
                    pixels[y * 5 + x] = (0, 0, 0, 0)
    return 5, 5, pixels


def main() -> None:
    text = SOURCE.read_text(encoding="utf-8", errors="replace")
    entries = parse_objects_section(text)
    print(f"Parsed {len(entries)} entries from OBJECTS")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    written = 0
    for name, body in entries:
        rendered = render_entry(name, body)
        if rendered is None:
            continue
        sw, sh, px = rendered
        out_w, out_h, big = upscale(sw, sh, px, 25)  # 5×25 = 125 ≈ 128
        # Pad to 128 by left/top to keep it crisp 25× and centered-ish.
        pw, ph = 128, 128
        ox = (pw - out_w) // 2
        oy = (ph - out_h) // 2
        canvas = [(0, 0, 0, 0)] * (pw * ph)
        for y in range(out_h):
            for x in range(out_w):
                canvas[(oy + y) * pw + (ox + x)] = big[y * out_w + x]
        write_png(OUT_DIR / f"{name}.png", pw, ph, canvas)
        written += 1
    print(f"Wrote {written} sprites to {OUT_DIR}")


if __name__ == "__main__":
    main()
