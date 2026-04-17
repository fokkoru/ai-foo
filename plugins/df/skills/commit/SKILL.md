---
name: commit
description: Use when the user explicitly asks to create one or more git commits from current working tree changes. Creates focused, atomic commits by analyzing changes and grouping them logically using Conventional Commits format, with a required user-confirmation step before staging or committing.
allowed-tools: Read, Bash(git status:*), Bash(git diff:*), Bash(git add:*), Bash(git commit:*), Bash(git restore --staged:*), Bash(git log:*), Bash(git branch:*)
shell: bash
model: haiku
---

<objective>
Create focused, atomic commits by analyzing changes and grouping them logically using Conventional Commits format.

**Core principle:** Analyze → Group → Confirm → Execute → Verify.

**Announce at start:** "I'm using the df-commit skill to create atomic commits with logical grouping."
</objective>

<context>
Current repository state, captured at skill-load time:

- git status: !`git status`
- diff summary (shortstat): !`git diff --stat HEAD`
- current branch: !`git branch --show-current`
- recent commits: !`git log --oneline -5`
</context>

<quick_start>

1. Review the `<context>` block above (status, shortstat, branch, recent commits)
2. Run `git diff HEAD -- <file>` for files whose content you need to read for grouping decisions
3. Determine logical grouping strategy (single vs multiple commits)
4. Present commit plan and wait for user confirmation
5. Execute staged commits with conventional messages
6. Verify with `git status` and `git log`
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

### Step 3: Present Plan

Present the commit plan and wait for confirmation:

```
I plan to create N commit(s):

1. type(scope): message
   - file1.ts
   - file2.ts

2. type(scope): message
   - file3.ts

Proceed?
```

Subject lines must follow the rules in `<message_rules>` below: imperative mood, ≤50 characters, no trailing period.

Do not stage or commit until the user confirms. Read-only inspection commands (`git diff <file>`, `git status`) may still run if needed to answer follow-up questions.

### Step 4: Execute

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

### Step 5: Verify

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

<message_quality>

Write commit messages that explain WHY, not just WHAT:

**Focus on:**

- Why the change was made (motivation, context)
- Key decisions and tradeoffs behind the approach
- Impact or implications of the change

**Avoid:**

- Mechanical lists of files modified without context
- Restating what's obvious from the diff
- Generic summaries that don't add value beyond the type/scope

The type and scope convey WHAT changed. The message body should convey WHY it matters.

</message_quality>

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

<message_rules>

- **NEVER add AI signatures** — no `Co-authored-by: Claude`, no "Generated with Claude Code", no "🤖" markers. The user adds co-authors manually if they want them.
- **Focus on WHY, not WHAT** — the diff shows what changed. The message explains motivation, constraints, tradeoffs.
- **Subject line**: imperative mood, ≤50 chars, no trailing period. Lowercase after the colon unless proper noun.
- **Body** (when present): wrap at ~72 chars per line. One blank line between subject and body.
- **Footer** (when present): one blank line after body. Use the tokens in `<commit_format>`.
- **Breaking changes**: use both `!` on subject and `BREAKING CHANGE:` footer for clarity.

</message_rules>

<scope_anti_patterns>

- Suggesting code changes or fixes while committing
- Reformatting or linting files before committing
- Creating overly granular commits for trivially related changes
- Investigating why changes were made — focus on what changed
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
