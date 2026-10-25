// Generates opm-lesson-extraction.drawio (5 OPDs). Edit coords here, re-run:
//   node opm-lesson-extraction.gen.js [out.drawio]
// Every process box is drawn with proc(), which names its STAGE_IO key from
// ../pipeline/extraction_schemas.py (written into the cell style as opmStage=<key>).
// pipeline/jp/tests/test_opm_sync.py checks the stages, their kinds and the OPL text agree.
const fs = require('fs');
const OUT = process.argv[2] || __dirname + '/opm-lesson-extraction.drawio';

const esc = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const dot = ' &#183; ';
const bar = ' &#124; ';   // literal pipe: a bare '|' is the line-break marker
const lbl = (title, detail) =>
  esc(`<b>${title}</b>`) + (detail ? esc('<br><font style="font-size:10px;color:#4d4d4d">') + esc(detail).replace(/\|/g, esc('<br>')) + esc('</font>') : '');

const S = {
  obj:    'rounded=0;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;strokeWidth=2;fontSize=12;verticalAlign=middle;spacing=4;',
  objTop: 'rounded=0;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;strokeWidth=2;fontSize=12;verticalAlign=top;spacingTop=6;',
  store:  'shape=cylinder3;boundedY=0.25;whiteSpace=wrap;html=1;fillColor=#e1d5e7;strokeColor=#9673a6;strokeWidth=2;fontSize=12;',
  // process fill now encodes STAGE_IO kind
  lm:     'ellipse;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;strokeWidth=2;fontSize=12;',
  lmZ:    'ellipse;whiteSpace=wrap;html=1;fillColor=#b8d4f5;strokeColor=#1f5fa9;strokeWidth=3;fontSize=12;',
  det:    'ellipse;whiteSpace=wrap;html=1;fillColor=#f0f0f0;strokeColor=#808080;strokeWidth=2;fontSize=12;',
  human:  'ellipse;whiteSpace=wrap;html=1;fillColor=#ffe6cc;strokeColor=#d79b00;strokeWidth=2;fontSize=12;',
  ctrl:   'rounded=0;whiteSpace=wrap;html=1;fillColor=#fff2cc;strokeColor=#d6b656;strokeWidth=2;fontSize=12;',
  state:  'rounded=1;arcSize=50;whiteSpace=wrap;html=1;fillColor=#ffffff;strokeColor=#82b366;fontSize=11;',
  gap:    'rounded=0;whiteSpace=wrap;html=1;fillColor=#f8cecc;strokeColor=#b85450;strokeWidth=2;dashed=1;dashPattern=6 4;fontSize=10;align=left;verticalAlign=top;spacing=6;',
  metric: 'rounded=0;whiteSpace=wrap;html=1;fillColor=#ffffff;strokeColor=#6c8ebf;strokeWidth=1;fontSize=10;align=left;verticalAlign=top;spacing=6;',
  frame:  'rounded=1;arcSize=4;whiteSpace=wrap;html=1;fillColor=none;strokeColor=#6c8ebf;strokeWidth=2;dashed=1;dashPattern=12 6;verticalAlign=top;fontSize=15;fontStyle=1;spacingTop=6;',
  note:   'text;html=1;whiteSpace=wrap;align=left;verticalAlign=top;fillColor=#f5f5f5;strokeColor=#b3b3b3;fontSize=11;spacing=10;',
};

const E = {
  consume: 'endArrow=block;endFill=1;strokeColor=#333333;',
  result:  'endArrow=block;endFill=1;strokeColor=#333333;',
  instr:   'endArrow=oval;endFill=0;strokeColor=#333333;',
  agent:   'endArrow=oval;endFill=1;strokeColor=#333333;',
  effect:  'startArrow=block;startFill=1;endArrow=block;endFill=1;strokeColor=#333333;',
  invoke:  'endArrow=openThin;endFill=0;strokeColor=#e07b00;strokeWidth=2.5;dashed=1;dashPattern=10 5;',
  gapLink: 'endArrow=none;strokeColor=#b85450;strokeWidth=1.5;dashed=1;dashPattern=4 4;',
  measure: 'endArrow=none;strokeColor=#6c8ebf;strokeWidth=1.2;dashed=1;dashPattern=3 3;',
};

let cells = [];
const node = (id, style, x, y, w, h, title, detail) =>
  cells.push(`<mxCell id="${id}" value="${lbl(title, detail)}" style="${style}" vertex="1" parent="1"><mxGeometry x="${x}" y="${y}" width="${w}" height="${h}" as="geometry"/></mxCell>`);
// A process box: stage is its STAGE_IO key, and the fill (S.lm / S.det / S.human) its kind.
const proc = (id, stage, style, x, y, w, h, title, detail) =>
  node(id, style + `opmStage=${stage};`, x, y, w, h, title, detail);
const raw = (id, style, x, y, w, h, value) =>
  cells.push(`<mxCell id="${id}" value="${value}" style="${style}" vertex="1" parent="1"><mxGeometry x="${x}" y="${y}" width="${w}" height="${h}" as="geometry"/></mxCell>`);

let ei = 0;
const edge = (kind, src, tgt, opts = {}) => {
  const { exit, entry, label = '', pts = [] } = opts;
  let st = 'edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;jettySize=12;strokeWidth=1.6;' + E[kind];
  if (exit) st += `exitX=${exit[0]};exitY=${exit[1]};exitDx=0;exitDy=0;`;
  if (entry) st += `entryX=${entry[0]};entryY=${entry[1]};entryDx=0;entryDy=0;`;
  const arr = pts.length ? `<Array as="points">${pts.map(p => `<mxPoint x="${p[0]}" y="${p[1]}"/>`).join('')}</Array>` : '';
  cells.push(`<mxCell id="e${ei++}" value="${esc(label).replace(/\|/g, esc('<br>'))}" style="${st}fontSize=10;fontColor=#555555;labelBackgroundColor=#ffffff;" edge="1" parent="1" source="${src}" target="${tgt}"><mxGeometry relative="1" as="geometry">${arr}</mxGeometry></mxCell>`);
};

const page = (name, id, w, h) => {
  const body = cells.join('\n        ');
  cells = [];
  return `  <diagram name="${name}" id="${id}">
    <mxGraphModel dx="1600" dy="1000" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="${w}" pageHeight="${h}" math="0" shadow="0">
      <root><mxCell id="0"/><mxCell id="1" parent="0"/>
        ${body}
      </root>
    </mxGraphModel>
  </diagram>`;
};

const LEGEND = (extra) => esc('<b>Legend</b><br>'
  + 'green rectangle = object &#183; yellow = control object &#183; purple cylinder = persistent store<br>'
  + '<b style="color:#1f5fa9">blue ellipse = LM stage</b> (gets a DSPy signature) &#183; '
  + '<b style="color:#666">grey ellipse = deterministic</b> (plain code) &#183; '
  + '<b style="color:#b07000">orange ellipse = human</b><br>'
  + '&#8594; solid = consumption / result &#183; &#8596; = effect &#183; &#8212;&#9675; = instrument &#183; &#8212;&#9679; = agent<br>'
  + '<b style="color:#e07b00">&#8212; &#8212;&#8594; orange dashed = asynchronous invocation</b> (queue hop, carries an Envelope)<br>'
  + '<b style="color:#b85450">red dashed box = a gap the schema could not close</b> &#8212; see # MISSING in extraction_schemas.py'
  + (extra ? '<br>' + extra : ''));

/* ═══════════════════════ SD — Content Extracting ═══════════════════════ */

raw('F0', S.frame, 330, 40, 900, 1480, esc('<b>Content Extracting</b> &#8212; in-zoomed (dashed frame stands for the parent process ellipse)'));

node('A0', S.obj,  540, 90,  320, 75, 'Source Document', 'pdf' + bar + 'epub' + bar + 'url' + bar + 'transcript' + bar + 'markdown|bytes_len: int ' + dot + 'mime: str ' + dot + 'origin: str');
proc('S1', 'Ingesting', S.det, 560, 195, 280, 65, 'Ingesting', 'fetch + store immutably');
node('A1', S.obj,  540, 300, 320, 70, 'Raw Asset', 'blob_ref ' + dot + 'sha256: str|mime: str ' + dot + 'fetched_at: datetime');
proc('S2', 'Normalizing', S.det, 560, 415, 280, 65, 'Normalizing', 'decode, de-layout, segment structure');
node('A2', S.obj,  540, 520, 320, 90, 'Canonical Text', 'plain_text: str ' + dot + 'detected_language|structure: list[StructureNode]');
proc('S3', 'Classifying', S.lm, 560, 655, 280, 65, 'Classifying', 'DSPy module');
node('A3', S.obj,  540, 755, 320, 110, 'Content Classification', 'doc_kind: DocKind|confidence: float 0..1|target_language? ' + dot + 'cefr_guess?: CEFR');
proc('S4', 'Routing', S.det, 560, 905, 280, 65, 'Routing', 'confidence gate + enqueue');
node('A4', S.obj,  540, 1010, 320, 70, 'Extraction Route', 'handler_id ' + dot + 'queue_topic: str|priority: int');

proc('S5a', 'HabitLessonExtracting', S.lm,  360, 1130, 250, 70, 'Habit Lesson Extracting', '');
proc('S5b', 'LanguageLessonExtracting', S.lmZ, 630, 1130, 250, 70, 'Language Lesson Extracting', 'in-zoomed in OPD SD1');
proc('S5c', 'ArticleExtracting', S.lm,  900, 1130, 250, 70, 'Article Extracting', '');

node('A5', S.objTop, 540, 1250, 320, 125, 'Lesson Bundle', 'state: BundleState');
node('B1', S.state, 560, 1320, 130, 32, 'needs review', '');
node('B2', S.state, 700, 1320, 80, 32, 'approved', '');
node('B3', S.state, 790, 1320, 60, 32, 'rejected', '');
proc('S6', 'Publishing', S.det, 560, 1385, 280, 65, 'Publishing', 'idempotent on run_id');
node('FS', S.store, 540, 1560, 320, 90, 'Firestore', 'lessons ' + dot + 'practice_items');

node('QUEUE', S.ctrl, 60, 300, 230, 90,  'Work Queue', 'topic ' + dot + 'visibility_timeout|max_retries ' + dot + 'dead-letter queue');
node('LLM',   S.ctrl, 60, 440, 230, 50,  'LLM Engine', '');
node('CSPEC', S.ctrl, 60, 655, 230, 70,  'Classifier Spec', 'compiled DSPy program');

proc('ST', 'Triaging', S.human, 1270, 790, 250, 70, 'Triaging', 'low confidence or unknown');
node('COACH', S.ctrl, 1270, 900, 250, 50, 'Coach', '');

node('JOB', S.objTop, 1270, 280, 250, 310, 'Extraction Job', 'run_id: str ' + dot + 'attempt: int|last_error: str?');
node('J1', S.state, 1290, 370, 210, 32, 'queued', '');
node('J2', S.state, 1290, 412, 210, 32, 'running', '');
node('J3', S.state, 1290, 454, 210, 32, 'needs review', '');
node('J4', S.state, 1290, 496, 210, 32, 'published', '');
node('J5', S.state, 1290, 538, 210, 32, 'failed', '');
node('DLQ', S.store, 1270, 640, 250, 80, 'Dead-letter Queue', 'poison payloads ' + dot + 'replayable');

edge('consume', 'A0', 'S1', { exit: [0.5, 1], entry: [0.5, 0] });
edge('result',  'S1', 'A1', { exit: [0.5, 1], entry: [0.5, 0] });
edge('consume', 'A1', 'S2', { exit: [0.5, 1], entry: [0.5, 0] });
edge('result',  'S2', 'A2', { exit: [0.5, 1], entry: [0.5, 0] });
edge('consume', 'A2', 'S3', { exit: [0.5, 1], entry: [0.5, 0] });
edge('result',  'S3', 'A3', { exit: [0.5, 1], entry: [0.5, 0] });
edge('consume', 'A3', 'S4', { exit: [0.5, 1], entry: [0.5, 0] });
edge('result',  'S4', 'A4', { exit: [0.5, 1], entry: [0.5, 0] });
edge('consume', 'A4', 'S5b', { exit: [0.5, 1], entry: [0.5, 0] });
edge('result',  'S5b', 'A5', { exit: [0.5, 1], entry: [0.5, 0] });
edge('consume', 'A5', 'S6', { exit: [0.5, 1], entry: [0.5, 0], label: 'approved' });
edge('result',  'S6', 'FS', { exit: [0.5, 1], entry: [0.5, 0] });

edge('invoke', 'S1', 'S2', { exit: [0, 0.5], entry: [0, 0.5], pts: [[400, 227], [400, 447]], label: 'async' });
edge('invoke', 'S2', 'S3', { exit: [0, 0.5], entry: [0, 0.5], pts: [[400, 447], [400, 687]], label: 'async' });
edge('invoke', 'S3', 'S4', { exit: [0, 0.5], entry: [0, 0.5], pts: [[400, 687], [400, 937]], label: 'async' });
edge('invoke', 'S4', 'S5a', { exit: [0, 0.5], entry: [0.5, 0], pts: [[400, 937], [400, 1100], [485, 1100]], label: 'async' });
edge('invoke', 'S4', 'S5b', { exit: [0.5, 1], entry: [0.2, 0], label: '' });
edge('invoke', 'S4', 'S5c', { exit: [1, 0.5], entry: [0.5, 0], pts: [[1190, 937], [1190, 1100], [1025, 1100]], label: 'async' });
edge('invoke', 'S5b', 'S6', { exit: [1, 0.5], entry: [1, 0.5], pts: [[1190, 1165], [1190, 1417]], label: 'async' });

edge('instr', 'QUEUE', 'F0',   { exit: [1, 0.5], entry: [0, 0.18] });
edge('instr', 'LLM',   'S3',   { exit: [1, 0.5], entry: [0, 0.25] });
edge('instr', 'CSPEC', 'S3',   { exit: [1, 0.5], entry: [0, 0.6] });
edge('agent', 'COACH', 'ST',   { exit: [0.5, 0], entry: [0.5, 1] });
edge('consume', 'A3', 'ST', { exit: [1, 0.5], entry: [0, 0.3], label: 'confidence &lt; threshold' });
edge('effect',  'ST', 'A3', { exit: [0, 0.8], entry: [1, 0.85] });
edge('effect', 'F0',  'JOB', { exit: [1, 0.1], entry: [0, 0.15], label: 'every stage' });
edge('result', 'S4',  'J5',  { exit: [1, 0.8], entry: [0, 0.5], pts: [[1230, 955], [1230, 554]], label: 'retries exhausted' });
edge('consume','J5',  'DLQ', { exit: [0.5, 1], entry: [0.5, 0] });

raw('LEG0', S.note, 60, 1560, 420, 180, LEGEND(''));

const p0 = page('SD &#8212; Content Extracting', 'opd-sd', 1700, 1850);

/* ═══════════════════════ SD1 — Language Lesson Extracting ═══════════════════════ */

raw('F1', S.frame, 330, 40, 1060, 2120, esc('<b>SD1 &#8212; Language Lesson Extracting</b> &#8212; in-zoomed from SD. Types track <i>pipeline/extraction_schemas.py</i>.'));

const ax = 540, aw = 360;   // chain artifact x / width  (centre 720)
const px = 580, pw = 280;   // chain process  x / width

node('L0', S.obj,  ax, 90, aw, 90, 'Canonical Text', 'plain_text: str ' + dot + 'detected_language|structure: list[StructureNode]|&#8592; carried in from SD');
proc('T1', 'Segmenting', S.det, px, 215, pw, 65, 'Segmenting', 'spaCy / stanza &#8212; not an LM call');
node('L1', S.obj,  ax, 320, aw, 115, 'Sentence Unit', 'id: str ' + dot + 'text: str ' + dot + 'char_span: CharSpan|audio_span: TimeSpan?|tokens: list[Token] ' + dot + 'l1_gloss: str');
proc('T2', 'Mining', S.lm, px, 470, pw, 75, 'Mining', 'document-scoped: ONE call|over list[SentenceUnit]');

node('L2a', S.obj, 350, 590, 320, 115, 'Vocab Item', 'lemma: str ' + dot + 'pos: str ' + dot + 'gloss: str|frequency_rank: int?|example_sentence_id: str');
node('L2b', S.obj, 770, 590, 320, 115, 'Grammar Point', 'pattern_id: str ' + dot + 'cefr: CEFR|construction: str|l1_contrast_note: str|example_sentence_id: str');

proc('T3', 'Scoping', S.lm, px, 745, pw, 70, 'Scoping', '');
node('L3', S.obj,  ax, 855, aw, 125, 'Lesson Scope', 'id: str ' + dot + 'cefr: CEFR ' + dot + 'item_budget: int|target_grammar_point_id: str|target_lexis: list[str]|prerequisite_ids: list[str]');

proc('T4', 'Drafting', S.lm, 345, 1020, 240, 80, 'Drafting', 'one call per Lesson Scope');
proc('T5', 'SentenceItemGenerating', S.lm, 605, 1020, 240, 80, 'Sentence Item Generating', '&#215;N &#8212; one call per Sentence Unit');
proc('T6', 'GrammarItemGenerating', S.lm, 865, 1020, 240, 80, 'Grammar Item Generating', '&#215;N &#8212; one call per Grammar Point');

node('L4', S.obj, 340, 1145, 250, 150, 'Lesson Draft', 'id ' + dot + 'scope_id: str|title: str ' + dot + 'description: str|explanation: str|l1_contrast_note: str|worked_examples: list[str]');
node('L5', S.obj, 600, 1145, 250, 150, 'Sentence Practice Item', 'id ' + dot + 'scope_id: str|kind: SentenceItemKind|prompt ' + dot + 'answer: str|accepted_variants: list[str]|distractors: list[str] ' + dot + 'hint: str?|source_sentence_id: str');
node('L6', S.obj, 860, 1145, 250, 150, 'Grammar Practice Item', 'id ' + dot + 'scope_id: str|kind: GrammarItemKind|prompt ' + dot + 'answer ' + dot + 'rule_ref: str|distractors: list[str] ' + dot + 'hint: str?|source_sentence_id: str &#8592; added');

proc('T7', 'Validating', S.det, 395, 1340, 250, 70, 'Validating', '5 checks, no LLM');
proc('T8', 'Evaluating', S.lm,  830, 1340, 250, 70, 'Evaluating', 'gold set + LLM judge');
node('L7', S.obj, 385, 1450, 270, 120, 'Validation Result', 'id ' + dot + 'scope_id: str|checked_item_ids: list[str]|failures: list[CheckFailure]|passed: bool (derived)');
node('L8', S.obj, 820, 1450, 270, 120, 'Eval Report', 'id ' + dot + 'run_id ' + dot + 'spec_version: str|per_metric_scores:|&#160;&#160;dict[MetricName, float]|per_item_verdicts: list[ItemVerdict]');

proc('T9', 'Assembling', S.det, px, 1630, pw, 70, 'Assembling', 'gate: validation.passed');
proc('T10', 'Reviewing', S.human, px, 1770, pw, 70, 'Reviewing', 'human gate, hours not seconds');
proc('T11', 'Publishing', S.det, px, 1910, pw, 70, 'Publishing', 'idempotent on run_id');
node('FS1', S.store, ax, 2020, aw, 90, 'Firestore', 'lessons ' + dot + 'practice_items');

node('L9', S.objTop, 1130, 1620, 250, 200, 'Lesson Bundle', 'id ' + dot + 'run_id: str|state: BundleState');
node('C1', S.state, 1148, 1700, 215, 32, 'needs review', '');
node('C2', S.state, 1148, 1742, 215, 32, 'approved', '');
node('C3', S.state, 1148, 1784, 215, 32, 'rejected', '');
node('L10', S.obj, 1130, 1860, 250, 70, 'Review Note', 'bundle_id ' + dot + 'reviewer: str|reason: str ' + dot + 'reviewed_at');

node('ENV',  S.ctrl, 60, 215, 250, 120, 'Envelope[T]', 'run_id ' + dot + 'stage ' + dot + 'spec_version|idempotency_key: str|attempt: int ' + dot + 'payload: T|carried by every orange link');
node('CPROG',S.ctrl, 60, 470, 250, 95, 'Compiled Program', 'per LM stage|spec_version: str|recompiled in SD2');
node('CUR',  S.ctrl, 60, 745, 250, 100, 'Curriculum Spec', 'grammar_syllabus:|&#160;&#160;dict[pattern_id, CEFR]|lexical_sets: dict[CEFR, list[str]]');
node('PROF', S.ctrl, 60, 880, 250, 120, 'Learner Profile', 'l1 ' + dot + 'target_language: LanguageCode|current_cefr: CEFR|known_lemmas: set[str]|error_history: dict[str, int]');
node('ELLM', S.ctrl, 60, 1040, 250, 50, 'LLM Engine', '');
node('ESET', S.ctrl, 60, 1340, 250, 90, 'Eval Set', 'list[GoldExample]|see SD2');
node('CO2',  S.ctrl, 60, 1780, 250, 50, 'Coach', '');

// gaps the schema could not close
node('G1', S.gap, 1410, 320, 250, 110, 'MISSING', 'Token has no morphological features (tense, person, number). "Conjugate to 2sg preterite" is unspecifiable without them.');
node('G2', S.gap, 1410, 590, 250, 90, 'MISSING', 'frequency_rank against WHICH corpus? A rank is meaningless until the list is named.');
node('G3', S.gap, 1410, 745, 250, 110, 'MISSING', 'pattern_id needs one id space shared with Curriculum Spec, or prerequisites and rule_ref_valid are uncheckable.');
node('G4', S.gap, 1410, 1040, 250, 100, 'OPEN', 'Learner Profile in Scoping makes every lesson learner-specific, which breaks shared authoring.');

edge('consume', 'L0', 'T1', { exit: [0.5, 1], entry: [0.5, 0] });
edge('result',  'T1', 'L1', { exit: [0.5, 1], entry: [0.5, 0], label: 'list[SentenceUnit]' });
edge('consume', 'L1', 'T2', { exit: [0.5, 1], entry: [0.5, 0] });
edge('result',  'T2', 'L2a', { exit: [0.2, 1], entry: [0.5, 0] });
edge('result',  'T2', 'L2b', { exit: [0.8, 1], entry: [0.5, 0] });
edge('consume', 'L2a', 'T3', { exit: [0.8, 1], entry: [0.15, 0] });
edge('consume', 'L2b', 'T3', { exit: [0.2, 1], entry: [0.85, 0] });
edge('result',  'T3', 'L3', { exit: [0.5, 1], entry: [0.5, 0] });

edge('consume', 'L3', 'T4', { exit: [0.1, 1], entry: [0.5, 0] });
edge('consume', 'L3', 'T5', { exit: [0.5, 1], entry: [0.5, 0] });
edge('consume', 'L3', 'T6', { exit: [0.9, 1], entry: [0.5, 0] });
edge('result',  'T4', 'L4', { exit: [0.5, 1], entry: [0.5, 0] });
edge('result',  'T5', 'L5', { exit: [0.5, 1], entry: [0.5, 0] });
edge('result',  'T6', 'L6', { exit: [0.5, 1], entry: [0.5, 0] });
edge('instr',   'L1', 'T5', { exit: [1, 0.5], entry: [0.9, 0], pts: [[1300, 377], [1300, 985], [812, 985]] });
edge('instr',   'L2b', 'T6', { exit: [1, 0.3], entry: [0.9, 0], pts: [[1140, 624], [1140, 995], [1072, 995]] });

edge('consume', 'L5', 'T7', { exit: [0.15, 1], entry: [0.75, 0] });
edge('consume', 'L6', 'T7', { exit: [0.05, 1], entry: [1, 0.4] });
edge('consume', 'L4', 'T8', { exit: [0.95, 1], entry: [0, 0.3] });
edge('consume', 'L5', 'T8', { exit: [0.85, 1], entry: [0.3, 0] });
edge('consume', 'L6', 'T8', { exit: [0.6, 1], entry: [0.7, 0] });
edge('result',  'T7', 'L7', { exit: [0.5, 1], entry: [0.5, 0] });
edge('result',  'T8', 'L8', { exit: [0.5, 1], entry: [0.5, 0] });

edge('consume', 'L7', 'T9', { exit: [0.5, 1], entry: [0.2, 0] });
edge('consume', 'L8', 'T9', { exit: [0.5, 1], entry: [0.8, 0] });
edge('consume', 'L4', 'T9', { exit: [0, 0.5], entry: [0, 0.4], pts: [[318, 1220], [318, 1658]] });
edge('result',  'T9', 'L9',   { exit: [1, 0.5], entry: [0, 0.2] });
edge('consume', 'C1', 'T10',  { exit: [0, 0.5], entry: [1, 0.5] });
edge('effect',  'T10', 'L9',  { exit: [1, 0.75], entry: [0, 0.85], label: 'approve ' + bar + ' reject' });
edge('result',  'T10', 'L10', { exit: [0.9, 1], entry: [0, 0.4] });
edge('consume', 'C2', 'T11',  { exit: [0, 0.5], entry: [1, 0.3] });
edge('result',  'T11', 'FS1', { exit: [0.5, 1], entry: [0.5, 0] });

edge('invoke', 'T1', 'T2',  { exit: [0, 0.5], entry: [0, 0.5], pts: [[335, 247], [335, 507]], label: 'async' });
edge('invoke', 'T2', 'T3',  { exit: [1, 0.5], entry: [1, 0.5], pts: [[1120, 507], [1120, 780]], label: 'async' });
edge('invoke', 'T3', 'T4',  { exit: [0, 0.5], entry: [0, 0.5], pts: [[335, 780], [335, 1060]], label: 'fan-out' });
edge('invoke', 'T3', 'T6',  { exit: [1, 0.5], entry: [1, 0.5], pts: [[1200, 780], [1200, 1060]], label: 'fan-out' });
edge('invoke', 'T7', 'T9',  { exit: [0, 0.5], entry: [0, 0.2], pts: [[345, 1375], [345, 1644]], label: 'join' });
edge('invoke', 'T8', 'T9',  { exit: [1, 0.5], entry: [1, 0.2], pts: [[1200, 1375], [1200, 1644]], label: 'join' });
edge('invoke', 'T10', 'T11',{ exit: [0, 0.5], entry: [0, 0.5], pts: [[335, 1805], [335, 1945]], label: 'async' });

edge('instr', 'ENV',   'F1',  { exit: [1, 0.5], entry: [0, 0.11] });
edge('instr', 'CPROG', 'T2',  { exit: [1, 0.5], entry: [0, 0.5] });
edge('instr', 'ELLM',  'F1',  { exit: [1, 0.5], entry: [0, 0.47] });
edge('instr', 'CUR',   'T3',  { exit: [1, 0.5], entry: [0, 0.4] });
edge('instr', 'PROF',  'T3',  { exit: [1, 0.2], entry: [0, 0.8] });
edge('instr', 'ESET',  'T8',  { exit: [1, 0.5], entry: [0, 0.75], pts: [[330, 1385], [330, 1310], [1150, 1310], [1150, 1393]] });
edge('agent', 'CO2',   'T10', { exit: [1, 0.5], entry: [0, 0.5] });

edge('gapLink', 'G1', 'L1',  { exit: [0, 0.5], entry: [1, 0.5] });
edge('gapLink', 'G2', 'L2a', { exit: [0, 0.9], entry: [0.9, 1], pts: [[1180, 718], [690, 718]] });
edge('gapLink', 'G3', 'L2b', { exit: [0, 0.5], entry: [1, 0.8] });


raw('LEG1', S.note, 60, 1960, 420, 190, LEGEND('every stage: one input object in, one output object out'));

const p1 = page('SD1 &#8212; Language Lesson Extracting', 'opd-sd1', 1720, 2250);

/* ═══════════════════════ SD2 — Evaluating & Optimizing ═══════════════════════ */

raw('F2', S.frame, 330, 40, 820, 1180, esc('<b>SD2 &#8212; Evaluating &amp; Optimizing</b> &#8212; one metric set per optimizable module. The OPM had one eval at the end; DSPy compiles per module.'));

const mods = [
  ['M1', 'Mining',                   'Mining',                 140, ['citation_valid &#8212; DET', 'grammar_point_precision &#8212; JUDGE', 'vocab_gloss_accuracy &#8212; JUDGE']],
  ['M2', 'Scoping',                  'Scoping',                320, ['scope_single_unit &#8212; DET', 'scope_prerequisites_respected &#8212; DET', 'scope_level_fit &#8212; JUDGE']],
  ['M3', 'Drafting',                 'Drafting',               500, ['no_hallucinated_rule &#8212; JUDGE', 'l1_contrast_accuracy &#8212; JUDGE']],
  ['M4', 'Sentence Item Generating', 'SentenceItemGenerating', 660, ['item_answerable &#8212; JUDGE', 'item_level_fit &#8212; JUDGE', 'distractor_plausibility &#8212; JUDGE']],
  ['M5', 'Grammar Item Generating',  'GrammarItemGenerating',  840, ['rule_ref_valid &#8212; DET', 'item_answerable &#8212; JUDGE', 'distractor_plausibility &#8212; JUDGE']],
];
let i = 0;
for (const [id, name, stage, y, metrics] of mods) {
  proc(id, stage, S.lm, 360, y, 250, 70, name, '');
  raw(id + 'm', S.metric, 660, y - 12, 330, 24 + metrics.length * 16,
      esc('<b>metrics</b><br>') + metrics.map(m => esc('&#8226; ') + esc(m)).join(esc('<br>')));
  edge('measure', id + 'm', id, { exit: [0, 0.5], entry: [1, 0.5] });
  const lane = 1000 + i * 22, ey = 0.2 + i * 0.15;
  edge('result', id, 'ER2', { exit: [1, 0.9], entry: [0, ey], pts: [[lane, y + 63], [lane, 420 + ey * 150]] });
  i += 1;
}

proc('V2', 'Validating',  S.det, 360, 1020, 250, 70, 'Validating', 'gate, not a metric');
raw('V2m', S.metric, 660, 1000, 330, 128,
    esc('<b>ValidationCheck</b> &#8212; all DET<br>')
    + ['unique_answer', 'no_answer_leak', 'distractor_not_also_correct', 'lemma_in_known_set', 'length_bounds']
      .map(m => esc('&#8226; ') + esc(m)).join(esc('<br>')));
edge('measure', 'V2m', 'V2', { exit: [0, 0.5], entry: [1, 0.5] });

node('GOLD', S.ctrl, 40, 140, 260, 160, 'Gold Example', 'canonical_text: CanonicalText|expected_scope: LessonScope|expected_sentence_items: list[...]|expected_grammar_items: list[...]|rubric: str|&#8592; one row of the Eval Set');
node('ER2', S.obj, 1190, 420, 280, 150, 'Eval Report', 'id ' + dot + 'run_id ' + dot + 'spec_version: str|scope_id: str|per_metric_scores:|&#160;&#160;dict[MetricName, float]|per_item_verdicts: list[ItemVerdict]');
node('ATT2', S.obj, 1190, 640, 280, 130, 'Attempt Record', 'item_id ' + dot + 'learner_id: str|correct: bool ' + dot + 'latency_ms: int|attempted_at: datetime|reported_broken: bool');
proc('OPT2', 'Optimizing', S.det, 1205, 840, 250, 75, 'Optimizing', 'DSPy compile, offline');
node('CP2', S.ctrl, 1190, 970, 280, 130, 'Compiled Program', 'spec_version: str|signature + instructions + demos|one per LM module|NOT a data object &#8212; it is the module');

node('G5', S.gap, 40, 640, 260, 150, 'MISSING &#8212; Attempt Record', 'A low correct-rate confounds "hard item" with "broken item". Optimizing on raw attempts drifts toward easy items. Calibrate difficulty, or restrict the signal to reported_broken.');
node('G6', S.gap, 40, 350, 260, 130, 'MISSING &#8212; Gold Example.rubric', 'rubric is a free-text str doing the judge\'s whole job. One rubric per metric, or one per gold example? Until this is settled, every JUDGE metric above is a stub.');

edge('instr', 'GOLD', 'F2', { exit: [1, 0.5], entry: [0, 0.1] });


edge('consume', 'ER2', 'OPT2', { exit: [0.2, 1], entry: [0.25, 0], pts: [[1246, 600]] });
edge('consume', 'ATT2', 'OPT2', { exit: [0.5, 1], entry: [0.5, 0] });
edge('effect', 'OPT2', 'CP2', { exit: [0.5, 1], entry: [0.5, 0] });
edge('instr', 'CP2', 'F2', { exit: [0, 0.5], entry: [1, 0.9], label: 'recompiled, to every LM module' });
edge('result', 'V2', 'ER2', { exit: [1, 0.5], entry: [0, 0.9], pts: [[1100, 1055], [1100, 555]] });

raw('LEG2', S.note, 40, 1120, 260, 120, esc('<b>DET vs JUDGE</b><br>DET metrics are plain Python and cost nothing &#8212; write them first, they catch more than the judge will.<br>JUDGE metrics need an LM and a rubric, and every one of them is blocked on the gap above.'));

const p2 = page('SD2 &#8212; Evaluating &amp; Optimizing', 'opd-sd2', 1550, 1300);

/* ═══════════════ SD3 — Structured Sources (tables, tutor sheets, images) ═══════════════ */
// Added 2026-10-23 after running five real sources (pipeline/jp/s01..s05). SD assumed
// every source normalizes to prose. Three of five did not.

raw('F3', S.frame, 330, 40, 1120, 1880, esc('<b>SD3 &#8212; Structured Sources</b> &#8212; Normalizing in-zoomed by source shape, the tutor path that skips Mining, cataloging (type + uses), and how the learner finds a pattern (search, sort by use). Code: <i>pipeline/jp/</i>.'));

node('X0', S.obj, 700, 80, 380, 80, 'Source Document', 'shape: text' + bar + 'picture table' + bar + 'image' + bar + 'sheet|detected from the file, not guessed');

proc('N1', 'Normalizing', S.det, 360, 220, 240, 70, 'Normalizing (text)', 'PyMuPDF geometry, never a stream');
proc('N2', 'NormalizingPictureTable', S.det, 620, 220, 240, 70, 'Normalizing (picture table)', 'render + sample cell fill');
proc('N3', 'Transcribing', S.lm,  880, 220, 240, 70, 'Transcribing', 'vision; no text layer');
proc('N4', 'NormalizingSheet', S.det, 1140, 220, 240, 70, 'Normalizing (sheet)', 'merged cells, links, formulas');

node('Y1', S.obj, 360, 340, 240, 60, 'Canonical Text', 'see SD');
node('Y2', S.obj, 620, 330, 500, 90, 'Canonical Table', 'cells: x, y, fill class, lines|fill class is DATA (legend: sound change, special)|header cells merged per column');
node('OCR', S.ctrl, 880, 450, 240, 60, 'OCR Engine', 'Windows.Media.Ocr ja|independent second reading');
node('Y4', S.obj, 1140, 340, 240, 80, 'Sheet Table', 'rows with merged cells filled|hyperlink targets|formula + cached value');

proc('T1', 'TableExtracting', S.det, 620, 560, 240, 70, 'Table Extracting', 'row + column headers to cells');
proc('T2', 'CurriculumImporting', S.det, 1140, 560, 240, 70, 'Curriculum Importing', 'given, not mined');

node('R1', S.obj, 360, 680, 240, 110, 'Reference Item', 'number + counter &#8594; reading|alt readings|mark: regular' + bar + 'sound change' + bar + 'special');
node('R2', S.obj, 620, 680, 240, 110, 'Verb Pair', 'transitive ' + dot + 'intransitive|groups ' + dot + 'gloss|example per side');
node('R3', S.obj, 880, 680, 240, 110, 'Paradigm Cell', 'dictionary form ' + dot + 'group|form ' + dot + 'result|= gold for the engine');
node('R4', S.obj, 1140, 680, 240, 150, 'Curriculum Spec', 'lesson &#8594; Grammar Point[]|pattern ' + dot + 'example ' + dot + 'goal|requires_forms (prerequisites)|resource: tutor notes link|self-check: after class' + bar + 'can use it' + bar + 'review needed');

node('ENG', S.ctrl, 880, 870, 240, 80, 'Conjugation Engine', 'plain code, 12 forms|group() returns every group that fits;|ambiguous verbs never resolve silently');

proc('V3', 'ValidatingSources', S.det, 560, 1000, 360, 80, 'Validating (cross-source)', 'kana only ' + dot + 'grid complete ' + dot + 'legend consistent|engine = tutor gold ' + dot + 'pairs agree across sources|examples confirm verb + group');
node('A6', S.objTop, 560, 1130, 360, 110, 'Lesson Bundle', 'one per source, state:');
node('B6a', S.state, 575, 1190, 120, 30, 'needs review', '');
node('B6b', S.state, 705, 1190, 80, 30, 'blocked', '');
node('B6c', S.state, 795, 1190, 110, 30, 'approved', '');
proc('RV3', 'Reviewing', S.human, 600, 1290, 280, 70, 'Reviewing', 'review notes name the exact cells');
node('COACH3', S.ctrl, 960, 1300, 200, 50, 'Coach (Mark)', '');
node('TUT3', S.ctrl, 1480, 1300, 200, 50, 'Tutor (Mari)', '');

node('G7', S.gap, 40, 220, 260, 150, 'GAP &#8212; image sources', 'An image has no text layer, so Transcribing is an LM call and its output can never skip Reviewing. The OCR cross-check narrows what a person reads; it does not replace them.');
node('G8', S.gap, 40, 420, 260, 170, 'GAP &#8212; external tutor tools', 'Mari\'s Canva decks (25 links) and the web conjugation drill are linked, not extracted. Canva needs a login; the drill is a third-party page. Keep them as resources until Mari can export.');
raw('LEG3', S.note, 40, 1700, 270, 230, LEGEND('<b>SD3 rule:</b> a source a tutor wrote is curriculum, not raw text. It enters as given, through a human-authored path, and Mining (an LM) never touches it.'));

edge('consume', 'X0', 'N1', { exit: [0.1, 1], entry: [0.5, 0] });
edge('consume', 'X0', 'N2', { exit: [0.35, 1], entry: [0.5, 0] });
edge('consume', 'X0', 'N3', { exit: [0.65, 1], entry: [0.5, 0] });
edge('consume', 'X0', 'N4', { exit: [0.9, 1], entry: [0.5, 0] });
edge('result', 'N1', 'Y1', { exit: [0.5, 1], entry: [0.5, 0] });
edge('result', 'N2', 'Y2', { exit: [0.5, 1], entry: [0.25, 0] });
edge('result', 'N3', 'Y2', { exit: [0.5, 1], entry: [0.75, 0], label: 'needs review' });
edge('instr', 'OCR', 'N3', { exit: [1, 0.3], entry: [1, 0.5], pts: [[1135, 468], [1135, 255]] });
edge('result', 'N4', 'Y4', { exit: [0.5, 1], entry: [0.5, 0] });
edge('consume', 'Y2', 'T1', { exit: [0.25, 1], entry: [0.5, 0] });
edge('consume', 'Y4', 'T1', { exit: [0, 0.9], entry: [1, 0.5], pts: [[1000, 412], [1000, 595]] });
edge('consume', 'Y4', 'T2', { exit: [0.5, 1], entry: [0.5, 0] });
edge('result', 'T1', 'R1', { exit: [0, 0.5], entry: [0.5, 0], pts: [[480, 595]] });
edge('result', 'T1', 'R2', { exit: [0.5, 1], entry: [0.5, 0] });
edge('result', 'T1', 'R3', { exit: [1, 0.8], entry: [0.5, 0], pts: [[1000, 616]] });
edge('result', 'T2', 'R4', { exit: [0.5, 1], entry: [0.5, 0] });
edge('agent', 'TUT3', 'T2', { exit: [0.5, 0], entry: [1, 0.5], pts: [[1580, 595]] });
edge('instr', 'ENG', 'V3', { exit: [0.5, 1], entry: [0.85, 0] });
edge('consume', 'R1', 'V3', { exit: [0.5, 1], entry: [0.1, 0], pts: [[480, 960], [596, 960]] });
edge('consume', 'R2', 'V3', { exit: [0.5, 1], entry: [0.4, 0] });
edge('consume', 'R3', 'ENG', { exit: [0.5, 1], entry: [0.5, 0], label: 'gold' });
edge('consume', 'R4', 'V3', { exit: [0.5, 1], entry: [1, 0.5], pts: [[1260, 1040]] });
edge('result', 'V3', 'A6', { exit: [0.5, 1], entry: [0.5, 0] });
edge('consume', 'A6', 'RV3', { exit: [0.5, 1], entry: [0.5, 0] });
edge('agent', 'COACH3', 'RV3', { exit: [0, 0.5], entry: [1, 0.5] });
edge('effect', 'RV3', 'A6', { exit: [0, 0.5], entry: [0, 0.8], pts: [[540, 1325], [540, 1218]] });

// ── Cataloging and finding (added 2026-10-24). Every extracted item gets a lesson TYPE
// (from the extractor that made it, deterministic) and its USES (what it is for, an LM
// judgment kept as reviewable data in uses.json). The app searches and sorts this
// catalog, so it never guesses what a piece of content is.
proc('CATG', 'Cataloging', S.det, 960, 1150, 230, 70, 'Cataloging', 'type: from the extractor|uses: from Use Taxonomy');
node('UTAX', S.ctrl, 1220, 1140, 210, 90, 'Use Taxonomy', '29 uses: asking advice' + bar + 'plan' + bar + 'regret...|LM-tagged, reviewed|pipeline/jp/uses.json');
node('CAT', S.obj, 1220, 1260, 210, 110, 'Catalog Entry', 'type ' + dot + 'uses[] ' + dot + 'lesson?|title ' + dot + 'summary|search text ' + dot + 'open target');
edge('consume', 'A6', 'CATG', { exit: [1, 0.3], entry: [0, 0.5] });
edge('instr', 'UTAX', 'CATG', { exit: [0, 0.5], entry: [1, 0.4] });
edge('result', 'CATG', 'CAT', { exit: [0.5, 1], entry: [0, 0.5], pts: [[1075, 1315]] });

proc('PUB3', 'PublishingApp', S.det, 600, 1400, 280, 70, 'Publishing (app)', 'approved only + corrections|stale correction = fail');
node('CORR', S.ctrl, 960, 1420, 220, 70, 'Corrections', 'reviewed decisions|item + field + from + to + why');
node('ASSET', S.store, 590, 1510, 300, 80, 'App Lesson File', 'jp_grammar.json: lessons + catalog');
edge('consume', 'RV3', 'PUB3', { exit: [0.5, 1], entry: [0.5, 0], label: 'approved' });
edge('instr', 'CORR', 'PUB3', { exit: [0, 0.5], entry: [1, 0.5] });
edge('consume', 'CAT', 'PUB3', { exit: [0.5, 1], entry: [1, 0.15], pts: [[1325, 1410]] });
edge('result', 'PUB3', 'ASSET', { exit: [0.5, 1], entry: [0.5, 0] });

proc('FIND', 'Finding', S.det, 600, 1650, 280, 75, 'Finding', 'search the catalog ' + bar + 'sort by use, then type|runs in the app, no LM');
node('QRY', S.obj, 960, 1640, 240, 95, 'Query', 'text: str?|use: str?|type order: grammar, particle, numbers, pairs, conjugation, vocabulary');
node('LRN', S.ctrl, 1240, 1660, 180, 50, 'Learner', '');
node('RES', S.obj, 590, 1770, 300, 80, 'Result List', 'Catalog Entry[] across types|labeled type + lesson|tap opens the right screen');
edge('consume', 'ASSET', 'FIND', { exit: [0.5, 1], entry: [0.5, 0] });
edge('consume', 'QRY', 'FIND', { exit: [0, 0.5], entry: [1, 0.5] });
edge('agent', 'LRN', 'QRY', { exit: [0, 0.5], entry: [1, 0.5] });
edge('result', 'FIND', 'RES', { exit: [0.5, 1], entry: [0.5, 0] });

const p3 = page('SD3 &#8212; Structured Sources', 'opd-sd3', 1750, 1980);

/* ═══════════════ SD4 — Kanji Versions and Answer Checking ═══════════════ */
// Added 2026-10-25 (docs/plans/2026-10-24-japanese-typing-kanji-speaking.md). Every
// grammar sentence gets a kanji version behind a toggle; typed and spoken answers are
// checked in the app. Hiragana stays the default display.

raw('F4', S.frame, 330, 40, 1100, 1260, esc('<b>SD4 &#8212; Kanji Versions and Answer Checking</b> &#8212; a kanji twin for every Japanese field, an independent judge, and the checks the app runs on typed and spoken answers. Code: <i>pipeline/jp/</i> and the app.'));

node('GD', S.obj, 540, 80, 420, 95, 'Grammar Draft', 'drafts/L&lt;n&gt;.json: Lesson Draft + Grammar Practice Items|hiragana fields: example, prompt, answer, accepted, options');
proc('KD', 'KanjiDrafting', S.lm, 590, 215, 320, 70, 'Kanji Drafting', 'one twin per Japanese field|standard N4 kanji only');
node('KV', S.obj, 540, 325, 420, 115, 'Kanji Version', '_ruby twin: jp_ruby ' + dot + 'prompt_ruby ' + dot + 'answer_ruby|accepted_ruby[] ' + dot + 'options_ruby[] (parallel lists)|漢字{かんじ}: one bracket per kanji word|okurigana outside: 買{か}い物{もの}');
proc('KVAL', 'KanjiValidating', S.det, 380, 490, 300, 75, 'Kanji Validating', 'ruby.py: reading-of = hiragana, exactly|bracket base is kanji only');
proc('JUDG', 'Judging', S.lm, 820, 490, 300, 75, 'Judging', 'independent LM judge|review/judge_*.json');
node('VR4', S.obj, 380, 610, 300, 70, 'Validation Result', 'missing twin or reading mismatch = fail');
node('JF', S.obj, 820, 610, 300, 90, 'Judge Finding', 'point_id ' + dot + 'item_index|verdict ' + dot + 'fix|applied: bool');
proc('PUB4', 'PublishingApp', S.det, 600, 740, 300, 70, 'Publishing (app)', 'see SD3|carries the twins into the app file');
node('ASSET4', S.store, 570, 850, 360, 80, 'App Lesson File', 'jp_grammar.json|written only by publish.py');

proc('ACHK', 'AnswerChecking', S.det, 380, 1000, 300, 80, 'Answer Checking', 'in the app, no LM|hiragana, any accepted form,|or the kanji surface');
proc('SCHK', 'SpeechChecking', S.det, 820, 1000, 300, 80, 'Speech Checking', 'in the app, no LM|judge() with the kanji surface');
node('TA', S.obj, 40, 1000, 260, 80, 'Typed Answer', 'Japanese keyboard|hintLocales: ja-JP');
node('TR', S.obj, 1460, 1000, 260, 80, 'Transcript', 'speech recognition|often kanji, sometimes hiragana');
node('LRN4', S.ctrl, 40, 1130, 260, 50, 'Learner', '');
node('AV', S.obj, 380, 1130, 300, 80, 'Answer Verdict', 'correct' + bar + 'wrong|matched form');
node('SV', S.objTop, 780, 1120, 380, 140, 'Speech Verdict', 'heard text ' + dot + 'matched span');
node('SVa', S.state, 795, 1200, 100, 30, 'correct', '');
node('SVb', S.state + 'fillColor=#ffe599;', 905, 1200, 100, 30, 'close', '');
node('SVc', S.state, 1015, 1200, 130, 30, 'self-check', '');
node('G9', S.gap, 1460, 1120, 260, 130, 'RULE &#8212; never marked wrong', 'Close shows in amber with the matching part of the heard text highlighted, then self-check (PIN-10). A transcript that cannot be compared goes to self-check (PIN-2).');

edge('consume', 'GD', 'KD', { exit: [0.5, 1], entry: [0.5, 0] });
edge('result', 'KD', 'KV', { exit: [0.5, 1], entry: [0.5, 0] });
edge('consume', 'KV', 'KVAL', { exit: [0.25, 1], entry: [0.5, 0] });
edge('consume', 'KV', 'JUDG', { exit: [0.75, 1], entry: [0.5, 0] });
edge('consume', 'GD', 'JUDG', { exit: [1, 0.5], entry: [1, 0.5], pts: [[1180, 127], [1180, 527]] });
edge('result', 'KVAL', 'VR4', { exit: [0.5, 1], entry: [0.5, 0] });
edge('result', 'JUDG', 'JF', { exit: [0.5, 1], entry: [0.5, 0] });
edge('consume', 'VR4', 'PUB4', { exit: [0.5, 1], entry: [0, 0.5], pts: [[530, 775]], label: 'gate' });
edge('consume', 'JF', 'PUB4', { exit: [0.5, 1], entry: [1, 0.5], pts: [[970, 775]], label: 'every finding applied' });
edge('result', 'PUB4', 'ASSET4', { exit: [0.5, 1], entry: [0.5, 0] });
edge('consume', 'ASSET4', 'ACHK', { exit: [0.25, 1], entry: [0.5, 0] });
edge('consume', 'ASSET4', 'SCHK', { exit: [0.75, 1], entry: [0.5, 0] });
edge('consume', 'TA', 'ACHK', { exit: [1, 0.5], entry: [0, 0.5] });
edge('consume', 'TR', 'SCHK', { exit: [0, 0.5], entry: [1, 0.5] });
edge('agent', 'LRN4', 'ACHK', { exit: [1, 0.5], entry: [0, 0.8] });
edge('result', 'ACHK', 'AV', { exit: [0.5, 1], entry: [0.5, 0] });
edge('result', 'SCHK', 'SV', { exit: [0.5, 1], entry: [0.5, 0] });
edge('gapLink', 'G9', 'SV', { exit: [0, 0.5], entry: [1, 0.5] });
edge('invoke', 'KD', 'KVAL', { exit: [0, 0.5], entry: [0, 0.5], pts: [[360, 250], [360, 527]], label: 'async' });
edge('invoke', 'KD', 'JUDG', { exit: [1, 0.5], entry: [1, 0.3], pts: [[1150, 250], [1150, 512]], label: 'async' });

raw('LEG4', S.note, 40, 1320, 420, 190, LEGEND('<b>SD4 rule:</b> hiragana is the default display; the kanji version is shown only behind the &#28450;&#23383; toggle.'));

const p4 = page('SD4 &#8212; Kanji Versions and Answer Checking', 'opd-sd4', 1750, 1560);

fs.writeFileSync(OUT, `<mxfile host="app.diagrams.net">\n${p0}\n${p1}\n${p2}\n${p3}\n${p4}\n</mxfile>\n`);
console.log('wrote', OUT, fs.statSync(OUT).size, 'bytes');
