"""Registry: which OPM stage each pipeline/jp module runs (PIN-12).

Every .py file under pipeline/jp (tests, fixtures and drafts aside) is either in STAGES,
naming the STAGE_IO keys from pipeline/extraction_schemas.py it implements, or in
HELPERS, with the reason it runs no stage. pipeline/jp/tests/test_opm_sync.py fails
when a module is in neither, or names a stage STAGE_IO does not hold.

Keys are paths relative to pipeline/jp, with forward slashes.
"""

from __future__ import annotations

STAGES: dict[str, tuple[str, ...]] = {
    "common.py": ("Ingesting", "Assembling"),
    "image_table.py": ("NormalizingPictureTable",),
    "s01_counters.py": ("Ingesting", "NormalizingPictureTable", "TableExtracting",
                        "ValidatingSources"),
    "s02_pairs_mari.py": ("Ingesting", "Normalizing", "TableExtracting", "ValidatingSources"),
    "s03_pairs_textbook.py": ("Ingesting", "Transcribing", "TableExtracting",
                              "ValidatingSources"),
    "s04_mari_checklist.py": ("Ingesting", "NormalizingSheet", "CurriculumImporting",
                              "ValidatingSources"),
    "s05_mari_verb_forms.py": ("Ingesting", "NormalizingSheet", "TableExtracting",
                               "ValidatingSources"),
    # The Conjugation Engine is an instrument of cross-source validation and of the
    # draft checks in publish.py.
    "conjugate.py": ("ValidatingSources",),
    "catalog.py": ("Cataloging",),
    # check_draft() is the deterministic Validating gate for the LM drafts. It also runs
    # the kanji twin checks (check_twin, twin_errors) on every draft field.
    "publish.py": ("Validating", "KanjiValidating", "PublishingApp"),
    # Applies the reviewed findings of the judge pass to the drafts.
    "review/apply_judge_fixes.py": ("Judging",),
    # Applies Mark's kanji rulings of 2026-10-26 (the strict kanji_n5_n4.json list, and
    # 私{わたし}) to the twins, and logs each change as a judge finding.
    "review/apply_kanji_rulings.py": ("Judging",),
    # Kanji twin helpers: reading-of, printed-text, and the bracket-form check that
    # publish.twin_errors() calls.
    "ruby.py": ("KanjiValidating",),
}

HELPERS: dict[str, str] = {
    "stages.py": "this registry",
    "refresh_fixtures.py": "copies extractor output into the CI fixtures; runs no stage",
}
