"""First-pass schemas for the Content Extracting / Language Lesson Extracting pipeline.

Companion to opm-lesson-extraction.md and .drawio. One model per OPM object.
The models are a PROPOSAL to argue with. STAGE_IO and OPM_NAMES are not: the guard test
pipeline/jp/tests/test_opm_sync.py holds them in step with the diagram and the OPL text.

Three comment markers, all greppable:

    # GUESS:    I invented a type or value domain the OPM does not state. Check me.
    # DECISION: the OPM was ambiguous or contradictory; I picked one and said why.
                Each of these should go back into the diagram.
    # MISSING:  the OPM has no answer and neither do I. You decide.

Requires pydantic v2.  Run `python extraction_schemas.py` for the self-check at the
bottom — it verifies the stage graph actually composes. CI runs it too
(pipeline/jp/tests).
"""

from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Generic, Literal, TypeVar

from pydantic import BaseModel, Field


# ───────────────────────────── enumerations ─────────────────────────────


class CEFR(str, Enum):
    A1 = "A1"
    A2 = "A2"
    B1 = "B1"
    B2 = "B2"
    C1 = "C1"
    C2 = "C2"


class DocKind(str, Enum):
    HABIT_LESSON = "habit_lesson"
    LANGUAGE_LESSON = "language_lesson"
    ARTICLE = "article"
    TRANSCRIPT = "transcript"
    UNKNOWN = "unknown"


class SentenceItemKind(str, Enum):
    CLOZE = "cloze"
    TRANSLATE = "translate"
    REORDER = "reorder"
    DICTATION = "dictation"


class GrammarItemKind(str, Enum):
    TRANSFORM = "transform"
    CONTRAST_PAIR = "contrast_pair"
    ERROR_CORRECTION = "error_correction"


class BundleState(str, Enum):
    NEEDS_REVIEW = "needs_review"
    # DECISION (SD3, 2026-10-23): added. A bundle whose hard checks fail is still
    # written so a reviewer can see why, but it cannot be approved until re-run.
    BLOCKED = "blocked"
    APPROVED = "approved"
    REJECTED = "rejected"


class SourceShape(str, Enum):
    """SD3. Detected from the file, and it picks the Normalizing variant.

    Running five real Japanese sources showed SD's one Normalizing step is wrong for
    three of them: prose is the minority shape for language material."""

    TEXT = "text"  # real text layer, read by geometry (PyMuPDF)
    PICTURE_TABLE = "picture_table"  # table drawn as an image, OCR text layer on top
    IMAGE = "image"  # no text layer at all: needs Transcribing (LM)
    SHEET = "sheet"  # spreadsheet: merged cells, hyperlinks, formulas


class ReadingMark(str, Enum):
    """The legend on a reference table. It is data: the color says which cells to
    learn as a sound change and which as a special word."""

    REGULAR = "regular"
    SOUND_CHANGE = "sound_change"
    SPECIAL = "special"


class JobState(str, Enum):
    QUEUED = "queued"
    RUNNING = "running"
    NEEDS_REVIEW = "needs_review"
    PUBLISHED = "published"
    FAILED = "failed"


# ───────────────────────────── shared value types ─────────────────────────────

# GUESS: language codes are ISO 639-1 two-letter ("es", "en"). BCP-47 ("pt-BR")
# matters the moment you care about regional variety. The OPM says only
# "targetLanguage".
LanguageCode = str


class CharSpan(BaseModel):
    """Offsets into CanonicalText.plain_text. Half-open: [start, end)."""

    start: int
    end: int


class TimeSpan(BaseModel):
    start_ms: int
    end_ms: int


class Token(BaseModel):
    surface: str
    lemma: str
    # GUESS: Universal Dependencies UPOS tagset ("NOUN", "VERB", "AUX"...).
    # The OPM says only "lemma+POS".
    pos: str
    # MISSING: morphological features (tense, person, number) are what a grammar
    # drill actually needs — "conjugate to 2sg preterite" is unanswerable without
    # them. The OPM has no field for this at all.
    feats: dict[str, str] = Field(default_factory=dict)


# ───────────────────────────── SD — Content Extracting ─────────────────────────────


class SourceDocument(BaseModel):
    id: str
    mime: str
    origin: str = Field(description="URL, upload id, or integration reference.")
    bytes_len: int
    uploaded_by: str
    uploaded_at: datetime


class RawAsset(BaseModel):
    id: str
    source_document_id: str
    blob_ref: str
    sha256: str
    mime: str
    bytes_len: int
    fetched_at: datetime


class StructureNode(BaseModel):
    """One element of the structure map: heading, paragraph, caption, turn."""

    kind: str  # GUESS: free string. An enum here would be better once you know the set.
    text: str
    span: CharSpan
    page: int | None = None
    time: TimeSpan | None = None


class CanonicalText(BaseModel):
    id: str
    raw_asset_id: str
    plain_text: str
    structure: list[StructureNode]
    detected_language: LanguageCode


class ContentClassification(BaseModel):
    canonical_text_id: str
    doc_kind: DocKind
    # GUESS: float in [0, 1]. Could equally be a coarse label, and a coarse label
    # is easier for an LM to produce honestly. Worth deciding before Routing's
    # threshold means anything.
    confidence: float = Field(ge=0.0, le=1.0)
    target_language: LanguageCode | None = None
    cefr_guess: CEFR | None = None
    rationale: str


class ExtractionRoute(BaseModel):
    canonical_text_id: str
    handler_id: str
    queue_topic: str
    priority: int = 0


class ExtractionJob(BaseModel):
    run_id: str
    canonical_text_id: str | None = None
    state: JobState
    attempt: int = 0
    started_at: datetime | None = None
    last_error: str | None = None


# ───────────────────────────── SD1 — language objects ─────────────────────────────


class SentenceUnit(BaseModel):
    id: str
    text: str
    char_span: CharSpan
    audio_span: TimeSpan | None = None
    tokens: list[Token]
    l1_gloss: str = Field(description="Translation into the learner's L1.")


class VocabItem(BaseModel):
    lemma: str
    pos: str
    gloss: str
    # MISSING: frequency rank against WHICH corpus? A rank is meaningless without
    # naming the list, and "is this word worth teaching" depends entirely on it.
    frequency_rank: int | None = None
    example_sentence_id: str


class GrammarPoint(BaseModel):
    # RESOLVED for tutor sources (SD3): the tutor's sheet IS the namespace. Mari's
    # ids are "mari.L<lesson>.<n>", and her lessons are the curriculum order. Mined
    # grammar points still have no shared namespace.
    pattern_id: str
    construction: str = Field(description="The pattern itself, e.g. 'ir + a + infinitive'.")
    # DECISION (SD3): CEFR is European. Japanese material is graded by JLPT (Mari's
    # sheet is "N4"). A level is a (framework, value) pair, not a CEFR.
    level: str | None = Field(default=None, description="'CEFR:A2', 'JLPT:N4', ...")
    l1_contrast_note: str = ""
    example_sentence_id: str
    provenance: Literal["mined", "tutor"] = "mined"
    goal: str = ""  # tutor sources state the communicative goal; mined ones cannot
    requires_forms: list[str] = Field(
        default_factory=list,
        description="Verb forms the pattern needs (te, nai, plain...). Prerequisites.")


class LessonScope(BaseModel):
    id: str
    target_grammar_point_id: str
    target_lexis: list[str] = Field(description="Lemmas, matching VocabItem.lemma.")
    cefr: CEFR
    prerequisite_ids: list[str]
    item_budget: int


class LessonDraft(BaseModel):
    id: str
    scope_id: str
    title: str
    description: str
    explanation: str
    l1_contrast_note: str
    worked_examples: list[str]


class SentencePracticeItem(BaseModel):
    id: str
    scope_id: str
    kind: SentenceItemKind
    prompt: str
    answer: str
    accepted_variants: list[str] = Field(default_factory=list)
    distractors: list[str] = Field(default_factory=list)
    hint: str | None = None
    source_sentence_id: str


class GrammarPracticeItem(BaseModel):
    id: str
    scope_id: str
    kind: GrammarItemKind
    prompt: str
    answer: str
    rule_ref: str = Field(description="GrammarPoint.pattern_id this item drills.")
    distractors: list[str] = Field(default_factory=list)
    hint: str | None = None
    # DECISION: added. The OPM gives Sentence items a source_sentence_id but not
    # Grammar items, which breaks provenance for exactly half the output.
    source_sentence_id: str


PracticeItem = SentencePracticeItem | GrammarPracticeItem


# ───────────────────────────── SD3 — structured sources ─────────────────────────────


class TableCell(BaseModel):
    x: float
    y: float
    fill: str = Field(description="Fill class from the legend, or 'header'.")
    lines: list[str]


class CanonicalTable(BaseModel):
    """What Normalizing yields for a table, sheet or transcribed image. The prose
    CanonicalText cannot carry a cell's color, and the color is part of the answer."""

    id: str
    raw_asset_id: str
    shape: SourceShape
    cells: list[TableCell]
    loose_text: list[str] = Field(default_factory=list, description="Titles, footnotes.")
    transcribed_by: str | None = Field(
        default=None, description="Set when an LM produced this. Then Reviewing is mandatory.")


class ReferenceItem(BaseModel):
    """One cell of a lookup table: 3 + 本 -> さんぼん."""

    id: str
    table: str
    key: str  # the row label, e.g. "3"
    column: str  # the column header, e.g. "本 ほん pens, bottles"
    reading: str
    alt_readings: list[str] = Field(default_factory=list)
    mark: ReadingMark


class VerbPair(BaseModel):
    id: str
    transitive: str
    intransitive: str
    transitive_group: int | None = None  # None = undecidable from the form; say so
    intransitive_group: int | None = None
    gloss: str = ""
    example_transitive: str = ""
    example_intransitive: str = ""


class ParadigmCell(BaseModel):
    """A tutor's worked conjugation. Gold for the Conjugation Engine."""

    dictionary: str
    group: int
    form: str
    result: str


class ExternalResource(BaseModel):
    """A tutor tool that is linked, not extracted (Canva deck, web drill)."""

    kind: str
    label: str
    url: str


class CatalogEntry(BaseModel):
    """SD3 Cataloging. One findable thing. Typed at extraction time so the app's search
    and sort never guess what a piece of content is."""

    id: str
    type: Literal["grammar_point", "particle", "reference_table", "verb_pair",
                  "conjugation", "vocabulary", "source_file"]
    source: str
    lesson: int | None = None
    title: str
    summary: str = ""
    uses: list[str] = Field(default_factory=list, description="Ids from the Use Taxonomy.")
    search: list[str] = Field(default_factory=list, description="Extra text to match.")
    open: dict[str, str | int] = Field(description="Which screen, with which parameters.")
    from_: list[str] = Field(default_factory=list, alias="from",
                             description="The data files the entry came from.")
    # A source_file entry describes one data file. Its counts are computed from the
    # file at catalog build time, so no prose restates them (PIN-13).
    file: str | None = Field(default=None, description="source_file: repo path of the file.")
    role: str | None = Field(default=None, description="source_file: what the file is for.")
    origin: str | None = Field(default=None, description="source_file: where it came from.")
    counts: dict[str, int] | None = Field(default=None, description="source_file: live counts.")


class Query(BaseModel):
    """What the learner asks the app. Text wins, then use, then type order."""

    text: str | None = None
    use: str | None = None


class ResultList(BaseModel):
    entries: list[CatalogEntry]


# ───────────────────── kanji versions, judging, answer checking ─────────────────────
# Added by docs/plans/2026-10-24-japanese-typing-kanji-speaking.md.


class KanjiVersion(BaseModel):
    """The `_ruby` twin of one Japanese field: kanji written `漢字{かんじ}`, one bracket
    per kanji word, okurigana outside (`買{か}い物{もの}`). Replacing every bracket
    with its reading must give the hiragana text exactly (PIN-5, PIN-11)."""

    owner_id: str = Field(description="Grammar point id, plus the item index for practice.")
    field: str = Field(description="jp_ruby, prompt_ruby, answer_ruby, accepted_ruby, ...")
    hiragana: str
    ruby: str


class JudgeFinding(BaseModel):
    """One finding of the independent judge pass (pipeline/jp/review/judge_*.json)."""

    point_id: str
    item_index: int = Field(description="-1 for the point itself, else the practice item.")
    verdict: str
    detail: str
    fix: str
    applied: bool = False


class TypedAnswer(BaseModel):
    """What the learner typed into a fill-in box (Japanese keyboard, PIN-3)."""

    item_id: str
    text: str


class AnswerVerdict(BaseModel):
    item_id: str
    correct: bool
    matched: str | None = Field(
        default=None, description="The accepted form or kanji surface it matched.")


class Transcript(BaseModel):
    """What speech recognition heard. Often kanji, sometimes hiragana."""

    item_id: str
    heard: str


class SpeechResult(str, Enum):
    CORRECT = "correct"
    CLOSE = "close"  # amber, matching part highlighted, then self-check (PIN-10)
    SELF_CHECK = "self_check"  # uncomparable: never marked wrong (PIN-2)


class SpeechVerdict(BaseModel):
    item_id: str
    heard: str
    result: SpeechResult
    matched_span: CharSpan | None = None


# ───────────────────────────── gates and reports ─────────────────────────────


class ValidationCheck(str, Enum):
    """The five deterministic checks. All computable without an LM."""

    UNIQUE_ANSWER = "unique_answer"
    NO_ANSWER_LEAK = "no_answer_leak"
    DISTRACTOR_NOT_ALSO_CORRECT = "distractor_not_also_correct"
    LEMMA_IN_KNOWN_SET = "lemma_in_known_set"
    LENGTH_BOUNDS = "length_bounds"


class CheckFailure(BaseModel):
    item_id: str
    check: ValidationCheck
    detail: str


class ValidationResult(BaseModel):
    id: str
    scope_id: str
    checked_item_ids: list[str]
    failures: list[CheckFailure]

    @property
    def passed(self) -> bool:
        return not self.failures


class MetricName(str, Enum):
    """PROPOSED metrics. The OPM names a `per_metric_scores` container and then
    never names a single metric — this enum is the gap being filled, so treat
    every member as a proposal to accept, rename, or delete.

    Suffix convention: _DET is computable in code, _JUDGE needs an LM.
    """

    # Mining
    CITATION_VALID_DET = "citation_valid_det"
    GRAMMAR_POINT_PRECISION_JUDGE = "grammar_point_precision_judge"
    VOCAB_GLOSS_ACCURACY_JUDGE = "vocab_gloss_accuracy_judge"
    # Scoping
    SCOPE_SINGLE_UNIT_DET = "scope_single_unit_det"
    SCOPE_PREREQUISITES_RESPECTED_DET = "scope_prerequisites_respected_det"
    SCOPE_LEVEL_FIT_JUDGE = "scope_level_fit_judge"
    # Drafting
    NO_HALLUCINATED_RULE_JUDGE = "no_hallucinated_rule_judge"
    L1_CONTRAST_ACCURACY_JUDGE = "l1_contrast_accuracy_judge"
    # Item generation (both kinds)
    RULE_REF_VALID_DET = "rule_ref_valid_det"
    ITEM_ANSWERABLE_JUDGE = "item_answerable_judge"
    ITEM_LEVEL_FIT_JUDGE = "item_level_fit_judge"
    DISTRACTOR_PLAUSIBILITY_JUDGE = "distractor_plausibility_judge"


class ItemVerdict(BaseModel):
    item_id: str
    metric: MetricName
    score: float = Field(ge=0.0, le=1.0)
    rationale: str


class EvalReport(BaseModel):
    id: str
    run_id: str
    # DECISION: spec_version belongs on every artifact a compiled program produced,
    # not just here. Otherwise a score delta can't be attributed to a spec change.
    # See Envelope below.
    spec_version: str
    scope_id: str
    per_metric_scores: dict[MetricName, float]
    per_item_verdicts: list[ItemVerdict]
    failures: list[ItemVerdict]


class ReviewNote(BaseModel):
    bundle_id: str
    reviewer: str
    reason: str
    reviewed_at: datetime


class LessonBundle(BaseModel):
    id: str
    run_id: str
    state: BundleState
    draft: LessonDraft
    sentence_items: list[SentencePracticeItem]
    grammar_items: list[GrammarPracticeItem]
    validation: ValidationResult
    evaluation: EvalReport
    review: ReviewNote | None = None


class AttemptRecord(BaseModel):
    item_id: str
    learner_id: str
    correct: bool
    latency_ms: int
    attempted_at: datetime
    # MISSING: without a difficulty estimate, a low correct-rate confounds "hard
    # item" with "broken item", and Optimizing against raw outcomes will drift
    # toward easy items. Either calibrate difficulty or restrict the optimizer to
    # items flagged by learners.
    reported_broken: bool = False


# ───────────────────────────── control objects ─────────────────────────────


class CurriculumSpec(BaseModel):
    id: str
    language: LanguageCode
    # Keyed by GrammarPoint.pattern_id — the shared namespace flagged above.
    grammar_syllabus: dict[str, CEFR]
    lexical_sets: dict[CEFR, list[str]]


class LearnerProfile(BaseModel):
    learner_id: str
    l1: LanguageCode
    target_language: LanguageCode
    current_cefr: CEFR
    known_lemmas: set[str]
    # GUESS: error history as counts keyed by pattern_id. Could as easily be a
    # list of past attempts; this shape assumes you only need aggregates.
    error_history: dict[str, int] = Field(default_factory=dict)


class GoldExample(BaseModel):
    """One row of the Eval Set. The OPM says 'gold lessons + rubric' and stops.

    This is the DSPy trainset row: field names here must match the signature's
    input/output field names for an optimizer to use it.
    """

    canonical_text: CanonicalText
    expected_scope: LessonScope
    expected_sentence_items: list[SentencePracticeItem]
    expected_grammar_items: list[GrammarPracticeItem]
    # MISSING: "rubric" in the OPM is doing enormous unexamined work — it IS the
    # judge. A free-text rubric per example, or one global rubric per metric?
    rubric: str


# ───────────────────────────── queue envelope ─────────────────────────────

T = TypeVar("T", bound=BaseModel)


class Envelope(BaseModel, Generic[T]):
    """Every async hop carries this. Addresses the OPM's missing ids: only
    EvalReport had a run_id and only Publishing mentioned idempotency."""

    run_id: str
    stage: str
    spec_version: str
    idempotency_key: str
    created_at: datetime
    attempt: int = 0
    payload: T


# ───────────────────────────── stage I/O contracts ─────────────────────────────

# DECISION (cardinality). The OPM contradicts itself: the stage list says
# "Sentence Unit[] -> Vocab Item[]" while OPL sentence 5 says Mining "consumes
# Sentence Unit and yields Vocab Item", singular. Resolved as:
#
#   Mining is document-scoped (takes the whole list) — recurring grammar patterns
#   are only visible across sentences, so per-sentence mining would miss the point.
#
#   Item generation is per-source, mapped — one LM call per (sentence | grammar
#   point). Costs more calls, but gives a per-item metric, which is what makes
#   each generator independently optimizable. One call emitting N items gives you
#   one score for N items and you cannot tell which one was bad.
#
# Both belong back in the diagram.

LM = "llm"  # LM call, gets a DSPy signature
DET = "deterministic"  # pure code, no signature
HUMAN = "human"

Models = tuple[type[BaseModel], ...]

STAGE_IO: dict[str, tuple[str, Models, Models]] = {
    # stage:            (kind, inputs, outputs)
    "Ingesting": (DET, (SourceDocument,), (RawAsset,)),
    "Normalizing": (DET, (RawAsset,), (CanonicalText,)),
    "Classifying": (LM, (CanonicalText,), (ContentClassification,)),
    "Routing": (DET, (ContentClassification,), (ExtractionRoute,)),
    "Triaging": (HUMAN, (ContentClassification,), (ContentClassification,)),
    # DECISION: Segmenting is NOT an LM call — spaCy/stanza do this better and
    # cheaply. The OPM left it unmarked, which implied it might be.
    "Segmenting": (DET, (CanonicalText,), (SentenceUnit,)),
    "Mining": (LM, (SentenceUnit,), (VocabItem, GrammarPoint)),
    "Scoping": (LM, (VocabItem, GrammarPoint, CurriculumSpec, LearnerProfile), (LessonScope,)),
    "Drafting": (LM, (LessonScope, SentenceUnit), (LessonDraft,)),
    "SentenceItemGenerating": (LM, (LessonScope, SentenceUnit), (SentencePracticeItem,)),
    "GrammarItemGenerating": (LM, (LessonScope, GrammarPoint), (GrammarPracticeItem,)),
    "Validating": (DET, (SentencePracticeItem, GrammarPracticeItem), (ValidationResult,)),
    "Evaluating": (LM, (LessonDraft, SentencePracticeItem, GrammarPracticeItem), (EvalReport,)),
    "Assembling": (DET, (LessonDraft, ValidationResult, EvalReport), (LessonBundle,)),
    "Reviewing": (HUMAN, (LessonBundle,), (ReviewNote,)),
    "Publishing": (DET, (LessonBundle,), (LessonBundle,)),
    # Outputs () on purpose: Optimizing's real product is a recompiled DSPy
    # program, which has no honest pydantic type. See MISSING note below.
    "Optimizing": (DET, (EvalReport, AttemptRecord), ()),
    # ── SD3 (pipeline/jp/). Normalizing splits by SourceShape.
    "NormalizingPictureTable": (DET, (RawAsset,), (CanonicalTable,)),
    "NormalizingSheet": (DET, (RawAsset,), (CanonicalTable,)),
    "Transcribing": (LM, (RawAsset,), (CanonicalTable,)),
    "TableExtracting": (DET, (CanonicalTable,), (ReferenceItem, VerbPair, ParadigmCell)),
    # The tutor is the author; the code only reads her sheet. No LM touches it.
    "CurriculumImporting": (DET, (CanonicalTable,), (CurriculumSpec, GrammarPoint, ExternalResource)),
    "ValidatingSources": (DET, (ReferenceItem, VerbPair, ParadigmCell, CurriculumSpec,
                                ExternalResource), (ValidationResult,)),
    # Type is deterministic (which extractor made the item). Uses come from a reviewed
    # data file, so Cataloging itself makes no LM call.
    "Cataloging": (DET, (LessonBundle,), (CatalogEntry,)),
    # The judge's findings gate publishing: every one must be applied first.
    "PublishingApp": (DET, (LessonBundle, CatalogEntry, JudgeFinding), ()),
    # Runs in the app, on the published file.
    "Finding": (DET, (CatalogEntry, Query), (ResultList,)),
    # ── Kanji versions and answer checking (plan 2026-10-24).
    "KanjiDrafting": (LM, (LessonDraft, GrammarPracticeItem), (KanjiVersion,)),
    "KanjiValidating": (DET, (KanjiVersion,), (ValidationResult,)),
    # Independent LM judge over the drafts and their kanji versions.
    "Judging": (LM, (LessonDraft, GrammarPracticeItem, KanjiVersion), (JudgeFinding,)),
    # Both run in the app, on the published file.
    "AnswerChecking": (DET, (GrammarPracticeItem, KanjiVersion, TypedAnswer), (AnswerVerdict,)),
    "SpeechChecking": (DET, (GrammarPracticeItem, KanjiVersion, Transcript), (SpeechVerdict,)),
    # ── Composite processes on SD: each zooms into stages (Language Lesson Extracting
    # into SD1). Listed so every process the diagram draws has an entry.
    "HabitLessonExtracting": (LM, (ExtractionRoute, CanonicalText), (LessonBundle,)),
    "LanguageLessonExtracting": (LM, (ExtractionRoute, CanonicalText), (LessonBundle,)),
    "ArticleExtracting": (LM, (ExtractionRoute, CanonicalText), (LessonBundle,)),
}

# The name each stage carries in the diagram and the OPL text (docs/opm-lesson-extraction.md).
OPM_NAMES: dict[str, str] = {
    "Ingesting": "Ingesting",
    "Normalizing": "Normalizing",
    "Classifying": "Classifying",
    "Routing": "Routing",
    "Triaging": "Triaging",
    "Segmenting": "Segmenting",
    "Mining": "Mining",
    "Scoping": "Scoping",
    "Drafting": "Drafting",
    "SentenceItemGenerating": "Sentence Item Generating",
    "GrammarItemGenerating": "Grammar Item Generating",
    "Validating": "Validating",
    "Evaluating": "Evaluating",
    "Assembling": "Assembling",
    "Reviewing": "Reviewing",
    "Publishing": "Publishing",
    "Optimizing": "Optimizing",
    "NormalizingPictureTable": "Normalizing (picture table)",
    "NormalizingSheet": "Normalizing (sheet)",
    "Transcribing": "Transcribing",
    "TableExtracting": "Table Extracting",
    "CurriculumImporting": "Curriculum Importing",
    "ValidatingSources": "Validating (cross-source)",
    "Cataloging": "Cataloging",
    "PublishingApp": "Publishing (app)",
    "Finding": "Finding",
    "KanjiDrafting": "Kanji Drafting",
    "KanjiValidating": "Kanji Validating",
    "Judging": "Judging",
    "AnswerChecking": "Answer Checking",
    "SpeechChecking": "Speech Checking",
    "HabitLessonExtracting": "Habit Lesson Extracting",
    "LanguageLessonExtracting": "Language Lesson Extracting",
    "ArticleExtracting": "Article Extracting",
}

# MISSING: Optimizing's real output is a new compiled DSPy program, not a model.
# "Extraction Spec" is drawn in the OPM as an object with an instrument link, but
# a DSPy spec is not an input to a module — it IS the module. There is no honest
# pydantic type for it, which is itself the finding: that arrow in the diagram is
# a category error and should be redrawn.

# Stages with no upstream producer — pipeline roots and control objects.
# TypedAnswer and Transcript come from the learner, in the app.
_ROOTS = {SourceDocument, CurriculumSpec, LearnerProfile, AttemptRecord, GoldExample, Query,
          TypedAnswer, Transcript}

# Produced but deliberately consumed by nothing — the pipeline's end products.
_TERMINAL = {LessonBundle, ReviewNote, ExtractionRoute, ExtractionJob, ResultList,
             AnswerVerdict, SpeechVerdict}


def _check() -> None:
    """Fails if the stage graph stops composing: an input nothing produces, or an
    output nothing consumes. The second half is the one that matters — a dropped
    output is silent, which is exactly how VocabItem went missing on the first pass."""
    produced = {o for _, _, outs in STAGE_IO.values() for o in outs} | _ROOTS
    consumed = {i for _, ins, _ in STAGE_IO.values() for i in ins}

    for stage, (kind, ins, outs) in STAGE_IO.items():
        assert kind in (LM, DET, HUMAN), f"{stage}: bad kind {kind}"
        for i in ins:
            assert i in produced, f"{stage} consumes {i.__name__}, which nothing produces"
    assert set(OPM_NAMES) == set(STAGE_IO), "every stage needs exactly one OPM name"

    orphans = produced - consumed - _TERMINAL - _ROOTS
    assert not orphans, f"produced but never consumed: {sorted(o.__name__ for o in orphans)}"

    # Every metric must be attributable to a stage an optimizer can compile.
    lm_stages = [s for s, (k, _, _) in STAGE_IO.items() if k == LM]
    assert len(lm_stages) >= 5, "expected at least 5 optimizable modules"

    # Provenance: every practice item must trace back to a sentence.
    for m in (SentencePracticeItem, GrammarPracticeItem):
        assert "source_sentence_id" in m.model_fields, f"{m.__name__} lost provenance"

    print(f"ok: {len(STAGE_IO)} stages, {len(lm_stages)} LM modules, no orphaned artifacts")


if __name__ == "__main__":
    _check()
