---
name: weave
description: Weave raw sources under thoughts/ into the project's long-term memory — a durable, committed knowledge base under docs/ shaped by Open Knowledge Format, routed by whether a claim is a verified fact about the current code or a proposal, each carrying per-source provenance
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Grep, Glob, LS, Bash(date:*), Bash(git config:*), Bash(git rev-parse:*), Bash(*check-docs.sh*)
---

<objective>
Turn accumulated raw sources into pages that get smarter, not into more siblings. The output under `docs/` is the project's long-term memory: the layer a later session reads instead of re-reading the raw notes, and the layer a new contributor reads instead of asking.

This is a batch pass somebody runs, not a recall mechanism that fires on its own, which is why it is not called "memory" — that word already names mechanisms in both runtimes that inject context automatically, and this one never does. It is called `weave` because a second source on a topic is worked into the page that already covers it rather than filed beside it, and that is the test the skill gives for its own success.

The input is a directory of markdown. `thoughts/` is not any plugin's artifact, and a project that has never installed another plugin compiles its own notes with this skill unchanged.

</objective>

<artifact_scope>
Writes are allowed under `docs/` and `.kb/`.

`.kb/schema.md` is written only by the seed and adopt rows of Step 0. The file `map:` names is the owner's; a run only ever appends one line to it, to register a new page — nothing else in that file is touched.

On the adoption row of Step 0 the allowed writes narrow further to what `references/adopt.md` lists: `.kb/schema.md`, and `docs/index.md` only when the tree has no map of its own. That run writes no page body and compiles no source.

</artifact_scope>

<quick_start>
If sources are named, begin at Step 0.

If no sources are named and `docs/` holds pages but there is no `.kb/schema.md`, begin at Step 0: that is its adoption row, and an adoption compiles nothing, so it has no sources to name.

Otherwise, if no sources are named, ask which ones to compile and wait for the answer. Never default to the whole corpus — a first run over everything produces a tree nobody reviews.

`weave captures` names a class rather than filenames: the pending capture records, whichever they turn out to be. `check-docs.sh captures-eligible <records root>` computes that class from `.kb/consumed.tsv` and the records on disk. An invocation naming unrelated files absorbs no captures, and a bare invocation follows the two rules above.

`weave reconsider` is the pass that returns to what an earlier run deferred: `check-docs.sh captures-deferred <records root>` lists those decisions, and the run re-examines each against current evidence and consumes any that now route. A deferred decision does not wake on its own — nothing schedules this pass, and reaching a deferred decision takes a run somebody starts.

`weave pending` prints the queue and asks: `check-docs.sh sources-pending <raw root>` lists every raw source outside `captures/` that no run has consumed at its current bytes, as `new` or `changed`. Show that list, ask which entries this run takes, and wait for the answer — the same wait as a bare invocation. An empty list ends the run with a one-line report: nothing is pending, and there is nothing to claim or snapshot for. The list is the queue, not the batch: a scope the model picks is not reproducible from the invocation, and the whole queue at once is the tree-nobody-reviews failure the bare invocation guards against.

0. Claim, seed and snapshot
1. Read the sources and scan for supersession
2. Route each claim
3. Produce updates, not siblings
4. Write provenance
5. Update the map
6. Check
7. Report

</quick_start>

<workflow>

### Step 0: Claim, seed and snapshot

Everywhere below, including this step, `check-docs.sh` means `../../scripts/check-docs.sh` relative to the base directory the harness announces for this skill, not a command on `PATH` — the checker lives in the plugin's own `scripts/` rather than this skill's, because it is shared, and the working directory is the project being compiled. Every `references/` path below hangs off the announced directory directly. Resolve both once, here, and reuse them.

Take the run's claim first, before anything else, with `check-docs.sh claim-acquire "${CLAUDE_SESSION_ID}" $PPID`. Keep the run id it prints. One claim covers the whole run rather than the snapshot and the verification separately: a capture publishes into the raw layer during a live session, so a gap in the middle is a gap another writer can use, and this run edits the compiled layer in that middle with nothing staged and nothing to roll back.

`$PPID` inside a shell the harness starts for you is the harness process itself, observed on Claude Code 2.1.261. That process is what the claim names as its owner, which is what lets a later run tell an abandoned claim from a live one.

If the claim is refused, stop and report what `claim-acquire` printed. A live owner means another run is going; an abandoned one means a run died, and somebody has to look at what it left in `docs/` before the claim is released by hand.

Then run `check-docs.sh snapshot`. It records a hash of every file under the raw root and prints the path of the manifest holding them. Keep that path: Step 6 needs it, and it names this run's manifest alone, so a compile running beside this one cannot be confused with it. `NO-RAW-ROOT` from it is a halt on every row of the table below except the third: a hand-written tree may have no raw layer at all, and `references/adopt.md` says what an adoption does without a manifest.

Then settle what `docs/` already is:

| State                                      | Do this                                                                                                                                                                                                          |
| ------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.kb/schema.md` exists                     | Read it. It is authoritative and outranks this file wherever the two disagree                                                                                                                                    |
| `docs/` absent or empty                    | Read `references/schema-template.md` and write it unchanged to `.kb/schema.md`. Also write `docs/index.md` holding an H1 and nothing else, and set `map: docs/index.md` in the schema. Report that you seeded it |
| `docs/` has content but no `.kb/schema.md` | Read `references/adopt.md` and follow it to its end. The run stops when the adoption is reported; nothing is compiled in it                                                                                      |

The third row is a hand-written documentation tree, not a knowledge base with a missing file. Overwriting one is the single most expensive mistake this skill can make, which is why the procedure that adopts one is written down separately and read only here: it changes nothing that is there, and it ends the run so the adoption is committed on its own.

### Step 1: Read the sources and scan for supersession

Read every named source completely. A source is the unit the user named; reading half of one produces a page that cites a fragment nobody checked.

The ledger decides only for the `pending` class. A source the owner named by filename is read in full whatever `.kb/consumed.tsv` says about it: naming it is the way back to a source recorded `no-home` whose bytes never changed but whose code did. Capture records are governed by `weave captures` and `weave reconsider` exactly as before, not by this rule. Within the `pending` class a source is read only if `sources-pending` listed it; one listed as `changed` is read again in full, because the ledger records what was consumed, not a diff.

Then read the file `map:` names and, for every topic the sources touch, the pages it links to. You cannot update a page you have not read, and Step 3 turns on knowing which pages already exist.

Before anything is routed, run `check-docs.sh supersession-scan <records root> docs "<target>"` for every decision the run is about to touch — each capture decision it read, and each compiled decision page it is about to update. The scan runs after the claim is taken, so a cooperating publisher cannot change the set of records while it runs.

A reference names one decision, never a whole file, in one of two forms:

```
Supersedes: decision <decision_id>
Supersedes: record <path> ### <the literal heading line>
```

Exit 3 means the scan is incomplete: a record does not conform, so the edges it holds could not be read. Stop the run and report which record. An incomplete scan is never reported as "nothing supersedes this" — the difference between the two is the whole reason the scan has its own exit code.

Supersession is terminal. If B superseded A and C later supersedes B, A does not come back; re-adopting A takes a new record asserting it.

### Step 2: Route each claim

Route by what the claim is, not by which document carried it. One source routinely produces claims for more than one directory.

| The claim is                                                      | It goes to                    | With                                                                              |
| ----------------------------------------------------------------- | ----------------------------- | --------------------------------------------------------------------------------- |
| A statement about current behaviour, located at a `file:line`     | `architecture/` or `product/` | `status: stable`                                                                  |
| A rule in effect, evidenced in code or in a checked-in config     | `decisions/`                  | `status: stable`                                                                  |
| Anything else, including a plan whose change is not in the code   | `roadmap/`                    | `status: draft`                                                                   |
| A decision that a later one replaced                              | both decision pages           | the old page `status: deprecated` plus `superseded_by`, the new page `supersedes` |
| A rule that no longer holds, whose replacement is not implemented | the old decision page         | `status: deprecated` with no `superseded_by`; the replacement is not compiled     |

The first row has a gate: a claim reaches `architecture/` or `product/` only after you have located the behaviour at a `file:line` in the current code. That location becomes a `provenance-commit` staging line, not a `sources[]` record.

A provenance row names tracked code or checked-in config, and never an internal note. The raw root is not in a fresh clone, so a citation into it names a file the reader does not have, and a claim nobody else can check is not a fact this layer records. `provenance-commit` refuses one. A capture record is refused separately and for a different reason: a record sits outside the source trust order entirely, never competing for a page and never cited by one. What it does is send you to look at the code, the config and the plans.

An external source is cited in the page body instead, never staged for `provenance-commit`, so the two rules never overlap. Mark the claim `[reported]` and put the URL and `retrieved YYYY-MM-DD` on the same line. External sources stay informal — no snapshot file, no drift checking, no refresh mode — and the checker reports a `[reported]` line missing either half.

Where a record contradicts a stale plan and current code does not settle which is right, the contradiction stays unresolved and the run stops.

Settle the whole supersession family from Step 1 before writing to any page. A page updated and then contradicted inside one run is a page whose history says two things happened when one did.

What supersession buys is exactly one thing: the contradiction gate does not halt the run for the conflict the record itself declares. It certifies nothing else. It does not say the intention was implemented, it does not say the rationale is factual, and any unrelated contradiction still halts the run.

Two records superseding one target and contradicting each other halt the run while the conflict is unresolved. Establishing from current code which behaviour is implemented does not settle it: that answers what the code does, and the dispute is over what was intended. An open dispute over intent halts the run.

**Deprecation takes two independent tests, and a record never flips a page on its own:**

| Old rule still holds | Replacement implemented | The old page                                   |
| -------------------- | ----------------------- | ---------------------------------------------- |
| yes                  | no                      | stays stable; the new decision is not compiled |
| no                   | yes                     | deprecated, plus a `superseded_by` link        |
| no                   | no                      | deprecated, with no `superseded_by`            |

The third row is the one that surprises: a rule rests on something, that something is reverted, a replacement is proposed and never built. The replacement is uncompileable, but the old rule is already false, and leaving the page stable tells the reader to rely on behaviour the repository removed.

Deprecating a page is three edits, not a frontmatter change. The page stays linked from its index, because the checker grants a deprecated page no reachability exemption. Its body and its index description stop asserting the rule that was withdrawn. And its provenance rows stay as they are and go on being checked — a deleted resource goes with the prose it supported, the same as anywhere else.

A source that fits no directory is not forced into one. Say so in the report and leave it uncompiled — a wrong home costs more than an absence, because the next run reads the wrong home as settled.

### Step 3: Produce updates, not siblings

Read `references/page-templates.md` before writing any page. It holds the four skeletons, one per page type, and it is where the frontmatter shape is written down. A page written without it is a page whose keys were invented. The checker validates provenance and reachability; `title`, `description`, `status`, and `generated` it never sees, so nothing downstream would notice.

For each source, name the existing page its claims land on before writing anything.

Write a new page only when the report can carry one sentence naming which existing pages you considered and why none of them is the home. That sentence goes in the report and into the proposed commit body from Step 7.

This is the step the whole skill exists for. A knowledge base that gains a page per source is a second copy of the raw notes with worse search.

### Step 4: Write provenance

Every page's footnote citations are staged and committed in one call, never typed into `.kb/provenance.tsv` by hand. `provenance-commit` replaces every row for each page named in the staging file, so the stage for a page is its complete citation set, not a diff against what was there before: list one line for every citation the page makes, not only the ones this run added or moved, or the rows this run leaves out are lost.

```
docs/<page>	<label>	<resource>	<fragment>
```

`<fragment>` is a heading line, an `L<start>-L<end>` range for a resource with no headings, or empty for the whole file. Then run `check-docs.sh provenance-commit <staging> <raw root>`. It computes the hash itself. It refuses a row whose page is not on disk, whose resource does not exist or lives in the raw root, whose label is empty or carries whitespace, or whose fragment does not resolve, and writes nothing at all if any row fails.

A citation whose resource no longer exists is deleted together with the prose it supported — dropped from the staging file rather than restaged — and the deletion goes into the proposed commit body from Step 7. A claim whose evidence is gone is not a claim the page can still make.

`provenance-commit` replaces rows only for a page named in the staging file, so when the citation being dropped was the page's only one, staging nothing for that page drops nothing — its row survives with no citation left to justify it. When the citation being retired is the page's last, run `check-docs.sh pages-forget <page>` and then `check-docs.sh pages-commit <staging>` naming that page, to re-register it with no provenance rows: that is the correct end state for a page that now cites nothing, and it is the only sequence that clears the stale row using shipped modes alone.

A new decision page also gets its `decision_id`, which is how a supersession reference names the decision across an editorial rename. Write the page with `decision_id: "unset"`, then run `check-docs.sh assign-id <page>` and write the value it prints into the key. Assign it once: a later edit to the page never reassigns it, and a substantively different decision is a new page with its own.

### Step 5: Update the map

Every page must be reachable from the file `map:` names, by following relative links. A page written and not linked is the most common failure of this whole workflow, which is why the checker fails on it.

A new page gets one line added to that file and nothing else — the map itself is the owner's, not something `weave` compiles, and it is never staged into `pages-commit` below.

### Step 6: Check

Run `check-docs.sh check`, then `check-docs.sh verify-sources <manifest>` with the manifest path Step 0 printed.

Fix whatever it reports about a page this run wrote, new or updated, and run it again. A finding on a page this run never touched is not this run's defect — an adopted or partially-linted tree can carry one indefinitely, and gating this loop on the whole tree would make it unwinnable in exactly that state.

A failure from the second is different in kind. It means this run wrote into the raw layer, which `<artifact_scope>` forbids. That is a defect in the run, not a finding to hand to the user: say so plainly, name the files, and stop.

Once `verify-sources` passes — regardless of what the first `check` reported elsewhere in the tree — run `check-docs.sh pages-commit <staging>` with one page path per line, every page this run wrote, new or updated. It writes each page's fingerprint. Gating this on `check` as well as `verify-sources` would leave the pages this run actually wrote unregistered whenever any other finding in `docs/` stayed open — the ordinary case for an adopted or partially-linted tree, not the exception. An adopted tree's own findings, handed to the owner as backlog by `references/adopt.md`, are exactly that case: the run after an adoption cannot reach `pages-commit` at all if this gate stayed on a green whole tree.

Run `check-docs.sh check` again. `decision_id`-missing, a fingerprint mismatch, and `unregistered-citation` all gate on a page being registered, so the run before `pages-commit` could not have seen any of the three on a page this run just created — it was not registered yet to check against. This second run is the one that actually holds this run's new pages to those rules; fix whatever it reports about a page this run touched — most commonly a decision page left at `decision_id: "unset"` because the `assign-id` round trip in Step 4 was skipped — then run `pages-commit` and `check` again before going on. A finding this run did not cause — left open elsewhere in the tree, or already settled as undetermined by an earlier `kb:lint` pass — is expected to still be there and is not this loop's job.

Then write the consumption ledger. Stage one line per decision this run touched and one per named non-capture source outside `captures/` this run read:

```
capture	<record path relative to the captures directory>	<decision heading>	consumed|deferred
note	<path relative to the raw root>		consumed|no-home
```

A note row is `consumed` when at least one claim from it reached a page and `no-home` when none did. Then run `check-docs.sh consumed-commit <raw root> <staging file>`. It computes each row's hash itself, validates the whole set, and writes nothing unless all of it validates, so a run that stops here leaves no entry.

Acknowledgement is per decision, never per record: a record is routinely half compiled and half deferred, and marking the whole file done would lose the deferred half. "Offered", "confirmed" and "read for context" are not acknowledgement. A decision that routed nowhere is `deferred` and waits indefinitely — nothing expires, and only a run the owner starts returns to it.

Then run `check-docs.sh consumed-check <raw root>` and carry what it notes into the report. A source skipped in Step 1 is not staged: it is already recorded. Nor is a named source whose last ledger line already carries its current hash and state — a repeat run over unchanged sources leaves the ledger as it was, the same way it leaves the pages.

The consumption ledger and `.kb/pages.tsv` are committed alongside the pages they describe, so reverting a bad run reverts its bookkeeping too.

Release the claim with `check-docs.sh claim-release <run id>` once Step 6 is done, and also on the halt path above after reporting. Holding it through a halt buys nothing: the user has already been told exactly what went wrong, while a claim left behind blocks the next run until this session's process dies and then makes somebody inspect a compiled layer they already know the state of.

### Step 7: Report

Report:

- the captures consumed, and separately the eligible records left alone — a model-chosen scope is not reproducible from the invocation and the repository state, only from being written down
- any record opened for context, named as such: a contextual read is not consumption and produces no ledger entry
- pages created, and for each, the one sentence from Step 3
- pages updated
- sources consumed, and any source that found no home
- the result of both checker runs

End with a proposed commit body: one sentence per new page, the Step 3 sentence naming which existing pages were considered and why none is the home; one sentence per citation deleted because its resource is gone; one sentence per page deprecated. There is no `log.md` to carry this instead — the proposed commit body is the run's history.

On the run that seeded `.kb/schema.md`, and on an adoption run, print — never write — a `## Documentation` block for the user to paste into their own instructions file, pointing a later session at `docs/` before `thoughts/`.

Close by saying that `docs/` is ready to be committed on its own.

</workflow>

<constraints>

- Never write, move, or delete anything under `thoughts/`. Before any Write or Edit call, verify the target path is inside `docs/` or `.kb/`, and stop and ask the user if it is not. Inspection cannot prove the denial held, because a project may hide `thoughts/` from git and a write into it then never appears in `git status`, so it is verified by `snapshot` in Step 0 and `verify-sources` in Step 6
- Never run `git add`, `git commit`, or any other git write. Committing is somebody else's job — `df:commit` when that plugin is installed, the user's own hands otherwise — and `docs/` lands in its own commit so that a bad compile is recoverable with one `git revert`
- Do not report success while an unresolved contradiction or an unevidenced factual claim remains. This is a whole-run failure rather than a per-page one: partial updates across `architecture/`, `decisions/`, and the file `map:` names can end up disagreeing with each other
- A repeat `weave pending` over unchanged sources produces no diff — no timestamp bumps, no ledger row. A non-capture source the ledger records at its current hash is not in that list, and the list is the check, not a re-read. A source named by filename, and every capture record, is outside this rule
- Never rewrite an existing `.kb/schema.md`
- Never write a page under `docs/` that the map does not reach
- An adoption run ends at its report, and that report lists the tree's own findings as the owner's backlog rather than resolving them: the run adopted pages, it did not compile claims, so the whole-run rule above has nothing of this run's to judge

</constraints>

<anti_patterns>

- Creating a dated summary page per source
- Promoting a plan to `architecture/` because the plan exists
- Deleting a conflicting claim instead of flagging it on the page that won
- Compiling the whole corpus when the user named a few sources
- Following a reference out of the named class into the rest of the raw corpus. A record naming a plan does not put that plan in scope

</anti_patterns>

<success_criteria>

- The run ends in a `git diff` under `docs/` that a human reads in one sitting
- The second source on a topic changed an existing page instead of adding a sibling

</success_criteria>
