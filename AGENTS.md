# HolyHim working rules

- Follow the personal iOS development rule in `/Users/amir/.codex/AGENTS.md`: use Amir’s real iPhone wirelessly for builds/runs; do not use Simulator unless explicitly requested.
- Keep Xcode build storage lean and preserve signing material, release archives, source and real-device app data.
- Work on `redesign/v2`; preserve `snapshot/walk-v1`. Do not push, deploy Firebase, or upload to the App Store without the user’s explicit approval. Development installation on the user’s iPhone is authorized.
- Lesson prose is written sequentially in the approved First Watch voice (`content/STYLE.md`): plain, direct and brotherly, for young men. `content/lessons_v2.json` is the source of truth; run the content and independent Scripture validators after each batch. Do not parallelize lesson authorship unless the user asks to use a workflow.
- HolyHim runs on HolyHer's engine. Take HolyHer changes only through `python3 tool/sync_upstream.py` and a merge of `upstream/holyher-renamed`; never write inside `/Users/amir/Downloads/HolyHer` and never touch HolyHer's Firebase, RevenueCat or App Store records.
