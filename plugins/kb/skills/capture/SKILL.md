---
name: capture
description: Record a decision this session reached — what was chosen, what was rejected, and why — into thoughts/captures/ before the session ends. Use when a session settles a question, picks between options, changes its mind, or finishes a design discussion.
allowed-tools: Read, Write, Grep, Glob, LS, Bash(date:*), Bash(git status:*), Bash(git log:*), Bash(git rev-parse:*), Bash(mkdir:*), Bash(mv:*), Bash(*check-docs.sh*)
---

<objective>
A session reaches a conclusion, the session ends, and the conclusion is gone. The code shows what was chosen and never why, so the rejected alternative and the reason are the parts nothing else preserves.

This skill writes them down while the session is still running, into a record the knowledge base compiler can later read. It fires on its own, because a conclusion that has to be remembered before it is written down is a conclusion that gets lost.

It never writes the compiled layer. A second writer there would bypass routing, evidence checking, contradiction handling and page consolidation.

</objective>

<quick_start>

Everywhere below, `check-docs.sh` means `../../scripts/check-docs.sh` relative to the base directory the harness announces for this skill — the checker lives in the plugin's own `scripts/`, not this skill's. Resolve it once, here.

1. Decide whether there is a decision to record
2. Write the record to the staging directory
3. Try the claim, and publish if it is free
4. Report, and offer a run

</quick_start>

<workflow>

### Step 1: Decide whether there is a decision to record

The live conversation is primary for the decision, the rejected alternative and the reason. Git and the tracked tree corroborate what was implemented and supply the evidence pointer. A diff carries two of those four parts and cannot reconstruct the other two, so it is never the whole input.

**Skip a record only when durable sources already preserve the whole decision, including its reason and the alternative that was rejected.** Code shows what was chosen and never why, so a rule that skipped anything derivable from the code would discard precisely what this exists to keep. The exclusions hold even when the user asks for a record anyway.

When in doubt, write nothing. The doubt is about whether a durable, non-redundant decision was reached — never about whether code exists. A decision with nothing built behind it is the case this skill exists for: record it with the absence marked, never refuse it for that.

A session that reached no durable conclusion produces no file. Say that in the report; it is a different outcome from being unable to capture.

The number of records a session produces is yours to decide. It is not one per session and not one per turn — it is one per decision that stands on its own.

### Step 2: Write the record to the staging directory

Write to `.git/kb-staged/<session id>-<n>.md`, outside the raw layer and outside every snapshot, so nothing exists in `thoughts/` until publication.

```markdown
# Capture: <topic>

## Decisions

### <the decision, as its own heading, unique within this record>

Rejected: <the alternative>
Because: <the reason>
Evidence: <a pointer to a durable source, or `none` when there is no implementation>
Supersedes: <one reference per line, omitted when this supersedes nothing>

## Reversed inside this session

## What the session said

## Still open
```

The record carries no frontmatter. Decisions are the immediate `###` headings under `## Decisions`; a `###` inside a fenced block is not one.

A `Supersedes:` reference names one decision, never a whole file, in one of two forms:

```
Supersedes: decision <decision_id>
Supersedes: record <path> ### <the literal heading line>
```

**A conclusion reversed later in the session goes under `## Reversed inside this session`, never as a silent overwrite of the original.** The reversal is itself part of what happened, and a record that shows only the final answer hides the fact that the question was reopened.

**The owner's words go under `## What the session said`, marked as speech.** The compiler reads the raw layer as source material, so an unmarked remark becomes evidence for a claim nobody made.

**Every part the runtime could not supply is marked missing, never omitted and never inferred.** No record is suppressed for being incomplete: a record with three of four parts and the fourth marked missing is worth more than no record.

Then run `check-docs.sh check-capture <staged file>` and fix whatever it reports before going on.

### Step 3: Try the claim, and publish if it is free

Snapshot the compiled layer first: `check-docs.sh snapshot docs`. Keep the manifest path.

Try the claim once: `check-docs.sh claim-acquire "$CLAUDE_SESSION_ID" $PPID`. Once — not again, and never in a loop.

If the claim is refused, leave the record where it is, marked unpublished, and continue the session with no delay. Nothing waits for the claim to free up.

If the claim is held, publish: create `thoughts/captures/` if it is absent and move the staged file into it. A published record is immutable — never edit or delete one that was published earlier, including one you wrote. `thoughts/captures/` is append-only, and it stays untracked.

Then verify what you touched: `check-docs.sh verify-sources <manifest> docs`. It proves the compiled layer did not move while you wrote, which `git status` cannot do — a project may hide a directory from git, and a write into it then shows up nowhere.

Release the claim: `check-docs.sh claim-release <run id>`.

### Step 4: Report, and offer a run

Three outcomes, and they stay distinguishable. Never write the third as the second.

| Outcome                            | Say                                                       |
| ---------------------------------- | --------------------------------------------------------- |
| Captured                           | which records were published, and each decision they hold |
| Examined, and it held no decisions | that the session reached no durable conclusion            |
| Still pending                      | that a record is staged and unpublished, and where it is  |

Then offer a weave run naming the published record, and stop. The owner confirms and invokes `/kb:weave` themselves: weave is manual-only on purpose, and whether a bare confirmation can activate a manual-only skill is a harness question this skill does not get to answer for itself.

</workflow>

<artifact_scope>

- Writes `.git/kb-staged/` and `thoughts/captures/`, and nothing else
- Never writes anything under the compiled layer, verified after the write rather than inspected in `git status`
- Never edits or deletes a published record
- Never runs `git add`, `git commit`, or any other git write

</artifact_scope>

<constraints>

- Never read weave's body and carry out its steps. That routes around a manual-only gate, and the compiled layer is not this skill's to write
- Never compile an unpublished staging file, and never offer one for compilation
- Never treat the absence of an implementation as a reason to refuse a record
- Never write "could not capture" as "concluded nothing"

</constraints>

<anti_patterns>

- **One record per session.** The session boundary is not a decision boundary. A design session reaches several independent conclusions and a long implementation session reaches none
- **Waiting for the claim.** One attempt, then carry on. A session that pauses to take a lock is a session the owner notices
- **Recording the outcome and dropping the reason.** The outcome is in the code already. The reason is the whole reason this file exists
- **Quoting the owner as if it were evidence.** Speech goes under `## What the session said`, marked as speech

</anti_patterns>

<success_criteria>

- Every published record passes `check-docs.sh check-capture`
- `thoughts/captures/` gained files and the compiled layer did not change
- The report names which of the three outcomes happened

</success_criteria>
