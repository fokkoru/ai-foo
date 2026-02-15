---
allowed-tools: Read, Bash(git status:*), Bash(git diff:*), Bash(git add:*), Bash(git commit:*), Bash(git restore --staged:*), Bash(git log:*)
description: Create atomic commits with logical grouping
---

<objective>
Create focused, atomic commits by analyzing changes and grouping them logically using Conventional Commits format.
</objective>

<quick_start>

1. Run `git status` and `git diff HEAD` to analyze all changes
2. Determine logical grouping strategy (single vs multiple commits)
3. Present commit plan and wait for user confirmation
4. Execute staged commits with conventional messages
5. Verify with `git status` and `git log`
</quick_start>

<workflow>

### Step 1: Analyze Changes

Run `git status` and `git diff HEAD` to understand:

- What files changed and how they relate
- Whether changes form one logical unit or multiple
- Recent commit history for message style consistency (`git log --oneline -5`)

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

Do not execute any git commands until the user confirms.

### Step 4: Execute

For each commit group:

```bash
git add file1.ts file2.ts          # Stage specific files
git commit -m "type(scope): msg"   # Commit with conventional message
```

If files were pre-staged, run `git restore --staged .` first to start clean.

### Step 5: Verify

Run `git status` to confirm no uncommitted changes remain.
Show `git log --oneline -N` with the created commits.

</workflow>

<commit_format>

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): description

Optional body with details.

Breaking Change: description (if applicable)
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `style`

</commit_format>

<success_criteria>

- All logical change groups committed with appropriate conventional messages
- No uncommitted changes remain (unless user chose to defer some)
- Each commit is atomic and self-contained
- Commit messages accurately describe the changes based on diff content
</success_criteria>

<guidelines>
- NEVER use `git add .` or `git add -A` — always stage specific files by name
- NEVER include AI signatures — no "Generated with Claude" or "Co-Authored-By" lines
- Analyze diff content, not just file names — understand what actually changed to write accurate messages
- Don't assume tight coupling — verify that files belong together by reading the diffs
</guidelines>

<anti_patterns>

- Suggesting code changes or fixes while committing
- Reformatting or linting files before committing
- Creating overly granular commits for trivially related changes
- Investigating why changes were made — focus on what changed
- Running tests or builds as part of the commit process

Stay focused on creating clean, well-grouped commits.
</anti_patterns>

<circuit_breakers>
Stop and ask the user for guidance if:

- Working tree has no changes to commit
- Changes appear to include sensitive files (.env, credentials, keys)
- Staged changes conflict with unstaged changes in the same files
- More than 5 logical commit groups identified (scope may be too large)
- Unsure whether changes should be one commit or multiple

When triggered: present the issue clearly, explain what was found, and ask how to proceed.
</circuit_breakers>

<constraints>

- **NEVER commit without user confirmation** — always present the plan first and wait for explicit approval
- **NEVER stage all files** — use specific file names, never `git add .` or `git add -A`
- **NEVER add AI signatures** — no Co-Authored-By, no "Generated with" lines in commit messages
- **NEVER modify code during commit** — this command only stages and commits existing changes

</constraints>
