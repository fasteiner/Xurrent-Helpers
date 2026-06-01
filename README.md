# XurrentHelpers - A PowerShell module to automate your Xurrent environment

[![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/XurrentHelpers?label=PSGallery%20Version)](https://www.powershellgallery.com/packages/XurrentHelpers)
[![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/XurrentHelpers?label=Downloads)](https://www.powershellgallery.com/packages/XurrentHelpers)
![Platform](https://img.shields.io/badge/Platform-Windows|Linux|MacOS-blue)
[![GitHub Issues](https://img.shields.io/github/issues/fasteiner/Xurrent-Helpers?label=Issues)](https://github.com/fasteiner/Xurrent-Helpers/issues)

[Xurrent](https://www.xurrent.com) (formerly 4me) is an enterprise IT Service Management platform designed for high-velocity service delivery across organizations and their service providers.

This PowerShell module provides cmdlets to automate Xurrent administration tasks, built and maintained by [techwork data GmbH](https://www.techwork.at).

For detailed API reference, see the [Xurrent API documentation](https://developer.xurrent.com).

## Functions

| Knowledge Articles                    |
| ------------------------------------- |
| ConvertTo-XurrentKnowledgeArticle     |
| Export-XurrentKnowledgeArticle        |
| New-XurrentKnowledgeArticleCsvExample |
| New-XurrentKnowledgeArticleTemplate   |

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

The knowledge article cmdlets let you author articles in Markdown and bulk-import them into Xurrent via the CSV import format.

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
SERVICE_INSTANCES=techwork automator for ACS
```

```powershell
Export-XurrentKnowledgeArticle -Folder .\Articles
# Reads SERVICE / SERVICE_INSTANCES from .env automatically
```

### Generate an example CSV

```powershell
New-XurrentKnowledgeArticleCsvExample
# Creates example-knowledge_articles.csv in the current directory

New-XurrentKnowledgeArticleCsvExample -OutputPath C:\Temp\example.csv
```
