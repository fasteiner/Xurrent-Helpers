function Export-XurrentKnowledgeArticle
{
    <#
        .SYNOPSIS
        Exports Xurrent knowledge articles from Markdown files or objects to a CSV import file.

        .DESCRIPTION
        Accepts either a folder path (scanned recursively for *KnowledgeArticle.md files) or an
        array of pre-built article objects (e.g. the output of ConvertTo-XurrentKnowledgeArticle)
        and writes a CSV in the Xurrent / 4me bulk-import format. The CSV is encoded as
        UTF-8 without a byte-order mark (BOM); a BOM makes Xurrent reject the file with
        "Illegal quoting in line 1".

        When using the Folder parameter set, Subject is read from the first H1 heading,
        Description and Instructions from same-named ## sections, Keywords from a
        **Keywords:** line, and ID/Service/Service Instances from their metadata lines.
        Service and ServiceInstances can be set via parameters or loaded from a .env file
        (SERVICE and SERVICE_INSTANCES keys) and are used as fallbacks when the Markdown
        file does not provide service metadata. A warning naming the article's Subject is
        written for each article whose effective Service Instances value is empty after
        applying the fallback.

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
        Xurrent service instance name(s) for the Service Instances column. Optional - the Xurrent
        API does not require a value. Can be supplied via SERVICE_INSTANCES= in a .env file. The
        value is a fallback for articles without their own **Service Instances:** Markdown
        metadata; a warning naming the article's Subject is written for each article whose
        effective Service Instances value is empty, because that article will then be visible
        to every specialist covered for the service rather than scoped to one instance.

        .PARAMETER OutputPath
        Full path of the CSV file to write. When only a directory is supplied (or the
        path ends with a directory separator), the default file name
        import-knowledge_articles.csv is appended automatically.
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
        $OutputPath = (Get-Location).Path,

        [Parameter(ParameterSetName = 'FromFolder')]
        [string]
        $EnvFile = (Join-Path (Get-Location).Path '.env')
    )

    begin
    {
        $rows = [System.Collections.Generic.List[object]]::new()

        # When only a directory is supplied (including the default current location),
        # append the default file name so the export always targets a CSV file.
        if ((Test-Path -LiteralPath $OutputPath -PathType Container) -or
            ($OutputPath -and (
                $OutputPath.EndsWith([System.IO.Path]::DirectorySeparatorChar) -or
                $OutputPath.EndsWith([System.IO.Path]::AltDirectorySeparatorChar))))
        {
            $OutputPath = Join-Path $OutputPath 'import-knowledge_articles.csv'
        }
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
            $article = ConvertTo-XurrentKnowledgeArticle -File $file -Service $Service -ServiceInstances $ServiceInstances

            if (-not $article.'Service Instances')
            {
                Write-Warning "No Service Instances specified for article '$($article.Subject)' (service '$($article.Service)') - the article will be visible to every specialist covered for any instance of this service, rather than scoped to one specific instance."
            }

            $rows.Add($article)
        }
    }

    end
    {
        if ($rows.Count -eq 0) { return }

        if ($PSCmdlet.ShouldProcess($OutputPath, 'Export CSV'))
        {
            # Write BOM-less UTF-8. Xurrent rejects a leading BOM ("Illegal quoting in line 1"),
            # and Windows PowerShell 5.1 has no BOM-less option for Export-Csv -Encoding, so build
            # the CSV text and write it with an explicit encoding that behaves the same on PS 5.1 and 7+.
            $resolvedPath = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($OutputPath)
            $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
            $csvLines = $rows | ConvertTo-Csv -NoTypeInformation
            [System.IO.File]::WriteAllLines($resolvedPath, $csvLines, $utf8NoBom)
            Write-Verbose "Exported $($rows.Count) article(s) to $OutputPath"
        }
    }
}
