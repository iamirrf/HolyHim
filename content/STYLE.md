# HolyHim voice

Write the way a warm, wise friend talks to you over coffee: short, clear,
and kind. Every lesson should feel like God's love said out loud, to her.

## The reader

A woman with an ordinary, complicated life. She may be new to the Bible or
coming back to it. She is reading on her phone, maybe in a parking lot or
before anyone else is awake. Do not assume marriage, children, a job,
good health or a particular age.

## How it sounds

- **Plain words.** Aim for a fifth-grade reading level. If a short word works,
  use it. "Help", not "assistance". "Hard", not "challenging".
- **Short sentences.** Most under 15 words. None over 22.
- **Pictures, not ideas.** Say what it looks like: a sink full of dishes, a
  phone that keeps buzzing, a long drive home. Not "practical
  companionship" or "relational dimensions".
- **Speak to "you".** The meaning card explains the verse to her. The heart
  card talks with her. The prayer is hers, in "I" and "me".
- **Say God's love plainly.** At least once in every lesson, tell her
  directly what God is like toward her: he is with you, he sees you, he has
  not given up on you. Ground it in the verse.
- **One small step.** The heart card ends with one thing she can do today,
  small enough to do in a minute or two.
- **Keep pain honest.** Do not rush past grief, fear or tiredness. God meets
  her in it; he does not make it disappear on cue.

## Each card

1. **Today's Word**: the verse, World English Bible, quoted exactly. Never edit
   `verse` or `reference`.
2. **What it means** (`meaning`, 30 to 45 words): who said this, to whom, and
   what it meant then, in one or two concrete pictures. Then what it means for
   her.
3. **For your heart** (`heart`, 30 to 45 words): God's love said plainly, a
   real-life moment, and one small step for today.
4. **Prayer** (`prayer`, 30 to 50 words): simple, first person, honest, ends
   with "Amen."

Also:

- **`holdOn`** (8 to 18 words): the "carry this today" line on the celebration
  screen. A sentence she could repeat to herself at a red light.
- **`teaser`** (90 characters at most): a curiosity line for the Today card
  and the morning notification. Make her want to open it. No clickbait, no
  promises the lesson does not keep.

## Guardrails

- Quote the World English Bible exactly, including punctuation.
- Keep promises in their context. Never promise health, money, a relationship,
  a baby or an easy outcome.
- Never put invented words in God's mouth. Say what the verse says he did or
  said, not new speeches.
- Prayer never replaces practical help. Point to safe people, doctors and
  counsellors when the subject calls for it.
- Honour safety: never tell her to stay in danger, forgive on a timetable or
  keep a harmful secret.

## Words to avoid

Clinical or corporate words make the lessons feel like a report. The
validator rejects: tapestry, delve, navigate, embrace, unlock, beacon,
testament to, in today's fast-paced world, it's important to remember,
transformative journey, sacred dance, gentle reminder, practical, component,
facilitate, utilize, aspect, dimension, framework, paradigm, leverage,
optimal, implement, perspective, significant, mechanism, intentional,
ultimately, essentially, prioritize, companionship, consequently, individuals,
circumstances, demonstrate.

## Process

Lessons are written in order, in batches of at most 28 days, directly in
`content/lessons_v2.json`. After each batch: `python3 tool/verify_lessons.py`,
`python3 tool/build_lessons.py`, `python3 tool/verify_scripture.py`, then one
commit. The validator is a mechanical gate; it does not replace reading the
lesson aloud.
