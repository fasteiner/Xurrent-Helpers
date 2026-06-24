function ConvertFrom-XurrentKnowledgeArticle
{
    <#
        .SYNOPSIS
        Converts a Xurrent knowledge article CSV row to a Markdown file.

        .DESCRIPTION
        Takes a PSCustomObject in the Xurrent / 4me bulk-import CSV schema (as produced
        by Import-Csv or ConvertTo-XurrentKnowledgeArticle) and writes a *KnowledgeArticle.md
        file with the correct structure: H1 for Subject, **ID:**, **Service:**,
        **Service Instances:**, and **Keywords:** metadata lines, plus
        ## Description and ## Instructions sections. Accepts pipeline input for batch processing
        of CSV rows. Invalid filename characters in Subject are replaced with hyphens.

        .PARAMETER InputObject
        A PSCustomObject with ID, Service, Service Instances, Subject, Description,
        Instructions, and Keywords properties, matching the Xurrent knowledge article CSV
        schema. Accepts pipeline input.

        .PARAMETER Path
        The folder in which to write the Markdown file.
        Defaults to the current working directory.

        .EXAMPLE
        Import-Csv .\knowledge_articles.csv | ConvertFrom-XurrentKnowledgeArticle -Path .\Articles

        .EXAMPLE
        $row = [PSCustomObject]@{ Subject = 'VPN Setup'; Description = 'How to...'; Instructions = 'Step 1...'; Keywords = 'vpn' }
        ConvertFrom-XurrentKnowledgeArticle -InputObject $row -Path .\Output
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([System.IO.FileInfo])]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]
        $InputObject,

        [Parameter()]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]
        $Path = (Get-Location).Path
    )

    process
    {
        $id           = if ($InputObject.ID)           { [string]$InputObject.ID }           else { '' }
        $service      = if ($null -ne $InputObject.PSObject.Properties['Service'] -and
                            $InputObject.PSObject.Properties['Service'].Value)
                        {
                            [string]$InputObject.Service
                        }
                        else
                        {
                            ''
                        }
        $serviceInstances = if ($null -ne $InputObject.PSObject.Properties['Service Instances'] -and
                                $InputObject.PSObject.Properties['Service Instances'].Value)
                            {
                                [string]$InputObject.'Service Instances'
                            }
                            elseif ($null -ne $InputObject.PSObject.Properties['ServiceInstances'] -and
                                    $InputObject.PSObject.Properties['ServiceInstances'].Value)
                            {
                                [string]$InputObject.ServiceInstances
                            }
                            else
                            {
                                ''
                            }
        $subject      = if ($InputObject.Subject)      { [string]$InputObject.Subject }      else { '' }
        $description  = if ($InputObject.Description)  { [string]$InputObject.Description }  else { '' }
        $instructions = if ($InputObject.Instructions) { [string]$InputObject.Instructions } else { '' }
        $keywords     = if ($InputObject.Keywords)     { [string]$InputObject.Keywords }     else { '' }

        $invalidChars = [System.IO.Path]::GetInvalidFileNameChars() -join ''
        $safeName = $subject -replace "[$([regex]::Escape($invalidChars))]", '-'
        $safeName = $safeName.Trim('-', ' ')
        if (-not $safeName) { $safeName = 'Unknown' }

        $fileName = '{0}KnowledgeArticle.md' -f $safeName
        $filePath = Join-Path -Path $Path -ChildPath $fileName

        $content = @"
# $subject

**ID:** $id

**Service:** $service

**Service Instances:** $serviceInstances

**Keywords:** $keywords

## Description

$description

## Instructions

$instructions
"@

        if ($PSCmdlet.ShouldProcess($filePath, 'Create knowledge article Markdown file'))
        {
            Set-Content -Path $filePath -Value $content -Encoding UTF8
            Get-Item -Path $filePath
        }
    }
}
