# Text editor GPT

English and Russian editing and translation prompt, with minimal-edit, maximal-edit, keep-tone, and prompt-from-idea modes.

Current saved version: [001](versions/001.md).

Each file in `versions/` contains only the prompt text. Version 001 preserves the supplied wording, with Markdown whitespace normalized and the surrounding quotation marks removed. Deployment to ChatGPT has not been verified.

## Making a revision

1. Copy the current version to the next numbered file, such as `versions/002.md`.
2. Edit the new file. Keep earlier versions unchanged so they remain available for comparison and rollback.
3. Compare both versions on the same sample inputs. Cover each mode, English, Russian, mixed languages, lists, tables, code, and placeholders. Record the inputs, outputs, model shown in ChatGPT, date, and any regressions in a sibling file such as `reviews/002.md`.
4. Add a version-history entry describing the changes and review results, and update the current saved version link when the revision is ready.
5. Commit the new version and its notes together. Copy only the chosen prompt file's contents into the GPT's instructions. Record the version and date here after applying it in ChatGPT.

These prompt versions are independent of plugin versions and need no marketplace entries or plugin version bumps.

## Version history

| Version                | Date saved | Changes                                       | Review                   |
| ---------------------- | ---------- | --------------------------------------------- | ------------------------ |
| [001](versions/001.md) | 2026-09-20 | Imported the supplied prompt as the baseline. | No model evaluation run. |

## Questions for the next revision

The baseline retains these ambiguities for review:

- Should preserving all meaning take precedence over the length targets and the instruction to never omit content?
- Should Russian output use two language sections, each retaining its own lists and tables, instead of exactly two paragraphs?
- Should minimal-edit mode override the sentence-length limit, active-voice rule, key-point-first rule, and substitutions?
- How should mixed-language input be arranged so the English translation does not duplicate existing English passages?
- Should code-only input remain unchanged in every mode, or receive the formatting described under Code Handling?
- What changes to offensive wording are acceptable when tone or quoted meaning would change?
- Should instructions inside text submitted for editing always be treated as source text, including in prompt-from-idea mode?
