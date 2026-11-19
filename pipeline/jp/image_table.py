"""Normalizing for a PDF whose table is a PICTURE with an OCR text layer on top.

number.pdf is this shape: the font is "Glyphless" (text recognized from an image) and
there are no vector fills. The cell colors carry meaning (the legend says orange =
sound change, blue = special reading), so a text-only extract loses data. This reads
the color from the rendered page instead.

Output is a CanonicalTable: cells with a rect, a fill class and their text lines.
Layout meaning (which cell is a header) is left to the source's Mining step.
"""

from __future__ import annotations

import fitz
import numpy as np

from common import nfc

SCALE = 2

# Calibrated by sampling number.pdf (see docs/japanese-lessons.md). Nearest wins.
FILLS = {
    "white": (255, 255, 255),
    "regular": (245, 246, 250),
    "sound_change": (252, 227, 197),
    "special": (217, 232, 251),
    "header": (36, 51, 74),
    "header_alt": (91, 100, 117),
}


def _classify(rgb) -> str:
    r = np.array(rgb, dtype=int)
    return min(FILLS, key=lambda k: int(((np.array(FILLS[k]) - r) ** 2).sum()))


def _cell_rect(img: np.ndarray, x: int, y: int) -> tuple[int, int, int, int]:
    """Walk outward from a point inside a cell until the color class changes."""
    cls = _classify(img[y, x])
    h, w, _ = img.shape

    def same(xx, yy):
        return _classify(img[yy, xx]) == cls

    x0 = x
    while x0 > 0 and same(x0 - 1, y):
        x0 -= 1
    x1 = x
    while x1 < w - 1 and same(x1 + 1, y):
        x1 += 1
    # Walk up the cell's left padding, which no glyph crosses. A midpoint column can
    # hit the line above in a wrapped cell (にじゅうさんに / ち) and stop early.
    xm = min(x0 + 3, x1)
    y0 = y
    while y0 > 0 and same(xm, y0 - 1):
        y0 -= 1
    y1 = y
    while y1 < h - 1 and same(xm, y1 + 1):
        y1 += 1
    return x0, y0, x1, y1


def normalize_page(page: fitz.Page) -> dict:
    pm = page.get_pixmap(matrix=fitz.Matrix(SCALE, SCALE))
    img = np.frombuffer(pm.samples, np.uint8).reshape(pm.h, pm.w, pm.n)[:, :, :3]

    cells: dict[tuple, dict] = {}
    loose: list[dict] = []
    for b in page.get_text("dict")["blocks"]:
        for line in b.get("lines", []):
            text = nfc("".join(s["text"] for s in line["spans"]))
            if not text:
                continue
            x0, y0, x1, y1 = line["bbox"]
            # Sample just left of the text: inside the cell padding, clear of glyphs.
            sx, sy = int((x0 - 3) * SCALE), int((y0 + y1) / 2 * SCALE)
            fill = _classify(img[sy, sx])
            if fill == "white":
                loose.append({"text": text, "bbox": [round(v, 1) for v in line["bbox"]]})
                continue
            # Key on the top-left corner only. The walk right and down can stop early
            # on colored bold glyphs, but the walk left and up crosses only padding.
            x0c, y0c, _, _ = _cell_rect(img, sx, sy)
            key = (round(x0c / SCALE / 2) * 2, round(y0c / SCALE / 2) * 2)
            c = cells.setdefault(key, {"x": key[0], "y": key[1], "fill": fill, "lines": []})
            c["lines"].append({"text": text, "y": round(y0, 1), "x": round(x0, 1)})

    out = []
    for c in cells.values():
        c["lines"].sort(key=lambda l: (l["y"], l["x"]))
        out.append(c)
    out.sort(key=lambda c: (c["y"], c["x"]))
    return {"page": page.number + 1, "cells": out, "loose_text": loose}
