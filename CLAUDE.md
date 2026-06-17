# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

`XurrentHelpers` is a PowerShell module (targeting PS 5.0+) that provides cmdlets for Xurrent (formerly 4me) ITSM administration. The project is scaffolded with [Sampler](https://github.com/gaelcolas/Sampler) and built via InvokeBuild.

All build files (`build.ps1`, `build.yaml`, `source/`, `tests/`, etc.) live at the **repo root**.

## Build Commands

All commands must be run from the repo root (where `build.ps1` lives).

**First-time setup — resolve dependencies:**
```powershell
.\build.ps1 -ResolveDependency -Tasks noop
```

**Build the module:**
```powershell
.\build.ps1 -Tasks build
```

**Run all tests:**
```powershell
.\build.ps1 -Tasks test
```
Or via VSCode: use the `test` task defined in `.vscode/tasks.json`.

**Build + test (default workflow):**
```powershell
.\build.ps1
```

**Run a specific Pester test file directly** (after `build` has run once):
```powershell
Invoke-Pester -Path tests\Unit\Public\ConvertTo-XurrentKnowledgeArticle.tests.ps1
```

**Generate documentation (wiki):**
```powershell
.\build.ps1 -Tasks docs
```

## Architecture

```
(repo root)
  source/
    Public/      ← exported functions (one file per function)
      ConvertTo-XurrentKnowledgeArticle.ps1
      Export-XurrentKnowledgeArticle.ps1
      New-XurrentKnowledgeArticleCsvExample.ps1
      New-XurrentKnowledgeArticleTemplate.ps1
    Private/     ← internal helpers (not exported)
      Get-Section.ps1
    en-US/       ← external help
    XurrentHelpers.psd1   ← module manifest
    XurrentHelpers.psm1   ← empty stub; rebuilt by ModuleBuilder at build time
  tests/
    Unit/Public/ ← Pester tests, one file per public function
    Unit/Private/
    QA/          ← module-level quality tests (PSSA, help, changelog)
  build.yaml     ← Sampler pipeline config (tasks, Pester thresholds)
  build.ps1      ← InvokeBuild entry point (bootstraps deps, then runs tasks)
  RequiredModules.psd1   ← build/test dependencies (InvokeBuild, Pester, etc.)
  Resolve-Dependency.ps1 / .psd1  ← dependency resolution bootstrap
  GitVersion.yml ← semver bump rules keyed on commit message keywords
  CHANGELOG.md   ← Keep a Changelog format; must be updated with every PR
```

The `source/XurrentHelpers.psm1` is intentionally empty; ModuleBuilder merges all `Public/` and `Private/` files into it during `build`. The built artefact lands in `output/module/XurrentHelpers/<version>/`.

## Naming Convention

All exported cmdlets follow the pattern **`Verb-XurrentNoun`** — `Xurrent` is always inserted between the verb and the domain noun. Examples: `ConvertTo-XurrentKnowledgeArticle`, `Export-XurrentKnowledgeArticle`, `New-XurrentKnowledgeArticleTemplate`.

## Adding a New Cmdlet

1. Add `source/Public/Verb-XurrentNoun.ps1` with the function.
2. Add `tests/Unit/Public/Verb-XurrentNoun.tests.ps1` with Pester tests.
3. Update `CHANGELOG.md` under `## [Unreleased] > ### Added`.

## QA Requirements (enforced by `tests/QA/module.tests.ps1`)

Every exported function must have:
- `.SYNOPSIS`
- `.DESCRIPTION` longer than 40 characters
- At least one `.EXAMPLE` that includes the function name
- `.PARAMETER` descriptions longer than 25 characters for each parameter
- A passing PSScriptAnalyzer run
- A corresponding `tests/Unit/…/FunctionName.tests.ps1`

Code coverage threshold is **85%** (set in `build.yaml`).

## Versioning

GitVersion drives semver automatically from commit messages:
- `breaking change` / `breaking` / `major` → major bump
- `adds?` / `features?` / `minor` → minor bump
- `fix` / `patch` → patch bump
- `+semver: skip` / `+semver: none` → no bump
