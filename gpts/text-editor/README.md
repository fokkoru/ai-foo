# Text editor GPT

English and Russian editing and translation prompt, with minimal-edit, maximal-edit, keep-tone, and prompt-from-idea modes.

Current saved version: [001](versions/001.md), the baseline. Candidate: [002](versions/002.md), with [revision notes and comparison cases](reviews/002.md). It becomes current once a recorded comparison exists, as step 3 below requires. OpenAI plans to retire custom GPTs in favour of Plugins, Enterprise from 2026-12-11; the notes carry the source.

Each file in `versions/` contains only the prompt text. Version 001 preserves the supplied wording, with Markdown whitespace normalized and the surrounding quotation marks removed. Deployment to ChatGPT has not been verified.

## Making a revision

1. Copy the current version to the next numbered file, such as `versions/002.md`.
2. Edit the new file. Keep earlier versions unchanged so they remain available for comparison and rollback.
3. Compare both versions on the same sample inputs. Cover each mode, English, Russian, mixed languages, lists, tables, code, and placeholders. Record the inputs, outputs, model shown in ChatGPT, date, and any regressions in a sibling file such as `reviews/002.md`.
4. Add a version-history entry describing the changes and review results, and update the current saved version link when the revision is ready.
5. Commit the new version and its notes together. Copy only the chosen prompt file's contents into the GPT's instructions. Record the version and date here after applying it in ChatGPT.

These prompt versions are independent of plugin versions and need no marketplace entries or plugin version bumps.

## Version history

| Version                | Date saved | Changes                                                                                                                                   | Review                                                                                                                            |
| ---------------------- | ---------- | ----------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| [001](versions/001.md) | 2026-09-20 | Imported the supplied prompt as the baseline.                                                                                             | No model evaluation run.                                                                                                          |
| [002](versions/002.md) | 2026-09-20 | Applied OpenAI prompting guidance, resolved conflicting rules, added targeted examples, and fixed the output container as plain Markdown. | Static review only; [sources, behavior changes, why writing blocks were withdrawn, and pending comparison cases](reviews/002.md). |

## Next review

Version 002 records decisions for the baseline's ambiguities in its [revision notes](reviews/002.md#changes-from-001). Validate these choices in the target GPT before treating the revision as an improvement:

- Check meaning preservation when length targets cannot be met.
- Check bilingual lists and tables, mixed-language duplication, and Russian prompt mode.
- Check verbatim code and quotations, mode carryover, and embedded instructions.
- Record the model, outputs, regressions, and deployed version after testing.
