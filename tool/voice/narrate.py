#!/usr/bin/env python3
"""Narrate HolyHim's lessons with Kokoro, offline on this Mac.

Each lesson becomes one AAC file, assets/audio/lessons/day-NNN.m4a, with a
cue where each of its four cards begins. The cues are written to
assets/audio/lessons/manifest.json:

    {"voice": "af_heart", "speed": 0.9, "quality": "compact",
     "lessons": {"1": {"file": "day-001.m4a", "seconds": 152.4,
                       "cues": [0.0, 31.2, 70.1, 112.8], "text": "<hash>"}}}

Only lessons whose spoken words, voice or settings changed are read again.
Kokoro (Apache 2.0) runs in Codellion Studio's own environment; nothing
leaves the Mac. Lesson text comes from content/lessons_v2.json, the source of
truth.

  python3 tool/voice/narrate.py samples [--day 1]        Day 1 in three voices and two qualities
  python3 tool/voice/narrate.py build [--from 1] [--to 365] --voice af_heart --quality compact
  python3 tool/voice/narrate.py check                     every lesson has current audio of a sane length
  python3 tool/voice/narrate.py script --day 1            what would be read, with its pauses
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
LESSONS = ROOT / "content/lessons_v2.json"
OUT = ROOT / "assets/audio/lessons"
MANIFEST = OUT / "manifest.json"
SAMPLES = ROOT / "store/voice-samples"
STUDIO = Path("/Users/amir/Downloads/Cognein - Assets & Marketing/Cognein_Ads/Codellion_Studio")
KOKORO_PY = STUDIO / "tools/voice/venv/bin/python"
MODELS = STUDIO / "tools/voice/models"

# A devotional pace: slower than the studio's shorts (190-230 wpm), close to
# someone reading aloud to a friend.
SPEED = 0.9
# A reading pace that sounds unhurried. Lessons with many short words read a
# little faster at the same speed (Day 176 is 176), so the ceiling has room.
WPM_RANGE = (115, 180)

# Pauses, in seconds, after each kind of segment.
PAUSE_TITLE = 1.0
PAUSE_HEADING = 0.55
PAUSE_SENTENCE = 0.42
PAUSE_REFERENCE = 1.3
PAUSE_CARD = 1.35
TAIL = 0.8

QUALITIES = {
    # Speech at a size that suits 365 lessons inside the app.
    # Profile 4 is HE-AAC (aac_he) in AudioToolbox's numbering.
    "compact": ["-c:a", "aac_at", "-profile:a", "4", "-b:a", "24k"],
    # Fuller, about twice the size.
    "clear": ["-c:a", "aac_at", "-b:a", "48k"],
}
SAMPLE_VOICES = ["af_heart", "af_bella", "bf_emma"]

ONES = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
        "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen"]
TENS = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]
ORDINAL_BOOK = {"1": "First", "2": "Second", "3": "Third"}


def number_words(n: int) -> str:
    """Cardinal words up to 999, as Scripture references need."""
    if n < 20:
        return ONES[n]
    if n < 100:
        return TENS[n // 10] + ("" if n % 10 == 0 else "-" + ONES[n % 10])
    rest = n % 100
    return ONES[n // 100] + " hundred" + ("" if rest == 0 else " " + number_words(rest))


def spoken_reference(reference: str) -> str:
    """'1 Samuel 1:10' -> 'First Samuel, chapter one, verse ten'.

    A Psalm is named with its number ('Psalm forty-six, verse one'); every
    other book names its chapter. A range is 'verses five to six'.
    """
    m = re.fullmatch(r"(?:(\d) )?([A-Za-z][A-Za-z ]*?) (\d+):(\d+)(?:-(\d+))?", reference.strip())
    if not m:
        raise ValueError(f"Unreadable reference: {reference!r}")
    order, book, chapter, first, last = m.groups()
    name = f"{ORDINAL_BOOK[order]} {book}" if order else book
    verses = (f"verses {number_words(int(first))} to {number_words(int(last))}" if last
              else f"verse {number_words(int(first))}")
    if book == "Psalm":
        return f"Psalm {number_words(int(chapter))}, {verses}"
    return f"{name}, chapter {number_words(int(chapter))}, {verses}"


def clean(text: str) -> str:
    """What a reader would say, with what a machine misreads put right."""
    t = text
    # Small capitals in the World English Bible: the LORD is read 'Lord'.
    t = re.sub(r"\bLORD\b", "Lord", t)
    t = re.sub(r"\bGOD\b", "God", t)
    t = re.sub(r"\bTV\b", "T V", t)
    # Curly apostrophes inside words become plain ones; quotation marks are
    # not spoken, and an excerpt can leave one unbalanced.
    t = re.sub(r"(?<=\w)[’'](?=\w)", "'", t)
    t = re.sub(r"[“”\"‘’]", "", t)
    t = re.sub(r"(?<!\w)'|'(?!\w)", "", t)
    t = t.replace("—", ", ").replace("–", ", ").replace("…", "...")
    t = re.sub(r"\s+,", ",", t)
    t = re.sub(r"\s{2,}", " ", t).strip()
    if t and t[-1] not in ".!?":
        t += "."
    return t


def sentences(text: str) -> list[str]:
    parts = re.split(r"(?<=[.!?])\s+(?=[A-Z0-9])", clean(text))
    return [p.strip() for p in parts if p.strip()]


def script(lesson: dict) -> list[list[tuple[str, float]]]:
    """The four cards as spoken segments, each with the pause that follows."""
    day = int(lesson["day"])

    def card(heading: str | None, body: str, ending: float) -> list[tuple[str, float]]:
        segs = [(heading, PAUSE_HEADING)] if heading else []
        lines = sentences(body)
        segs += [(s, PAUSE_SENTENCE) for s in lines]
        segs[-1] = (segs[-1][0], ending)
        return segs

    first = [(f"Day {number_words(day)}. {clean(lesson['title'])}", PAUSE_TITLE),
             ("Today's word.", PAUSE_HEADING)]
    first += [(s, PAUSE_SENTENCE) for s in sentences(lesson["verse"])]
    first[-1] = (first[-1][0], PAUSE_SENTENCE + .1)
    first.append((spoken_reference(lesson["reference"]) + ".", PAUSE_REFERENCE))
    return [
        first,
        card("What it means.", lesson["meaning"], PAUSE_CARD),
        card("For your heart.", lesson["heart"], PAUSE_CARD),
        card("Let us pray.", lesson["prayer"], TAIL),
    ]


def words(cards: list[list[tuple[str, float]]]) -> int:
    return sum(len(text.split()) for segs in cards for text, _ in segs)


def text_hash(cards, voice: str, speed: float, quality: str) -> str:
    payload = json.dumps({"cards": cards, "voice": voice, "speed": speed, "quality": quality},
                         ensure_ascii=False, sort_keys=True)
    return hashlib.sha1(payload.encode()).hexdigest()[:16]


def load_lessons() -> list[dict]:
    return json.loads(LESSONS.read_text(encoding="utf-8"))


# ---------------------------------------------------------------- Kokoro side

def synth_worker(job_path: str) -> None:
    """Runs inside the Kokoro venv: one model load, many lessons."""
    import numpy as np
    import soundfile as sf
    from kokoro_onnx import Kokoro

    job = json.loads(Path(job_path).read_text(encoding="utf-8"))
    model = MODELS / "kokoro-v1.0.onnx"
    tts = Kokoro(str(model), str(MODELS / "voices-v1.0.bin"))

    def trim(x, sr, floor_db=-44, pad=0.025):
        frame = int(sr * 0.01)
        env = np.array([np.sqrt(np.mean(x[i:i + frame] ** 2) + 1e-12) for i in range(0, len(x), frame)])
        loud = np.where(20 * np.log10(env + 1e-9) > floor_db)[0]
        if len(loud) == 0:
            return x[:0]
        a = max(0, loud[0] * frame - int(pad * sr))
        b = min(len(x), (loud[-1] + 1) * frame + int(pad * sr))
        return x[a:b]

    for item in job["lessons"]:
        parts, cues, t, sr = [], [], 0.0, 24000
        for card in item["cards"]:
            cues.append(round(t, 3))
            for text, pause in card:
                audio, sr = tts.create(text, voice=job["voice"], speed=job["speed"], lang=job["lang"])
                audio = trim(audio.astype(np.float32), sr)
                parts += [audio, np.zeros(int(pause * sr), np.float32)]
                t += len(audio) / sr + pause
        sf.write(item["wav"], np.concatenate(parts), sr)
        Path(item["cues"]).write_text(json.dumps({"cues": cues, "seconds": round(t, 3)}))
        print(f"  read Day {item['day']}: {t:.1f} s", flush=True)


# ------------------------------------------------------------- orchestration

def kokoro(lessons: list[dict], voice: str, speed: float, work: Path) -> dict[int, dict]:
    """Synthesizes [lessons] to WAV in [work]; returns each day's cues."""
    if not KOKORO_PY.exists():
        sys.exit(f"Kokoro's environment is missing: {KOKORO_PY}")
    lang = "en-gb" if voice.startswith("b") else "en-us"
    items = [{"day": int(l["day"]), "cards": script(l),
              "wav": str(work / f"day-{int(l['day']):03d}.wav"),
              "cues": str(work / f"day-{int(l['day']):03d}.json")} for l in lessons]
    job = work / "job.json"
    job.write_text(json.dumps({"voice": voice, "speed": speed, "lang": lang, "lessons": items},
                              ensure_ascii=False))
    subprocess.run([str(KOKORO_PY), "-I", str(Path(__file__).resolve()), "_synth", str(job)],
                   check=True, env=dict(os.environ, PYTHONUNBUFFERED="1"))
    return {i["day"]: json.loads(Path(i["cues"]).read_text()) for i in items}


def encode(wav: Path, out: Path, quality: str) -> None:
    """Loudness to -18 LUFS (speech), peaks under -1.5 dBTP, then AAC."""
    out.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(wav),
                    "-af", "loudnorm=I=-18:TP=-1.5:LRA=11", "-ar", "24000", "-ac", "1",
                    *QUALITIES[quality], "-movflags", "+faststart", str(out)], check=True)


def duration(path: Path) -> float:
    probe = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                            "-of", "default=nw=1:nk=1", str(path)], capture_output=True, text=True, check=True)
    return float(probe.stdout.strip())


def cmd_script(args) -> None:
    lesson = load_lessons()[args.day - 1]
    for i, card in enumerate(script(lesson)):
        print(f"--- card {i + 1}")
        for text, pause in card:
            print(f"{text}   [{pause:.2f} s]")
    print(f"\n{words(script(lesson))} words")


def cmd_samples(args) -> None:
    lesson = load_lessons()[args.day - 1]
    SAMPLES.mkdir(parents=True, exist_ok=True)
    report = []
    with tempfile.TemporaryDirectory(prefix="holyhim-voice-") as tmp:
        for voice in args.voices.split(","):
            work = Path(tmp) / voice
            work.mkdir()
            cues = kokoro([lesson], voice, args.speed, work)[int(lesson["day"])]
            wav = work / f"day-{int(lesson['day']):03d}.wav"
            for quality in QUALITIES:
                out = SAMPLES / f"day-{int(lesson['day']):03d}-{voice}-{quality}.m4a"
                encode(wav, out, quality)
                report.append({"voice": voice, "quality": quality, "file": str(out.relative_to(ROOT)),
                               "seconds": round(duration(out), 1), "kb": out.stat().st_size // 1024,
                               "wpm": round(words(script(lesson)) / cues["seconds"] * 60)})
    (SAMPLES / "samples.json").write_text(json.dumps(report, indent=1))
    for r in report:
        print(f"{r['file']}: {r['seconds']} s, {r['kb']} KB, {r['wpm']} wpm")


def cmd_build(args) -> None:
    lessons = load_lessons()
    manifest = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {"lessons": {}}
    manifest.update(voice=args.voice, speed=args.speed, quality=args.quality)
    wanted = [l for l in lessons if args.start <= int(l["day"]) <= args.end]
    stale = []
    for l in wanted:
        entry = manifest["lessons"].get(str(l["day"]))
        current = text_hash(script(l), args.voice, args.speed, args.quality)
        if not entry or entry.get("text") != current or not (OUT / entry["file"]).exists():
            stale.append(l)
    print(f"{len(stale)} of {len(wanted)} lessons need reading.")
    batch = 10
    for i in range(0, len(stale), batch):
        group = stale[i:i + batch]
        with tempfile.TemporaryDirectory(prefix="holyhim-voice-") as tmp:
            work = Path(tmp)
            cues = kokoro(group, args.voice, args.speed, work)
            for l in group:
                day = int(l["day"])
                name = f"day-{day:03d}.m4a"
                encode(work / f"day-{day:03d}.wav", OUT / name, args.quality)
                manifest["lessons"][str(day)] = {
                    "file": name, "seconds": cues[day]["seconds"], "cues": cues[day]["cues"],
                    "text": text_hash(script(l), args.voice, args.speed, args.quality)}
        MANIFEST.write_text(json.dumps(manifest, indent=1, sort_keys=True))
    print(f"Manifest: {MANIFEST.relative_to(ROOT)}")


def cmd_check(args) -> int:
    lessons = load_lessons()
    if not MANIFEST.exists():
        print("No narration yet.")
        return 1
    manifest = json.loads(MANIFEST.read_text())
    problems = []
    for l in lessons:
        day = str(l["day"])
        entry = manifest["lessons"].get(day)
        if not entry:
            problems.append(f"Day {day}: not read")
            continue
        path = OUT / entry["file"]
        if not path.exists():
            problems.append(f"Day {day}: {entry['file']} is missing")
            continue
        if entry["text"] != text_hash(script(l), manifest["voice"], manifest["speed"], manifest["quality"]):
            problems.append(f"Day {day}: the lesson changed since it was read")
        seconds = duration(path)
        wpm = words(script(l)) / seconds * 60
        if not WPM_RANGE[0] <= wpm <= WPM_RANGE[1]:
            problems.append(f"Day {day}: {wpm:.0f} words a minute is outside {WPM_RANGE}")
        cues = entry["cues"]
        if len(cues) != 4 or cues != sorted(cues) or cues[-1] >= seconds:
            problems.append(f"Day {day}: cues {cues} do not fit {seconds:.1f} s")
    for p in problems:
        print(p)
    total = sum(p.stat().st_size for p in OUT.glob("*.m4a"))
    print(f"{len(lessons) - len(problems)} lessons fine, {len(problems)} problems, {total / 1e6:.1f} MB of audio.")
    return 1 if problems else 0


def main(argv: list[str] | None = None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    if argv[:1] == ["_synth"]:
        synth_worker(argv[1])
        return 0
    cli = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = cli.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("script")
    s.add_argument("--day", type=int, default=1)
    s = sub.add_parser("samples")
    s.add_argument("--day", type=int, default=1)
    s.add_argument("--voices", default=",".join(SAMPLE_VOICES))
    s.add_argument("--speed", type=float, default=SPEED)
    s = sub.add_parser("build")
    s.add_argument("--from", dest="start", type=int, default=1)
    s.add_argument("--to", dest="end", type=int, default=365)
    s.add_argument("--voice", required=True)
    s.add_argument("--quality", choices=sorted(QUALITIES), default="compact")
    s.add_argument("--speed", type=float, default=SPEED)
    sub.add_parser("check")
    args = cli.parse_args(argv)
    if args.cmd in ("samples", "build") and not shutil.which("ffmpeg"):
        sys.exit("ffmpeg is required (brew install ffmpeg).")
    return {"script": cmd_script, "samples": cmd_samples, "build": cmd_build,
            "check": cmd_check}[args.cmd](args) or 0


if __name__ == "__main__":
    sys.exit(main())
