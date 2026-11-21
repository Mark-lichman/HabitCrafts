---
name: rules-test-ci-job-installs-function-codebases-without-lockfile-or-token-limits
description: Resolved in phase 1, the rules CI job now installs with ignore-scripts and a read-only token
metadata:
  type: project
  keywords: [firestore-rules-tests, ci.yml, npm install, lockfile, ignore-scripts, persist-credentials, GITHUB_TOKEN permissions, supply chain, emulator, setup-java]
  provenance: code-verified
  slug: rules-test-ci-job-installs-function-codebases-without-lockfile-or-token-limits
  phase: 1
  tags: [ci, security, firebase, resolved, pattern]
  created: 2026-11-19
---

Pattern: a CI job that runs `npm install` on a codebase with no lockfile resolves new transitive versions and runs their install scripts on every run.
Such a job should set `permissions: contents: read`, `persist-credentials: false` on checkout, and `--ignore-scripts`.

The audit flagged the `firestore-rules-tests` job in `.github/workflows/ci.yml` for all three.
The landed job has them: a `permissions:` block, `persist-credentials: false`, and `--ignore-scripts` on the install loop for `firebase/functions`, `firebase/custom_cloud_functions` and `firebase/speech_functions`.
The job also pins `setup-java` to Java 21, which firebase-tools needs. See [[land-gate-runs-rules-emulator-tests-without-the-pinned-firebase-tools]].
The `setup-java` and `setup-node` SHA pins were never confirmed offline, so check them on the first CI run, because a wrong SHA fails at action checkout.

Verify still present before acting: the `firestore-rules-tests` job in `.github/workflows/ci.yml` on `integration/jp-web-sync/phase-1` @ phase 1 (tip 74c4260).
