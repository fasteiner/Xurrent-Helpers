function ConvertTo-KnowledgeArticle
{
    <#
        .SYNOPSIS
        Converts a Markdown knowledge article file to a Xurrent import object.

        .DESCRIPTION
        Reads a *KnowledgeArticle.md file and extracts the Subject (first H1 heading),
        Description (## Description section), Instructions (## Instructions section),
        and Keywords (**Keywords:** line) into a PSCustomObject formatted for the
        Xurrent / 4me bulk-import CSV schema.

        .PARAMETER File
        The FileInfo object of the *KnowledgeArticle.md file to convert.
        Accepts pipeline input.

        .PARAMETER Service
        The Xurrent service name to write to the Service column of the import row.

        .PARAMETER ServiceInstances
        The Xurrent service instance name(s) for the Service Instances column.

        .EXAMPLE
        Get-Item .\MyAppKnowledgeArticle.md | ConvertTo-KnowledgeArticle -Service 'techwork automator' -ServiceInstances 'techwork automator for ACS'

        .EXAMPLE
        Get-ChildItem -Recurse -Filter '*KnowledgeArticle.md' | ConvertTo-KnowledgeArticle -Service 'my svc' -ServiceInstances 'my inst'
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.IO.FileInfo]
        $File,

        [Parameter(Mandatory = $true)]
        [string]
        $Service,

        [Parameter(Mandatory = $true)]
        [string]
        $ServiceInstances
    )

    process
    {
        $raw = Get-Content -Path $File.FullName -Raw -Encoding UTF8

        $subject = ''
        if ($raw -match '(?m)^#\s+(.+)$') { $subject = $Matches[1].Trim() }

        $keywords = ''
        if ($raw -match '\*\*Keywords:\*\*\s*(.+)') { $keywords = $Matches[1].Trim() }

        [PSCustomObject]@{
            ID                  = ''
            Source              = '4me'
            'Source ID'         = ''
            Status              = 'work_in_progress'
            Service             = $Service
            'Service Instances' = $ServiceInstances
            Subject             = $subject
            Description         = Get-Section -Content $raw -Heading 'Description'
            Instructions        = Get-Section -Content $raw -Heading 'Instructions'
            Keywords            = $keywords
            Template            = ''
        }
    }
}
