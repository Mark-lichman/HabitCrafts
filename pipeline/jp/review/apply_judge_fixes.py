"""Apply the reviewed judge findings (judge_*.json) to the drafts and uses.json.
Approved by Mark on 2026-10-24. Run once: python review/apply_judge_fixes.py

Each fix is explicit here, not parsed from the judges' free text, so the change to
every draft is reviewable in one diff. Re-running is safe: each edit checks first.
"""

from __future__ import annotations

import json
from pathlib import Path

JP = Path(__file__).resolve().parents[1]


def lesson(pid: str) -> int:
    return int(pid.split(".")[1][1:])


def point(drafts: dict, pid: str) -> dict:
    return next(p for p in drafts[lesson(pid)]["points"] if p["id"] == pid)


def add_accepted(drafts, pid, i, *more):
    q = point(drafts, pid)["practice"][i]
    acc = q.setdefault("accepted", [])
    for m in more:
        if m not in acc and m != q["answer"]:
            acc.append(m)


def set_why_wrong(drafts, pid, i, key_part, text):
    ww = point(drafts, pid)["practice"][i]["why_wrong"]
    key = next(k for k in ww if key_part in k)
    ww[key] = text


def main() -> None:
    files = {int(f.stem[1:]): f for f in (JP / "drafts").glob("L*.json")}
    drafts = {n: json.loads(f.read_text(encoding="utf-8")) for n, f in files.items()}

    # Correct answers that were not accepted (a learner would be marked wrong).
    add_accepted(drafts, "mari.L27.5", 0, "すきじゃないです", "すきではないです",
                 "すきじゃありません", "すきではありません")
    add_accepted(drafts, "mari.L33.4", 0, "いいました")
    add_accepted(drafts, "mari.L34.1", 0, "ように")
    add_accepted(drafts, "mari.L37.2", 0, "から")
    add_accepted(drafts, "mari.L40.2", 0, "か")
    add_accepted(drafts, "mari.L42.1", 0, "ため")
    add_accepted(drafts, "mari.L49.3", 0, "おいでに なります", "おこしに なります",
                 "みえます", "おみえに なります")

    # Explanations that stated a wrong rule.
    set_why_wrong(drafts, "mari.L27.4", 3, "だけ",
                  "With ありません, だけ means only that part is missing. To say 'only', use しか.")
    set_why_wrong(drafts, "mari.L45.2", 2, "ために",
                  "ために gives a purpose or cause. It cannot show an unexpected result.")
    point(drafts, "mari.L30.3")["explain"] = (
        "ておきます can also mean leaving something as it is, or getting a task done so it "
        "is taken care of. Ask someone to leave things as they are with ておいて ください.")
    point(drafts, "mari.L50.3")["note"] = (
        "ございます (exists) is for things. For a person who is there, use いらっしゃいます "
        "or おります. でございます is fine when you name yourself.")

    for n, f in files.items():
        f.write_text(json.dumps(drafts[n], ensure_ascii=False, indent=2), encoding="utf-8")

    # Use tags.
    up = JP / "uses.json"
    uses = json.loads(up.read_text(encoding="utf-8"))
    if not any(u["id"] == "meaning" for u in uses["uses"]):
        uses["uses"].insert(len(uses["uses"]) - 1,
                            {"id": "meaning", "label": "Explaining what something means"})
    pts = uses["points"]
    pts["mari.L30.3"] = ["request", "state"]
    pts["mari.L33.3"] = ["meaning"]
    pts["mari.L38.5"] = ["certain"]
    pts["mari.L44.1"] = ["regret", "opinion", "emphasis"]
    pts["mari.L46.3"] = ["certain", "guess"]
    up.write_text(json.dumps(uses, ensure_ascii=False, indent=1), encoding="utf-8")
    print("applied 11 fixes and 5 tag changes")


if __name__ == "__main__":
    main()
