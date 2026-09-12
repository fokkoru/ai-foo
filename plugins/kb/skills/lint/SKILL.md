---
name: lint
description: Inspect the compiled knowledge base under docs/ for pages that have gone wrong — dead anchors, citations that join nothing, provenance whose evidence moved — and repair what has a demonstrated failure and an oracle. Reads thoughts/ and never writes it. Invoke it manually; it never fires on its own.
disable-model-invocation: true
allowed-tools: Read, Edit, Grep, Glob, LS, Bash(date:*), Bash(git config:*), Bash(git rev-parse:*), Bash(*check-docs.sh*)
---

<objective>
`weave` returns to a page only when a new source touches it, and its Step 3 updates existing pages rather than adding siblings — so a page whose topic never comes up again is never revisited, however wrong it has become. Nothing else in the plugin inspects a page on its own account.

`kb:lint` is that inspection. It reads the compiled layer under `docs/` on its own account, independent of whether any new source arrived to trigger a run, and it runs in two stages: one pass attaches evidence to a candidate, a separate pass decides what that finding means.

This is a maintenance pass somebody runs, not a mechanism that fires on its own — a run that fired unprompted would edit the compiled layer while the owner is doing something else.

</objective>

<artifact_scope>
Writes are allowed under `docs/` and `.kb/`: any page under `docs/`; `.kb/provenance.tsv` and `.kb/pages.tsv` through `provenance-commit`, `pages-commit` and `pages-forget` only, never by hand; and the map, one line per page it links or unlinks — following the same provenance and template rules `weave` follows. `references/page-templates.md` is the one copy of the frontmatter shape; it is shared from `weave` rather than duplicated here, and `kb:lint` reads it rather than restating it.

</artifact_scope>

<quick_start>
`/kb:lint` with no argument runs over the candidate set alone: what `check-docs.sh check` reports and notes on `docs/`.

`/kb:lint <page>` adds each named page to that set. Naming a page authorises inspection on suspicion alone, with no checker record behind it — the only intake for a claim that misread evidence which never moved, since no mechanical rule can catch that.

A run whose candidate set is empty and whose invocation named no page does nothing, and says so.

0. Acquire the claim
1. Snapshot `thoughts/`
2. Collect candidates
3. Decide a verdict per finding
4. Verify and release

</quick_start>

<workflow>

### Step 0: Acquire the claim

Everywhere below, including this step, `check-docs.sh` means `../../scripts/check-docs.sh` relative to the base directory the harness announces for this skill, not a command on `PATH` — the checker lives in the plugin's own `scripts/` rather than this skill's, because it is shared, and the working directory is the project being linted. `references/page-templates.md` is shared with `weave` rather than duplicated here, and resolves as `../weave/references/page-templates.md` relative to the same announced directory. Resolve both once, here, and reuse them.

Take the run's claim first, before anything else, with `check-docs.sh claim-acquire "${CLAUDE_SESSION_ID}" $PPID`. Keep the run id it prints. `weave` and `lint` both write pages, the map and `.kb/`, so two runs interleaving would collide on the compiled layer; and `kb:capture` publishes into `thoughts/captures/` mid-session only when the claim is free, so without one held here, a capture landing during this run adds a file to the raw layer that an unmodified `verify-sources` then reports at the end of a run that did nothing wrong.

If the claim is refused, stop and report what `claim-acquire` printed: a live owner means another run is going, an abandoned one means a run died and somebody has to look at what it left in `docs/` before the claim is released by hand.

The claim is acquired here, before the snapshot in the next step, and released — with `check-docs.sh claim-release <run id>` — after Step 4's verification, and on a handled failure too. A snapshot proves the tree matched at two points in time; it does not prevent a write in between, and it cannot say who made one. The claim is the part that prevents it.

### Step 1: Snapshot `thoughts/`

Run `check-docs.sh snapshot`. It records a hash of every file under the raw root and prints the path of the manifest holding them. Keep that path: Step 4 needs it, and it names this run's manifest alone, so a `weave` run going at the same time cannot be confused with it.

### Step 2: Collect candidates

Work over the union of two sets.

**M** is what `check-docs.sh check` reports and notes over `docs/`, read as candidates rather than as a pass/fail verdict. Step 3 below has a verdict for these rules only, whether they fail the run (`source-missing`, `fragment-missing`, `source-drift`, `unreachable`, `dead-anchor`, `unjoined-footnote`, `page-gone`) or only note it (`open-marker`, `unused-source`, `page-edited`, `unregistered-citation`). `check` computes others too — `schema-missing`, `map-missing`, `provenance-label`, `provenance-malformed`, `provenance-gone`, `decision-id-missing`, `decision-id-duplicate`, `superseded-by-dangling`, `valid-links`, `external-claim-incomplete`, `frontmatter-parseable`, `source-in-raw-root`, `source-is-capture`, among more — and a finding under one of those still enters M and still needs its evidence collected below, but Step 3 has no verdict built for it: it goes to the report as undetermined rather than being forced into a verdict meant for something else.

**H** is each page named on the invocation, validated as an existing `.md` file under `docs/`. Naming a page authorises inspection, nothing more — every finding it produces still needs its own demonstrated failure and its own oracle, the same as one M surfaced. A fragment hash catches evidence that moved; it cannot catch a claim that misread evidence that never moved, and no mechanical rule can — H is the only intake for that class.

For each page in the union, collect findings. A finding carries the page, the claim as written, the rule or the reason it is suspect, and the evidence: a `file:line` in current code, a conflicting line on another page, or the checker record that raised it. A finding with no evidence attached is not a finding, and is dropped here — it never reaches Step 3.

### Step 3: Decide a verdict per finding

Read the file at the path Step 0 resolved for `references/page-templates.md` before the first edit below — it holds the citation form and the staging line the second verdict builds, and a page written without it is a page whose keys were invented.

Take each finding on its own and settle it as one of six things.

The page is wrong: name the correction, ground it in the finding's evidence, and make the edit. Keep the page's path — it is staged for `pages-commit` in Step 4, alongside every other page this verdict or the next one touches. `source-missing`, `unjoined-footnote` and `unused-source` on a citation whose resource is gone settle here: delete the prose it supported along with the footnote, then restage the page's remaining citations as its complete set, this one left out — a claim whose evidence is gone is not a claim the page can still make. `provenance-commit` replaces rows only for a page named in its stage, so when the citation retired this way was the page's only one, no citations remain to restage: staging nothing for that page drops nothing and the stale row survives with no citation left to justify it. When that is the case, run `check-docs.sh pages-forget <page>` and then `check-docs.sh pages-commit <staging>` naming that page, to re-register it with no provenance rows — the correct end state for a page that now cites nothing, and the only sequence that clears the row using shipped modes alone.

The claim still holds but its provenance no longer demonstrates it: `provenance-commit` replaces every row for each page named in the staging file, so the stage for this page is its complete citation set, not the one row that drifted — list one line for every citation the page still makes, the corrected one on the fragment that now carries the evidence and every other one restated unchanged, or the rows left out of the stage are lost. Run `check-docs.sh provenance-commit <staging> <raw-root>`, then leave the prose alone. This is the ordinary case for a drift record: the source moved, the prose it supports is still true, and only the citation is stale. Confirm the new fragment actually supports the claim before taking this branch — a fragment that does not support it is the first case, not this one. `unregistered-citation` — a footnote definition with no provenance row at all — settles the same way: stage the page's complete citation set, this row included.

The page was edited by hand and still holds: confirm every citation on it still supports its sentence. Keep its path — it is staged for `pages-commit` in Step 4 alongside the wrong-page corrections, not committed here on its own. Advance the fingerprint only after that reading; a fingerprint advanced on sight endorses whatever the edit said, whether or not it was true.

The page was renamed: a `page-gone` whose fingerprint equals the fingerprint of an unregistered page on disk. The gone page's recorded fingerprint is the second column of its row in `.kb/pages.tsv`; a candidate's current fingerprint is what `check-docs.sh assign-id <page>` prints — the same normalize-and-hash pipeline `check` compares fingerprints with, so the two numbers are comparable. The candidates are the `.md` files under the docs root with no row in `.kb/pages.tsv`; list them and compute each one's value. On a match: stage the old rows under the new path and run `check-docs.sh provenance-commit <staging> <raw-root>`, then stage the new path on its own line and run `check-docs.sh pages-commit <staging>`, then relink the map from the old path to the new one, then run `check-docs.sh pages-forget <old page>` last, once the new path is registered and reachable. No match: report it and leave it — never infer a rename from a title.

The page is right: dismiss the finding. Name it in the report and write nothing.

The answer is not determinable from the repository: report it, with the pages it concerns and what settling it would take, and write nothing. Restructuring, merging two pages, splitting one, and rewriting prose that is not false all land here — none of it has an oracle. Such a finding recurs in the next report until the owner acts or the page changes; that repetition is the accepted cost of not building a queue for it.

Reading is not bounded by the union — a finding on one page routinely needs another page read to settle, and a correction routinely touches the map or a decision page. Writing is bounded by `<artifact_scope>` above.

### Step 4: Verify and release

Run `check-docs.sh check` over `docs/` and report what it said — this run's own edits answer to the same gate everything else in `docs/` does. A finding Step 3 left open on purpose (an undetermined answer, or a `page-gone` with no fingerprint match) can leave this run non-zero with nothing wrong in what this run did; that alone is not a defect. Then run `check-docs.sh verify-sources <manifest>` with the manifest path Step 1 printed.

A failure from `verify-sources` means this run wrote into the raw layer, which `<artifact_scope>` forbids. That is a defect in the run, not a finding to hand to the user: say so plainly, name the files, and stop.

Once `verify-sources` passes — regardless of what the first `check` reported elsewhere in the tree — stage every page kept from the "page is wrong" and "the page was edited by hand" verdicts above, one path per line, and run `check-docs.sh pages-commit <staging>`. It writes each page's fingerprint. Gating this on `check` as well as `verify-sources` would leave the pages this run actually inspected unregistered whenever any other finding in `docs/` stayed open, which is the ordinary case, not the exception. The renamed-page verdict already registered its own page in Step 3 and is not staged again here.

Run `check-docs.sh check` a second time, as the report of where the tree stands. `page-edited` on a page this run just corrected could not have cleared before its fingerprint was advanced, so this run is the one that actually confirms the correction stuck — a page still reported `page-edited` here means `pages-commit` was skipped or staged the wrong path. Fix whatever it reports about a page this run touched, then repeat `pages-commit` and `check`. A finding Step 3 already settled as undetermined, or an unmatched `page-gone`, is expected to still be there and is not this loop's job.

Release the claim with `check-docs.sh claim-release <run id>` once `verify-sources` has passed and the `pages-commit`-then-`check` cycle above is done, and also on the halt path above after reporting. A `check` finding Step 3 left open on purpose does not withhold release — the paragraph above already treats that as the ordinary case, not the exception: holding the claim for a green whole-tree `check` would refuse every later `lint` run's `claim-acquire` until the owner's separate pass clears it. Holding the claim through a halt buys nothing either: the owner has already been told exactly what went wrong, while a claim left behind blocks the next run until this session's process dies.

Report: the size of M and H, a verdict for every finding, the pages edited, and the result of every `check` and `verify-sources` run in Step 4. End with a proposed commit body, one sentence per correction, saying whether the citation moved or the prose was wrong.

</workflow>

<constraints>

- Never write, move, or delete anything under `thoughts/`. A project may hide `thoughts/` from git, in which case a write into it never appears in `git status` and nothing downstream would catch it, so the denial is verified by `snapshot` in Step 1 and `verify-sources` in Step 4, not by inspection
- Never run `git add`, `git commit`, or any other git write, matching `weave`. Committing is somebody else's job
- Never rewrite `.kb/schema.md`. A finding against it is reported and left, since it is the owner's schema
- A finding with no evidence attached is not a finding, and is dropped before it reaches a verdict

</constraints>

<anti_patterns>

- Filing an undeterminable finding into a proposal file, a `status` field, or any other queue — the report is the only place it lives; the owner acts on it or does not
- Naming a dismissed finding in the proposed commit body — a knowledge base that accumulates a permanent record of every question that turned out to be nothing is the opposite of pages getting smarter; the report is where a dismissal lives
- Treating a `source-drift` record as proof the page itself is wrong — it proves the cited fragment changed, and nothing about whether the prose built on it is still true

</anti_patterns>

<success_criteria>

- `docs/` or `.kb/` changed and `thoughts/` did not
- Every page the run edited traces to a finding that named its evidence

</success_criteria>
