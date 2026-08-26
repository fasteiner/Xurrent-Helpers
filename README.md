# XurrentHelpers - A PowerShell module to automate your Xurrent environment

[![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/XurrentHelpers?label=PSGallery%20Version)](https://www.powershellgallery.com/packages/XurrentHelpers)
[![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/XurrentHelpers?label=Downloads)](https://www.powershellgallery.com/packages/XurrentHelpers)
![Platform](https://img.shields.io/badge/Platform-Windows|Linux|MacOS-blue)
[![GitHub Issues](https://img.shields.io/github/issues/fasteiner/Xurrent-Helpers?label=Issues)](https://github.com/fasteiner/Xurrent-Helpers/issues)

[Xurrent](https://www.xurrent.com) (formerly 4me) is an enterprise IT Service Management platform designed for high-velocity service delivery across organizations and their service providers.

This PowerShell module provides cmdlets to automate Xurrent administration tasks, built and maintained by [techwork data GmbH](https://www.techwork.at).

For detailed API reference, see the [Xurrent API documentation](https://developer.xurrent.com).

## Functions

| Knowledge Articles                     |
| -------------------------------------- |
| ConvertTo-XurrentKnowledgeArticle      |
| ConvertFrom-XurrentKnowledgeArticle    |
| Export-XurrentKnowledgeArticle         |
| Import-XurrentKnowledgeArticle         |
| New-XurrentKnowledgeArticleCsvExample  |
| New-XurrentKnowledgeArticleTemplate    |

## Getting Started

```powershell
# PowerShellGet 2.x
Install-Module -Name XurrentHelpers -Repository PSGallery

# PowerShellGet 3.x
Install-PSResource -Name XurrentHelpers

Import-Module XurrentHelpers

# List all available cmdlets provided by the module
Get-Command -Module XurrentHelpers
```

## Knowledge Articles

The knowledge article cmdlets work in both directions: author articles in Markdown and bulk-import them into Xurrent, or export from Xurrent and convert back to Markdown files. The article `ID` is preserved through both conversions (as an `**ID:**` line in the Markdown and an `ID` column in the CSV), so a round-tripped article updates the existing Xurrent record instead of creating a duplicate.

### Create a new article template

```powershell
New-XurrentKnowledgeArticleTemplate -Name 'HowToResetPassword'
# Creates HowToResetPasswordKnowledgeArticle.md in the current directory
```

### Convert a single Markdown file to an import object

```powershell
Get-Item .\HowToResetPasswordKnowledgeArticle.md |
    ConvertTo-XurrentKnowledgeArticle -Service 'My Service' -ServiceInstances 'My Service Instance'
```

### Export a folder of articles to a Xurrent import CSV

```powershell
Export-XurrentKnowledgeArticle -Folder .\Articles -Service 'My Service' -ServiceInstances 'My Service Instance'
# Writes import-knowledge_articles.csv in the current directory
```

You can also store `SERVICE` and `SERVICE_INSTANCES` in a `.env` file in the working directory so you don't have to pass them each time:

```ini
SERVICE=techwork automator
SERVICE_INSTANCES=techwork automator for techwork
```

```powershell
Export-XurrentKnowledgeArticle -Folder .\Articles
# Reads SERVICE / SERVICE_INSTANCES from .env automatically
```

You can also pipe pre-built article objects (from `ConvertTo-XurrentKnowledgeArticle`) straight into the export, which is handy when you want to filter or adjust them first:

```powershell
Get-ChildItem -Recurse -Filter '*KnowledgeArticle.md' |
    ConvertTo-XurrentKnowledgeArticle -Service 'My Service' -ServiceInstances 'My Service Instance' |
    Export-XurrentKnowledgeArticle -OutputPath .\out.csv
```

### Import a Xurrent CSV export back to Markdown files

```powershell
Import-XurrentKnowledgeArticle -CsvPath .\export-knowledge_articles.csv -OutputFolder .\Articles
# Writes one *KnowledgeArticle.md file per row into .\Articles
```

### Convert a single CSV row to a Markdown file

```powershell
Import-Csv .\export-knowledge_articles.csv |
    ConvertFrom-XurrentKnowledgeArticle -Path .\Articles
```

### Update existing articles (round-trip by ID)

Because the article `ID` survives the round-trip, you can pull existing articles out of Xurrent, edit them as Markdown, and push them back as updates rather than new records:

```powershell
# 1. Export from Xurrent, then convert the CSV to editable Markdown (the **ID:** line is filled in)
Import-XurrentKnowledgeArticle -CsvPath .\export-knowledge_articles.csv -OutputFolder .\Articles

# 2. Edit the *KnowledgeArticle.md files — leave the **ID:** line intact

# 3. Convert back to an import CSV; the ID is carried through so Xurrent updates the existing articles
Export-XurrentKnowledgeArticle -Folder .\Articles
```

> New articles authored from `New-XurrentKnowledgeArticleTemplate` have an empty `**ID:**` line and are imported as new records.

### Generate an example CSV

```powershell
New-XurrentKnowledgeArticleCsvExample
# Creates example-knowledge_articles.csv in the current directory

New-XurrentKnowledgeArticleCsvExample -OutputPath C:\Temp\example.csv
```
