# Architecture

- [Prompt A/B harness](prompt-eval-harness.md) - How two variants of a shipped prompt are compared against the same fixed tasks.
- [Independent review dispatch](review-dispatch.md) - How df reviews a run: one pass per phase, one over the whole run, and a refuter behind every blocking finding.
- [Agent fleet and its tiers](agent-fleet.md) - The nine subagents df ships, and how each one's model and effort are pinned together in frontmatter.
- [Antigravity execution boundary](agy-execution-boundary.md) - What the Antigravity CLI is allowed to do under each permission mode, and which flags the two skills therefore pass.
- [The two-line status line](statusline.md) - How the Claude Code status line is assembled from ccstatusline's git widgets and one local script, and how to recreate it on a new machine.
- [The knowledge compiler](knowledge-compiler.md) - How kb turns an untracked corpus of notes into the committed pages under docs/, and what keeps the two layers from writing over each other.
- [Shipping one plugin tree to two runtimes](dual-runtime-distribution.md) - How the same plugins reach Claude Code and Codex CLI: two catalogs, two manifests, a mirrored agent set, and the one install step a Codex plugin cannot carry.
