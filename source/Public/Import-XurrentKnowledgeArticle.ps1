function Import-XurrentKnowledgeArticle
{
    <#
        .SYNOPSIS
        Imports Xurrent knowledge articles from a CSV export file and writes Markdown files.

        .DESCRIPTION
        Reads a CSV file in the Xurrent / 4me bulk-import format and writes one
        *KnowledgeArticle.md file per row to the specified output folder. Subject becomes
        the H1 heading and the filename prefix, Description and Instructions populate their
        respective ## sections, and Keywords are written to a **Keywords:** line. Passes
        -WhatIf through to ConvertFrom-XurrentKnowledgeArticle for dry-run support.

        .PARAMETER CsvPath
        Path to the Xurrent knowledge article CSV export file to read.

        .PARAMETER OutputFolder
        The folder in which to write the Markdown files.
        Defaults to the current working directory.

        .EXAMPLE
        Import-XurrentKnowledgeArticle -CsvPath .\export-knowledge_articles.csv -OutputFolder .\Articles

        .EXAMPLE
        Import-XurrentKnowledgeArticle -CsvPath .\export.csv
        Writes Markdown files to the current working directory.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([System.IO.FileInfo])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]
        $CsvPath,

        [Parameter()]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]
        $OutputFolder = (Get-Location).Path
    )

    process
    {
        $rows = @(Import-Csv -Path $CsvPath -Encoding UTF8)

        if ($rows.Count -eq 0)
        {
            Write-Warning "No rows found in $CsvPath"
            return
        }

        Write-Verbose "Found $($rows.Count) row(s) in $CsvPath"

        if ($PSCmdlet.ShouldProcess($CsvPath, 'Import knowledge articles to Markdown'))
        {
            foreach ($row in $rows)
            {
                Write-Verbose "  Processing '$($row.Subject)'"
                ConvertFrom-XurrentKnowledgeArticle -InputObject $row -Path $OutputFolder
            }
        }
    }
}
