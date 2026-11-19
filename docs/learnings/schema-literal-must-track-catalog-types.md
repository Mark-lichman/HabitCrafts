---
name: schema-literal-must-track-catalog-types
description: The CatalogEntry type Literal in extraction_schemas.py drifted from catalog.TYPES with no failing test; a contract test now binds them
metadata:
  type: project
  provenance: code-verified
  keywords: [CatalogEntry, Literal, catalog.TYPES, source_file, pydantic, contract test, extraction_schemas]
---

Task 10 added `source_file` to `catalog.TYPES` but not to the `CatalogEntry` `type` Literal in
`pipeline/extraction_schemas.py`, and nothing failed because tests only ran `_check()`. The guard is a
contract test in `pipeline/jp/tests/test_catalog_sources.py`: validate the built catalog through
`ResultList` and compare the Literal to `TYPES`, in order. Pydantic drops undeclared keys silently, so
assert key membership before reading a value.
