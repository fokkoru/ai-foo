---
name: commit
description: Use when the user explicitly asks to create one or more git commits from current working tree changes. Creates focused, atomic commits by analyzing changes and grouping them logically using Conventional Commits format, with a required user-confirmation step before staging or committing.
allowed-tools: Read, Skill, Bash(git status:*), Bash(git diff:*), Bash(git add:*), Bash(git commit:*), Bash(git restore --staged:*), Bash(git log:*), Bash(git branch:*)
shell: bash
---

<objective>
Create focused, atomic commits by analyzing changes and grouping them logically using Conventional Commits format.

**Core principle:** Analyze → Group → Size → Confirm → Execute → Verify.

**Announce at start:** "I'm using the df-commit skill to create atomic commits with logical grouping."
</objective>

<context>
Current repository state, captured at skill-load time:

- git status: !`git status`
- diff summary (shortstat): !`git diff --stat HEAD`
- current branch: !`git branch --show-current`
- recent commits: !`git log -5 --pretty=format:'%h %s%n%b'`
</context>

<quick_start>

1. Review the `<context>` block above (status, shortstat, branch, recent commits)
2. Run `git diff HEAD -- <file>` for files whose content you need to read for grouping decisions
3. Determine logical grouping strategy (single vs multiple commits)
4. Size each message — pick a tier, add a body only against a stated reason
5. Present commit plan and wait for user confirmation
6. Execute staged commits with conventional messages
7. Verify with `git status` and `git log`
</quick_start>

<workflow>

### Step 1: Analyze Changes

Review the `<context>` block above to understand:

- Which files changed and how they relate (from status + shortstat)
- Whether changes form one logical unit or multiple
- How recent commits are styled (for message consistency)

The `<context>` shows only a shortstat summary — not the full diff. Before building the plan, run `git diff HEAD -- <file>` (or `git diff --staged -- <file>`) for each file whose actual content you need to read. This keeps cold-trigger cost bounded while giving full fidelity for files that matter.

If the `<context>` snapshot is stale (user edited files after skill loaded), refresh with `git status` and re-diff affected files.

### Step 2: Determine Grouping Strategy

**Single commit when:** All changes belong to one cohesive logical unit.

**Multiple commits when:** Changes span different concerns. Group by:

- **Feature layer**: Interface + implementation + DI + tests = one commit
- **Functional unit**: Migration + schema = one commit
- **Concern**: Bug fix separate from refactor separate from feature

When a file contains unrelated changes, ask the user to manually stage the relevant hunks, or commit the file as-is and note the mixed concern for a future cleanup commit.

### Step 3: Size Each Message

For each group from Step 2, write these two lines down before drafting any message text:

    Tier: trivial | moderate | complex
    Body: none | required, because <one clause>

If you cannot fill in the "because" clause, the answer is none. Write the subject first. A body gets added only against a reason already written down, never drafted first and justified after.

Most commits are trivial and need no body.

If a group lands at Complex, try to split it into groups that each land at Trivial or Moderate before moving on. Splitting is the first response to complexity; a longer message is the fallback when splitting is not possible. Step 2's groupings win: never break apart files that must land together to keep the tree buildable.

### Step 4: Present Plan

Present the commit plan and wait for confirmation:

```
I plan to create N commit(s):

1. type(scope): message   [trivial]
   - file1.ts
   - file2.ts

2. type(scope): message   [moderate]
   - file3.ts
   body: one paragraph on why the timeout moved to 30s

Proceed?
```

Subject lines must follow the rules in `<message_rules>` below: imperative mood, ≤50 characters, no trailing period. Message length follows the tiers in `<commit_scale>`.

Do not stage or commit until the user confirms. Read-only inspection commands (`git diff <file>`, `git status`) may still run if needed to answer follow-up questions.

### Step 5: Execute

If files were pre-staged, run `git restore --staged .` first to start clean.

**Pre-commit hooks**: If `.pre-commit-config.yaml` exists at the repo root, hooks may reformat staged files. Handle this cleanly:

1. Stage the files for the commit
2. Let `git commit` trigger hooks
3. If hooks modify files (exit code non-zero + "files were modified by this hook"), re-stage the same files and re-run `git commit`
4. If hooks fail for non-formatting reasons, stop and present the error to the user — do not retry

For each commit group (single-line subject):

```bash
git add file1.ts file2.ts
git commit -m "type(scope): short imperative subject"
```

For commits with a body or footer, use HEREDOC to preserve formatting:

```bash
git add file1.ts file2.ts
git commit -m "$(cat <<'EOF'
feat(auth): add JWT validation

Validates tokens on every protected route. Tokens expire after 24 hours
to balance usability against session-hijacking risk.

Fixes #42
EOF
)"
```

Use the single-quoted HEREDOC (`<<'EOF'`) to prevent shell expansion of `$`, backticks, or `!` in the message body.

### Step 6: Verify

Run `git status` to confirm no uncommitted changes remain.
Show `git log --oneline -N` with the created commits.

</workflow>

<commit_format>

Follow [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/):

```
type(scope): description

[optional body]

[optional footer(s)]
```

### Type Quick Reference

| Type       | Use For                                       |
| ---------- | --------------------------------------------- |
| `feat`     | New feature                                   |
| `fix`      | Bug fix                                       |
| `refactor` | Code refactoring (no behavior change)         |
| `docs`     | Documentation only                            |
| `test`     | Adding or updating tests                      |
| `chore`    | Maintenance (deps, configs, version bumps)    |
| `perf`     | Performance improvement                       |
| `style`    | Formatting, whitespace (no logic change)      |
| `revert`   | Reverts a previous commit                     |

### Subject Discipline

- Imperative mood ("add", not "added" or "adds")
- ≤50 characters
- No trailing period
- Lowercase after the colon unless referencing a proper noun

### Breaking Changes

Two equivalent mechanisms — use both together for maximum clarity:

1. `!` before the colon on the subject: `feat(api)!: remove deprecated /v1/login endpoint`
2. `BREAKING CHANGE:` footer (uppercase required):

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

</commit_format>

<commit_scale>

Size the message to the change. The default is no body.

### The test

Read your subject line, then read the diff. Could a reviewer holding both work out why the change was made? If yes, the message is done. Ship the subject alone.

Diff size is a hint, not the rule. A 400-line regenerated file is trivial. A three-line change to lock ordering may need a paragraph.

### Tiers

| Tier     | When                                                                                  | Body                    |
| -------- | ------------------------------------------------------------------------------------- | ----------------------- |
| Trivial  | Subject plus diff already explain the change. Mechanical, generated, or self-evident. | None                    |
| Moderate | Subject is accurate, but the motivation is not visible in the diff.                   | One paragraph, ~3 lines |
| Complex  | Two or more rationales, or a tradeoff a reader would otherwise re-litigate.           | Split first, see below  |

Trivial covers version bumps, typo and comment fixes, dependency updates, formatting, renames, regenerated files, and single-file edits whose subject says everything.

Moderate covers a bug fix whose root cause is not visible in the patch, a refactor with one stated reason, a default value chosen deliberately.

Complex is a split signal before it is a writing signal. Break the change into commits that each land at Trivial or Moderate. Only when the change is genuinely atomic, meaning a split would leave the tree broken or the halves meaningless, does it earn a body: at most two short paragraphs covering the reason and the one decision a reader would otherwise question.

Split along independent concerns only. The groupings from Step 2 take precedence: a feature layer (interface, implementation, wiring, tests) and a functional unit (migration plus schema) stay in one commit even when their rationale is compound, because splitting them leaves intermediate commits that do not build. A compound rationale is not by itself a reason to split. Two independent concerns is. If splitting would push the count past five groups, `<circuit_breakers>` applies: stop and ask.

### The cap is a split signal

If a body is outgrowing its tier, the commit is too big. Split it. Do not extend the message. This is the rule the kernel and Git submitting-patches docs both state: a description that keeps growing means the patch covers more than one problem.

If a change genuinely cannot be split and still needs more than two paragraphs, stop and tell the user, naming the split you considered and why it does not work.

### Report the tier

Mark each commit with its tier in the Step 4 plan so the user can push back before anything is staged.

</commit_scale>

<message_voice>

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

Match the repository's voice. The `<context>` block shows recent full messages. Follow their register, sentence length, and punctuation habits, including whether they use em dashes.

If the `humanizer` skill is available, invoke it in embedded mode on any body before committing; it returns final text with no commentary. Its rule against diff-anchored writing does not apply here, since a commit message is version-scoped by definition and that rule exempts version-scoped documents. The tier cap still governs the result: if the returned body is longer than its tier allows, keep the shorter text. If humanizer is not installed, the rules above are the baseline, not a fallback.

</message_voice>

<message_rules>

- **NEVER add AI signatures** — no `Co-authored-by: Claude`, no "Generated with Claude Code", no "🤖" markers. The user adds co-authors manually if they want them.
- **Message length**: sized by `<commit_scale>`, written per `<message_voice>`. Most commits are subject-only.
- **Subject line**: imperative mood, ≤50 chars, no trailing period. Lowercase after the colon unless proper noun.
- **Body** (when present): wrap at ~72 chars per line. One blank line between subject and body.
- **Footer** (when present): one blank line after body. Use the tokens in `<commit_format>`.
- **Breaking changes**: use both `!` on subject and `BREAKING CHANGE:` footer for clarity.

</message_rules>

<success_criteria>

- All logical change groups committed with appropriate conventional messages
- No uncommitted changes remain (unless user chose to defer some)
- Each commit is atomic and self-contained
- Commit messages accurately describe the changes based on diff content
</success_criteria>

<staging_rules>

- **NEVER stage without user confirmation** — always present the plan first and wait for explicit approval. Read-only commands (`git status`, `git diff`, `git log`) may run as needed to build the plan.
- **NEVER stage all files** — use specific file names only. Never `git add .`, never `git add -A`, never `git add *`.
- **NEVER modify code** — this skill only stages and commits existing changes. No reformatting, no linting, no "while I'm here" fixes.
- Verify file coupling by reading diffs, not just file names. A shared filename does not imply shared concern.

</staging_rules>

<scope_anti_patterns>

- Suggesting code changes or fixes while committing
- Reformatting or linting files before committing
- Creating overly granular commits for trivially related changes
- Digging through issue trackers or prior branches to reconstruct rationale — use what the diff and this session give you
- Running tests or builds as part of the commit process

Stay focused on creating clean, well-grouped commits.
</scope_anti_patterns>

## Integration

**Called after:**

- `/df:implement` — after implementing a plan phase
- `/df:validate` — after verifying implementation against plan

**Pairs with:**

- `/df:handoff` — for session transfers after committing

<circuit_breakers>
Stop and ask the user for guidance if:

- Working tree has no changes to commit
- Changes appear to include sensitive files (.env, credentials, keys)
- Staged changes conflict with unstaged changes in the same files
- More than 5 logical commit groups identified (scope may be too large)
- Unsure whether changes should be one commit or multiple

When triggered: present the issue clearly, explain what was found, and ask how to proceed.
</circuit_breakers>
