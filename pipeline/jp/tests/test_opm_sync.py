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
        assert module in on_disk or module in stages.PENDING, f"{module}: no such file"
    for module in stages.HELPERS:
        assert module in on_disk, f"helper {module}: no such file"
    assert stages.PENDING <= set(stages.STAGES)


def test_refresh_fixtures_is_a_helper_and_ruby_is_pre_registered():
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
