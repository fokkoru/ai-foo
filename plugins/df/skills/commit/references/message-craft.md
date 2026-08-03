# Message craft

Read this before drafting a commit body or a footer. A subject-only commit needs nothing here. The
invoking skill supplies the tier for the message and the recent-commit sample used as a voice
reference.

### Body craft

Bodies are prose. Never a bullet list of what changed. The diff is already that list.

Do not:

- Restate the diff. Type, scope, and subject carry WHAT. A body carries WHY.
- Narrate the session. No "initially tried X, then switched to Y", no "as requested", no "per review feedback". The commit records the change, not how it was arrived at.
- Open with "This commit", "This change", or "This PR".
- Guess at rationale you do not have. If you cannot state why from the diff and this session, write the shorter message.
- Reach for inflated words: robust, comprehensive, seamless, powerful, significantly, enhance, leverage, streamline.
- Tack on -ing clauses: "ensuring correctness", "allowing future growth", "improving performance".
- Group items into threes for rhythm.
- Use bold, emoji, or headings.
- Hedge, or close with a summary sentence that adds nothing.

Match the repository's voice. The recent-commit sample the invoking skill provides holds full messages — drop version bumps and anything that reads as generated, then follow the register, sentence length, and punctuation habits of what is left, including whether they use em dashes.

If the `humanizer` skill is available, invoke it in embedded mode on any body before committing; it returns final text with no commentary. Its rule against diff-anchored writing does not apply here, since a commit message is version-scoped by definition and that rule exempts version-scoped documents. If humanizer is not installed, the rules above are the baseline, not a fallback.

### The probe

Dispatch the probe only when the drafted body reaches 15 words. Below that, a commit body is
template text — `This reverts commit <sha>`, a cherry-pick trailer — and every token in it is on
the preserve list, so the probe has nothing to grade and returns nothing. Fifteen is where
authored prose starts in the measured corpus; judge a borderline body against that, not the
number.

Fill the template at `../deslop/references/voice-prober.md` — a path relative to the base directory the harness announces for this skill, not to the working directory — and send it to `voice-prober` via `Task`. Pass the draft body, the curated recent-commit messages as the voice sample, and every identifier, path, number, and issue reference the body must reproduce verbatim. Pass nothing else: not this session's conversation, not your own reasoning. It returns one verdict per sentence and never replacement text, so rewrite from the verdicts yourself. If `voice-prober` is not installed — Codex CLI takes its subagents from `install-codex-agents.sh`, a manual step — skip the dispatch.

Dispatch the template directly; do not invoke `df:deslop`. Its description matches a commit body, so the model may reach for it, and an invoked skill's body stays in this session for the rest of it — buying nothing `df:commit` is not already doing.

The tier cap still governs the result: if the returned body is longer than its tier allows, keep the shorter text.

### Body layout

Wrap the body at 72 columns. That is Tim Pope's convention rather than a git rule — git's own docs
state a 50-character soft limit on the subject and say nothing about the body.

One blank line between subject and body.

### The cap is a split signal

If a body is outgrowing its tier, the commit is too big. Split it. Do not extend the message. This
is the rule the kernel's submitting-patches guide states: "If your description starts to get
long, that's a sign that you probably need to split up your patch."

If a change genuinely cannot be split and still needs more than two paragraphs, stop and tell the user, naming the split you considered and why it does not work.

### Breaking Changes

Two equivalent mechanisms — use both together for maximum clarity. The `!` goes before the colon on the subject line; the other is a `BREAKING CHANGE:` footer (uppercase required):

```
feat(api)!: remove deprecated /v1/login endpoint

BREAKING CHANGE: /v1/login has been removed. Use /v2/auth/login.
Existing clients must migrate before the next release.
```

### Footer Format

One blank line after body, then `token: value` or `token #value`. Tokens use hyphens, not spaces.

| Footer                  | Purpose                                            |
| ----------------------- | -------------------------------------------------- |
| `Fixes #N`              | Closes issue N on merge (bug fixes)                |
| `Closes #N`             | Closes issue N on merge (features)                 |
| `Refs #N`               | References issue N without closing                 |
| `BREAKING CHANGE: <x>`  | Describes the breaking change (uppercase required) |
| `Co-authored-by: N <e>` | Credit co-authors (only if user asks)              |
| `Refs: <sha>`           | For `revert` commits, reference reverted SHA(s)    |

### Revert Example

```
revert: feat(auth): add JWT validation

This reverts commit abc123def. JWT validation broke session renewal
for mobile clients; reverting while we fix the renewal path.

Refs: abc123def
```
