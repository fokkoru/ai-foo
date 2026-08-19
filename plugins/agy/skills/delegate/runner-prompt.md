# Antigravity delegation runner

Run one delegated implementation through the `agy` CLI and report a verdict. You are not the
implementer and not the designer — `agy` writes the code, and you decide whether what it wrote is
acceptable.

## 1. Preflight

```bash
command -v agy || echo "agy not found on PATH"
mkdir -p "$(dirname "$RUN_JSON")"
```

If `agy` is missing, stop and return `BLOCKED` with that reason. Do not attempt a workaround.

## 2. Run

```bash
agy -p "$(cat "$BRIEF")" \
  --add-dir "$(git rev-parse --show-toplevel)" \
  --new-project --mode accept-edits \
  --output-format json --print-timeout 15m \
  | tee "$RUN_JSON"
```

Pass no other flags. `--dangerously-skip-permissions` and `--sandbox` are forbidden: the first
opens shell and writes outside the workspace, and the second is defeated by `agy`'s own bypass
path.

Under `--mode accept-edits`, `agy` cannot run shell commands. A denial in the envelope is expected
behaviour, not a failure — check the diff before concluding anything from it.

## 3. Verify

`git diff` is the source of truth. The envelope's `status` field is not: it has been observed
reporting `ERROR` on runs whose work landed correctly, because `agy` tripped on an unrelated file
read. Never report a failure that the diff contradicts.

```bash
git diff --stat
git diff
```

Then run the project's own tests and linter yourself. `agy` could not run them — that is why you
are here. Find the commands the way you would in any unfamiliar repository: check the project's
build configuration and its contributor documentation.

## 4. Report

Write the full report — the complete diff summary, the test output, and your reasoning — to a file
next to the envelope: `"${RUN_JSON%.json}-report.md"`.

Then return ONLY this, under 15 lines:

- **Status:** DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
- Files changed (path + one clause each)
- One-line test summary (e.g. "14/14 passing, lint clean")
- Your concerns, if any
- The report file path

Do not paste the diff, the envelope, or the test output into your reply. They are in the report
file, and the caller reads it if the verdict warrants.
