function ConvertTo-XurrentCrossEnvironmentImport
{
    <#
        .SYNOPSIS
        Prepares Xurrent CSV exports for import into another environment by moving ID into Source ID.

        .DESCRIPTION
        Prepares Xurrent CSV exports from one environment (e.g. QA) for import into another
        environment (e.g. Production). An import row that carries an ID updates the record with that
        ID in the target environment. Moving the value to the Source ID column makes the import
        create a new record instead, while the original ID stays traceable.

        For every row with a non-empty ID, Source ID is set to the ID and the ID is emptied; the ID
        column itself stays in the file. Rows with an empty ID are left untouched, so a second run
        does not wipe the Source ID written by the first. An existing, different Source ID is
        overwritten with a warning. A file without rows, or without the ID or Source ID column, is
        skipped with a warning.

        The file is overwritten in place. Column order and all other values are kept, including
        multi-line quoted fields such as the HTML, CSS and JavaScript of UI extension exports. Every
        field is written quoted, as UTF-8 without a byte-order mark (BOM); Xurrent rejects a BOM with
        "Illegal quoting in line 1".

        Files are selected by name (-Path, also from the pipeline) or by download time (-LastHours,
        the default).

        .PARAMETER Path
        One or more CSV files to convert. Relative names are resolved against -Folder. Accepts
        pipeline input by value and by property name (FullName), so the output of Get-ChildItem can
        be piped in. A name that is not found produces a warning and is skipped.

        .PARAMETER LastHours
        Selects every *.csv file in -Folder whose CreationTime or LastWriteTime lies within the last
        N hours. Defaults to 1. Applies when -Path is not given.

        .PARAMETER Folder
        Folder that relative -Path names are resolved against and that -LastHours scans. Defaults to
        the Downloads folder in the user's home directory.

        .PARAMETER IdColumn
        Name of the CSV column holding the record ID that is moved and then emptied. Defaults to
        'ID'.

        .PARAMETER SourceIdColumn
        Name of the CSV column that receives the record ID. Defaults to 'Source ID'.

        .OUTPUTS
        One object per processed file with the properties File (full path), Moved (number of moved
        IDs) and Status: Moved, NothingToMove, Skipped, or WhatIf when the file was not written
        because of -WhatIf or a declined -Confirm.

        .EXAMPLE
        ConvertTo-XurrentCrossEnvironmentImport
        Converts every CSV file downloaded to the Downloads folder within the last hour.

        .EXAMPLE
        ConvertTo-XurrentCrossEnvironmentImport -LastHours 3 -WhatIf
        Shows which CSV files of the last three hours would be changed, without writing them.

        .EXAMPLE
        ConvertTo-XurrentCrossEnvironmentImport -Path slas-1.csv
        Converts slas-1.csv in the Downloads folder.

        .EXAMPLE
        ConvertTo-XurrentCrossEnvironmentImport -Path teams-1.csv, slas-1.csv -Folder .\Exports
        Converts two files in the Exports folder below the current directory.

        .EXAMPLE
        Get-ChildItem -Path .\Exports -Filter '*slas*.csv' | ConvertTo-XurrentCrossEnvironmentImport
        Converts the files passed through the pipeline.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'ByTime')]
    [OutputType([PSCustomObject])]
    param
    (
        [Parameter(Mandatory = $true, ParameterSetName = 'ByName', Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('FullName')]
        [string[]]
        $Path,

        [Parameter(ParameterSetName = 'ByTime')]
        [double]
        $LastHours = 1,

        [Parameter()]
        [string]
        $Folder = (Join-Path $HOME 'Downloads'),

        [Parameter()]
        [string]
        $IdColumn = 'ID',

        [Parameter()]
        [string]
        $SourceIdColumn = 'Source ID'
    )

    begin
    {
        $files = [System.Collections.Generic.List[object]]::new()
    }

    process
    {
        # The process block also runs once when nothing is piped in; only -Path adds files here.
        if ($PSCmdlet.ParameterSetName -ne 'ByName')
        {
            return
        }

        foreach ($name in $Path)
        {
            # Split-Path -IsAbsolute recognises PowerShell drives (e.g. TestDrive:\x.csv), which
            # [System.IO.Path]::IsPathRooted reports as relative.
            $fullPath = if (Split-Path -Path $name -IsAbsolute) { $name } else { Join-Path -Path $Folder -ChildPath $name }

            if (Test-Path -LiteralPath $fullPath -PathType Leaf)
            {
                $files.Add((Get-Item -LiteralPath $fullPath))
            }
            else
            {
                Write-Warning "Not found: $fullPath"
            }
        }
    }

    end
    {
        if ($PSCmdlet.ParameterSetName -eq 'ByTime')
        {
            # On Windows CreationTime is the download time. LastWriteTime can be older when the
            # browser keeps the server's timestamp, so a file counts when either one is recent.
            $cutoff = (Get-Date).AddHours(-$LastHours)
            Get-ChildItem -LiteralPath $Folder -Filter '*.csv' -File |
                Where-Object { $_.CreationTime -ge $cutoff -or $_.LastWriteTime -ge $cutoff } |
                Sort-Object -Property Name |
                ForEach-Object { $files.Add($_) }
        }

        if ($files.Count -eq 0)
        {
            Write-Warning 'No CSV files selected.'
            return
        }

        foreach ($file in $files)
        {
            $moved = 0
            $status = 'Skipped'

            # Without -Encoding, Windows PowerShell 5.1 reads the file as ANSI.
            $rows = @(Import-Csv -LiteralPath $file.FullName -Encoding UTF8)
            $columns = if ($rows.Count -gt 0) { $rows[0].PSObject.Properties.Name }

            if ($rows.Count -eq 0)
            {
                Write-Warning "$($file.Name): no rows, skipped"
            }
            elseif ($columns -notcontains $IdColumn -or $columns -notcontains $SourceIdColumn)
            {
                Write-Warning "$($file.Name): column '$IdColumn' or '$SourceIdColumn' missing, skipped"
            }
            else
            {
                foreach ($row in $rows)
                {
                    $id = $row.$IdColumn

                    # An empty ID means the row was already converted (or never had one). Skipping it
                    # keeps the Source ID of an earlier run instead of overwriting it with nothing.
                    if ([string]::IsNullOrWhiteSpace($id))
                    {
                        continue
                    }

                    $existing = $row.$SourceIdColumn
                    if (-not [string]::IsNullOrWhiteSpace($existing) -and $existing -ne $id)
                    {
                        Write-Warning "$($file.Name): '$SourceIdColumn' '$existing' overwritten with '$id'"
                    }

                    $row.$SourceIdColumn = $id
                    $row.$IdColumn = ''
                    $moved++
                }

                if ($moved -eq 0)
                {
                    $status = 'NothingToMove'
                    Write-Verbose "$($file.Name): nothing to move"
                }
                elseif ($PSCmdlet.ShouldProcess($file.FullName, "Move $moved ID(s) to '$SourceIdColumn'"))
                {
                    # Export-Csv cannot write UTF-8 without a BOM on Windows PowerShell 5.1, and
                    # Xurrent rejects a BOM ("Illegal quoting in line 1"). ConvertTo-Csv quotes every
                    # field, which the import accepts, and keeps multi-line values intact.
                    $csvLines = $rows | ConvertTo-Csv -NoTypeInformation
                    [System.IO.File]::WriteAllLines($file.FullName, $csvLines, [System.Text.UTF8Encoding]::new($false))
                    $status = 'Moved'
                    Write-Verbose "$($file.Name): $moved ID(s) moved to '$SourceIdColumn'"
                }
                else
                {
                    $status = 'WhatIf'
                }
            }

            [PSCustomObject]@{
                File   = $file.FullName
                Moved  = $moved
                Status = $status
            }
        }
    }
}
