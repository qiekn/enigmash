#!/usr/bin/env python3
"""Decode the original enigmash LEVELS block into a single region JSON.

Reads ../refs/enigmash-original/game.txt, resolves each cell character
through the LEGEND section, then maps PS object names to our sharply
smaller vocabulary and writes assets/data/world/enigmash.json.

The original map is a single ~104x104 grid with all 6 mechanics woven
through it. We treat the whole thing as one body and additionally emit
a `region_map` (same shape as cells) that labels each cell 0..6: 0 means
"default region" (r1_sokoban), 1..6 mean the matching mechanic. The map
is computed via multi-source BFS from the in-source N-marker tiles
('1'..'6'), with walls blocking propagation. The C++ dispatcher reads
region_map[y][x] when the player stands on it.

We don't support every original mechanic (letters, messages, warps,
connectors, multi-sprite composites). Unmapped chars become floor.
"""
from __future__ import annotations

import json
import re
import sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "refs/enigmash-original/game.txt"
OUT = ROOT / "assets/data/world/enigmash.json"

# Lines that demarcate the LEVELS grid inside the source. Lines before
# LEVEL_START_PATTERN but inside the section are comments / messages.
LEVEL_BAR_LINE_LEN = 60  # lines shorter than this aren't level rows


def slurp() -> list[str]:
    return SOURCE.read_text(encoding="utf-8", errors="replace").splitlines()


def find_section(lines: list[str], name: str) -> tuple[int, int]:
    target = name.upper()
    start = -1
    for i, ln in enumerate(lines):
        if ln.strip().upper() == target:
            start = i
            break
    if start < 0:
        sys.exit(f"Could not find section {name}")
    end = len(lines)
    for j in range(start + 1, len(lines)):
        s = lines[j].strip().upper()
        if s in {"OBJECTS", "LEGEND", "SOUNDS", "COLLISIONLAYERS",
                 "RULES", "WINCONDITIONS", "LEVELS"} and j != start:
            end = j
            break
    return start, end


def parse_legend(lines: list[str]) -> dict[str, list[str]]:
    """Returns {char: [primitive_object_names]}.

    LEGEND entries look like `X = foo` or `X = foo and bar` or
    `X = foo or bar`. We model them as `and`-expansions (treat 'or' as
    the first option since tiles must be concrete).
    """
    lo, hi = find_section(lines, "LEGEND")
    raw: dict[str, str] = {}
    for ln in lines[lo + 2:hi]:
        s = ln.strip()
        if "=" not in s:
            continue
        lhs, rhs = s.split("=", 1)
        lhs = lhs.strip()
        rhs = rhs.strip()
        if not lhs or not rhs:
            continue
        raw[lhs.lower()] = rhs.lower()

    def resolve(token: str, seen: set[str]) -> list[str]:
        token = token.strip().lower()
        if not token:
            return []
        if token in seen:
            return [token]
        seen = seen | {token}
        expr = raw.get(token)
        if expr is None:
            return [token]
        # Handle 'or' by taking the first branch (arbitrary but deterministic).
        if " or " in expr:
            first = expr.split(" or ", 1)[0].strip()
            return resolve(first, seen)
        # Handle 'and' by union.
        if " and " in expr:
            out: list[str] = []
            for part in re.split(r"\s+and\s+", expr):
                out.extend(resolve(part, seen))
            return out
        return resolve(expr, seen)

    out: dict[str, list[str]] = {}
    for k in raw:
        if len(k) == 1:
            out[k] = resolve(k, set())
    # LEGEND also defines some multi-char aliases which aren't cell
    # chars; ignore them. But single-char PS builtins (letters) may not
    # appear in LEGEND at all — they map to themselves.
    return out


def find_levels_grid(lines: list[str]) -> list[str]:
    """Returns the rows of the single big level. Stops at the first
    large run of level-looking lines of constant width."""
    lo, _ = find_section(lines, "LEVELS")
    # Walk forward; pick the longest contiguous run of equal-length,
    # non-message rows. Lines that start with a lowercase word followed
    # by whitespace are messages (`message ...`).
    rows: list[str] = []
    current: list[str] = []
    for ln in lines[lo + 2:]:
        s = ln.rstrip("\n")
        if len(s) < LEVEL_BAR_LINE_LEN:
            if len(current) > len(rows):
                rows = current
            current = []
            continue
        if s.startswith("message "):
            if len(current) > len(rows):
                rows = current
            current = []
            continue
        # All chars ascii printable?
        current.append(s)
    if len(current) > len(rows):
        rows = current
    # Normalize to max width
    width = max(len(r) for r in rows)
    rows = [r.ljust(width, "x") for r in rows]
    return rows


# PS object name -> our object name (None = drop this entity entirely).
# This is the honest subset of mechanics we actually implement; the
# original has ~20 extra visual decorator objects (letters, trim,
# connectors, warps, markers, barriers, traces, legs) that don't
# affect gameplay meaning in our port — they become floor.
PS_TO_OURS: dict[str, str | None] = {
    # walls
    "wall": "wall",
    "wallone": "wall",
    "walltwo": "wall",
    "wallthree": "wall",
    "wallfour": "wall",
    "wallfour2": "wall",
    "wallfour2down": "wall",
    "wallfive": "wall",
    "wallfivealt": "wall",
    "wallsix": "wall",
    "walltwoup": "wall",
    "walltwodown": "wall",
    "walltwoleft": "wall",
    "walltworight": "wall",
    "wallthingone": "wall",
    "wallthingtwo": "wall",
    "wallthingfour": "wall",
    # stops (single-direction walls — treat as full walls for now)
    "stopleft": "wall",
    "stopright": "wall",
    "stopdown": "wall",
    "stopup": "wall",
    # pushables
    "thing": "box",
    "thingone": "box",
    "thingtwo": "box",
    "thingthree": "box",
    "thingfour": "box",
    "thingfive": "box",
    "thingfive2": "box",
    "thingsix": "box",
    # player
    "p": "player",
    "player": "player",
    "playerone": "player",
    "camera": None,  # camera tracks the player; drop
    # regions via backgrounds: our RegionUnderPlayer reads Region info
    # from RegionInfo not from backgrounds, so they become floor for
    # now. The region mechanic is assigned at the index.json level.
    "background": None,
    "backgroundone": None,
    "backgroundtwo": None,
    "backgroundthree": None,
    "backgroundfour": None,
    "backgroundfive": None,
    "backgroundsix": None,
    # toggle / checkpoint / goal / numbered tiles
    "toggle": "toggle",
    "check": "checkpoint",
    "one": None,     # region-1 numeric tile; not a mechanic in our port
    "two": None,
    "three": None,
    "four": None,
    "five": None,
    "six": None,
    "seven": "wall",  # seven acts as a wall-variant in original
    # decoration / markers / hide — drop
}

# Anything starting with one of these prefixes becomes floor (None).
DROP_PREFIXES = (
    "letter", "mark", "hide", "tmp", "swap", "connector", "warp",
    "barrier", "legs", "trim", "trace", "link", "went", "moving",
    "stationary", "fix", "supported", "sunk", "winspawn", "winner",
    "exitmark", "camerashift", "dangthisisohackyblargh", "tail",
    "touching", "climb", "went", "noswap", "justswapped", "camerastick",
    "efive", "tailmark", "backgroundhere",
)


def translate_cell(char: str, legend: dict[str, list[str]]) -> list[str]:
    if char == " " or char == "x":
        return ["wall"]  # the big "x" border is treated as wall
    if char == ".":
        return []       # floor only (implicit background handles visuals)
    prims = legend.get(char, [char])
    out: list[str] = []
    for p in prims:
        mapped = None
        if p in PS_TO_OURS:
            mapped = PS_TO_OURS[p]
        elif any(p.startswith(pre) for pre in DROP_PREFIXES):
            mapped = None
        elif p.startswith("player"):
            mapped = "player"
        elif p.startswith("thing"):
            mapped = "box"
        elif p.startswith("wall"):
            mapped = "wall"
        elif p.startswith("check"):
            mapped = "checkpoint"
        elif p.startswith("toggle"):
            mapped = "toggle"
        else:
            mapped = None
        if mapped is not None and mapped not in out:
            out.append(mapped)
    return out


def build_region_map(grid: list[str], cells: list[list[list[str]]]) -> list[list[int]]:
    """Multi-source BFS from N-marker chars ('1'..'6') through walkable
    cells. A cell is walkable iff its translated objects do not include
    'wall'. Walls block propagation. Cells never reached stay 0
    (handled as default region by the dispatcher)."""
    h = len(grid)
    w = len(grid[0])
    region_map = [[0] * w for _ in range(h)]
    walkable = [[("wall" not in cells[y][x]) for x in range(w)] for y in range(h)]

    q: deque[tuple[int, int]] = deque()
    for y, row in enumerate(grid):
        for x, ch in enumerate(row):
            if ch in "123456":
                region_map[y][x] = int(ch)
                q.append((x, y))

    while q:
        x, y = q.popleft()
        n = region_map[y][x]
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and region_map[ny][nx] == 0 and walkable[ny][nx]:
                region_map[ny][nx] = n
                q.append((nx, ny))

    return region_map


def main() -> None:
    lines = slurp()
    legend = parse_legend(lines)
    grid = find_levels_grid(lines)
    print(f"Level grid: {len(grid)} rows x {len(grid[0])} cols")

    # Build the cells array. Anywhere we see a 'player' entry, remember
    # only the first one (original has multiple; the rest are decoys).
    seen_player = False
    cells: list[list[list[str]]] = []
    for y, row in enumerate(grid):
        out_row: list[list[str]] = []
        for x, ch in enumerate(row):
            objs = translate_cell(ch, legend)
            if "player" in objs:
                if seen_player:
                    objs = [o for o in objs if o != "player"]
                else:
                    seen_player = True
            out_row.append(objs)
        cells.append(out_row)

    region_map = build_region_map(grid, cells)
    counts = [0] * 7
    for row in region_map:
        for v in row:
            counts[v] += 1
    print(f"Region cell counts (0=default): {counts}")

    doc = {
        "_comment": "Auto-decoded from refs/enigmash-original/game.txt via tools/decode_levels.py. Regenerate with that script after editing the source.",
        "width": len(grid[0]),
        "height": len(grid),
        "background": "floor",
        "cells": cells,
        "region_map": region_map,
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(doc, indent=1))
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
