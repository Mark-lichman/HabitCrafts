---
name: sentence-letters-stops-coloring-after-one-unmatched-mora
description: sentenceLetters never advances its mora cursor on a mismatch, so later letters stay uncolored; fall back to word coloring
metadata:
  type: project
  provenance: code-verified
  promoted: dev/2026-10-27-azure-pronunciation@phase-1
  keywords: [sentenceLetters, mora, PIN-8, letter coloring, fallback]
---

`sentenceLetters` does not advance its mora cursor on a mismatch. Every later letter stays uncolored.
The failure is no color, never a wrong color. The drill falls back to word-level coloring (PIN-8) when
scored morae are left over.
The drill's `_letters` in `quiet_room_speak_widget.dart` falls back to `words[i].letters` when any letter
stays uncolored, not only on a count mismatch. It then shows the scored words one space apart.
