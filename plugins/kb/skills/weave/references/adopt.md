# Adopting a hand-written tree

Read from `weave` Step 0 when `docs/` holds pages but no `.kb/schema.md`. That is a documentation tree somebody wrote by hand, and this file turns it into one `weave` and `lint` can work in by adding what is missing and changing nothing that is there. The pages' bodies are the owner's work and leave this run byte for byte what they were.

The run that follows this file compiles nothing. It ends at "Report" below, so the adoption is committed on its own and reverted on its own.

## Contents

- [What this run may write](#what-this-run-may-write)
- [Halts](#halts)
- [Survey the tree](#survey-the-tree)
- [Propose the mapping and wait](#propose-the-mapping-and-wait)
- [Write the schema](#write-the-schema)
- [Check, verify, release](#check-verify-release)
- [Report](#report)

## What this run may write

`.kb/schema.md`, and `docs/index.md` only when the tree has no `README.md` and no `index.md` anywhere under it that could serve as one. Nothing else: no page body edited, no page moved or renamed, no directory created, no frontmatter key added to an existing page.

An existing `README.md` or `index.md` that already serves the tree as a map is left as it is and named in the report.

`thoughts/**` stays denied, and the snapshot from Step 0 is what proves it in "Check, verify, release". If Step 0 found no raw root — a documentation-only repository has no `thoughts/` — there was no snapshot; skip `verify-sources` below and say in the report that there was no raw layer to protect.

## Halts

Stop, report, and release the claim when the owner does not confirm the mapping in "Propose the mapping and wait".

## Survey the tree

List the top-level directories under `docs/` and, for each, the count of `.md` pages at any depth. List separately the pages directly under `docs/` and every `README.md` or template page inside a directory; the next section gives them their own row.

Read two or three pages from each directory, whole. Note the frontmatter keys they carry and the heading shape they share.

Read `docs/README.md` if there is one: a hand-written tree often keeps its own map there, and the schema below is built to point at that map rather than to replace it.

## Propose the mapping and wait

Read `schema-template.md` beside this file. Two of its sections describe a tree this project does not have: "The four directories" (the table of directories and what each holds) and "The routing test" (whose destination column names those directories).

Build the replacement table from the survey: one row per top-level directory, naming what it holds. Use a shipped label where the directory plainly matches one — a numbered ADR directory holds decisions; a directory describing how the system works is architecture; one describing behaviour and concepts is product — and propose a label for the rest, named after what the directory holds, such as guide. When a directory holds subdirectories that plainly differ in kind — specifications of the architecture beside specifications of features — propose a row per subdirectory instead.

Add one last row for everything the directory rows do not cover: pages directly under `docs/`, and any `README.md` or template page inside a mapped directory. Propose no label for that row; list the candidates and let the owner name one.

Propose which file is the map: `docs/README.md` when it exists, otherwise the candidate under `docs/` that most plainly already serves as one. When nothing under `docs/` links the tree, propose that this run writes `docs/index.md` and use that as the map, so the owner confirms writing it along with the rest of the table.

Put the whole table, and the proposed map, to the owner as one question and wait for the answer. Write nothing before it: a wrong entry in a schema the tree's pages will be checked against is an entry every later run has to work around. If the owner changes a row or the proposed map, use their answer.

## Write the schema

Write `.kb/schema.md` from `schema-template.md` with these changes and no others. First, the "The four directories" table is replaced by the confirmed table, followed by one sentence saying these are the directories as found, not the template's. Second, in "The routing test", every destination is rewritten as the directory the confirmed table maps to that claim shape; a shape with no mapped directory — `roadmap` on most trees — keeps its row, with the destination reading "no directory carries this yet; `weave` reports such a claim as uncompiled until one is added to the table above". Third, `map:` and `decisions:` are set to the confirmed map and the confirmed decisions directory. Fourth, one dated sentence at the end of "Provenance": pages adopted on this date are unregistered and carry no provenance until a `weave` run touches one. Everything else — the trust order, the confidence vocabulary, the rest of the provenance rules — is kept as shipped, because it describes what `weave` will do from now on, not what the tree was.

If the confirmed map is an existing file, this is the only file the run writes, and `docs/` is untouched. If no existing file could serve as the map, write `docs/index.md`: an H1 naming the bundle, then one entry per existing page — the link, then the description from the page's `description:` key or, absent that, its first H1 — grouped by directory in the order of the confirmed table. Set `map: docs/index.md` in the schema written above.

## Check, verify, release

Run `check-docs.sh check docs thoughts` once, now that the schema exists — before it, `check` reports only `schema-missing` and stops, so this is the first run that can see the tree at all, and every finding it prints is the owner's backlog rather than something this run introduced. The one exception is `unreachable`: that finding is the owner's backlog only when the confirmed map already existed; when this run wrote `docs/index.md` itself, an `unreachable` page means an entry was missed, and this run adds it before reporting.

Run `check-docs.sh verify-sources <manifest>` with the path Step 0 printed, unless there was no raw root. A failure is a defect in this run: report it, and release the claim.

Release the claim with `check-docs.sh claim-release <run id>`, also on every halt above once the halt has been reported.

## Report

Report, in this order:

- the confirmed mapping table, and which file was confirmed as the map
- the file written — `.kb/schema.md` alone, or `.kb/schema.md` and `docs/index.md` — and the existing map that was left as it was, if any
- `check`'s findings, labelled as the owner's backlog; and, separately, that the adopted pages carry no provenance, which `check` is silent about, so `/kb:lint <page>` on a named page is how one gets inspected
- the result of `verify-sources`, or that there was no raw root

Print — never write — a `## Documentation` block for the owner to paste into their instructions file, pointing a later session at `docs/` before `thoughts/`, the way Step 7 does on the run that seeds a tree.

Close by saying that `git status docs/` is expected clean, that `.kb/schema.md` is ready to be committed on its own, and that `weave pending` is the next pass. Do not go on to Step 1: this run is over.
