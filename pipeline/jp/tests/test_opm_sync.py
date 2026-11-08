"""Guard: the OPM stays in step with the code (PIN-12).

Four sources must agree on the set of pipeline stages:
- STAGE_IO in pipeline/extraction_schemas.py (the typed contract),
- the diagram generator docs/opm-lesson-extraction.gen.js and the .drawio it writes,
- the OPL sentences in docs/opm-lesson-extraction.md,
- the module registry pipeline/jp/stages.py (which code runs which stage).

Each process box in the generator names its STAGE_IO key through proc(), which writes
it into the cell style as opmStage=<key>. The test reads those keys back from the
committed .drawio, after proving the .drawio equals a fresh run of the generator.
"""

from __future__ import annotations

import html
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import pytest

JP = Path(__file__).resolve().parents[1]
REPO = JP.parents[1]
DOCS = REPO / "docs"
GEN = DOCS / "opm-lesson-extraction.gen.js"
DRAWIO = DOCS / "opm-lesson-extraction.drawio"
OPL = DOCS / "opm-lesson-extraction.md"

sys.path.insert(0, str(JP))
sys.path.insert(0, str(JP.parent))

import extraction_schemas as xs  # noqa: E402
import stages  # noqa: E402

# Process fill color in the generator -> STAGE_IO kind (see S.lm / S.lmZ / S.det / S.human).
FILL_KIND = {"#dae8fc": xs.LM, "#b8d4f5": xs.LM, "#f0f0f0": xs.DET, "#ffe6cc": xs.HUMAN}

# The stages this plan adds (docs/plans/2026-10-24-japanese-typing-kanji-speaking.md).
NEW_STAGES = {
    "KanjiDrafting": xs.LM,
    "KanjiValidating": xs.DET,
    "Judging": xs.LM,
    "AnswerChecking": xs.DET,
    "SpeechChecking": xs.DET,
}


def _style(style: str) -> dict[str, str]:
    return dict(p.split("=", 1) for p in style.split(";") if "=" in p)


def _processes(xml_text: str) -> list[tuple[str, str, str, str]]:
    """(page, cell id, opmStage or '', kind from fill) for every process ellipse."""
    out = []
    root = ET.fromstring(xml_text)
    for diagram in root.iter("diagram"):
        page = diagram.get("name", "")
        for cell in diagram.iter("mxCell"):
            style = cell.get("style") or ""
            if cell.get("vertex") != "1" or not style.startswith("ellipse;"):
                continue
            st = _style(style)
            out.append((page, cell.get("id"), st.get("opmStage", ""),
                        FILL_KIND.get(st.get("fillColor", ""), "?")))
    return out


def _opl_sentences(md: str) -> list[str]:
    """Every numbered sentence under an 'OPL sentences:' line, continuations joined."""
    sentences: list[str] = []
    inside = False
    for line in md.splitlines():
        if line.startswith("## "):
            inside = False
        elif line.strip() == "OPL sentences:":
            inside = True
        elif inside and re.match(r"\d+\. ", line):
            sentences.append(line)
        elif inside and sentences and line.startswith("   ") and line.strip():
            sentences[-1] += " " + line.strip()
    return sentences


@pytest.fixture(scope="module")
def drawio_text() -> str:
    return DRAWIO.read_text(encoding="utf-8").replace("\r\n", "\n")


@pytest.fixture(scope="module")
def procs(drawio_text) -> list[tuple[str, str, str, str]]:
    return _processes(drawio_text)


def test_drawio_is_a_fresh_run_of_the_generator(tmp_path, drawio_text):
    node = shutil.which("node")
    assert node, "node is required to check the diagram against its generator"
    out = tmp_path / "fresh.drawio"
    subprocess.run([node, str(GEN), str(out)], check=True, capture_output=True)
    fresh = out.read_text(encoding="utf-8").replace("\r\n", "\n")
    assert drawio_text == fresh, "run: node docs/opm-lesson-extraction.gen.js, then commit"


def test_plan_stages_are_in_stage_io():
    for stage, kind in NEW_STAGES.items():
        assert stage in xs.STAGE_IO, f"{stage} missing from STAGE_IO"
        assert xs.STAGE_IO[stage][0] == kind, f"{stage}: kind should be {kind}"


def _unnamed(procs: list[tuple[str, str, str, str]]) -> list[str]:
    """'page / cell id' of every process box that names no opmStage."""
    return [f"{page} / {cid}" for page, cid, stage, _ in procs if not stage]


def test_every_generator_process_names_a_stage_io_entry(procs):
    assert procs, "no process boxes found in the diagram"
    assert not _unnamed(procs), (
        f"process boxes with no opmStage (use proc() in the generator): {_unnamed(procs)}")
    for page, cid, stage, _ in procs:
        assert stage in xs.STAGE_IO, f"{page} / {cid}: {stage} is not a STAGE_IO stage"


def test_every_process_box_kind_matches_stage_io(procs):
    for page, cid, stage, kind in procs:
        assert kind == xs.STAGE_IO[stage][0], (
            f"{page} / {cid}: {stage} is drawn as {kind}, STAGE_IO says {xs.STAGE_IO[stage][0]}")


def test_every_stage_io_stage_has_a_process_box(procs):
    drawn = {stage for _, _, stage, _ in procs}
    missing = sorted(set(xs.STAGE_IO) - drawn)
    assert not missing, f"no process box in the generator for: {missing}"


def test_every_stage_has_an_opm_name():
    assert set(xs.OPM_NAMES) == set(xs.STAGE_IO)
    names = list(xs.OPM_NAMES.values())
    assert len(set(names)) == len(names), "two stages share one OPM name"


def test_every_stage_io_stage_has_an_opl_sentence():
    sentences = _opl_sentences(OPL.read_text(encoding="utf-8"))
    assert sentences, "no OPL sentences found"
    missing = [s for s, name in xs.OPM_NAMES.items()
               if not any(f"**{name}**" in sent for sent in sentences)]
    assert not missing, f"no OPL sentence names: {missing}"


def _modules_on_disk() -> set[str]:
    skip = {"tests", "fixtures", "out", "drafts", "__pycache__"}
    return {p.relative_to(JP).as_posix() for p in JP.rglob("*.py")
            if not skip & set(p.relative_to(JP).parts[:-1])}


def test_every_pipeline_module_is_registered_or_a_helper():
    on_disk = _modules_on_disk()
    assert "publish.py" in on_disk
    unregistered = sorted(on_disk - set(stages.STAGES) - set(stages.HELPERS))
    assert not unregistered, f"register these in pipeline/jp/stages.py: {unregistered}"


def test_registry_entries_exist_and_name_real_stages():
    on_disk = _modules_on_disk()
    assert not set(stages.STAGES) & set(stages.HELPERS), "a module is both stage and helper"
    for module, names in stages.STAGES.items():
        assert names, f"{module}: registers no stage"
        for s in names:
            assert s in xs.STAGE_IO, f"{module}: {s} is not a STAGE_IO stage"
        assert module in on_disk, f"{module}: no such file"
    for module in stages.HELPERS:
        assert module in on_disk, f"helper {module}: no such file"


def test_refresh_fixtures_is_a_helper_and_ruby_is_registered():
    assert "refresh_fixtures.py" in stages.HELPERS
    assert stages.STAGES.get("ruby.py") == ("KanjiValidating",)


def test_stage_graph_still_composes():
    xs._check()


def test_guard_catches_an_unregistered_process(procs):
    bad = ('<mxfile><diagram name="X"><mxGraphModel><root>'
           '<mxCell id="P" style="ellipse;fillColor=#f0f0f0;" vertex="1"/>'
           '</root></mxGraphModel></diagram></mxfile>')
    bad_procs = _processes(bad)
    assert bad_procs == [("X", "P", "", xs.DET)]
    assert _unnamed(bad_procs) == ["X / P"], "the guard must flag a box with no opmStage"
    assert _unnamed(procs) == [], "the committed diagram must pass the same guard"


# ───────────── plan 2026-11-06 (jp-tutor-loop), Task 10, PIN-8 ─────────────
# SD5 and SD6 draw the built tutor loop: the lesson link, the Discuss mark, the say cards
# scored by Azure and the modes. The lesson doc describes the same, and both point at the
# code for the numbers.

LESSON_DOC = DOCS / "japanese-lessons.md"
MASTERY_RULE = REPO / "lib/components/pages/quiet_room_mastery/mastery_rule.dart"

TUTOR_LOOP_STAGES = {
    "LessonReviewing": xs.HUMAN,
    "DiscussMarking": xs.HUMAN,
    "PronunciationScoring": xs.DET,
}


def _diagram(drawio_text: str, prefix: str) -> str:
    """The XML of the one diagram page whose name starts with [prefix]."""
    pages = re.findall(r'<diagram name="([^"]*)".*?</diagram>', drawio_text, flags=re.S)
    bodies = re.findall(r'<diagram name="[^"]*".*?</diagram>', drawio_text, flags=re.S)
    found = [b for n, b in zip(pages, bodies) if n.startswith(prefix)]
    assert len(found) == 1, f"expected one page named {prefix}..., got {pages}"
    return found[0]


def _cell_values(page_xml: str) -> list[str]:
    """The unescaped `value` (the drawn label) of every cell on one diagram page."""
    return [html.unescape(cell.get("value", ""))
            for cell in ET.fromstring(page_xml).iter("mxCell")]


def _opl_section(md: str, heading: str) -> str:
    """The text of the '## <heading>' section, up to the next '## '."""
    m = re.search(rf"^## {re.escape(heading)}\n(.*?)(?=^## )", md, flags=re.S | re.M)
    assert m, f"no '## {heading}' section"
    return m.group(1)


def _template_modes() -> dict[str, str]:
    """`kTemplateModes` in mastery_rule.dart: template name to mode (D18)."""
    body = re.search(r"kTemplateModes = \{(.*?)\};", MASTERY_RULE.read_text(encoding="utf-8"),
                     flags=re.S)
    assert body, "kTemplateModes not found in mastery_rule.dart"
    pairs = dict(re.findall(r"'(\w+)': ProbeMode\.(\w+)", body.group(1)))
    assert pairs, "kTemplateModes holds no entry"
    return pairs


def test_opm_tutor_loop_stages_are_in_stage_io():
    for stage, kind in TUTOR_LOOP_STAGES.items():
        assert stage in xs.STAGE_IO, f"{stage} missing from STAGE_IO"
        assert xs.STAGE_IO[stage][0] == kind, f"{stage}: kind should be {kind}"


def test_opm_discuss_mark_moves_no_grade_and_no_schedule():
    # PIN-6: a Discuss mark is read by no stage that grades, schedules, plans or judges.
    for stage in ("Grading", "Scheduling", "Planning", "MasteryJudging"):
        assert xs.DiscussMark not in xs.STAGE_IO[stage][1], f"{stage} reads the Discuss mark"
    assert xs.STAGE_IO["DiscussMarking"][2] == (xs.DiscussMark,)


def test_opm_counting_speech_is_scored_by_azure():
    # PIN-2: Grading reads the Azure verdict; the session's answers carry a recording.
    assert xs.PronunciationVerdict in xs.STAGE_IO["Grading"][1]
    assert xs.SpokenAnswer in xs.STAGE_IO["Answering"][2]
    assert {r.value for r in xs.PronunciationResult} == {"correct", "close", "wrong",
                                                         "unverified"}
    assert "spoken_close" in xs.StudyAttempt.model_fields


def test_opm_sd5_and_sd6_draw_nothing_planned(drawio_text):
    for prefix in ("SD5", "SD6"):
        page = _diagram(drawio_text, prefix)
        assert "PLANNED" not in page, f"{prefix} still draws a planned gap box"
        assert "strokeColor=#b85450" not in page, f"{prefix} still draws a red gap box"


def test_opm_sd5_and_sd6_opl_name_nothing_planned():
    md = OPL.read_text(encoding="utf-8")
    for heading in ("SD5 — Studying", "SD6 — Mastery Judging"):
        text = _opl_section(md, heading)
        assert not re.search(r"\bplanned\b", text, flags=re.I), f"{heading} still says planned"


def test_opm_sd6_records_the_close_rule_and_the_mode_table(drawio_text):
    sd6 = _opl_section(OPL.read_text(encoding="utf-8"), "SD6 — Mastery Judging")
    assert "PIN-10" in sd6 and "D18" in sd6
    # The cell values, not the raw page: a bare substring search would find `fill` in every
    # cell style's fillColor.
    labels = "\n".join(_cell_values(_diagram(drawio_text, "SD6")))
    for template in _template_modes():
        assert f"`{template}`" in sd6, f"SD6's OPL does not name the template {template}"
        assert re.search(rf"\b{re.escape(template)}\b", labels), \
            f"SD6's diagram does not name the template {template}"


def test_opm_lesson_doc_describes_the_tutor_loop():
    doc = LESSON_DOC.read_text(encoding="utf-8")
    low = doc.lower()
    for phrase in ("discuss with mari", "review the lesson", "say card", "type it", "see it",
                   "say it", "lesson reviewed", "practice listens, not counted"):
        assert phrase in low, f"the lesson doc does not describe: {phrase}"
    # De-mirror: the numbers stay in the code and the data files.
    for pointer in ("mastery_rule.dart", "kTemplateModes", "kTransferProbes", "kMoveOnClearDays",
                    "particle_sentences.json", "discuss_list_widget.dart"):
        assert pointer in doc, f"the lesson doc does not point at {pointer}"
    # ASK-3: an unverified spoken check after the reveal is wrong, so no grade row says
    # unscored is never wrong without saying so.
    row = next(line for line in doc.splitlines() if line.startswith("| unscored |"))
    assert "never wrong" not in row, f"the grades table still says: {row}"
    for ask in ("ASK-1", "ASK-2", "ASK-3", "ASK-4", "ASK-5"):
        assert f"plan 2026-11-06, {ask})" in doc, f"the lesson doc does not cite {ask}"
