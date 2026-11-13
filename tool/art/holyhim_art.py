#!/usr/bin/env python3
"""HolyHim's resumable Gemini art workshop. Never writes credentials to disk.

Start with `plan --dry-run`, generate Day 1 anchors, review an anchor, then
produce and approve batches. Every paid request is an explicit generate command.
"""
from __future__ import annotations

import argparse
import base64
import concurrent.futures
import hashlib
import html
import io
import json
import mimetypes
import os
from pathlib import Path
import random
import re
import shutil
import sys
import threading
import time
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "art"
MANIFEST = ART / "manifest.json"
DEFAULT_MODEL = "gemini-3-pro-image"
FALLBACK_MODEL = "gemini-3-pro-image-preview"
DOCS = "https://ai.google.dev/gemini-api/docs/models/gemini-3-pro-image"
LOCK = threading.Lock()

MOTIFS = [
    "a small almond blossom on cream linen", "pearl beads beside a still pool",
    "pale pink cherry blossom reflected in water", "a single white rose with dew",
    "morning mist over calm blush water", "a peony opening in window light",
    "a soft fold of ivory linen", "a branch of white magnolia",
    "a pale garden rose floating on water", "delicate baby's breath on warm stone",
    "a tiny olive branch and pearl", "a translucent glass vase with a wildflower",
    "light ripples across pale sand", "a silver-pink dawn cloud",
    "a white lily beside still water", "a pale camellia in morning light",
    "a soft peach horizon over the sea", "a rose quartz pebble in a stream",
    "pink cosmos reaching into light", "a seashell resting on ivory silk",
    "a white feather resting on blush linen", "a tiny spring bud on a branch",
    "a petal trail on warm cream stone", "a wild daisy beside a gentle stream",
    "a pale flowering apple branch", "glittering dew on a soft green leaf",
    "a shallow porcelain bowl with petals", "a white anemone with a warm center",
    "mist drifting over a sunlit meadow", "a blush dahlia against pale plaster",
    "a single pearl on a folded ribbon", "a sunlit corner of a walled garden",
    "soft pink hydrangea near an open window", "the lightest peach sky over hills",
    "a fern frond beside flowing water", "white jasmine on cream cotton",
    "a few tiny snowdrops at dawn", "a white tulip in a porcelain vessel",
    "a camellia petal on a quiet pond", "blush ranunculus in clear morning light",
    "a sandy path between soft grasses", "a pale pink water lily",
    "sunlight through gauzy ivory curtains", "a rosebud beside an old stone step",
    "a white orchid over warm linen", "a quiet cove at peach-colored dawn",
    "a soft pink sweet pea climbing a thread", "a cluster of cream roses",
    "one pale leaf carried by a stream", "a small clay vessel beside white blossoms",
    "a white garden gate in morning haze", "silvery light on a calm lake",
    "a pale pink iris beside a window", "a ribbon curled on pearl-white silk",
    "a flowering dogwood branch", "a sunlit patch of moss and tiny flowers",
    "white freesia in a clear glass", "a soft blush sky reflected in a porcelain cup",
    "small white flowers on a weathered garden wall", "a peach rose beside still water",
]
LIGHTS = ["diffused dawn through a sheer curtain", "a soft north-facing morning window",
          "overcast garden light with a silver rim", "gentle golden sunrise reflected off water",
          "pale high-key studio daylight", "a quiet peach morning haze"]
COMPOSITIONS = ["the motif in the lower right with a slight diagonal", "the motif low at center, delicate and small",
                "a cropped motif along the lower left edge", "a layered motif at the bottom with a very soft reflection",
                "a single motif low in the frame with generous quiet space", "an off-center motif near the lower third"]
BADGES = [(f"days-{n:03}", f"{n} days", n) for n in [1,3,7,14,21,30,50,75,100,150,200,250,300,365]] + [
    ("streak-007","A Faithful Week",7),("streak-030","A Steady Month",30),
    ("streak-100","Rooted in Faith",100),("first-saved","A Word to Keep",1),
    ("promise-kept","Your Promise Kept",7)]
SCENES = ["welcome-peace","welcome-minute","welcome-growth","onboarding-heart",
          "onboarding-promise","saved-empty","growth-empty","celebration"]
STYLE = (
    "HolyHim visual family: airy high-key white and blush pink, whispers of peach, "
    "refined photographic-painterly realism, soft morning light, tactile linen and porcelain, "
    "subtle rose-gold glints, restrained editorial luxury. No text, letters, numbers, "
    "people, faces, hands, logos or watermarks. No dark muddy mauve."
)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read_manifest() -> dict:
    if MANIFEST.exists():
        return json.loads(MANIFEST.read_text())
    return {"version": 2, "style": None, "items": {}}


def save_manifest(manifest: dict) -> None:
    ART.mkdir(exist_ok=True)
    temp = MANIFEST.with_suffix(".tmp")
    temp.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    temp.replace(MANIFEST)


def selected_numbers(raw: str | None, maximum: int) -> set[int]:
    if not raw:
        return set(range(1, maximum + 1))
    result = set()
    for section in raw.split(","):
        if not re.fullmatch(r"\d+(?:-\d+)?", section.strip()):
            raise ValueError("Ranges use numbers such as 1-5,8,12-14.")
        parts = [int(s) for s in section.strip().split("-")]
        lo, hi = parts[0], parts[-1]
        if lo < 1 or hi > maximum or hi < lo:
            raise ValueError(f"Range must stay between 1 and {maximum}.")
        result.update(range(lo, hi + 1))
    return result


def inventory() -> list[dict]:
    lessons = json.loads((ROOT / "content/lessons_v2.json").read_text())
    if len(lessons) != 365:
        raise ValueError("Art planning requires exactly 365 lessons.")
    items = []
    for lesson in lessons:
        day = lesson["day"]
        verse = lesson["verse"].lower()
        motif = MOTIFS[(day * 17) % len(MOTIFS)]
        for image_word, preferred in [("water",4),("light",42),("refuge",31),("grow",21),
                                      ("path",40),("pearl",10),("flower",29),("olive",10)]:
            if image_word in verse:
                motif = MOTIFS[(preferred + day % 3) % len(MOTIFS)]
                break
        prompt = (f"{STYLE} Portrait 9:16 devotional background. Theme: {lesson['theme']}; "
                  f"scriptural imagery from {lesson['reference']}. Motif: {motif}. "
                  f"Lighting: {LIGHTS[(day-1)%6]}. Composition: {COMPOSITIONS[(day//6)%6]}. "
                  "The top 55 percent is nearly empty, very light, gently graduated negative space "
                  "for dark reading text. Keep all visual weight in the lower part. "
                  f"Distinct composition variation {day}: use a fresh petal arrangement and focus depth.")
        items.append({"id":f"lessons/day-{day:03}","kind":"lessons","number":day,
                      "title":lesson["title"],"prompt":prompt,"aspectRatio":"9:16"})
    for n, (key,title,goal) in enumerate(BADGES, 1):
        prompt = (f"{STYLE} Single glossy 3D porcelain and rose-gold circular award medallion, "
                  f"inspired by this achievement: {title}. Sculpted icon and two delicate laurel branches; "
                  f"choose a distinct symbolic relief, variation {n}, with no text or digits. "
                  "Front three-quarter view, highly tactile ceramic, tiny metallic rim highlights. "
                  "Centered entire object with generous margin. Flat pure chroma green #00FF00 background, "
                  "uniform and completely unlit, no cast shadows on the green. Square 1:1 composition.")
        items.append({"id":f"badges/{key}","kind":"badges","number":n,
                      "title":title,"prompt":prompt,"aspectRatio":"1:1","goal":goal})
    for n, key in enumerate(SCENES,1):
        prompt = (f"{STYLE} Portrait 9:16 cinematic atmosphere for {key.replace('-',' ')}. "
                  f"Motif: {MOTIFS[(n*7)%60]}. Lighting: {LIGHTS[n%6]}. "
                  "The top 55 percent is nearly empty and very light for dark text. "
                  "Gentle depth of field, soft drifting petals near the lower corners, no letters or people.")
        items.append({"id":f"scenes/{key}","kind":"scenes","number":n,"title":key.replace('-',' ').title(),
                      "prompt":prompt,"aspectRatio":"9:16"})
    return items


def choose(args) -> list[dict]:
    all_items = inventory()
    kinds = [args.kind] if args.kind != "all" else ["lessons","badges","scenes"]
    chosen = []
    for kind in kinds:
        group = [x for x in all_items if x["kind"]==kind]
        nums = selected_numbers(args.range, len(group))
        chosen.extend(x for x in group if x["number"] in nums)
    return chosen


def prompt_hash(item: dict, model: str, style_sha: str = "") -> str:
    return sha(json.dumps({"prompt":item["prompt"],"model":model,"style":style_sha,
                           "aspectRatio":item["aspectRatio"],"imageSize":"2K"},sort_keys=True).encode())


def plan(args) -> int:
    items = choose(args)
    summary = {kind:sum(x["kind"]==kind for x in items) for kind in ["lessons","badges","scenes"]}
    print(json.dumps({"images":len(items),"counts":summary,"model":args.model,
                      "paidRequests":0,"dryRun":args.dry_run,"docs":DOCS},indent=2))
    if not args.dry_run:
        ART.mkdir(exist_ok=True)
        (ART / "plan.json").write_text(json.dumps(items,ensure_ascii=False,indent=2)+"\n")
    return 0


class GenerationError(Exception):
    def __init__(self, code: int):
        self.code = code
        super().__init__(f"Image service returned HTTP {code}.")


def request_image(item: dict, model: str, key: str, style: Path | None) -> tuple[bytes,str]:
    parts = [{"text":item["prompt"]}]
    if style:
        mime=mimetypes.guess_type(style.name)[0] or "image/png"
        parts.append({"inlineData":{"mimeType":mime,"data":base64.b64encode(style.read_bytes()).decode()}})
        parts.append({"text":"Use this approved image as the visual style reference; preserve its palette and light, while creating the new motif."})
    body={"contents":[{"role":"user","parts":parts}],"generationConfig":{
        "responseModalities":["TEXT","IMAGE"],"imageConfig":{"aspectRatio":item["aspectRatio"],"imageSize":"2K"}}}
    req=urllib.request.Request(f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
        data=json.dumps(body).encode(),headers={"Content-Type":"application/json","x-goog-api-key":key},method="POST")
    try:
        with urllib.request.urlopen(req,timeout=180) as response:
            result=json.load(response)
    except urllib.error.HTTPError as error:
        # Never print provider response bodies, request objects, URLs with keys, or headers.
        raise GenerationError(error.code) from None
    except (urllib.error.URLError, TimeoutError):
        raise GenerationError(503) from None
    for candidate in result.get("candidates",[]):
        for part in candidate.get("content",{}).get("parts",[]):
            inline=part.get("inlineData") or part.get("inline_data")
            if inline and inline.get("data"):
                return base64.b64decode(inline["data"]), inline.get("mimeType","image/png")
    raise ValueError("Image service returned no image. The item remains retryable.")


def generate(args) -> int:
    items=choose(args)
    if args.dry_run:
        print(json.dumps({"images":len(items)*args.candidates,"paidRequests":0,"model":args.model,"dryRun":True},indent=2));return 0
    manifest=read_manifest()
    style=None
    if args.anchor:
        if args.kind!="lessons" or [x["number"] for x in items]!=[1]:
            raise ValueError("Style anchors must use --kind lessons --range 1.")
        items=[dict(items[0],id=f"lessons/day-001-candidate-{n:02}",prompt=items[0]["prompt"]+f" Style anchor candidate {n}: a unique camera and flower arrangement.") for n in range(1,args.candidates+1)]
    else:
        approved=manifest.get("style")
        if not approved or not approved.get("approved"):
            raise ValueError("Approve a Day 1 style anchor with review --style-ref PATH before generating a batch.")
        style=ROOT / approved["path"]
        if args.style_ref and Path(args.style_ref).resolve()!=style.resolve():
            raise ValueError("--style-ref must match the approved anchor. Review the new anchor first.")
        if not style.is_file() or sha(style.read_bytes())!=approved["sha256"]:
            raise ValueError("The approved style reference is missing or changed. Review it again.")
    key=os.environ.get("GEMINI_API_KEY","")
    if not key:
        raise ValueError("Set GEMINI_API_KEY to an AI Studio key with billing before generation.")
    if not re.fullmatch(r"[A-Za-z0-9._-]+",args.model):
        raise ValueError("Model IDs may contain only letters, digits, dots, underscores and dashes.")
    style_sha=sha(style.read_bytes()) if style else ""
    pending=[]
    for item in items:
        digest=prompt_hash(item,args.model,style_sha)
        old=manifest["items"].get(item["id"],{})
        path=ROOT/old.get("path", "art/missing")
        if old.get("promptHash")==digest and old.get("status")=="generated" and path.is_file() and sha(path.read_bytes())==old.get("sha256"):
            print(f"Resume: keeping {item['id']}");continue
        pending.append((item,digest))
    print(f"Generating {len(pending)} images with at most 4 concurrent requests. Credentials remain in memory.")
    failures=[]
    def worker(pair):
        item,digest=pair;model=args.model
        for attempt in range(6):
            try:
                data,mime=request_image(item,model,key,style)
                extension={"image/jpeg":".jpg","image/webp":".webp"}.get(mime,".png")
                path=ART/"raw"/(item["id"]+extension);path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
                entry={**item,"model":model,"requestedModel":args.model,"promptHash":digest,"status":"generated",
                       "path":str(path.relative_to(ROOT)),"sha256":sha(data),"approved":False,"anchor":args.anchor}
                with LOCK:
                    manifest["items"][item["id"]]=entry;save_manifest(manifest)
                print(f"Generated {item['id']}");return
            except GenerationError as error:
                if error.code in [400,404] and model==DEFAULT_MODEL and args.model==DEFAULT_MODEL:
                    model=FALLBACK_MODEL;continue
                if error.code in [408,429,500,502,503,504] and attempt<5:
                    time.sleep(min(30,2**attempt)+random.random());continue
                reason=str(error);break
            except (ValueError,OSError) as error:
                reason=str(error);break
        else:
            reason="Image service retry limit reached."
        with LOCK:
            manifest["items"][item["id"]]={**item,"model":model,"promptHash":digest,"status":"failed","error":reason,"approved":False}
            failures.append(item["id"]);save_manifest(manifest)
        print(f"Failed {item['id']}; safe to resume.",file=sys.stderr)
    with concurrent.futures.ThreadPoolExecutor(max_workers=min(4,args.workers)) as executor:
        list(executor.map(worker,pending))
    print(f"Finished: {len(pending)-len(failures)} generated, {len(failures)} retryable failures.")
    return 1 if failures else 0


def review(args) -> int:
    if args.dry_run:
        print("Review dry run: no approvals or files changed.");return 0
    manifest=read_manifest()
    if args.style_ref:
        path=Path(args.style_ref).resolve()
        try:relative=path.relative_to(ROOT)
        except ValueError:raise ValueError("Keep the approved style reference inside this project.") from None
        if not path.is_file():raise ValueError("Style reference does not exist.")
        matching=next((e for e in manifest["items"].values() if e.get("path")==str(relative) and e.get("status")=="generated"),None)
        if not matching or not matching.get("anchor"):
            raise ValueError("Choose a generated Day 1 anchor candidate from this manifest.")
        manifest["style"]={"path":str(relative),"sha256":sha(path.read_bytes()),"approved":True}
        matching["approved"]=True;matching["approvedSha256"]=matching["sha256"]
    if args.approve:
        ids={item["id"] for item in choose(args)}
        if args.approve!="selected":
            numbers=selected_numbers(args.approve,365 if args.kind=="lessons" else len(BADGES) if args.kind=="badges" else len(SCENES))
            ids={x["id"]for x in inventory() if x["kind"]==args.kind and x["number"]in numbers}
        for key in ids:
            entry=manifest["items"].get(key,{})
            if entry.get("status")!="generated":raise ValueError(f"Cannot approve missing image {key}.")
            path=ROOT/entry["path"]
            if not path.is_file() or sha(path.read_bytes())!=entry["sha256"]:raise ValueError(f"Review changed or missing image {key} again.")
        for key in ids:
            manifest["items"][key]["approved"]=True;manifest["items"][key]["approvedSha256"]=manifest["items"][key]["sha256"]
    save_manifest(manifest)
    cards=[]
    for key,entry in sorted(manifest["items"].items()):
        if entry.get("status")!="generated":continue
        path=Path(entry["path"]).relative_to("art")
        cards.append(f'<figure data-kind="{html.escape(entry["kind"])}"><img loading="lazy" src="{html.escape(str(path))}" alt="{html.escape(entry["title"])}"><figcaption><b>{html.escape(key)}</b><br>{"Approved" if entry.get("approved") else "Awaiting review"}</figcaption></figure>')
    page='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>HolyHim art review</title><style>body{font:15px system-ui;background:#fff7f5;color:#51353d;margin:28px}body.dark{background:#21192b;color:#fff2f4}button{padding:12px 18px;border:1px solid #c88899;border-radius:24px;background:transparent;color:inherit;cursor:pointer}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(170px,1fr));gap:22px}figure{margin:0}img{width:100%;aspect-ratio:9/16;object-fit:contain;border-radius:18px;background:linear-gradient(135deg,#fff,#eec8d2)}figcaption{padding:10px 0;overflow-wrap:anywhere}</style><h1>HolyHim · art review</h1><p>Inspect the full image on both backgrounds. Approve only after checking clarity, motif, hands/text exclusions, and badge edges.</p><button onclick="document.body.classList.toggle('dark')">Toggle light / dark</button><p>Approve ranges with <code>python3 tool/art/holyhim_art.py review --kind lessons --approve 1-14</code>. An approved file hash is pinned so later edits need fresh review.</p><div class="grid">'''+''.join(cards)+('</div><p>No generated images yet. Start with Day 1 candidates.</p>' if not cards else '</div>')+'</html>'
    (ART/"review.html").write_text(page)
    print(f"Contact sheet: art/review.html ({len(cards)} generated images).")
    return 0


def key_badge(image):
    """Chroma key with a feathered alpha and green despill. Imported lazily."""
    from PIL import Image,ImageFilter
    image=image.convert("RGBA")
    pixels=[];alpha=[]
    for r,g,b,a in image.getdata():
        dominance=g-max(r,b)
        spill=max(0,min(1,(dominance-12)/80)) if g>70 else 0
        # Keep ceramic/rose gold pixels while softening only the green edge.
        new_alpha=round(a*(1-spill))
        if spill>0:g=min(g,round(max(r,b)+(1-spill)*max(0,g-max(r,b))))
        pixels.append((r,g,b,new_alpha));alpha.append(new_alpha)
    image.putdata(pixels)
    mask=Image.new("L",image.size);mask.putdata(alpha);mask=mask.filter(ImageFilter.GaussianBlur(.55));image.putalpha(mask)
    return image


def package(args) -> int:
    if args.dry_run:
        print(f"Package dry run: {len(choose(args))} selected images; no files changed.");return 0
    try:from PIL import Image,ImageOps
    except ImportError:raise ValueError("Packaging requires Pillow: python3 -m pip install Pillow.") from None
    manifest=read_manifest();chosen={x["id"]for x in choose(args)};packaged=[]
    for key in sorted(chosen):
        entry=manifest["items"].get(key,{})
        if not entry.get("approved") or entry.get("status")!="generated":continue
        source=ROOT/entry["path"]
        if not source.is_file() or sha(source.read_bytes())!=entry.get("approvedSha256"):
            raise ValueError(f"Approved image {key} changed. Review it again.")
        kind=entry["kind"];out=ROOT/"public/art/v2"/key
        out.parent.mkdir(parents=True,exist_ok=True)
        with Image.open(source) as original:
            if kind=="badges":
                image=key_badge(original);image.thumbnail((1024,1024),Image.Resampling.LANCZOS)
                canvas=Image.new("RGBA",(1024,1024));canvas.alpha_composite(image,((1024-image.width)//2,(1024-image.height)//2))
                destination=out.with_suffix(".png");canvas.save(destination,optimize=True)
                thumb=out.with_name(out.name+"-thumb").with_suffix(".png");canvas.resize((360,360),Image.Resampling.LANCZOS).save(thumb,optimize=True)
            else:
                image=ImageOps.fit(original.convert("RGB"),(1080,1920),method=Image.Resampling.LANCZOS)
                destination=out.with_suffix(".webp");image.save(destination,"WEBP",quality=90,method=6)
                thumb=out.with_name(out.name+"-thumb").with_suffix(".webp");image.resize((360,640),Image.Resampling.LANCZOS).save(thumb,"WEBP",quality=84,method=6)
        bundled=kind!="lessons" or entry["number"]<=14
        if bundled:
            asset=ROOT/"assets/art"/key;asset.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(destination,asset.with_suffix(destination.suffix));shutil.copy2(thumb,asset.with_name(asset.name+"-thumb").with_suffix(thumb.suffix))
        entry["package"]={"path":str(destination.relative_to(ROOT)),"thumbnail":str(thumb.relative_to(ROOT)),"sha256":sha(destination.read_bytes()),"bundled":bundled}
        packaged.append({"id":key,**entry["package"]})
    save_manifest(manifest)
    target=ROOT/"public/art/v2/manifest.json";target.parent.mkdir(parents=True,exist_ok=True)
    all_packages=[{"id":key,**e["package"]}for key,e in manifest["items"].items() if e.get("package")]
    target.write_text(json.dumps({"version":2,"items":all_packages},indent=2)+"\n")
    assets=ROOT/"assets/art/manifest.json";assets.parent.mkdir(parents=True,exist_ok=True)
    assets.write_text(json.dumps({"version":2,"items":[p for p in all_packages if p["bundled"]]},indent=2)+"\n")
    print(f"Packaged {len(packaged)} approved images; {len(chosen)-len(packaged)} awaiting generation or approval. No upload performed.")
    return 0


def parser():
    root=argparse.ArgumentParser(description=__doc__)
    commands=root.add_subparsers(dest="command",required=True)
    for name in ["plan","generate","review","package"]:
        p=commands.add_parser(name)
        p.add_argument("--kind",choices=["all","lessons","badges","scenes"],default="all")
        p.add_argument("--range",help="Numbers, for example 1-5,8,12-14; interpreted within each selected kind")
        p.add_argument("--model",default=DEFAULT_MODEL)
        p.add_argument("--dry-run",action="store_true")
        if name=="generate":
            p.add_argument("--workers",type=int,choices=range(1,5),default=4)
            p.add_argument("--anchor",action="store_true",help="Generate unapproved Day 1 style candidates")
            p.add_argument("--candidates",type=int,choices=range(1,6),default=1)
            p.add_argument("--style-ref")
        if name=="review":
            p.add_argument("--approve",help="Explicitly approve a range, or 'selected' for --range")
            p.add_argument("--style-ref",help="Explicitly approve a generated style anchor path")
    return root


def main(argv=None):
    args=parser().parse_args(argv)
    try:return {"plan":plan,"generate":generate,"review":review,"package":package}[args.command](args)
    except (ValueError,OSError,json.JSONDecodeError) as error:
        print(f"Art workshop: {error}",file=sys.stderr);return 2

if __name__=="__main__":
    raise SystemExit(main())
