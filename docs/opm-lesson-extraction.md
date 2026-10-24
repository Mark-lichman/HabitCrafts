# OPM: Content Extracting → Language Lesson Extracting

Four OPDs in `opm-lesson-extraction.drawio` (page tabs at the bottom of draw.io):

- **SD — Content Extracting**: the general framework. Any document in, classified, routed to a kind-specific extractor.
- **SD1 — Language Lesson Extracting**: the in-zoom, entered once SD has classified the document as a *language lesson*. Carries the types from `pipeline/extraction_schemas.py`.
- **SD2 — Evaluating & Optimizing**: one metric set per optimizable module, and the DSPy compile loop.
- **SD3 — Structured Sources**: Normalizing split by source shape (table, sheet, image), and the
  tutor path where grammar points are given, not mined. Added 2026-10-23 after five real sources.

The OPL sentences below are the spec — edit these. The diagram is generated from
`opm-lesson-extraction.gen.js`; regenerate rather than hand-editing coordinates if the model changes.

## The asynchrony rule

Every stage boundary is a queue hop, drawn as an **orange dashed invocation link**. Two stages
share nothing but the output object between them:

- A stage reads exactly one input object and writes exactly one output object. No stage reaches
  back into a previous stage's internals.
- The output object is the whole contract. If it round-trips through JSON and still means the
  same thing, the boundary is real.
- Any stage can therefore run on its own worker, be retried from its input, or sit in a queue for
  hours (Reviewing does exactly that).
- Fan-out stages run concurrently and the next stage joins on all of them.

## SD — Content Extracting

Stages, each as input → output:

1. **Ingesting** — Source Document → Raw Asset. Fetch once, store immutably, hash it.
2. **Normalizing** — Raw Asset → Canonical Text. Decode, strip layout, keep a structure map of
   headings, spans and page/time offsets.
3. **Classifying** — Canonical Text → Content Classification. DSPy module; instruments are
   Classifier Spec and LLM Engine.
4. **Routing** — Content Classification → Extraction Route. Confidence gate, then enqueue.
5. **Habit Lesson Extracting / Language Lesson Extracting / Article Extracting** — Extraction Route
   + Canonical Text → Lesson Bundle. Exactly one runs per document. The language one is in-zoomed in SD1.
6. **Publishing** — approved Lesson Bundle → Firestore. Idempotent write keyed on runId.
7. **Triaging** — low-confidence Content Classification → corrected Content Classification. Coach is
   the agent; this is a human branch, not an error path.

OPL sentences:

1. **Content Extracting** zooms into **Ingesting**, **Normalizing**, **Classifying**, **Routing**, a
   kind-specific **Extracting**, and **Publishing**.
2. **Content Extracting** requires **Work Queue**; every subprocess pair is joined by an
   asynchronous invocation over it.
3. **Ingesting** consumes **Source Document** and yields **Raw Asset**. **Ingesting** invokes **Normalizing**.
4. **Normalizing** consumes **Raw Asset** and yields **Canonical Text**. **Normalizing** invokes **Classifying**.
5. **Classifying** requires **Classifier Spec** and **LLM Engine**, consumes **Canonical Text**, and
   yields **Content Classification**. **Classifying** invokes **Routing**.
6. **Content Classification** exhibits *docKind*, *confidence*, *targetLanguage*, and *cefrGuess*.
7. **Routing** consumes **Content Classification** and yields **Extraction Route**. **Routing** invokes
   exactly one of **Habit Lesson Extracting**, **Language Lesson Extracting**, or **Article Extracting**.
8. **Triaging** requires **Coach** as its agent, consumes a low-confidence **Content Classification**,
   and affects it.
9. **Language Lesson Extracting** consumes **Extraction Route** and **Canonical Text** and yields
   **Lesson Bundle**. It invokes **Publishing**.
10. **Lesson Bundle** can be **needs review**, **approved**, or **rejected**.
11. **Publishing** consumes an **approved Lesson Bundle** and yields records in **Firestore**.
12. **Extraction Job** can be **queued**, **running**, **needs review**, **published**, or **failed**.
    Every subprocess affects **Extraction Job**.
13. A **failed Extraction Job** whose retries are exhausted is consumed into the **Dead-letter Queue**.

## SD1 — Language Lesson Extracting

Entered with the document already classified as a language lesson. Stages as input → output:

1. **Segmenting** — Canonical Text → Sentence Unit[]. Sentence split, tokenise, lemma + POS, L1 gloss,
   keep char spans (and audio spans when the source was a transcript).
2. **Mining** — Sentence Unit[] → Vocab Item[] + Grammar Point[]. DSPy module. Each item cites the
   sentence it came from.
3. **Scoping** — Vocab Item[] + Grammar Point[] → Lesson Scope. Picks *one* teachable unit against
   Curriculum Spec and Learner Profile, and sets the item budget.
4. **Drafting** — Lesson Scope + Sentence Unit[] → Lesson Draft. Explanation prose, L1 contrast note,
   worked examples.
5. **Sentence Item Generating** — Lesson Scope + Sentence Unit[] → Sentence Practice Item[].
   Kinds: cloze, translate, reorder, dictation.
6. **Grammar Item Generating** — Lesson Scope + Grammar Point → Grammar Practice Item[].
   Kinds: transform, contrast pair, error correction.
7. **Validating** — Practice Item[] → Validation Result. Deterministic, no LLM: single correct answer,
   no answer leakage in the prompt, no distractor that is also correct, lemmas within the known set,
   length bounds.
8. **Evaluating** — Lesson Draft + Practice Item[] → Eval Report. Gold set plus LLM judge.
9. **Assembling** — Lesson Draft + Practice Item[] + Validation Result + Eval Report → Lesson Bundle.
   Gate: everything passes or the bundle is not built.
10. **Reviewing** — Lesson Bundle → approved or rejected Lesson Bundle + Review Note. Coach is the agent.
11. **Publishing** — approved Lesson Bundle → Firestore.
12. **Optimizing** — Eval Report + Attempt Record[] → updated Extraction Spec. Offline DSPy compile,
    on its own clock.

OPL sentences:

1. **Language Lesson Extracting** zooms into **Segmenting**, **Mining**, **Scoping**, **Drafting**,
   **Sentence Item Generating**, **Grammar Item Generating**, **Validating**, **Evaluating**,
   **Assembling**, **Reviewing**, and **Publishing**.
2. **Language Lesson Extracting** requires **LLM Engine**.
3. **Segmenting** consumes **Canonical Text** and yields **Sentence Unit**. **Segmenting** invokes **Mining**.
4. **Sentence Unit** exhibits *id*, *text*, *charSpan*, *audioSpan*, *tokens*, *lemma+POS*, and *L1 gloss*.
5. **Mining** requires **Extraction Spec**, consumes **Sentence Unit**, and yields **Vocab Item** and
   **Grammar Point**. **Mining** invokes **Scoping**.
6. **Vocab Item** exhibits *lemma*, *pos*, *gloss*, *frequencyRank*, and *exampleSentenceId*.
7. **Grammar Point** exhibits *patternId*, *construction*, *cefr*, *L1 contrast note*, and *exampleSentenceId*.
8. **Scoping** requires **Curriculum Spec** and **Learner Profile**, consumes **Vocab Item** and
   **Grammar Point**, and yields **Lesson Scope**.
9. **Lesson Scope** exhibits *targetGrammarPointId*, *targetLexis*, *cefr*, *prerequisiteIds*, and *itemBudget*.
10. **Scoping** invokes **Drafting**, **Sentence Item Generating**, and **Grammar Item Generating**
    concurrently.
11. **Drafting** consumes **Lesson Scope** and yields **Lesson Draft**.
12. **Sentence Item Generating** requires **Extraction Spec** and **Sentence Unit**, consumes
    **Lesson Scope**, and yields **Sentence Practice Item**.
13. **Sentence Practice Item** exhibits *kind*, *prompt*, *answer*, *acceptedVariants*, *distractors*,
    *hint*, and *sourceSentenceId*. *kind* can be **cloze**, **translate**, **reorder**, or **dictation**.
14. **Grammar Item Generating** consumes **Lesson Scope** and yields **Grammar Practice Item**.
15. **Grammar Practice Item** exhibits *kind*, *prompt*, *answer*, *ruleRef*, *distractors*, and *hint*.
    *kind* can be **transform**, **contrast pair**, or **error correction**.
16. **Validating** consumes **Sentence Practice Item** and **Grammar Practice Item** and yields
    **Validation Result**. **Validating** requires no LLM.
17. **Evaluating** requires **Eval Set**, consumes **Lesson Draft**, **Sentence Practice Item**, and
    **Grammar Practice Item**, and yields **Eval Report**.
18. **Validating** and **Evaluating** run concurrently and both invoke **Assembling**.
19. **Assembling** consumes **Lesson Draft**, the practice items, **Validation Result**, and
    **Eval Report**, and yields **Lesson Bundle** in state **needs review**.
20. **Reviewing** requires **Coach** as its agent, consumes the **needs review Lesson Bundle**, changes
    it to **approved** or **rejected**, and yields **Review Note**.
21. **Publishing** consumes the **approved Lesson Bundle** and yields records in **Firestore**.
22. **Attempt Record** exhibits *itemId*, *correct*, *latency*, *learnerId*, and *attemptedAt*, and is
    produced by learners working through published items.
23. **Optimizing** consumes **Eval Report** and **Attempt Record** and affects **Extraction Spec**.

## SD3 — Structured Sources

Five real sources ran through SD on 2026-10-23 (`pipeline/jp/s01..s05`). Only one of the five was
prose. The rest were a picture of a table, a vector table, a scanned page, and a tutor's
spreadsheet. SD's single Normalizing step to Canonical Text loses what matters in each.

OPL sentences:

1. **Source Document** exhibits *shape*, which can be **text**, **picture table**, **image**, or **sheet**.
2. **Normalizing (picture table)** consumes **Raw Asset** and yields **Canonical Table**. It samples
   each cell's fill from the rendered page, because the fill is data (sound change, special reading).
3. **Normalizing (sheet)** consumes **Raw Asset** and yields **Canonical Table**, with merged cells
   filled, hyperlink targets kept, and each formula kept beside its cached value.
4. **Transcribing** requires **LLM Engine** and **OCR Engine**, consumes an **image** **Raw Asset**,
   and yields **Canonical Table**. Its output is always **needs review**: OCR narrows the review,
   it never replaces it.
5. **Table Extracting** consumes **Canonical Table** and yields **Reference Item**, **Verb Pair**,
   and **Paradigm Cell**.
6. **Curriculum Importing** requires **Tutor** as its agent, consumes **Canonical Table**, and yields
   **Curriculum Spec**, **Grammar Point**, and **External Resource**. **Mining** does not run on a
   tutor's source: the tutor already did that work.
7. **Grammar Point** exhibits *provenance*, which can be **mined** or **tutor**, and *requires forms*,
   the verb forms the pattern needs.
8. **Conjugation Engine** is plain code. **Paradigm Cell** is its gold set: the engine must
   reproduce every tutor cell before it generates a drill item.
9. **Validating (cross-source)** consumes the items of several bundles. Two sources that cover the
   same fact must agree (verb pairs, counter readings in example sentences).
10. **Lesson Bundle** can also be **blocked**: written, so a reviewer sees why, but not approvable.
11. **Cataloging** consumes every **Lesson Bundle**, requires **Use Taxonomy**, and yields
    **Catalog Entry**. It runs at extraction time, before **Publishing**, so content is typed once.
12. **Catalog Entry** exhibits *type*, which can be **grammar point**, **particle**, **reference table**,
    **verb pair**, **conjugation**, or **vocabulary**. The type comes from the extractor that made the
    item, so it is deterministic.
13. **Catalog Entry** also exhibits *uses* (what the item is for: asking advice, stating a plan,
    showing regret...), *lesson*, *search text*, and *open target*. Uses are an LM judgment kept as
    reviewable data (`pipeline/jp/uses.json`), not computed at run time.
14. **Publishing** consumes the approved **Lesson Bundle**, **Catalog Entry**, and **Corrections**.
    A correction whose *from* no longer matches fails the publish.
15. **Finding** requires **Learner** as its agent, consumes **App Lesson File** and **Query**, and
    yields **Result List**. Text search wins, then the selected use, then type order. It runs in
    the app and needs no LM.

## Open questions

- ~~**Scoping picks one teachable unit**~~ — answered by the tutor's sheet: a lesson carries 2 to 6
  grammar points (Mari, lessons 26 to 50). One lesson is a set of points, not one point.
- **Level framework** — `GrammarPoint.cefr` is now `level` with a framework prefix. Japanese is
  graded by JLPT (N5 to N1), and CEFR alignment for it is contested.
- **Validating vs Evaluating** — Validating is a hard gate (sentence 19 refuses to assemble). Should a
  low Eval Report score also block, or only flag for the reviewer?
- **Do Vocab Item and Grammar Point deserve their own Firestore collections?** Right now they are
  intermediates that live only inside a run. Promoting them gives cross-lesson reuse and a
  "which lessons teach this pattern?" query, at the cost of a dedupe/merge process.
- **Learner Profile in Scoping** makes every lesson learner-specific, which breaks shared authoring.
  Split into a generic pass (Curriculum Spec only) and a personalisation pass?
- **Reviewing is the only human gate.** At what Eval Report score does it become auto-approve?

## Regenerating the diagram

`node opm-lesson-extraction.gen.js` (in this folder) writes `opm-lesson-extraction.drawio` (both pages). Open the file at
https://app.diagrams.net via File > Open From > Device, or drag it onto the canvas. The earlier
single-OPD mermaid version is gone — one picture, one source.

## Schemas

`../pipeline/extraction_schemas.py` is the first-pass typed schema derived from these objects —
one pydantic model per OPM object, plus a `STAGE_IO` map of every stage's inputs and outputs.
Grep it for three markers: `# GUESS:` (I invented a type the OPM does not state), `# DECISION:`
(the OPM was ambiguous and I picked one — these belong back in the diagram), and `# MISSING:`
(no answer exists yet). Running it executes a self-check that the stage graph still composes.

## What SD2 changed

The assessment found one structural problem the first diagram could not show: there was a single
`Evaluating` stage at the end, which can tell you the pipeline is bad but not which module to fix.
DSPy compiles per module, so SD2 gives each optimizable module its own metric set, each tagged
`DET` (plain Python, costs nothing) or `JUDGE` (needs an LM and a rubric).

Write the DET metrics first. They are free and they catch more than the judge will. Every JUDGE
metric is blocked on the `rubric` gap, drawn in red on SD2.

Three things moved out of SD1 and into SD2: `Optimizing`, `Attempt Record`, and the former
`Extraction Spec` — now drawn honestly as **Compiled Program**, which is not a data object but the
DSPy module itself. That was the category error flagged in the assessment.

Process fill now encodes the stage kind from `STAGE_IO`: blue = LM call (gets a signature),
grey = deterministic, orange = human. Red dashed boxes are gaps the schema could not close; each
one corresponds to a `# MISSING` in `extraction_schemas.py`.
