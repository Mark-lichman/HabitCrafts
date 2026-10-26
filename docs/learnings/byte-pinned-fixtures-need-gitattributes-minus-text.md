---
name: byte-pinned-fixtures-need-gitattributes-minus-text
description: A sha256-pinned fixture needs a -text line in .gitattributes in the same commit, or CRLF conversion breaks the hash
metadata:
  type: project
  provenance: code-verified
  keywords: [gitattributes, -text, sha256, fixture, CRLF, tanos]
---

The archived Tanos HTML pages carry CR bytes and are sha256-pinned. Two follow-up commits were needed
before they survived every checkout byte for byte. The fix is `pipeline/jp/tanos/*.html -text` in
`.gitattributes`. Add the `-text` line in the same commit as any new byte-pinned fixture.
