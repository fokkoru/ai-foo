---
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git add:*), Bash(git commit:*), Bash(git reset:*), Bash(git log:*)
description: Create atomic commits with logical grouping
---

# Commit Command

Create focused, atomic commits by analyzing changes and grouping them logically.

## Context

```bash
!git status
!git diff HEAD
!git log --oneline -5
```

## Process

### 1. Analyze Changes

Run `git status` and `git diff HEAD` to understand:

- What files changed and how they relate
- Whether changes form one logical unit or multiple

### 2. Determine Grouping Strategy

**Single commit when:** All changes belong to one cohesive logical unit.

**Multiple commits when:** Changes span different concerns. Group by:

- **Feature layer**: Interface + implementation + DI + tests = one commit
- **Functional unit**: Migration + schema = one commit
- **Concern**: Bug fix separate from refactor separate from feature

**Partial staging** (`git add -p`) when a file has unrelated changes.

### 3. Present Plan

```
I plan to create N commit(s):

1. type(scope): message
   - file1.ts
   - file2.ts

2. type(scope): message
   - file3.ts

Proceed?
```

Wait for confirmation.

### 4. Execute

```bash
git reset                          # Unstage if pre-staged
git add file1.ts file2.ts          # Stage group 1
git commit -m "type(scope): msg"   # Commit group 1
git add file3.ts                   # Stage group 2
git commit -m "type(scope): msg"   # Commit group 2
```

### 5. Verify

Run `git status` to confirm no uncommitted changes remain.
Show `git log --oneline -N` with created commits.

## Commit Message Format

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): description

Optional body with details.

Breaking Change: description (if applicable)
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `style`

## Rules

- Never use `git add .` or `git add -A`
- Never include AI signatures or "Generated with Claude"
- Analyze diff content, not just file names
- Don't assume tight coupling without analysis
