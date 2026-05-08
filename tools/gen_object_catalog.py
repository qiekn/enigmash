#!/usr/bin/env python3
"""Upsert default decoration entries into assets/data/objects.json.

For every PNG in assets/sprites/objects/ that doesn't already have a
catalog entry, append a minimal floor-layer decoration entry. Existing
entries are left untouched so hand-tuned tags / layers / colors survive.

Run after extracting new sprites or before re-decoding the level so the
loader can find every object name the decoder might emit.
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "assets/data/objects.json"
SPRITES = ROOT / "assets/sprites/objects"


def main() -> None:
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    existing = {k for k in catalog if not k.startswith("_")}

    added = 0
    for png in sorted(SPRITES.glob("*.png")):
        name = png.stem
        if name in existing:
            continue
        catalog[name] = {
            "layer": 0,
            "color": "#888888",
            "sprite": f"assets/sprites/objects/{png.name}",
        }
        added += 1

    if added:
        CATALOG.write_text(json.dumps(catalog, indent=2), encoding="utf-8")
        print(f"Added {added} default entries to {CATALOG.name}")
    else:
        print(f"No new sprites to register (catalog has {len(existing)} entries)")


if __name__ == "__main__":
    main()
