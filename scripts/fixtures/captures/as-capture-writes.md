# Capture: the shape kb:capture writes

## Decisions

### The staged record lives outside the raw layer

Rejected: writing straight into thoughts/captures/
Because: an unpublished record must not be visible to a compile run, and a staged file inside the raw layer would register as a source change
Evidence: plugins/kb/skills/capture/SKILL.md
Supersedes: record r1.md ### The manifest lives at a fixed path

### A decision with nothing built behind it is still recorded

Rejected: refusing a record when no implementation exists
Because: a design session is the case this skill exists for, and code shows what was chosen and never why
Evidence: none

## Reversed inside this session

The session first settled on one record per session, then reversed it: the number of records is the
model's, because a design session reaches several independent conclusions and a long implementation
session reaches none.

## What the session said

> "Let's not tie this to the session boundary."

## Still open

Whether a bare confirmation can activate a manual-only skill.
