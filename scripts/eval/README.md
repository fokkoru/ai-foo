# Prompt A/B harness

Compares two or more variants of a prompt by running the same fixed tasks under each and measuring
what comes back. A variant is called an **arm**, a fixed task is a **cell**, and one run of one arm
on one cell is a **repetition**.

These are maintainer tools for this repository. They ship to nobody: a user installing a plugin
receives `plugins/<name>/**` and nothing else.

This file is how to run an experiment. Why an experiment is shaped the way it is — what the unit of
analysis is, how many cells to run, when a judge is needed at all, and which readings are allowed to
decide anything — belongs to the prompt evaluation methodology in the knowledge base under `docs/`.
Read that before designing one.

## An experiment directory

Everything specific to a comparison lives in one directory, and the scripts take that directory or
one of its results directories as their only handle.

| Path                 | Required | What it is                                                                               |
| -------------------- | -------- | ---------------------------------------------------------------------------------------- |
| `experiment.env`     | yes      | Sourced by `run.sh` and `drive.sh`. Sets `INJECT`, the arm and model defaults            |
| `arms/`              | yes      | The variants. Shape depends on `INJECT`                                                  |
| `prompts/<cell>.txt` | yes      | One file per cell. The cell name is any string with no underscore                        |
| `metrics.py`         | yes      | `score(text) -> dict`, plus optional `LABELS` and `EXCLUDE_CELLS`                        |
| `fixture/`           | no       | A working tree copied into each run, so a cell can involve real files                    |
| `judge-rubric.txt`   | no       | Plain-text rubric handed to a judge                                                      |
| `judge-schema.json`  | no       | JSON schema the judge's output must satisfy                                              |
| `ground-truth.csv`   | no       | The true answer per cell, where a cell has one                                           |
| `<results-dir>/`     | produced | One per run: responses, raw event streams, scores, masked review copies, the sweep queue |

A second run of the same experiment writes to a second results directory, set with `RESULTS`, so
runs never overwrite each other.

## How an arm reaches the model

`INJECT` in `experiment.env` names the substitution point. Each is a flag `claude -p` documents in
`claude -p --help` on 2.1.259.

| `INJECT`               | `arms/` holds       | Flag                                   |
| ---------------------- | ------------------- | -------------------------------------- |
| `output-style`         | `*.md` style bodies | `--settings '{"outputStyle":"<arm>"}'` |
| `append-system-prompt` | `<arm>.txt`         | `--append-system-prompt`               |
| `system-prompt`        | `<arm>.txt`         | `--system-prompt`                      |
| `agents`               | `<arm>.json`        | `--agents` plus `--agent <arm>`        |
| `plugin-dir`           | `<arm>/`            | `--plugin-dir`                         |

Only `output-style` has been run against a model. All five build the argv they claim to, verified
against a `claude` test double that records its arguments, but the other four have never had a
response come back, so treat the first real use of one as a smoke test rather than a measurement.

With `output-style` the arm name is the `name` in the style file's frontmatter, not the filename,
and Claude Code namespaces a plugin's styles as `<plugin>:<name>`. Every file in `arms/` is copied
into each run, so the names have to be distinct.

## Running one

```bash
R=scripts/eval
E=thoughts/validation/<experiment>

# 1. Sweep. Resumes by re-running the same command: a combination that already
#    has a response is not queued again.
ARMS="AF Old|AF New" MODELS="opus fable" RESULTS=results-gate-a "$R/drive.sh" "$E" 6 3 10 11 12

# 2. Mechanical metrics. Free, deterministic, no model involved.
python3 "$R/score.py" "$E/results-gate-a"

# 3. Resource use: cost, wall clock, turns, tokens, cache share.
python3 "$R/cost.py" "$E/results-gate-a"

# 4. The comparison. The cell is the unit, not the response.
python3 "$R/paired.py" "$E/results-gate-a" words "AF Old" "AF New"

# 5. Only if a metric needs judgement. Mask first, and record the seed.
python3 "$R/mask.py" "$E/results-gate-a" 20260901
"$R/judge-agy.sh" "$E/results-gate-a" "$E/results-gate-a/mannerisms-gemini.csv"
```

`drive.sh` takes the experiment directory, a parallelism, a repetition count, then the cells.

## What each script will not do

`run.sh` writes no response for a run that did not succeed. A `claude` that exits nonzero, a result
event whose subtype is not `success`, a success carrying no text, and — under `output-style` — a
session that loaded a style other than the arm each leave the raw JSON and the cost row behind and
no `.md`. That is the file a sweep queues on, so the run is retried rather than scored.

`drive.sh` will not report a sweep as done when a run failed. It counts the failures into
`failed.log` and exits nonzero, because the alternative is a sweep that looks complete and is short
a cell.

`score.py` computes nothing that needs a model. Every metric is a property of the text decided by a
regex, which is what makes them free to recompute and impossible to bias. A metric needing
judgement goes to a judge.

`mask.py` refuses to overwrite an existing `mapping.csv`, because judgements are keyed by review id
and remapping silently invalidates every judgement already recorded. It also reports how many
responses actually had a label masked rather than claiming the judge was blind: length, punctuation
and vocabulary still identify an arm to a judge that is looking. A re-mask keeps the previous review
files until the whole replacement set is written, then removes whatever the new set does not cover.

`judge-agy.sh` records `ERROR` for anything that is not a usable answer, never a zero. That covers a
reply the schema did not fit, and one that fits it but reports a count which is not a number or
disagrees with the phrase list it counts. A zero would pull that arm's mean down and look like data.

`paired.py` drops tied pairs from the sign test rather than splitting them, which shrinks n instead
of padding either side.

## Cost before you start

`cost.py` on a previous run gives the median cost and wall clock per cell, which multiplies out to
the price of a planned sweep. Run it against the last results directory and do that multiplication
before queueing a large one. A sweep is arms times models times cells times repetitions, and the
third and fourth factors are the ones that look small.
