---
title: "A bilingual prompt answers in plain Markdown"
description: "The text-editor GPT returns its two language versions as plain Markdown separated by a horizontal rule, and asks the interface for nothing."
status: stable
decision_id: "ea1b4ee44c7c"
supersedes: ""
superseded_by: ""
generated:
  by: "kb:weave"
  at: "2026-09-20T17:23:28-07:00"
---

# A bilingual prompt answers in plain Markdown

## Context

The text-editor GPT returns an edited Russian text followed by its English translation, and a
reader wants to copy each on its own. A draft of the prompt asked the model for native editable
writing blocks, one per language, so each could be edited and copied separately, with ordinary
text as the fallback.[^review-container]

OpenAI's help article on writing blocks says ChatGPT places a draft in one on its own judgement,
"when ChatGPT creates text that you are likely to revise or reuse", and lists the formatting a
block supports as bold, italic, headings, links, lists and checklists, with tables absent.
`[reported]` https://help.openai.com/en/articles/20001246, retrieved 2026-09-20. Nothing in it
gives a GPT's instructions control over that placement or promises two blocks in one response, so a
Russian table would fall back to ordinary text in exactly the case the draft was written
for.[^review-container]

## Decision

The prompt returns plain Markdown: the two language blocks are separated by a horizontal rule, a
line holding only `---` with a blank line on each side, neither block is wrapped in a code fence,
a quotation or any other container, and the prompt neither requests nor imitates interface
features such as writing blocks.[^prompt-output] The interface decides how to render the Markdown.

## Consequences

A wrapper can only lose. A code fence shows headings as raw text and breaks when the source
carries its own fence, and a writing block drops tables. The horizontal rule exists because a blank
line alone does not end a Markdown list, so a Russian list and its English translation would
otherwise render as one list; a second opinion from Codex on 2026-09-20 pointed that
out.[^review-container] Separate copying of each language is not something the prompt can
provide, and if the interface places a response in a writing block on its own, that is recorded as
an interface observation rather than a prompt failure.

The decision holds for as long as the prompt targets a custom GPT. OpenAI plans to retire custom
GPTs in favour of Plugins, Enterprise from 2026-12-11. `[reported]`
https://help.openai.com/en/articles/8554397-creating-a-gpt, retrieved 2026-09-20. Whether the
prompt is carried forward at all is undecided.

[^prompt-output]: `gpts/text-editor/versions/002.md`, "Language and output".

[^review-container]: `gpts/text-editor/reviews/002.md`, "Output container".
