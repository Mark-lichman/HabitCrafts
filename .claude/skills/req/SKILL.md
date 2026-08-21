---
name: req
description: >
  Requirements writing for HabitCrafts, a Flutter + Firebase habit-tracking app migrated out of
  FlutterFlow. Runs a five-phase interview — read-back, gap questions, draft, confirm, file — and
  produces a GitHub issue whose every factual claim carries a source. Leads with a prototype
  screenshot when one exists, refuses to invent the field types and limits the build will settle
  anyway, and marks an unstated goal visibly rather than inferring one silently. Trigger when the
  user mentions: requirements, write a ticket, file an issue, spec this out, scope this, define
  what needs building, or turns a note or Trello card into work. Always use when the user
  types /req.
argument-hint: "[feature description, or #NN to respec an existing issue]"
---

# HabitCrafts Requirements

This skill writes the tickets `/cto-review` later judges. Whatever it invents here becomes settled
fact downstream, so its central discipline is not completeness — it is **provenance**.

## Why this skill exists

1. **The requester and the engineer are the same person, months apart.** There is nobody to ask
   "what did you mean." A ticket that made sense the day it was written and not on the day it is
   picked up has failed, and the failure is silent — it looks like a normal ticket.
2. **Invented detail becomes rework, not a harmless guess.** `/cto-review` reads the code; this
   skill does not. A field type or a batch limit written here before anyone opened
   `lib/backend/schema/` is a guess wearing the clothes of a specification, and the next reader
   will treat it as decided.
3. **The backlog is the roadmap.** 62 issues, no project board, no sprint. The issue body is the
   only place intent is recorded, so it carries weight a ticket in a groomed backlog does not.
4. **A picture already exists.** The prototype is deployed and covers every screen. Describing a
   surface in prose when you could link the surface is a choice to be less clear.

## Context you must hold

**Two repos, and tickets routinely confuse them.**

- `Mark-lichman/HabitCrafts` — the Flutter app. Where tickets are filed.
- `Mark-lichman/habitcrafts-prototype` — design research, design direction, and clickable static
  mockups of every screen. Deployed to <https://mark-lichman.github.io/habitcrafts-prototype/>,
  redeployed on every push to `main`, so a link is never stale. Nothing here ships.

**This is a live defect, not a hypothetical.** Issue #59 cites `docs/design-direction.md` §3.4 and
`prototype/create-habit.html`. Neither path exists in HabitCrafts — both live in the prototype
repo, unnamed. **Every source names its repo.** A bare path is a broken citation.

**The prototype is the target, not the present.** A prototype screenshot shows what a screen should
become; the Flutter build shows what it is. When both matter — most design-system tickets — you
need both, and the caption must say which is which.

**No project board, no milestones, no assignee, no revenue field.** Do not invent process. The
metadata that exists is labels, sub-issue relationships, and the body.

**iOS cannot be built or simulated locally.** A ticket asserting iOS behaviour is asserting
something nobody can check before TestFlight. Say so in the ticket rather than letting
`/cto-review` discover it.

**Journeys J1–J12 in `docs/testing/journeys.md` are the behavioural baseline**, and every one is
currently `UNVERIFIED` — derived from source, never observed. A ticket changing behaviour a journey
asserts must say so, because the journey doc is corrected first and the test second.

---

## When invoked via /req — this is an interview, not a form

**Five phases. Do not skip to phase 3.**

- **1 · Read-back** — restate the ask in two sentences, in their words. Not blocking, but it is the
  cheapest misread-catcher available.
- **2 · Gap questions** — only what the input did not already answer. Max three, one round.
  **Blocking: wait for answers.**
- **3 · Draft** — the ticket, with the three honest sections.
- **4 · Confirm** — they push back; loop until "approved". **Blocking.**
- **5 · File** — `gh issue create`, labels, sub-issue link.

### Phase 1 — Read-back

Two sentences: what you think is being asked for, and who has the problem. Then *"Have I got that
right?"* A misread caught here costs one line. Caught in phase 5 it costs a filed ticket someone
has to close, in a backlog where closed tickets are the only history.

### Phase 2 — Ask only what is missing

**Gap-driven, never a fixed list.** The input may be a Trello card, a paragraph of
`docs/design-direction.md`, or a screenshot that already answers everything. Asking four questions
the input answered is friction, and friction is how a skill stops being used.

- Work out what the input already covers and **say which questions you are skipping and why**:
  *"Skipping the surface and journey questions — the design-direction section names both."*
- Ask at most **three**, in one round. Never a second round.
- **Open with the picture when there is one** — see below.

**Route by what can actually settle the question.** There is no second person, so "ask the
designer" is unavailable. Every open question resolves to exactly one of four:

- **The design direction decides it.** `habitcrafts-prototype docs/design-direction.md` is a
  standing decision record and overrules the research brief in five marked places. Go read it; do
  not re-decide what is already decided.
- **The prototype decides it.** If the screen exists, the layout question is answered. Link it.
- **You decide it now, in one line.** A judgment call with no external authority. Make it, write it
  into the ticket, and move on — an unmade decision in a solo backlog is not pending, it is
  forgotten.
- **The build decides it.** Types, limits, error copy. Name it as deferred and stop.

A fifth outcome — *research, not a decision* — applies only where an external standard governs:
store review guidelines, WCAG thresholds, Firebase quota behaviour.

### The goal gate

State the goal **in your own words**. Not the feature; the outcome — what is different for someone
using the app afterwards. If you cannot, push back **once**, plainly:

> "I can write this, but I can't tell what it's for. If the goal isn't clear yet, that's usually a
> sign this needs thinking rather than a ticket. Want me to file it anyway with the goal marked as
> unstated?"

If yes, **file it** — carrying a line that can be accepted but not erased:

> ⚠️ **Goal not stated** — Scope Anchor below is written from inference.

Same mechanism as `journeys.md`'s `UNVERIFIED` status and `/cto-review`'s `[inferred]` confidence
marker: work proceeds, the gap stays visible to whoever picks it up. **Never refuse to file.** A
skill that refuses gets bypassed, and then the ticket has no goal *and* no marker.

The gate bites hardest here precisely because nobody else will ever ask.

### The prototype question — lead with a picture

Ten screens are built and deployed. For anything touching a surface, the first question is a link,
not a paragraph:

    https://mark-lichman.github.io/habitcrafts-prototype/create-habit.html

Then: **"Is this the surface you mean? If yes, tell me what should be different. If it's the wrong
screen, name the right one."**

- Screens available: `index`, `app`, `home`, `onboarding`, `auth`, `explore`, `create-habit`,
  `library`, `library-detail`, `community`, `progress`, `profile`, and `system` — the design-system
  gallery, which is the right link for token, colour, motion and component questions.
- **Either outcome is useful.** Matches the ask → the ticket edits a real surface instead of an
  imagined one. Differs → that is a finding and it belongs in the ticket: either the prototype is
  behind the intent, or the ask is genuinely new.
- **Caption which artefact it is**, always: `prototype (target)` or `Flutter build (current)`. They
  are different screens with the same name, and a screenshot outlives the sentence around it.
- **No prototype screen for this** — say so and ask for a description. Never substitute a
  screenshot of the Flutter build and call it the design.
- **The Flutter build is capturable on Android and web only.** An iOS screenshot cannot be produced
  from this machine; do not ask for one.

### Invocation forms

- **A description** (`/req press-and-hold check-in`) — all five phases. A five-word fragment is
  exactly the input the goal gate exists for.
- **An issue number** (`/req #59`) — fetch with `gh issue view`, treat the body as phase-1 input.
  Still read back. An existing issue is not a stated goal, and re-speccing an old ticket is the
  most common way an unstated one survives.
- **Nothing** — ask what to spec, then all five phases.

### Proportionality — no ceremony on a copy fix

- **A copy change, a colour token, one field** → read-back, the picture, the goal question. Three
  exchanges. No three-section body; a paragraph and acceptance criteria is the whole ticket.
- **A screen migration or a new capability** → the full interview.
- **Input already states the goal** → skip phase 2 and say so.

---

## Titles — what someone saw, in 90 characters

The title is read in a list of sixty. It has two audiences and only the scanner reads it.

**Cap at 90 characters.** No backticks, no file paths, no function, widget or collection names, no
enum values, no error codes. Those go in the body, where they are looked for anyway.

**The strip test is mechanical.** Remove every backtick, path, symbol and enum from the title. If a
sentence remains, the title was describing the change. If nothing remains, the title was describing
the mechanism — and whatever you stripped belongs on a `**Mechanism:**` line at the top of the body.

- *Fix deepFlatten dropping two-level fields in checkins writes* → **Mood journal entries save empty
  when written from the group chat sheet**
- *Add requireAuth to GoRouter routes (#6 residual)* → **A signed-out user can open Profile by URL
  and see the previous account's data**

**A difference between two platforms, or two entry points, is the symptom** — keep it. "on web but
not on Android" earns its characters; it names the cohort a single-platform test misses. Cut the
mechanism to save room, never the asymmetry.

**Existing titles are not rewritten.** They are how issues are found and they are cited across
commits. This applies going forward.

---

## Ticket body

Target **40–90 lines**. Above that, it is two tickets or it is padded.

```markdown
[Part of #NN. Depends on #NN.]   <- only if true

**Scope Anchor:** This is DONE when [one observable outcome, in the requester's own words from
phase 2 — tightened for grammar, not rewritten for meaning].

**Journey:** J[N] — [name] · [unaffected | assertions change | new journey needed]
**Platforms:** Android · web · iOS — state each, or "no platform-specific behaviour: <why>"

## Why

Two or three sentences. What is different for someone using the app afterwards. Not the
implementation.

## What We Know

*(Facts with a source. Every row names its repo. No source is not a fact — it belongs below.)*

| Fact | Source |
|---|---|
| The check-in is a hold, not a tap | habitcrafts-prototype docs/design-direction.md §4.1 |
| Teal is retired from the UI | habitcrafts-prototype docs/design-direction.md §4.4 |
| Create Habit is a 560px modal at md+ | HabitCrafts #59 |

Section numbers are load-bearing and they move. Cite the number and the heading text together
when the section is doing real work: *§4.4 "Retire teal"*.

### Surface

*(The prototype link or screenshot, captioned `prototype (target)` or `Flutter build (current)`.
An ASCII wireframe if no surface exists yet. Delete if this ticket has no surface.)*

## What Must Be Decided

*(Every item names what settles it and what happens if it stays open.)*

| Question | What settles it | If unanswered |
|---|---|---|
| Does a streak survive a skipped day? | Decide now — no external authority | Blocks build |
| Does a 44px target pass on web at 200% zoom? | Research — WCAG 2.2 target size | Ship safe default |

## What The Build Determines

*(Deliberately deferred, not guessed. `/cto-review` reads the code; this skill does not.)*

- Field names, types and constraints on any new persisted shape
- Null and old-document handling — Firestore is schemaless and old documents live forever
- Query bounds, page sizes, listener lifecycles
- Exact error copy and its recovery path

## Acceptance criteria

- [ ] Observable, checkable by someone who did not write the ticket
- [ ] Light and dark
- [ ] Keyboard-operable, real label associations
- [ ] [the iOS position, explicitly — including "unverifiable until TestFlight"]

## Not in this ticket

One line each, so scope creep has to argue with something written down.
```

**Name what is deferred rather than inventing it.** Where a constraint is genuinely known — a store
requirement, a WCAG threshold, a Firestore document limit — it belongs in **What We Know**, with
its source.

---

## Self-check gate

One question, and the reader can check the answer:

> **Does every factual claim in this ticket name where it came from, and does every unsourced claim
> sit under "What Must Be Decided" or "What The Build Determines"?**

This is a provenance gate, not a shape checklist, deliberately. Every structural item — has a Why,
has acceptance criteria, has a journey line — can be satisfied by a well-formed invention. Only
provenance cannot.

Before filing, print the **Provenance Record**:

```
## Provenance
- Goal: stated by requester | ⚠️ inferred
- What We Know: N rows · N sourced · N naming their repo
- Surface: <link, or "none — no prototype screen exists for this">
- Journey: J[N] · doc needs updating: yes/no
- Deferred to the build: N items
- Questions asked: N of 3 · skipped: <which, and why>
```

A row that cannot be sourced is not trimmed quietly. Move it down a section and say you moved it.

---

## Filing

```bash
gh issue create --repo Mark-lichman/HabitCrafts \
  --title "..." --body-file <file> --label "..."
```

**Labels — use existing ones only.** `bug`, `enhancement`, `documentation`, `a11y`,
`design-system`, `creator-platform`, `from-trello`, `question`. Never invent a label without
asking; a one-off label in a 62-issue repo is noise, not taxonomy.

**Sub-issue links.** Design-system work hangs off #39. Put `Part of #NN` on the first line of the
body and create the real sub-issue relationship where the parent is known.

**The journey line is set here or nowhere.** You already identified it in order to write the Journey
line, so persist it. There is no grooming step downstream that will add it later — `/cto-review`
*reads* `docs/testing/journeys.md` and can only tell you the ticket failed to name a journey, never
which one it meant.

**If the journey doc needs updating, say so in the ticket** rather than updating it now. The doc is
corrected when the behaviour lands, not when it is planned.

---

## Behavioral rules

1. **A source names its repo.** `docs/design-direction.md` is ambiguous across two repos and has
   already produced one broken citation (#59). Write `habitcrafts-prototype docs/...`.
2. **Do not invent detail the build will settle.** Field types, lengths, limits, error strings. If
   you have not read the schema, you do not know the schema.
3. **The Scope Anchor is the requester's words.** Tighten grammar; do not rewrite meaning. If it was
   inferred, it says so.
4. **Never refuse to file.** Push back once, mark the gap, file.
5. **Link the surface rather than describing it.** Ten prototype screens are deployed. Prose about
   layout is a choice to be less clear.
6. **Caption every image with which artefact it is.** Target or current. They diverge, and the whole
   design-system epic exists because of that divergence.
7. **State the iOS position explicitly.** Unverifiable is a valid value. Silence is not.
8. **One maintainer.** No assignees, no review gates, no handoffs, no process needing a second
   person.
9. **Say what you skipped and why.** Skipped questions, unsourced rows moved down, sections deleted
   as not applicable. A quiet omission reads as a considered answer.
10. **Write it to be read cold.** Six months from now, by someone with no memory of the conversation
    that produced it. That someone is the maintainer.
