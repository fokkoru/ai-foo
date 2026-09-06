---
name: weave
description: Weave raw sources under thoughts/ into the project's long-term memory — a durable, committed knowledge base under docs/ of OKF-conformant pages, routed by whether a claim is a verified fact about the current code or a proposal, each carrying per-source provenance
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Grep, Glob, LS, Bash(date:*), Bash(git config:*), Bash(git rev-parse:*), Bash(*check-docs.sh*)
---

<objective>
Turn accumulated raw sources into pages that get smarter, not into more siblings. The output under `docs/` is the project's long-term memory: the layer a later session reads instead of re-reading the raw notes, and the layer a new contributor reads instead of asking.

This is a batch pass somebody runs, not a recall mechanism that fires on its own, which is why it is not called "memory" — that word already names mechanisms in both runtimes that inject context automatically, and this one never does. It is called `weave` because a second source on a topic is worked into the page that already covers it rather than filed beside it, and that is the test the skill gives for its own success.

The input is a directory of markdown. `thoughts/` is not any plugin's artifact, and a project that has never installed another plugin compiles its own notes with this skill unchanged.

</objective>

<artifact_scope>
Writes are allowed under `docs/` only.

`thoughts/**` is denied. Before any Write or Edit call, verify the target path is inside `docs/` — if it is not, stop and ask the user.

Inspection is not enough to prove that denial held. A project may hide `thoughts/` from git, in which case a write into it never appears in `git status` and nothing downstream would catch it. That is why Step 0 snapshots and Step 6 verifies.

</artifact_scope>

<quick_start>
If sources are named, begin at Step 0.

If no sources are named, ask which ones to compile and wait for the answer. Never default to the whole corpus — a first run over everything produces a tree nobody reviews.

`weave captures` names a class rather than filenames: the pending capture records, whichever they turn out to be. `check-docs.sh captures-eligible <records root> docs/kb-receipt.tsv` computes that class from the receipt and the records on disk. An invocation naming unrelated files absorbs no captures, and a bare invocation still asks and waits.

`weave reconsider` is the pass that returns to what an earlier run deferred: `check-docs.sh captures-deferred <records root> docs/kb-receipt.tsv` lists those decisions, and the run re-examines each against current evidence and consumes any that now route. A deferred decision does not wake on its own — nothing schedules this pass, and reaching a deferred decision takes a run somebody starts.

0. Claim, seed and snapshot
1. Read the sources and scan for supersession
2. Route each claim
3. Produce updates, not siblings
4. Write provenance
5. Update `index.md` and `log.md`
6. Check
7. Report

</quick_start>

<workflow>

### Step 0: Claim, seed and snapshot

Everywhere below, including this step, `check-docs.sh` means `../../scripts/check-docs.sh` relative to the base directory the harness announces for this skill, not a command on `PATH` — the checker lives in the plugin's own `scripts/` rather than this skill's, because it is shared, and the working directory is the project being compiled. Every `references/` path below hangs off the announced directory directly. Resolve both once, here, and reuse them.

Take the run's claim first, before anything else, with `check-docs.sh claim-acquire "${CLAUDE_SESSION_ID}" $PPID`. Keep the run id it prints. One claim covers the whole run rather than the snapshot and the verification separately: a capture publishes into the raw layer during a live session, so a gap in the middle is a gap another writer can use, and this run edits the compiled layer in that middle with nothing staged and nothing to roll back.

`$PPID` inside a shell the harness starts for you is the harness process itself, observed on Claude Code 2.1.261. That process is what the claim names as its owner, which is what lets a later run tell an abandoned claim from a live one.

If the claim is refused, stop and report what `claim-acquire` printed. A live owner means another run is going; an abandoned one means a run died, and somebody has to look at what it left in `docs/` before the claim is released by hand.

Then run `check-docs.sh snapshot`. It records a hash of every file under the raw root and prints the path of the manifest holding them. Keep that path: Step 6 needs it, and it names this run's manifest alone, so a compile running beside this one cannot be confused with it.

Then settle what `docs/` already is:

| State of `docs/`                          | Do this                                                                                                     |
| ----------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `docs/WIKI.md` exists                     | Read it. It is authoritative and outranks this file wherever the two disagree                               |
| `docs/` absent or empty                   | Read `references/wiki-template.md` and write it unchanged to `docs/WIKI.md`, then report that you seeded it |
| `docs/` has content but no `docs/WIKI.md` | Stop and ask the user to confirm the target directory before writing anything                               |

The third row is a hand-written documentation tree, not a knowledge base with a missing file. Overwriting one is the single most expensive mistake this skill can make.

### Step 1: Read the sources and scan for supersession

Read every named source completely. A source is the unit the user named; reading half of one produces a page that cites a fragment nobody checked.

Then read `docs/index.md` and, for every topic the sources touch, the pages it names. You cannot update a page you have not read, and Step 3 turns on knowing which pages already exist.

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

The first row has a gate: a claim reaches `architecture/` or `product/` only after you have located the behaviour at a `file:line` in the current code. That location becomes the entry's `sources[]` record, with `fragment: "L<start>-L<end>"`.

A `sources[]` entry names tracked code or checked-in config, and never an internal note. The raw root is not in a fresh clone, so a citation into it names a file the reader does not have, and a claim nobody else can check is not a fact this layer records. The checker reports one. A capture record is refused separately and for a different reason: a record sits outside the source trust order entirely, never competing for a page and never cited by one. What it does is send you to look at the code, the config and the plans.

An external source is cited in the page body instead, never in `sources[]`, so the two rules never overlap. Mark the claim `[reported]` and put the URL and `retrieved YYYY-MM-DD` on the same line. External sources stay informal — no snapshot file, no drift checking, no refresh mode — and the checker reports a `[reported]` line missing either half.

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

Deprecating a page is three edits, not a frontmatter change. The page stays linked from its index, because the checker grants a deprecated page no reachability exemption. Its body and its index description stop asserting the rule that was withdrawn. And its `sources[]` stay as they are and go on being provenance-checked — a deleted resource still gets `retired: true`, the same as anywhere else.

A source that fits no directory is not forced into one. Say so in the report and leave it uncompiled — a wrong home costs more than an absence, because the next run reads the wrong home as settled.

### Step 3: Produce updates, not siblings

Read `references/page-templates.md` before writing any page. It holds the six skeletons — one per page type, plus the bundle-root `index.md` and `log.md` — and it is where the frontmatter shape is written down. A page written without it is a page whose keys were invented. The checker validates `type` and every `sources[]` entry; `title`, `description`, `status`, and `generated` it never sees, so nothing downstream would notice.

For each source, name the existing page its claims land on before writing anything.

Write a new page only when the report can carry one sentence naming which existing pages you considered and why none of them is the home. That sentence goes in the report and into `log.md`.

This is the step the whole skill exists for. A knowledge base that gains a page per source is a second copy of the raw notes with worse search.

### Step 4: Write provenance

Every page gains or updates its `sources[]` entries. Each entry carries:

- `resource` — the path, relative to the repository root
- `id` — a short stable slug, which the page body cites as `[^slug]`; OKF makes this label the join key a consumer resolves attribution through
- `fragment` — the exact cited heading line, an `L<start>-L<end>` range for a resource with no headings, or `(whole)`
- `sha256` — the first 12 hex characters of the hash over that fragment

Get the hash from the checker rather than computing one yourself. Write the entry with `sha256: "unset"`, run `check-docs.sh check`, and read the value back off the line it prints:

```
source-drift(docs/architecture/routing.md): sources[1] records unset for L10-L20 of src/router.go, which now hashes to 3d4cea08f41a
```

Then write `3d4cea08f41a` into the entry. The checker owns the normalization — trailing whitespace, leading and trailing blank lines — so a hash produced any other way is a hash that will disagree with the tool that later checks it.

An entry whose `resource` no longer exists gets `retired: true` and a `log.md` line. Do not delete it: the page keeps the record of where its claim came from.

A new decision page also gets its `decision_id`, which is how a supersession reference names the decision across an editorial rename. Write the page with `decision_id: "unset"`, then run `check-docs.sh assign-id <page>` and write the value it prints into the key. Assign it once: a later edit to the page never reassigns it, and a substantively different decision is a new page with its own.

### Step 5: Update index.md and log.md

Every page must be reachable from `docs/index.md` by following relative links. A page written and not linked is the most common failure of this whole workflow, which is why the checker fails on it.

`log.md` carries one section per day, newest first, holding `**Creation**`, `**Update**`, and `**Deprecation**` bullets that link the pages they affected. If a section for today already exists, append this run's bullets to it rather than opening a second one — two runs in a day is the ordinary case, not a failure, and the checker reports two sections carrying one date.

### Step 6: Check

Run `check-docs.sh check`, then `check-docs.sh verify-sources <manifest>` with the manifest path Step 0 printed.

Fix whatever the first reports and run it again.

A failure from the second is different in kind. It means this run wrote into the raw layer, which `<artifact_scope>` forbids. That is a defect in the run, not a finding to hand to the user: say so plainly, name the files, and stop.

Once both pass, and not before, write the receipt. Stage one tab-separated line per decision this run touched — `<record path>\t<state>\t<decision heading>`, where the state is `consumed` or `deferred` — then run `check-docs.sh receipt-commit docs/kb-receipt.tsv <records root> <staging file>`. It computes each record's identity itself, validates the whole set, and writes nothing unless all of it validates, so a run that stops here leaves no entry.

Acknowledgement is per decision, never per record: a record is routinely half compiled and half deferred, and marking the whole file done would lose the deferred half. "Offered", "confirmed" and "read for context" are not acknowledgement. A decision that routed nowhere is `deferred` and waits indefinitely — nothing expires, and only a run the owner starts returns to it.

The receipt is committed alongside the pages it describes, so reverting a bad run reverts its bookkeeping too.

Release the claim with `check-docs.sh claim-release <run id>` once Step 6 is done, and also on the halt path above after reporting. Holding it through a halt buys nothing: the user has already been told exactly what went wrong, while a claim left behind blocks the next run until this session's process dies and then makes somebody inspect a compiled layer they already know the state of.

### Step 7: Report

Report:

- the captures consumed, and separately the eligible records left alone — a model-chosen scope is not reproducible from the invocation and the repository state, only from being written down
- any record opened for context, named as such: a contextual read is not intake and produces no receipt entry
- pages created, and for each, the one sentence from Step 3
- pages updated
- sources consumed, and any source that found no home
- `log.md` lines added
- the result of both checker runs

On the run that seeded `docs/WIKI.md`, print — never write — a `## Documentation` block for the user to paste into their own instructions file, pointing a later session at `docs/` before `thoughts/`.

Close by saying that `docs/` is ready to be committed on its own.

</workflow>

<constraints>

- Never write, move, or delete anything under `thoughts/`. This is verified by `snapshot` in Step 0 and `verify-sources` in Step 6, not by inspection
- Never run `git add`, `git commit`, or any other git write. Committing is somebody else's job — `df:commit` when that plugin is installed, the user's own hands otherwise — and `docs/` lands in its own commit so that a bad compile is recoverable with one `git revert`
- Do not report success while an unresolved contradiction or an unevidenced factual claim remains. This is a whole-run failure rather than a per-page one: partial updates across `architecture/`, `decisions/`, and `index.md` can end up disagreeing with each other
- A repeat run over unchanged sources produces no diff — no timestamp bumps, no `log.md` entry, nothing. Skip a source whose every recorded fragment hash still matches on every page citing it
- Never rewrite an existing `docs/WIKI.md`

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
