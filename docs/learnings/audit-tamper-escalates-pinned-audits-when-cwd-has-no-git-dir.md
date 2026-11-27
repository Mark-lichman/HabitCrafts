---
name: audit-tamper-escalates-pinned-audits-when-cwd-has-no-git-dir
description: A WAR run launched from a non-git cwd escalated both tasks on AUDIT-TAMPER although every audit pin resolved clean
metadata:
  promoted: dev/2026-11-19-jp-web-sync@phase-1
  type: project
  keywords: [AUDIT-TAMPER recurrence, gate-evidence escalate, unverifiable fingerprint, git common dir, escalate, held:escalation, cwd, audit-tree-fingerprint, detached worktree, Lead launch cwd, audit-pin resolved]
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

Recurred in phase 3 (same plan, relaunched run), with the same cwd fault.
Task 6 returned `audit-pin:resolved` with a clean pin, then `escalate` on every seat with "AUDIT-TAMPER: unverifiable fingerprint (no git common dir from cwd ...)".
The cwd named was again the user's home directory.
Task 8 merged and its gate was green (exit 0, rules suite `# fail 0`).
Its gate-evidence seat and the phase-3 integrated-tip seat still returned `escalate` on the same AUDIT-TAMPER text, with only Nit findings.
So the phase held `held:escalation` with Task 6 unlanded, although no seat found a code defect that blocks the land.
The real Task 6 findings (one Major) came from the earlier `audit-pin:resolved` pass: see [[sign-out-last-sync-must-pass-the-same-owner-guard-as-every-sync-path]].
Do not read the AUDIT-TAMPER escalate as a verdict on the code. Read the earlier pinned verdicts instead.
Checkout-topology note: the Lead's cwd was not a git repository, so the relaunch fix in this note was not applied before the phase 3 run.

Related: [[recovery-relaunch-can-hold-on-pin-transfer-finish-by-hand]] covers finishing a `held:escalation` phase by hand.

Grounding note: the integration branch `integration/jp-web-sync/phase-1` held no task code at the time of this note.
The task code lived only on `war/jp-web-sync/p1-1` and `war/jp-web-sync/p1-2`.
