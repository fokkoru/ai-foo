---
title: "Answer First output style"
description: "A response style that leads with the outcome, holds length to the size of the change, and ends with one labelled line when something is the reader's to do."
status: stable
generated:
  by: "kb:compile"
  at: "2026-09-03T17:32:57-07:00"
---

# Answer First output style

## What it is

An output style replaces the "how to talk" half of the harness's system prompt, so it reshapes every
response in the session rather than adding a step somebody invokes. `answer-first` is the one style
this repository ships, and it puts the main point first, holds a report's length to the size of the
change, and ends the message with one labelled line when something is the reader's to do.[^root-readme]

Its first sentence answers "what happened" or "what did you find", the thing the user would ask for
if they said "just give me the TLDR", with supporting detail after. Length follows the size of the
change rather than the length of the session behind it, and a detail is cut whole rather than
compressed into fragments, abbreviations or arrow chains.[^style-head]

Two rules come from none of its sources. The first is a test for jargon: a technical term stays only
when it is shorter than the plain phrasing, because "use the plain word" on its own gives the model
nothing to check against and comparing two lengths is something it can check. The second is the end
state. When something is the reader's to act on, the message ends with one of four exclusive labels — **Need from you**, **Blocked**, **Not
verified**, **Next** — taken in that order. An action the model can take itself is taken instead of
being written as a next step, and when nothing is open the message stops with the content.[^style-sources]

## When it applies

It governs default presentation and length. It overrides general communication and formatting
defaults, and never a format the user asked for, correctness, safety, or a required
confirmation.[^style-head]

Where the harness injects its own writing rules, the style is emitted before them, so the base
prompt's text carries recency. The style therefore repeats the base prompt's sentences where the two
overlap rather than rewording them, and adds only what the base prompt does not carry: the explicit
length rule and the end state. Where those harness rules are absent, the style is the only prose
rule set in the prompt, which is why it is standalone rather than a delta.[^style-placement]

## What it does not cover

It is not a length cap. A simple question gets one to three sentences, but detail asked for is given
in full.[^style-head]

The body has been compared against its predecessor on a fixed prompt set with the harness in
[Prompt A/B harness](../architecture/prompt-eval-harness.md), but that run's numbers are not
recorded in this repository, so no effect size is stated here. The marketplace entry ships
0.9.0.[^style-version]

[^style-head]: `plugins/style/output-styles/answer-first.md`, frontmatter and the first two paragraphs.

[^style-version]: `.claude-plugin/marketplace.json`, the style plugin's entry.

[^root-readme]: `README.md`, the style plugin's one-line summary.

[^style-sources]: `plugins/style/README.md`, "Where the rules came from".

[^style-placement]: `plugins/style/README.md`, "What the base prompt already says about prose".
