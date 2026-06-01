function Export-XurrentKnowledgeArticle
{
    <#
        .SYNOPSIS
        Exports Xurrent knowledge articles from Markdown files to a CSV import file.

        .DESCRIPTION
        Scans a folder recursively for *KnowledgeArticle.md files and writes a CSV in the
        Xurrent / 4me bulk-import format. Subject is read from the first H1 heading,
        Description and Instructions from same-named ## sections, Keywords from a
        **Keywords:** line. Service and ServiceInstances can be set via parameters or
        loaded from a .env file (SERVICE and SERVICE_INSTANCES keys).

        .PARAMETER Folder
        Path to the folder to scan recursively for *KnowledgeArticle.md files.

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
        Export-KnowledgeArticle -Folder .\ACS -Service 'techwork automator' -ServiceInstances 'techwork automator for ACS'

        .EXAMPLE
        Export-KnowledgeArticle -Folder .\TTTech
        Loads SERVICE and SERVICE_INSTANCES from .env in the current directory.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]
        $Folder,

        [Parameter()]
        [string]
        $Service = 'techwork automator',

        [Parameter()]
        [string]
        $ServiceInstances = '',

        [Parameter()]
        [string]
        $OutputPath = (Join-Path (Get-Location).Path 'import-knowledge_articles.csv'),

        [Parameter()]
        [string]
        $EnvFile = (Join-Path (Get-Location).Path '.env')
    )

    process
    {
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

        $rows = foreach ($file in $files)
        {
            Write-Verbose "  Processing $($file.FullName)"
            ConvertTo-XurrentKnowledgeArticle -File $file -Service $Service -ServiceInstances $ServiceInstances
        }

        if ($PSCmdlet.ShouldProcess($OutputPath, 'Export CSV'))
        {
            # PS 7+ needs utf8BOM for a BOM-prefixed file; PS 5.1 UTF8 already includes one.
            $encoding = if ($PSVersionTable.PSVersion.Major -ge 7) { 'utf8BOM' } else { 'UTF8' }
            $rows | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding $encoding
            Write-Verbose "Exported $($rows.Count) article(s) to $OutputPath"
        }
    }
}
