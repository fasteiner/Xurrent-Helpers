function Export-XurrentKnowledgeArticle
{
    <#
        .SYNOPSIS
        Exports Xurrent knowledge articles from Markdown files or objects to a CSV import file.

        .DESCRIPTION
        Accepts either a folder path (scanned recursively for *KnowledgeArticle.md files) or an
        array of pre-built article objects (e.g. the output of ConvertTo-XurrentKnowledgeArticle)
        and writes a CSV in the Xurrent / 4me bulk-import format.

        When using the Folder parameter set, Subject is read from the first H1 heading,
        Description and Instructions from same-named ## sections, Keywords from a
        **Keywords:** line. Service and ServiceInstances can be set via parameters or
        loaded from a .env file (SERVICE and SERVICE_INSTANCES keys).

        When using the InputObject parameter set the objects are exported as-is; Service,
        ServiceInstances, and EnvFile parameters are not applicable.

        .PARAMETER Folder
        Path to the folder to scan recursively for *KnowledgeArticle.md files.

        .PARAMETER InputObject
        One or more knowledge article objects (as returned by ConvertTo-XurrentKnowledgeArticle)
        to export directly without scanning a folder. Accepts pipeline input.

        .PARAMETER Service
        Xurrent service name written to the Service column of every export row.
        Defaults to 'techwork automator'. Can also be supplied via SERVICE= in a .env file.

        .PARAMETER ServiceInstances
        Xurrent service instance name(s) for the Service Instances column.
        Can be supplied via SERVICE_INSTANCES= in a .env file; prompts interactively if still empty.

        .PARAMETER OutputPath
        Full path of the CSV file to write.
        Defaults to import-knowledge_articles.csv in the current working directory.

        .PARAMETER EnvFile
        Path to a .env file supplying SERVICE and SERVICE_INSTANCES defaults.
        Defaults to .env in the current working directory when that file exists.

        .EXAMPLE
        Export-XurrentKnowledgeArticle -Folder .\ACS -Service 'techwork automator' -ServiceInstances 'techwork automator for ACS'

        .EXAMPLE
        Export-XurrentKnowledgeArticle -Folder .\TTTech
        Loads SERVICE and SERVICE_INSTANCES from .env in the current directory.

        .EXAMPLE
        Get-ChildItem -Recurse -Filter '*KnowledgeArticle.md' |
            ConvertTo-XurrentKnowledgeArticle -Service 'techwork automator' -ServiceInstances 'ACS' |
            Export-XurrentKnowledgeArticle -OutputPath .\out.csv
        Pipes pre-converted article objects directly into the export.

        .EXAMPLE
        $articles = ConvertTo-XurrentKnowledgeArticle -File .\MyArticleKnowledgeArticle.md -Service 'svc' -ServiceInstances 'inst'
        Export-XurrentKnowledgeArticle -InputObject $articles
        Passes an object array directly without pipeline.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'FromFolder')]
    param
    (
        [Parameter(Mandatory = $true, ParameterSetName = 'FromFolder')]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]
        $Folder,

        [Parameter(Mandatory = $true, ParameterSetName = 'FromObjects', ValueFromPipeline = $true)]
        [object[]]
        $InputObject,

        [Parameter(ParameterSetName = 'FromFolder')]
        [string]
        $Service = 'techwork automator',

        [Parameter(ParameterSetName = 'FromFolder')]
        [string]
        $ServiceInstances = '',

        [Parameter()]
        [string]
        $OutputPath = (Join-Path (Get-Location).Path 'import-knowledge_articles.csv'),

        [Parameter(ParameterSetName = 'FromFolder')]
        [string]
        $EnvFile = (Join-Path (Get-Location).Path '.env')
    )

    begin
    {
        $rows = [System.Collections.Generic.List[object]]::new()
    }

    process
    {
        if ($PSCmdlet.ParameterSetName -eq 'FromObjects')
        {
            foreach ($obj in $InputObject) { $rows.Add($obj) }
            return
        }

        if (Test-Path $EnvFile)
        {
            foreach ($line in (Get-Content $EnvFile))
            {
                if ($line -match "^([A-Z_]+)\s*=\s*'?([^']*?)'?\s*$")
                {
                    $key = $Matches[1]
                    $val = $Matches[2]
                    if ($key -eq 'SERVICE' -and -not $PSBoundParameters.ContainsKey('Service')) { $Service = $val }
                    if ($key -eq 'SERVICE_INSTANCES' -and -not $PSBoundParameters.ContainsKey('ServiceInstances')) { $ServiceInstances = $val }
                }
            }
        }

        if (-not $Service)
        {
            $Service = Read-Host -Prompt "Enter SERVICE name (e.g. 'techwork automator')"
        }
        if (-not $ServiceInstances)
        {
            $ServiceInstances = Read-Host -Prompt 'Enter SERVICE_INSTANCES'
        }

        $files = Get-ChildItem -Path $Folder -Recurse -Filter '*KnowledgeArticle.md'

        if ($files.Count -eq 0)
        {
            Write-Warning "No *KnowledgeArticle.md files found in $Folder"
            return
        }

        Write-Verbose "Found $($files.Count) knowledge article(s) in $Folder"

        foreach ($file in $files)
        {
            Write-Verbose "  Processing $($file.FullName)"
            $rows.Add((ConvertTo-XurrentKnowledgeArticle -File $file -Service $Service -ServiceInstances $ServiceInstances))
        }
    }

    end
    {
        if ($rows.Count -eq 0) { return }

        if ($PSCmdlet.ShouldProcess($OutputPath, 'Export CSV'))
        {
            $encoding = if ($PSVersionTable.PSVersion.Major -ge 7) { 'utf8BOM' } else { 'UTF8' }
            $rows | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding $encoding
            Write-Verbose "Exported $($rows.Count) article(s) to $OutputPath"
        }
    }
}
