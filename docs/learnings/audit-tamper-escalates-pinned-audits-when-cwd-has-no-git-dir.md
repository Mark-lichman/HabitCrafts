---
name: audit-tamper-escalates-pinned-audits-when-cwd-has-no-git-dir
description: A WAR run launched from a non-git cwd escalated both tasks on AUDIT-TAMPER although every audit pin resolved clean
metadata:
  type: project
  keywords: [AUDIT-TAMPER, unverifiable fingerprint, git common dir, escalate, held:escalation, cwd, audit-tree-fingerprint, detached worktree, Lead launch cwd, audit-pin resolved]
  provenance: agent-unverified
  slug: audit-tamper-escalates-pinned-audits-when-cwd-has-no-git-dir
  phase: 1
  tags: [war, escalation, launch-cwd]
  created: 2026-11-19
---

Plan jp-web-sync phase 1 held with `held:escalation` and landed no task.

Both tasks first returned `audit-pin:resolved`, with `pinMismatch: false` and `headSha` equal to every pinned sha.
Both then returned `escalate` with zero fix rounds.

The only escalate reason on every seat was: "AUDIT-TAMPER: unverifiable fingerprint (no git common dir from cwd ...)".
The cwd named in that message was the user's home directory, which is not a git repository.

Resolved cause: the Lead session cwd was not inside the target repo, so `hooks/audit-tree-fingerprint.sh` could not resolve `$MAIN`.
Fix that worked: the Lead ran `git worktree add --detach` of the target repo under the session scratchpad, moved its session cwd there, and relaunched.
After the relaunch the seats verified and no seat escalated AUDIT-TAMPER.

Rule: a WAR Lead session must launch with its cwd inside a worktree (or checkout) of the target repo.
If every seat escalates AUDIT-TAMPER with "no git common dir from cwd", check the Lead cwd first. It is a launch fault, not a code fault.
The audit findings stay usable while the phase is held.

Related: [[recovery-relaunch-can-hold-on-pin-transfer-finish-by-hand]] covers finishing a `held:escalation` phase by hand.

Grounding note: the integration branch `integration/jp-web-sync/phase-1` held no task code at the time of this note.
The task code lived only on `war/jp-web-sync/p1-1` and `war/jp-web-sync/p1-2`.
