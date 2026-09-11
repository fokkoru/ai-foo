# Adopting a hand-written tree

Read from `weave` Step 0 when `docs/` holds pages but no `docs/WIKI.md`. That is a documentation tree somebody wrote by hand, and this file turns it into one `weave` and `lint` can work in by adding what is missing and changing nothing that is there. The pages' bodies are the owner's work and leave this run byte for byte what they were.

The run that follows this file compiles nothing. It ends at "Report" below, so the adoption is committed on its own and reverted on its own.

## Contents

- [What this run may write](#what-this-run-may-write)
- [Halts](#halts)
- [Survey the tree](#survey-the-tree)
- [Propose the mapping and wait](#propose-the-mapping-and-wait)
- [Write the schema, index and log](#write-the-schema-index-and-log)
- [Stamp the pages](#stamp-the-pages)
- [Check, verify, release](#check-verify-release)
- [Report](#report)

## What this run may write

Under `docs/` only, and only these: `docs/WIKI.md`, `docs/index.md`, `docs/log.md` when absent; a `type:` frontmatter key on an existing page through `check-docs.sh stamp-type`; and a `decision_id:` key on a page stamped `decision` that has none. No other edit to an existing page, no page moved or renamed, no directory created. `index.md` and `log.md` at any depth, and `WIKI.md`, are never stamped: OKF reserves those names and `check` forbids frontmatter on a nested `index.md`.

Any of the three files already present is left as it is and named in the report.

`thoughts/**` stays denied, and the snapshot from Step 0 is what proves it in "Check, verify, release". If Step 0 found no raw root — a documentation-only repository has no `thoughts/` — there was no snapshot; skip `verify-sources` below and say in the report that there was no raw layer to protect.

## Halts

Stop, report, and release the claim when:

- `docs/index.md` exists and the baseline `check` reports it — no frontmatter, a key beside `okf_version`, a page it does not reach. It is a hand-written map, this run may not edit it, and `check` will not pass while it stays as it is. Say that renaming it — `README.md` is the usual name for such a map — and rerunning is the way through.
- The owner does not confirm the mapping in "Propose the mapping and wait".

## Survey the tree

List the top-level directories under `docs/` and, for each, the count of `.md` pages at any depth. List separately the pages directly under `docs/` and every `README.md` or template page inside a directory; the next section gives them their own row. Leave out of every list any `index.md`, `log.md` and `WIKI.md`.

Read two or three pages from each directory, whole. Note the frontmatter keys they carry, whether they carry `type:`, and the heading shape they share.

Read `docs/README.md` if there is one: a hand-written tree often keeps its own map there, and the index below is built from that map rather than beside it.

Run `check-docs.sh check docs thoughts` once and keep the output. It is the baseline: every finding on a page this run does not touch is the owner's backlog, and "Report" lists it as such rather than as a failure of this run.

## Propose the mapping and wait

Read `wiki-template.md` beside this file. Two of its sections describe a tree this project does not have: "The four directories" (the table of directories and their `type` values) and "The routing test" (whose destination column names those directories).

Build the replacement table from the survey: one row per top-level directory, with the `type` value it will carry. Use a shipped value where the directory plainly is one — a numbered ADR directory is `decision`; a directory describing how the system works is `architecture`; one describing behaviour and concepts is `product` — and propose a value for the rest, named after what the directory holds, such as `guide`. OKF requires only that `type` is non-empty, and `check` tests only that. When a directory holds subdirectories that plainly differ in kind — specifications of the architecture beside specifications of features — propose a row per subdirectory instead.

Add one last row for everything the directory rows do not cover: pages directly under `docs/`, and any `README.md` or template page inside a mapped directory. Propose no value for that row; list the candidates and let the owner name one. A `README.md` is a map and a template is a blank, and neither is a decision, so the `decision` value is never proposed for them — `check` demands a `decision_id` on every `type: decision` page, and an id on a template is an id every copy of it duplicates.

Put the whole table to the owner as one question and wait for the answer. Write nothing before it: `docs/WIKI.md` is the owner's schema, and a wrong `type` stamped onto forty pages is forty edits to undo. If the owner changes a row, use their value.

## Write the schema, index and log

Write `docs/WIKI.md` from `wiki-template.md` with three changes and no others. First, the "The four directories" table is replaced by the confirmed table, followed by one sentence saying these are the directories as found, not the template's. Second, in "The routing test", every destination is rewritten as the directory the confirmed table maps to that `type`; a `type` with no mapped directory — `roadmap` on most trees — keeps its row, with the destination reading "no directory carries this type yet; `weave` reports such a claim as uncompiled until one is added to the table above". Third, one dated sentence at the end of "Provenance": pages adopted on this date carry no `sources[]`, `check` does not report that, and a `weave` run that touches one adds provenance for what it changes. Everything else — the trust order, the confidence vocabulary, the rest of the provenance rules — is kept as shipped, because it describes what `weave` will do from now on, not what the tree was.

Write `docs/index.md` from the bundle-root skeleton in `page-templates.md`, with one entry per existing page: the link, then the description from the page's `description:` key or, absent that, its first H1. Group entries by directory in the order of the confirmed table. Where `docs/README.md` already lists a page with a description, use that description. A page from the last row of the table — a map or a template — has an H1 that names it rather than describes it, so its entry says in one clause what the page is, such as "the hand-written map of this tree" or "the blank a new decision record is copied from". `check_reachability` in "Check, verify, release" is the test that no page was missed.

Write `docs/log.md` from the skeleton with one section for today and one `**Creation**` bullet naming the three files this run wrote and the number of pages it stamped.

## Stamp the pages

For every page except a reserved `index.md`, `log.md` or `WIKI.md`, run `check-docs.sh stamp-type <page> <type>` with the value the confirmed table gives it — the directory's value, or the last row's value for a loose page, a `README.md` or a template. It refuses a page that already carries a `type:` and says why; carry each refusal into the report and move on.

Then, for every page that carries `type: decision` after stamping — stamped in this run or typed by hand before it — and has no `decision_id:` key with a value, run `check-docs.sh assign-id <page>` and write the value it prints into a `decision_id:` key, second line of the block, by one Edit that adds that line, or fills the empty one, and nothing else. A page that already carries a value keeps it — an identifier is assigned once — and `check` reports a decision page without one.

Nothing else on any page is touched. A page whose frontmatter lacks `title:` or `description:` stays that way; `check` does not test those keys, and adding them would be writing the owner's prose.

## Check, verify, release

Run `check-docs.sh check docs thoughts`. Compare with the baseline: a finding on `WIKI.md`, `index.md`, `log.md`, or on a stamped key is this run's and is fixed before going on; a finding that was in the baseline and is on a page body is the owner's backlog and is left. `unreachable` on any page means the index missed it — add the entry.

Run `check-docs.sh verify-sources <manifest>` with the path Step 0 printed, unless there was no raw root. A failure is a defect in this run: report it, and release the claim.

Release the claim with `check-docs.sh claim-release <run id>`, also on every halt above once the halt has been reported.

## Report

Report, in this order:

- the confirmed mapping table
- the files written, and any of the three that already existed and were left
- pages stamped, per directory, and every refusal with its rule
- decision pages given an id
- the checker's findings that remain, labelled as the owner's backlog; and, separately, that the adopted pages carry no `sources[]`, which `check` is silent about, so `/kb:lint <page>` on a named page is how one gets inspected
- the result of `verify-sources`, or that there was no raw root

Print — never write — a `## Documentation` block for the owner to paste into their instructions file, pointing a later session at `docs/` before `thoughts/`, the way Step 7 does on the run that seeds a tree.

Close by saying that `docs/` is ready to be committed on its own, and that `weave pending` is the next pass. Do not go on to Step 1: this run is over.
