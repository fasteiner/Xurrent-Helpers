function New-XurrentKnowledgeArticleCsvExample
{
    <#
        .SYNOPSIS
        Creates an example CSV file in the Xurrent knowledge article import format.

        .DESCRIPTION
        Writes a CSV file with all columns required by the Xurrent / 4me bulk-import schema
        for knowledge articles, pre-filled with one illustrative example row. Use it as a
        reference or starting point before populating real data via Export-KnowledgeArticle.
        The CSV is encoded as UTF-8 without a byte-order mark (BOM); a BOM makes Xurrent
        reject the file with "Illegal quoting in line 1".

        .PARAMETER OutputPath
        Full path of the CSV file to write.
        Defaults to example-knowledge_articles.csv in the current working directory.

        .EXAMPLE
        New-KnowledgeArticleCsvExample
        Creates example-knowledge_articles.csv in the current directory.

        .EXAMPLE
        New-KnowledgeArticleCsvExample -OutputPath C:\Temp\example.csv
        Creates the example CSV at the specified path.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([System.IO.FileInfo])]
    param
    (
        [Parameter()]
        [string]
        $OutputPath = (Join-Path (Get-Location).Path 'example-knowledge_articles.csv')
    )

    process
    {
        $example = [PSCustomObject]@{
            ID                  = ''
            Source              = '4me'
            'Source ID'         = ''
            Status              = 'work_in_progress'
            Service             = 'my service'
            'Service Instances' = 'my service instance'
            Subject             = 'Example knowledge article subject'
            Description         = 'A brief description of the knowledge article.'
            Instructions        = 'Step 1: Do this. Step 2: Do that.'
            Keywords            = 'example, keyword1, keyword2'
            Template            = ''
        }

        if ($PSCmdlet.ShouldProcess($OutputPath, 'Create example knowledge article CSV'))
        {
            # Write BOM-less UTF-8. Xurrent rejects a leading BOM ("Illegal quoting in line 1"),
            # and Windows PowerShell 5.1 has no BOM-less option for Export-Csv -Encoding, so build
            # the CSV text and write it with an explicit encoding that behaves the same on PS 5.1 and 7+.
            $resolvedPath = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($OutputPath)
            $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
            $csvLines = $example | ConvertTo-Csv -NoTypeInformation
            [System.IO.File]::WriteAllLines($resolvedPath, $csvLines, $utf8NoBom)
            Get-Item -Path $OutputPath
        }
    }
}
