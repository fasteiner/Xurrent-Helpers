function New-XurrentKnowledgeArticleCsvExample
{
    <#
        .SYNOPSIS
        Creates an example CSV file in the Xurrent knowledge article import format.

        .DESCRIPTION
        Writes a CSV file with all columns required by the Xurrent / 4me bulk-import schema
        for knowledge articles, pre-filled with one illustrative example row. Use it as a
        reference or starting point before populating real data via Export-KnowledgeArticle.

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
            $encoding = if ($PSVersionTable.PSVersion.Major -ge 7) { 'utf8BOM' } else { 'UTF8' }
            $example | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding $encoding
            Get-Item -Path $OutputPath
        }
    }
}
