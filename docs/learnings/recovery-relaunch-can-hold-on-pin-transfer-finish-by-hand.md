---
name: recovery-relaunch-can-hold-on-pin-transfer-finish-by-hand
description: A sanctioned recovery relaunch re-dispatched already-integrated tasks and held on pin-transfer proofs; finish with the escalation-completion land
metadata:
  type: project
  provenance: code-verified
  keywords: [recovery relaunch, pin transfer, empty-unmatched, escalation-completion land, land-advance, _refinery, held:escalation]
---

After a `held:escalation` phase, a sanctioned recovery relaunch (fresh run id, adopted integration
branch, `args.recovery.sanctioned`) did not skip the tasks already on the integration branch. They
were re-dispatched and escalated with pin-transfer status `empty-unmatched` (no task commits left
after the rebase), and the one real task escalated with "no independent Git proof" although its
pre- and post-rebase patch-ids matched.

What finished it: the escalation-completion land. Detach `_refinery` at `origin/<working>`,
`git merge --no-ff <audited task tip>`, provision the refinery first (it is NOT pre-provisioned:
`flutter pub get`, `python -m venv pipeline/.venv`, `pip install -r pipeline/jp/requirements-test.txt`),
run the full gate, then `provision-worktrees.sh land-advance <working> <merge-sha>` from the detached
`_refinery`, then `sync-follower`.
