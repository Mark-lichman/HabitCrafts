---
name: deploy-rules-before-enabling-the-anonymous-provider
description: Deploy the anonymous-excluding rules before the Anonymous sign-in provider goes on, or any minted token reads user data
metadata:
  type: project
  provenance: code-verified
  promoted: dev/2026-10-27-azure-pronunciation@phase-1
  keywords: [operator setup, anonymous provider, rules deploy, order]
---

The live rules admit any signed-in token to user data. If the Anonymous provider goes on first, anyone
can mint an anonymous token and pass every check. The plan's Operator setup note orders the rules
deploy first.
