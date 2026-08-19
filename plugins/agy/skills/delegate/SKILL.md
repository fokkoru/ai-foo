---
name: delegate
description: Hand an already-decided implementation to the Google Antigravity CLI so the edits happen outside this context. A subagent runs agy under accept-edits, verifies the result with git diff and the project's tests, and returns a verdict under 15 lines. Use when the plan exists and only the typing remains.
disable-model-invocation: true
allowed-tools: Read, Write, Task, Grep, Glob, LS, Bash(command -v agy), Bash(git rev-parse:*), Bash(mkdir:*), Bash(date:*), Bash(printf:*)
---

<objective>
Hand an already-decided implementation to `agy` so the edits happen outside this context, and bring back a verdict rather than a transcript.

A subagent exists not because `agy`'s output is large — the JSON envelope is compact — but because verification moved to the caller's side once shell closed under `accept-edits`. `git diff`, test output, and reading the run JSON are noise that this skill exists to keep out of the main context, and the subagent is where that noise stays.

</objective>

<quick_start>

1. Check the binary:

```bash
command -v agy
```

If it is missing, stop and say so — do not attempt the run.

2. Confirm the task qualifies: a decision already made, no shell needed inside the run, and a one-sentence acceptance criterion.
3. Print the three run paths — brief, envelope, report.
4. Write the brief to the printed brief path.
5. Dispatch `Agent(general-purpose)` with `runner-prompt.md`, the three paths substituted in, and act on the returned verdict.

</quick_start>

<workflow>

### 1. Confirm the task qualifies

Reject and say why if any of these hold:

- The decision has not been made. `agy` executes; it does not design. Send the question to `/agy:consult` or settle it here first.
- The work needs shell inside the run — a migration, code generation, `npm install`. Split the task; do not open the permission surface.
- There is no acceptance criterion. Nothing to verify means nothing to delegate.

### 2. Print the run paths

```bash
REPO="$(git rev-parse --show-toplevel)"
RUN_DIR="${TMPDIR:-/tmp}/agy-runs/${REPO##*/}"
RUN="$RUN_DIR/run-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RUN_DIR"
printf 'BRIEF=%s\nRUN_JSON=%s\nRUN_REPORT=%s\n' "$RUN-brief.md" "$RUN.json" "$RUN-report.md"
```

Read the three absolute paths this prints and write each one out literally wherever it is used below. The variables above live and die inside this one command: shell state does not survive to the next Bash call, does not reach `Write` — which performs no expansion at all — and does not cross into the subagent, which runs its own shell. `RUN_DIR` is keyed off the repository's own basename, so runs from different repositories never collide.

### 3. Write the brief

Write to the `BRIEF=` path Step 2 printed with `Write`, never inline in the command. The brief contains four parts: the task, the exact files in scope, the acceptance criterion, and this instruction verbatim: "Edit files only. Do not run any shell command — you do not have permission to, and the attempt will end the run."

### 4. Dispatch the subagent

Read `runner-prompt.md` — a path relative to the base directory the harness announces for this skill, not to the working directory, since the file ships inside the installed plugin while the working directory is the user's project. Then replace each `{{…}}` token in it with the matching absolute path Step 2 printed: `{{BRIEF}}`, `{{RUN_JSON}}`, `{{RUN_REPORT}}`. Dispatch `Agent(general-purpose)` with the result. A `{{…}}` token is not shell syntax, so an unreplaced one arrives at the subagent as a visible literal instead of expanding silently to an empty path and writing the report into the user's repository.

The skill itself never runs `agy` — that is the subagent's job, and running it here would put the verification noise back in the context this skill exists to protect.

### 5. Act on the verdict

Read the returned block. On `DONE`, report the change and the test line to the user. On `DONE_WITH_CONCERNS` or `NEEDS_CONTEXT`, read the report file before deciding. On `BLOCKED`, report the reason and the run path; do not re-dispatch automatically — a second identical run costs the same and fails the same way.

</workflow>

<artifact_scope>

The plugin's own artifacts never land inside the user's repository, so the plugin never forces a `.gitignore` edit on the project that installs it. The brief, the envelope, and the report are the three paths Step 2 prints, and all three sit under `${TMPDIR}/agy-runs/<repo>/`. The repository's own files are changed by `agy` inside the workspace, which is the point of the skill — the plugin's own artifacts are not.

</artifact_scope>

<constraints>
- Never pass `--dangerously-skip-permissions`. It auto-approves every tool call, shell included.
- Never pass `--sandbox`. Under `accept-edits` it adds nothing, since shell is already closed; under skip-permissions a probe showed `agy` bypassing it through its own escape path, and that pairing is the only one the bypass was measured in.
- Never pass `--model`. The user's `agy` configuration decides.
- Never treat `status` as the verdict. `git diff` is the truth; `status` has been observed reporting `ERROR` on runs whose work landed.
- Never delegate work whose acceptance criterion you cannot state in one sentence.

</constraints>

<anti_patterns>

| Excuse                                                           | Answer                                                                                                               |
| ---------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| "The task needs one quick command — I'll add skip-permissions."  | That flag opens everything, not one command. Split the task so the command runs on this side.                        |
| "`status` says ERROR, so it failed."                             | Check the diff. `status: ERROR` with the work landed is a measured behaviour of this CLI, not a rare edge case.      |
| "I'll run `agy` here instead of dispatching — it's one command." | The command is one line; the verification around it is not, and keeping that out of this context is the whole point. |

</anti_patterns>

<success_criteria>

- The returned block is under 15 lines
- The verdict is backed by a diff the subagent actually read
- The tests were run by the subagent rather than assumed
- The run path is reported so the envelope can be reopened

</success_criteria>
