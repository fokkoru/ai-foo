# Decisions

- [0001 One rule, one place](0001-one-rule-one-place.md) - A behavioural rule lives at its point of use plus the hard gate, and a restatement is classified before it is removed.
- [0002 Model tiering for dispatched work](0002-model-tiering-for-dispatched-work.md) - Route a dispatch by the shape of the work, reach for effort before a weaker model, and never send judging below the strong tier.
- [0003 The cell is the unit of analysis](0003-the-cell-is-the-unit-of-analysis.md) - A prompt experiment is read paired at the fixed task, not pooled over responses, and the floor check runs before the sweep.
- [0004 A removal names its replacement](0004-a-removal-names-its-replacement.md) - A commit that removes a capability names what replaces it in the body, or states that nothing does.
- [0006 Antigravity runs under accept-edits](0006-agy-runs-under-accept-edits.md) - Delegated runs get file edits and no shell; consultations get no permission flag at all.
- [0007 The rung decides what a prompt edit runs](0007-the-rung-decides-what-a-prompt-edit-runs.md) - A prompt edit is gated by what it is expected to do, on a three-rung ladder from no paid run to a full sweep with judging.
- [0008 A page cites only what a clone carries](0008-a-page-cites-only-what-a-clone-carries.md) - Every sources[] entry names a tracked file; a path inside the raw root is refused, and a capture record is refused on separate grounds.
- [0009 A version bump touches two manifests and no tag](0009-a-version-bump-touches-two-manifests-and-no-tag.md) - A plugin's version lives in its marketplace entry and its Codex manifest, bumped to the same value in one commit; the Codex catalog tracks main, so there is nothing to tag.
- [0010 A vanished source deletes its entry](0010-a-vanished-source-deletes-its-entry.md) - A sources[] entry whose resource no longer exists is removed together with the prose it supported, never flagged and kept.
- [0011 A preference is judged pairwise in both orders](0011-a-preference-is-judged-pairwise-in-both-orders.md) - One judge sees both responses for the same cell and repetition in each order, and a win counts only when the orders agree.
