function ConvertTo-XurrentKnowledgeArticle
{
    <#
        .SYNOPSIS
        Converts a Markdown knowledge article file to a Xurrent import object.

        .DESCRIPTION
        Reads a *KnowledgeArticle.md file and extracts the Subject (first H1 heading),
        Description (## Description section), Instructions (## Instructions section),
        Keywords (**Keywords:** line), ID (**ID:** line), Service (**Service:** line),
        and Service Instances (**Service Instances:** line) into a PSCustomObject formatted
        for the Xurrent / 4me bulk-import CSV schema. Service metadata from the Markdown
        prelude is used first; the Service and ServiceInstances parameters are fallbacks.

        .PARAMETER File
        The input file to convert. Supports FileInfo, path strings, and objects that
        expose a FullName or Path property. Accepts pipeline input.

        .PARAMETER Service
        The Xurrent service name to write to the Service column of the import row.

        .PARAMETER ServiceInstances
        The Xurrent service instance name(s) for the Service Instances column.

        .EXAMPLE
        Get-Item .\MyAppKnowledgeArticle.md | ConvertTo-XurrentKnowledgeArticle -Service 'techwork automator' -ServiceInstances 'techwork automator for ACS'

        .EXAMPLE
        Get-ChildItem -Recurse -Filter '*KnowledgeArticle.md' | ConvertTo-XurrentKnowledgeArticle -Service 'my svc' -ServiceInstances 'my inst'
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('FullName', 'Path', 'PSPath')]
        [object]
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
        $filePath = $null
        if ($File -is [System.IO.FileInfo])
        {
            $filePath = $File.FullName
        }
        elseif ($File -is [string])
        {
            $filePath = $File
        }
        elseif ($null -ne $File.PSObject.Properties['FullName'])
        {
            $filePath = [string]$File.FullName
        }
        elseif ($null -ne $File.PSObject.Properties['Path'])
        {
            $filePath = [string]$File.Path
        }

        if (-not $filePath)
        {
            throw 'File must be a path string, FileInfo, or an object with FullName/Path.'
        }

        $resolvedFile = Get-Item -LiteralPath $filePath -ErrorAction Stop
        if ($resolvedFile -isnot [System.IO.FileInfo])
        {
            throw "Input path '$filePath' is not a file."
        }

        $raw = Get-Content -Path $resolvedFile.FullName -Raw -Encoding UTF8

        $subject = ''
        if ($raw -match '(?m)^#\s+(.+)$') { $subject = $Matches[1].Trim() }

        $id = ''
        $prelude = ($raw -split '(?m)^\s*##\s+', 2)[0]
        if ($prelude -match '(?m)^\*\*ID:\*\*[ \t]*(.*?)[ \t]*$') { $id = $Matches[1].Trim() }
        $metadataService = ''
        if ($prelude -match '(?m)^\*\*Service:\*\*[ \t]*(.*?)[ \t]*$') { $metadataService = $Matches[1].Trim() }
        $metadataServiceInstances = ''
        if ($prelude -match '(?m)^\*\*Service Instances:\*\*[ \t]*(.*?)[ \t]*$') { $metadataServiceInstances = $Matches[1].Trim() }
        $keywords = ''
        if ($raw -match '(?m)^\*\*Keywords:\*\*[ \t]*(.+?)[ \t]*$') { $keywords = $Matches[1].Trim() }

        $effectiveService = if ($metadataService) { $metadataService } else { $Service }
        $effectiveServiceInstances = if ($metadataServiceInstances) { $metadataServiceInstances } else { $ServiceInstances }

        [PSCustomObject]@{
            ID                  = $id
            Source              = '4me'
            'Source ID'         = ''
            Status              = 'work_in_progress'
            Service             = $effectiveService
            'Service Instances' = $effectiveServiceInstances
            Subject             = $subject
            Description         = Get-Section -Content $raw -Heading 'Description'
            Instructions        = Get-Section -Content $raw -Heading 'Instructions'
            Keywords            = $keywords
            Template            = ''
        }
    }
}
