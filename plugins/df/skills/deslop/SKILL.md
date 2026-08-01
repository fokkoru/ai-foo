---
name: deslop
description: Use when writing or revising outbound prose that another person will read — a commit body, a PR description, a reply to a code review, a code comment — or when a draft reads as machine-generated: inflated adjectives, -ing clause tails, hedging, rule-of-three padding, generic praise, or prose that sounds like ChatGPT rather than like the author.
allowed-tools: Read, Task, Skill, Grep, Glob, Bash(git log:*), Bash(git config:*)
---

<objective>
Revise outbound prose so it reads as the author's own writing rather than a machine's.

The mechanism is a voice sample of that writing, matched by name. An isolated subagent grades each sentence; you hold the sample and do the writing.

</objective>

<quick_start>
Resolve the target first:

- Text supplied in the invocation is the target.
- A bare `/df:deslop` targets the draft under discussion. Name it back to the user first.
- Nothing identifiable: ask. Do not guess at the last message.

When another skill dispatches `references/voice-prober.md` directly, none of this applies — the draft arrives in the prompt.

</quick_start>

<workflow>

### Gate

Skip anything under 15 words, and skip one-line replies. Terse stays terse; nothing below runs. If the text is under the gate and the caller still asked for `recast`, stop and ask the user.

Fifteen is where authored prose starts in the measured corpus: everything below it is template text such as `This reverts commit <sha>`, entirely preserve-list tokens. It sits no higher because an 18-word message there carried three tells. Judge a borderline draft against those, not the number.

### Pick the mode

Read the mode from the invocation; default to `tune`. Modes are permitted-operation sets, never length targets: a 60-word body has no fat to cut, and a target forces the deletion `<constraints>` forbids.

| Mode     | Permitted operations                                            | Probe            |
| -------- | --------------------------------------------------------------- | ---------------- |
| `touch`  | Typos, grammar, punctuation only. No rephrasing or reordering.  | None             |
| `tune`   | Reword and reshape clauses. Sentence count and order unchanged. | Ladder steps 1–2 |
| `recast` | Restructure freely: merge, split, reorder, lead with the point. | Ladder steps 1–2 |

### Resolve the voice sample

Read `.claude/voice-sample.md` if it exists. Otherwise run `git log --no-merges --author="$(git config user.name)" --format=%B -n 30`.

Curate to 5–10 messages: drop version bumps, one-word subjects, subject-only commits, and anything that reads as generated. Curation is the mechanism, not tidying — corpus size tracks stylistic fidelity at r < 0.1, and a raw log holds messages the author is not proud of. If fewer than five survive, say so and work from the baseline. If no sample resolves at all and the caller expects one, stop and ask the user.

### Catalog

`tune` and `recast` only. If `humanizer` is available, invoke it in embedded mode: final text, no commentary. If not, the baseline below is the spec, not a fallback. Every line is a failure unaided agents committed on real commit bodies:

- Never introduce a fact the source did not carry. All five baseline agents did; 45.4% of AI-authored messages contradict their code (arXiv `2601.04886`).
- Never drop a load-bearing word. "Writing a tier down" became "Choosing a tier", which loses the mechanism.
- Do not inflate the register: "on disk" became "sit on disk", "consumed" became "burned", "since" became "because".
- Do not lengthen. The baseline runs came in at +16%, −2%, +8%, +32%, +267%.
- Carry WHY. The source already carries WHAT; restating it is lossy compression (arXiv `2603.15566`).
- No present-participial clause tails — "allowing a Codex-only suffix", "ensuring correctness". The strongest of 67 measured discriminators, at 527% of the human rate (PNAS `10.1073/pnas.2422455122`).
- Do not hedge behaviour into capability: "distinguishes", not "can tell apart".
- Do not open by restating the subject line or title.

### Dispatch the probe

Split the draft into numbered sentences. Fill `references/voice-prober.md` — a path relative to the base directory the harness announces for this skill, not to the working directory — and dispatch `general-purpose` via `Task`.

Pass the draft, the curated sample, the preserve list, and the mode. Pass nothing else. Wait for the verdicts.

Isolation is unavailable in two cases: the runtime has no generic subagent (Codex CLI today), or you are yourself a subagent — `df:deslop` fires on intent, so it loads inside dispatched agents too, where a skill's own dispatches have been reported to silently no-op and the probe would run in the very context that wrote the draft. Both take the same action: run the ladder inline, dispatch nothing, say so in the output.

If the subagent returns rewritten text instead of verdicts, stop and ask the user.

### Rewrite and ground

Author fresh from the verdicts, in the register of the curated sample. Never patch the probe's output; it returns judgements, not text.

Output exactly three parts, in this order:

1. The revised text.
2. `Matched:` at least two observable features of the curated sample — typical sentence length, paragraph count, em dashes, how it opens. A sample read but never named has not been used.
3. `Source:` the sample origin and how many messages survived curation.

### Re-check

Read the revised text back against the verdicts and the sample: every `rewrite` and `cut` is addressed, no new sentence reads as generated, every term names something the source carries. Fix what fails and re-read once.

Two rounds is the cap. If a sentence still fails on the second, the thought is wrong, not the wording — say so and leave it.

</workflow>

<constraints>

- Reproduce verbatim: code identifiers, file paths, `file:line` references, numbers, URLs, ticket and issue references, Conventional Commits type and scope, `{vars}`, `{{templates}}`, `$ENV`, `<tags>`, `%placeholders%`, code blocks, brand capitalization. Do not add backticks to a bare identifier, and do not reflow the source's line wrapping.
- Never add or omit content: fix wording, do not introduce a fact the source lacked, and do not drop one to hit a length.
- The subagent receives artifacts only — draft, sample, preserve list, mode. Never this session's conversation or your own reasoning. Isolation is the whole point.
- Never report isolation the run did not have. If the ladder ran inline for any reason, the output says so.
- Never emit draft stages or audit bullets when another skill is the caller — it asked for prose.
- Do not rename, reorder, or refactor code inside a fenced block; format only.

</constraints>

<anti_patterns>

- Rebuilding humanizer's catalog inline. Eight lines against measured failures; past fifteen it is a clone.
- Adding a translation round-trip. Measured here and dropped: it paraphrased a term of art and invented a causal connective.
- Letting the subagent rewrite. It returns verdicts; one that rewrites invents rationale it cannot see.
- Probing a whole document instead of its sentences.
- Resolving a voice sample and never naming what it matched.

</anti_patterns>

<success_criteria>

- The output has three parts, and `Matched:` names two observable features of the sample.
- Preserved tokens survive byte for byte, and a run without isolation says so.
- A `touch` run leaves sentence structure identical and dispatches nothing.

</success_criteria>
