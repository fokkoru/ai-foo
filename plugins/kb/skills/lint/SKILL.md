---
name: lint
description: Inspect the compiled knowledge base under docs/ for pages that have gone wrong — dead anchors, citations that join nothing, provenance whose evidence moved — and repair what has a demonstrated failure and an oracle. Reads thoughts/ and never writes it. Invoke it manually; it never fires on its own.
disable-model-invocation: true
allowed-tools: Read, Edit, Grep, Glob, LS, Bash(date:*), Bash(git config:*), Bash(git rev-parse:*), Bash(*check-docs.sh*)
---

<objective>
`weave` returns to a page only when a new source touches it, and it updates existing pages rather than adding siblings (`plugins/kb/skills/weave/SKILL.md:129`) — so a page whose topic never comes up again is never revisited, however wrong it has become. Nothing else in the plugin inspects a page on its own account.

`kb:lint` is that inspection. It reads the compiled layer under `docs/` on its own account, independent of whether any new source arrived to trigger a run, and it runs in two stages: one pass attaches evidence to a candidate, a separate pass decides what that finding means. A finding with no evidence attached is dropped before the second pass ever sees it.

This is a maintenance pass somebody runs, not a mechanism that fires on its own — a run that fired unprompted would edit the compiled layer while the owner is doing something else.

</objective>

<artifact_scope>
Writes are allowed under `docs/` only: any page, plus `index.md` and `log.md`, following the same provenance and template rules `weave` follows. `references/page-templates.md` is the one copy of the frontmatter shape; it is shared from `weave` rather than duplicated here, and `kb:lint` reads it rather than restating it.

`docs/WIKI.md` is never written. It is the owner's schema. A finding against it is reported and left.

`thoughts/**` is denied. Inspection is not enough to prove that denial held — a project may hide `thoughts/` from git, in which case a write into it never appears in `git status` and nothing downstream would catch it. That is why Step 1 snapshots and Step 4 verifies.

`git add` and `git commit` are never run, matching `weave`. Committing is somebody else's job.

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

Take the run's claim first, before anything else, with `check-docs.sh claim-acquire "${CLAUDE_SESSION_ID}" $PPID`. Keep the run id it prints. `weave` and `lint` both write pages, `index.md` and `log.md`, so two runs interleaving would collide on the compiled layer; and `kb:capture` publishes into `thoughts/captures/` mid-session only when the claim is free, so without one held here, a capture landing during this run adds a file to the raw layer that an unmodified `verify-sources` then reports at the end of a run that did nothing wrong.

If the claim is refused, stop and report what `claim-acquire` printed: a live owner means another run is going, an abandoned one means a run died and somebody has to look at what it left in `docs/` before the claim is released by hand.

The claim is acquired here, before the snapshot in the next step, and released — with `check-docs.sh claim-release <run id>` — after Step 4's verification, and on a handled failure too. A snapshot proves the tree matched at two points in time; it does not prevent a write in between, and it cannot say who made one. The claim is the part that prevents it.

### Step 1: Snapshot `thoughts/`

Run `check-docs.sh snapshot`. It records a hash of every file under the raw root and prints the path of the manifest holding them. Keep that path: Step 4 needs it, and it names this run's manifest alone, so a `weave` run going at the same time cannot be confused with it.

### Step 2: Collect candidates

Work over the union of two sets.

**M** is what `check-docs.sh check` reports and notes over `docs/`, read as candidates rather than as a pass/fail verdict — every rule it computes, whether it fails the run (`source-missing`, `fragment-missing`, `source-drift`, `unreachable`, `dead-anchor`, `unjoined-footnote`, `unhashed-source`) or only notes it (`open-marker`, `unused-source`).

**H** is each page named on the invocation, validated as an existing `.md` file under `docs/`. Naming a page authorises inspection, nothing more — every finding it produces still needs its own demonstrated failure and its own oracle, the same as one M surfaced. A fragment hash catches evidence that moved; it cannot catch a claim that misread evidence that never moved, and no mechanical rule can — H is the only intake for that class.

For each page in the union, collect findings. A finding carries the page, the claim as written, the rule or the reason it is suspect, and the evidence: a `file:line` in current code, a conflicting line on another page, or the checker record that raised it. A finding with no evidence attached is not a finding, and is dropped here — it never reaches Step 3.

### Step 3: Decide a verdict per finding

Read the file at the path Step 0 resolved for `references/page-templates.md` before the first edit below — it holds the `sources[]` entry shape the second verdict rewrites and the `log.md` section form the first and second both add to, and a page written without it is a page whose keys were invented.

Take each finding on its own and settle it as one of four things.

The page is wrong: name the correction, ground it in the finding's evidence, and make the edit.

The claim still holds but its provenance no longer demonstrates it: re-anchor the `sources[]` entry on the fragment that now carries the evidence and rewrite its hash — write `sha256: "unset"`, run `check-docs.sh check`, and copy the value off the `source-drift` line it prints, the same way `weave` gets one — then leave the prose alone. This is the ordinary case for a drift record: the source moved, the prose it supports is still true, and only the citation is stale. Confirm the new fragment actually supports the claim before taking this branch — a fragment that does not support it is the first case, not this one.

The page is right: dismiss the finding. Name it in the report and write nothing — no page, no `log.md` line.

The answer is not determinable from the repository: report it, with the pages it concerns and what settling it would take, and write nothing. Restructuring, merging two pages, splitting one, and rewriting prose that is not false all land here — none of it has an oracle. Such a finding recurs in the next report until the owner acts or the page changes; that repetition is the accepted cost of not building a queue for it.

Reading is not bounded by the union — a finding on one page routinely needs another page read to settle, and a correction routinely touches `index.md` or a decision page. Writing is bounded by `<artifact_scope>` above.

### Step 4: Verify and release

Run `check-docs.sh check` over `docs/` and report what it said — this run's own edits answer to the same gate everything else in `docs/` does. Then run `check-docs.sh verify-sources <manifest>` with the manifest path Step 1 printed.

A failure from `verify-sources` means this run wrote into the raw layer, which `<artifact_scope>` forbids. That is a defect in the run, not a finding to hand to the user: say so plainly, name the files, and stop.

Release the claim with `check-docs.sh claim-release <run id>` once both checks pass, and also on the halt path above after reporting. Holding it through a halt buys nothing: the owner has already been told exactly what went wrong, while a claim left behind blocks the next run until this session's process dies.

Report: the size of M and H, a verdict for every finding, the pages edited, the `log.md` lines added, and the result of both checker runs.

</workflow>

<constraints>

- Never write, move, or delete anything under `thoughts/`. This is verified by `snapshot` in Step 1 and `verify-sources` in Step 4, not by inspection
- Never run `git add`, `git commit`, or any other git write
- Never rewrite `docs/WIKI.md`. A finding against it is reported and left, since it is the owner's schema
- A finding with no evidence attached is not a finding, and is dropped before it reaches a verdict
- A run whose candidate set is empty and whose invocation named no page produces no diff. A run that resolved every finding as "the page is right" produces no diff under `docs/` either, only the report
- The run ends by running `check-docs.sh check` over `docs/` and reporting what it said

</constraints>

<anti_patterns>

- Filing an undeterminable finding into a proposal file, a `status` field, or any other queue — the report is the only place it lives; the owner acts on it or does not
- Writing a `log.md` line for a dismissed finding — a knowledge base that accumulates a permanent record of every question that turned out to be nothing is the opposite of pages getting smarter
- Treating a `source-drift` record as proof the page itself is wrong — it proves the cited fragment changed, and nothing about whether the prose built on it is still true

</anti_patterns>

<success_criteria>

- `docs/` changed and `thoughts/` did not
- Every page the run edited traces to a finding that named its evidence
- A run over a clean tree with no page named produces no diff at all

</success_criteria>
