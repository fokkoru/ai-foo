# Capture: the manifest gets run identity

## Decisions

### The source manifest is named per run

Rejected: keeping one fixed path under TMPDIR
Because: two runs sharing a temp directory overwrite each other's snapshot, which reads as a false failure or a false pass
Evidence: plugins/kb/scripts/check-docs.sh, cmd_snapshot

### The old fixed path is removed rather than kept as a fallback

Rejected: falling back to the fixed path when no manifest is passed
Because: nothing outside the plugin named it, and a fallback restores the collision the change exists to remove
Evidence: none

## Reversed inside this session

## What the session said

## Still open
