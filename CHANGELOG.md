# Changelog for XurrentHelpers

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0] - 2026-06-17

### Added

- `Connect-Xurrent`: Establishes an authenticated session to the Xurrent REST and GraphQL APIs. Supports Bearer token, OAuth2 client credentials, CliXML credential files, and Microsoft.PowerShell.SecretManagement vaults. Targets Demo, QA, or Prod environments and verifies connectivity via `/me` unless `-SkipConnectionTest` is specified.
- `Disconnect-Xurrent`: Clears the active Xurrent session and loaded configuration. Requires high-impact confirmation to prevent accidental disconnection in automation.
- `Invoke-XurrentRestMethod`: Sends authenticated HTTP requests to the Xurrent REST API. Builds the full URI from a relative path, supports query parameters, JSON bodies, and returns parsed objects or raw responses.
- `Invoke-XurrentGraphQLQuery`: Executes GraphQL queries and mutations against the Xurrent GraphQL endpoint. Handles rate limiting with automatic retry and returns the `data` property of the response.
- `Invoke-XurrentBulkUpload`: Bulk-imports objects into Xurrent via the `/import` endpoint. Serializes to a temporary CSV, auto-chunks batches exceeding `JobLimit`, polls for completion, and reports row-level errors from the job log.
- `Invoke-XurrentBulkDownload`: Bulk-exports one or more resource types via the `/export` endpoint. Returns parsed object arrays for single types or a hashtable for multiple types. Supports delta exports and saving the raw file.
- `New-XurrentWebhookConfiguration`: Saves a Techwork Automator (or other) webhook URL and Basic-auth credential to the module's `.env` config file and an encrypted CliXML file alongside the PowerShell profile.
- `Invoke-XurrentWebhook`: Triggers a configured webhook by name (loaded from config) or directly by URL. Does not require an active Xurrent API session.
- `Import-XurrentConfiguration`: Loads a `.env` configuration file into the module session. Auto-connects to the API when `-AutoConnect` is specified or `XURRENT_AUTO_CONNECT=true` is present in the file. Called automatically on module import when a default config is found at `(Split-Path $PROFILE)\.xurrent\config.env`.

## [0.4.0] - 2026-06-17

### Added

- `ConvertFrom-XurrentKnowledgeArticle`: Writes the article `ID` from the CSV row as a `**ID:**` line in the generated Markdown file, enabling round-trip editing of existing articles.
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
