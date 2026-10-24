"""Shared pieces for the Japanese lesson sources.

Every source runs the same SD path from docs/opm-lesson-extraction.md:
Ingesting -> Normalizing -> (Classifying, fixed per source here) -> Mining ->
Validating -> Assembling. Each stage writes ONE json file under out/<source>/, so a
stage can be re-run from its input alone (the asynchrony rule).

Reviewing and Publishing are deliberately not here: a bundle leaves this folder in
state "needs_review", and only a person moves it to "approved".
"""

from __future__ import annotations

import hashlib
import json
import os
import unicodedata
from datetime import datetime, timezone
from pathlib import Path

SOURCE_DIR = Path("C:/Users/markl/Desktop/Japanese")
# JP_OUT_DIR lets tests and CI read the committed fixtures: the source PDFs and the
# tutor's sheet live outside the repo, so CI cannot re-run the extractors.
OUT_DIR = Path(os.environ.get("JP_OUT_DIR", Path(__file__).parent / "out"))

HIRAGANA = range(0x3041, 0x3097)
KATAKANA = range(0x30A1, 0x30FB)
KANA_EXTRA = set("ー〜～（）()・／ 　")


def is_kana(text: str) -> bool:
    """True if every character is kana or allowed punctuation. No kanji, no Latin."""
    return bool(text) and all(
        ord(ch) in HIRAGANA or ord(ch) in KATAKANA or ch in KANA_EXTRA for ch in text
    )


def nfc(text: str) -> str:
    return unicodedata.normalize("NFC", text).strip()


def ingest(path: Path, source_id: str) -> dict:
    """Ingesting: fetch once, hash it. The hash is what later stages cite."""
    data = path.read_bytes()
    raw = {
        "source_id": source_id,
        "origin": str(path),
        "sha256": hashlib.sha256(data).hexdigest(),
        "bytes_len": len(data),
        "fetched_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }
    write(source_id, "raw_asset", raw)
    return raw


def write(source_id: str, stage: str, payload: object) -> Path:
    out = OUT_DIR / source_id / f"{stage}.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=1), encoding="utf-8")
    return out


def bundle(source_id: str, raw: dict, items: list[dict], failures: list[dict],
           review_notes: list[str], **extra) -> dict:
    """Assembling: the gate. A bundle with validation failures is still written, so a
    reviewer can see why, but its state says it cannot be approved as is."""
    b = {
        "source_id": source_id,
        "sha256": raw["sha256"],
        "state": "needs_review" if not failures else "blocked",
        "item_count": len(items),
        "validation": {"passed": not failures, "failures": failures},
        "review_notes": review_notes,
        **extra,
        "items": items,
    }
    write(source_id, "lesson_bundle", b)
    return b
