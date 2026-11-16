#!/usr/bin/env python3
"""Apply one batch of longer reading cards, in order, and record it.

Each lesson's three reading cards grow by 15 to 20 words so the app can set
them large and still fill the card (see content/STYLE.md). A batch file in
content/fill-batches/ lists, for each day:

    {"day": 29,
     "meaning": "Words added after the card's last sentence.",
     "heart": "Words added before the card's closing small step.",
     "prayer": "Words added before the final Amen.",
     "heartBefore": "optional: the start of the sentence to insert before"}

Days continue the sequence from content/fill.json, at most 28 at a time.
Scripture, titles and references are never touched. After applying, run the
validators and build the catalog, as STYLE.md says.

  python3 tool/fill_batch.py content/fill-batches/001-028.json
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "content/lessons_v2.json"
FILL = ROOT / "content/fill.json"
STEP_STARTS = ("Today", "Tonight", "This morning", "This week", "Before")


def sentence_starts(text: str) -> list[int]:
    return [0] + [m.end() for m in re.finditer(r"(?<=[.!?])\s+(?=[A-Z“‘])", text)]


def insert_before_step(heart: str, addition: str, anchor: str | None) -> str:
    """Puts [addition] before the heart card's closing small step."""
    if anchor:
        at = heart.index(anchor)
    else:
        starts = sentence_starts(heart)
        steps = [i for i in starts if heart[i:].startswith(STEP_STARTS)]
        at = steps[-1] if steps else starts[-1]
    return heart[:at] + addition.strip() + " " + heart[at:]


def main() -> int:
    cli = argparse.ArgumentParser(description=__doc__,
                                  formatter_class=argparse.RawDescriptionHelpFormatter)
    cli.add_argument("batch", type=Path)
    args = cli.parse_args()
    batch = json.loads(args.batch.read_text(encoding="utf-8"))
    lessons = json.loads(CONTENT.read_text(encoding="utf-8"))
    fill = json.loads(FILL.read_text()) if FILL.exists() else {"days": []}
    start = max(fill["days"], default=0) + 1
    days = [entry["day"] for entry in batch]
    if not 1 <= len(batch) <= 28 or days != list(range(start, start + len(batch))):
        raise SystemExit(f"A batch continues from Day {start}, in order, at most 28 days.")
    for entry in batch:
        extra = set(entry) - {"day", "meaning", "heart", "prayer", "heartBefore"}
        if extra:
            raise SystemExit(f"Day {entry['day']}: only reading cards change, not {sorted(extra)}.")
        lesson = lessons[entry["day"] - 1]
        before = {k: lesson[k] for k in ("verse", "reference", "title", "theme")}
        lesson["meaning"] = lesson["meaning"].rstrip() + " " + entry["meaning"].strip()
        lesson["heart"] = insert_before_step(lesson["heart"], entry["heart"], entry.get("heartBefore"))
        prayer = lesson["prayer"].rstrip()
        if not prayer.endswith("Amen."):
            raise SystemExit(f"Day {entry['day']}: the prayer must end with Amen.")
        lesson["prayer"] = prayer[: -len("Amen.")].rstrip() + " " + entry["prayer"].strip() + " Amen."
        assert before == {k: lesson[k] for k in before}, "Scripture and identity are untouched"
    CONTENT.write_text(json.dumps(lessons, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    fill["days"] = sorted(set(fill["days"]) | set(days))
    FILL.write_text(json.dumps(fill, indent=1) + "\n")
    print(f"Filled Days {days[0]}–{days[-1]}. Now run the validators and build the catalog.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
