# Changelog for XurrentHelpers

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-06-01

### Added

- `ConvertTo-XurrentKnowledgeArticle`: Converts a `*XurrentKnowledgeArticle.md` file into a `PSCustomObject` matching the Xurrent / 4me bulk-import CSV schema. Extracts Subject (first H1 heading), Description and Instructions (named `##` sections), and Keywords (`**Keywords:**` line). Accepts pipeline input.
- `Export-XurrentKnowledgeArticle`: Scans a folder recursively for `*XurrentKnowledgeArticle.md` files and writes a Xurrent-compatible import CSV. Supports `.env` file for `SERVICE` and `SERVICE_INSTANCES` defaults and falls back to interactive prompts when values are not provided.
- `New-XurrentKnowledgeArticleTemplate`: Creates a `*XurrentKnowledgeArticle.md` template file with the correct H1, Keywords, Description, and Instructions sections ready to fill in.
- `New-XurrentKnowledgeArticleCsvExample`: Creates an example CSV pre-filled with one illustrative row in the Xurrent / 4me knowledge article bulk-import column format.
- Added unit tests for the private `Get-Section` helper function.

### Fixed

- Replaced `ForEach-Object` with `foreach` in `Export-XurrentKnowledgeArticle` to resolve a false-positive PSScriptAnalyzer warning about unused variable assignments.

