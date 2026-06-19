# Changelog for XurrentHelpers

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- `Export-XurrentKnowledgeArticle` and `New-XurrentKnowledgeArticleCsvExample`: The CSV is now written as UTF-8 **without** a byte-order mark (BOM) on every supported PowerShell version. Previously the file was written with a BOM (`utf8BOM` on PowerShell 7+, and the BOM-emitting `UTF8` encoding on Windows PowerShell 5.1), which caused Xurrent to reject the import with "Illegal quoting in line 1".

## [0.4.0] - 2026-06-17

### Added

- `ConvertFrom-XurrentKnowledgeArticle`: Writes the article `ID` from the CSV row as an `**ID:**` line in the generated Markdown file, enabling round-trip editing of existing articles.
- `ConvertTo-XurrentKnowledgeArticle`: Parses the `**ID:**` line from Markdown files and populates the `ID` column in the exported CSV, so existing articles can be updated by ID.

## [0.3.0] - 2026-06-01

### Added

- `ConvertFrom-XurrentKnowledgeArticle`: Converts a PSCustomObject in the Xurrent / 4me bulk-import CSV schema (e.g. a row from `Import-Csv`) into a `*KnowledgeArticle.md` file. Accepts pipeline input for batch processing. Invalid filename characters in Subject are replaced with hyphens.
- `Import-XurrentKnowledgeArticle`: Reads a Xurrent knowledge article CSV export and writes one `*KnowledgeArticle.md` file per row to a specified output folder. Supports `-WhatIf` via propagation to `ConvertFrom-XurrentKnowledgeArticle`.

## [0.2.0] - 2026-06-01

### Added

- `ConvertTo-XurrentKnowledgeArticle`: Converts a `*XurrentKnowledgeArticle.md` file into a `PSCustomObject` matching the Xurrent / 4me bulk-import CSV schema. Extracts Subject (first H1 heading), Description and Instructions (named `##` sections), and Keywords (`**Keywords:**` line). Accepts pipeline input.
- `Export-XurrentKnowledgeArticle`: Scans a folder recursively for `*XurrentKnowledgeArticle.md` files and writes a Xurrent-compatible import CSV. Supports `.env` file for `SERVICE` and `SERVICE_INSTANCES` defaults and falls back to interactive prompts when values are not provided.
- `New-XurrentKnowledgeArticleTemplate`: Creates a `*XurrentKnowledgeArticle.md` template file with the correct H1, Keywords, Description, and Instructions sections ready to fill in.
- `New-XurrentKnowledgeArticleCsvExample`: Creates an example CSV pre-filled with one illustrative row in the Xurrent / 4me knowledge article bulk-import column format.
- Added unit tests for the private `Get-Section` helper function.

### Fixed

- Replaced `ForEach-Object` with `foreach` in `Export-XurrentKnowledgeArticle` to resolve a false-positive PSScriptAnalyzer warning about unused variable assignments.

