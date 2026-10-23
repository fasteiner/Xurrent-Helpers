function ConvertTo-XurrentPseudonymized
{
    <#
        .SYNOPSIS
        Replaces the values of selected columns in Xurrent CSV exports with consistent placeholders.

        .DESCRIPTION
        Prepares Xurrent CSV exports for analysis without real names, e-mail addresses or IP
        addresses. Every non-empty value in the selected columns is replaced with a placeholder
        such as Person-001, user001@example.invalid, 198.18.0.1 or Text-001. The same real value
        always gets the same placeholder: in every selected column, in every file of the call,
        and across calls that use the same mapping file.

        The pseudonymized CSV is written to a new file; the original export is not changed.
        Column order, the values of all other columns and multi-line quoted fields stay as they
        are. Free text in the other columns is not scanned for personal data.

        The mapping (placeholder -> real value) is written to a separate CSV file with the
        columns Placeholder, Type and Value. An existing mapping file is extended, never
        overwritten: its placeholders are reused and new ones continue its numbering. The
        mapping holds the real values, so keep it local and out of any repository; the default
        name ends in .mapping.csv, which a single .gitignore pattern covers.
        ConvertFrom-XurrentPseudonymized uses the mapping to translate analysis results back.

        All files are written as UTF-8 without a byte-order mark (BOM), like the files Xurrent
        accepts for import.

        .PARAMETER Path
        One or more CSV export files to pseudonymize. Accepts pipeline input, including the
        output of Get-ChildItem. Relative paths are resolved against the current location;
        missing files are reported as warnings and skipped.

        .PARAMETER Column
        Names of the columns whose values are replaced, for example 'Requested by'. Columns
        named in ColumnType are included as well. Column names are matched case-insensitively;
        a column that a file does not have is reported as a warning.

        .PARAMETER ColumnType
        Placeholder type per column, as a hashtable of column name to Name, Email, IP or Text:
        Name gives Person-001, Email gives user001@example.invalid, IP gives 198.18.0.1 and Text
        gives Text-001. Columns without an entry use Text. IP placeholders come from
        198.18.0.0/15, which is reserved for benchmarking, so they never match a real address.

        .PARAMETER MappingPath
        Mapping file to read and extend. Defaults to pseudonymization.mapping.csv in the folder
        of the first output file. When the file exists, its entries are kept and new entries are
        appended; it is only written when at least one output file is written.

        .PARAMETER OutputPath
        File or folder for the pseudonymized CSV. Defaults to <name>.pseudonymized.csv next to
        each input file. A folder (an existing one, or a path ending with a directory separator)
        receives <name>.pseudonymized.csv for each input; a file path is only allowed for a
        single input file and must differ from it.

        .OUTPUTS
        [PSCustomObject] One object per input file with Path, OutputPath, MappingPath, Rows,
        Replaced (number of replaced values) and Status (Pseudonymized, Skipped or NoRows).

        .EXAMPLE
        ConvertTo-XurrentPseudonymized -Path .\requests.csv -ColumnType @{ 'Requested by' = 'Name'; 'Requested for' = 'Name' }

        Writes requests.pseudonymized.csv and pseudonymization.mapping.csv next to requests.csv.

        .EXAMPLE
        Get-ChildItem .\Exports -Filter '*.csv' |
            ConvertTo-XurrentPseudonymized -Column 'Organization' -ColumnType @{ 'Primary email' = 'Email'; 'IP address' = 'IP' } -OutputPath .\Pseudonymized\ -MappingPath ..\Local\exports.mapping.csv

        Pseudonymizes several exports with one shared mapping kept outside the working folder.

        .EXAMPLE
        ConvertTo-XurrentPseudonymized -Path .\people.csv -ColumnType @{ Name = 'Name' } -WhatIf

        Shows which files would be written without writing anything.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param
    (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('FullName')]
        [string[]]
        $Path,

        [Parameter()]
        [string[]]
        $Column = @(),

        [Parameter()]
        [hashtable]
        $ColumnType = @{},

        [Parameter()]
        [string]
        $MappingPath,

        [Parameter()]
        [string]
        $OutputPath
    )

    begin
    {
        $validTypes = 'Name', 'Email', 'IP', 'Text'
        $typeOf = @{}
        foreach ($key in $ColumnType.Keys)
        {
            $type = $validTypes | Where-Object { $_ -eq $ColumnType[$key] }
            if (-not $type)
            {
                throw "Unknown ColumnType '$($ColumnType[$key])' for column '$key'. Allowed: $($validTypes -join ', ')."
            }
            $typeOf[$key] = $type
        }

        # Case-insensitive, so a column named twice (e.g. in -Column and -ColumnType) is replaced
        # once; a second pass would pseudonymize its placeholders.
        $selected = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($name in @($Column) + @($ColumnType.Keys)) { [void]$selected.Add($name) }
        if ($selected.Count -eq 0)
        {
            throw 'Name the columns to pseudonymize with -Column or -ColumnType.'
        }

        $files = [System.Collections.Generic.List[string]]::new()
    }

    process
    {
        foreach ($name in $Path)
        {
            # Resolves relative paths against the current location and PS drives (e.g. TestDrive:)
            # to file system paths, which the .NET file APIs below need.
            $fullPath = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($name)
            if (Test-Path -LiteralPath $fullPath -PathType Leaf)
            {
                $files.Add($fullPath)
            }
            else
            {
                Write-Warning "File not found: $fullPath"
            }
        }
    }

    end
    {
        if ($files.Count -eq 0) { return }

        $outputFolder = $null
        if ($OutputPath)
        {
            $resolvedOutput = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($OutputPath)
            if ((Test-Path -LiteralPath $resolvedOutput -PathType Container) -or
                $OutputPath.EndsWith([System.IO.Path]::DirectorySeparatorChar) -or
                $OutputPath.EndsWith([System.IO.Path]::AltDirectorySeparatorChar))
            {
                $outputFolder = $resolvedOutput
            }
            elseif ($files.Count -gt 1)
            {
                throw 'OutputPath names a single file, but more than one input file was given. Pass a folder instead.'
            }
        }

        $targets = @(foreach ($file in $files)
            {
                $fileName = [System.IO.Path]::GetFileNameWithoutExtension($file) + '.pseudonymized.csv'
                $target = if ($outputFolder) { [System.IO.Path]::Combine($outputFolder, $fileName) }
                elseif ($OutputPath) { $resolvedOutput }
                else { [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($file), $fileName) }

                if ($target -eq $file) { throw "OutputPath must not be the input file: $file" }
                [PSCustomObject]@{ Path = $file; OutputPath = $target; Rows = $null; Replaced = 0 }
            })

        $resolvedMapping = if ($MappingPath) { $PSCmdlet.GetUnresolvedProviderPathFromPSPath($MappingPath) }
        else { [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($targets[0].OutputPath), 'pseudonymization.mapping.csv') }
        if ($targets.Path -contains $resolvedMapping -or $targets.OutputPath -contains $resolvedMapping)
        {
            throw "MappingPath must not be an input or output file: $resolvedMapping"
        }

        $mapping = Import-PseudonymMapping -Path $resolvedMapping
        $savedCount = $mapping.Entries.Count
        $nextNumber = @{ Name = 1; Email = 1; IP = 1; Text = 1 }

        foreach ($target in $targets)
        {
            $rows = @(Import-Csv -LiteralPath $target.Path -Encoding UTF8)
            if ($rows.Count -eq 0)
            {
                Write-Warning "No rows to pseudonymize in $($target.Path)"
                continue
            }

            $headers = @($rows[0].PSObject.Properties.Name)
            foreach ($name in $selected)
            {
                if ($headers -notcontains $name) { Write-Warning "Column '$name' not found in $($target.Path)" }
            }

            $replaced = 0
            foreach ($row in $rows)
            {
                foreach ($header in $headers)
                {
                    if (-not $selected.Contains($header)) { continue }

                    $value = $row.$header
                    if ([string]::IsNullOrEmpty($value)) { continue }

                    $placeholder = $null
                    if (-not $mapping.ByValue.TryGetValue($value, [ref] $placeholder))
                    {
                        $type = if ($typeOf.ContainsKey($header)) { $typeOf[$header] } else { 'Text' }

                        # Skip numbers already taken in the mapping, so placeholders stay unique
                        # when an existing mapping is extended.
                        do
                        {
                            $number = $nextNumber[$type]
                            $nextNumber[$type]++
                            $placeholder = switch ($type)
                            {
                                'Name' { 'Person-{0:D3}' -f $number }
                                'Email' { 'user{0:D3}@example.invalid' -f $number }
                                'IP'
                                {
                                    if ($number -gt 131070) { throw 'No IP placeholders left in 198.18.0.0/15.' }
                                    $address = 3323068416 + $number # 198.18.0.0 + number
                                    '{0}.{1}.{2}.{3}' -f ($address -shr 24), (($address -shr 16) -band 255), (($address -shr 8) -band 255), ($address -band 255)
                                }
                                default { 'Text-{0:D3}' -f $number }
                            }
                        } while ($mapping.ByPlaceholder.ContainsKey($placeholder))

                        $mapping.ByValue[$value] = $placeholder
                        $mapping.ByPlaceholder[$placeholder] = $value
                        $mapping.Entries.Add([PSCustomObject]@{ Placeholder = $placeholder; Type = $type; Value = $value })
                    }

                    $row.$header = $placeholder
                    $replaced++
                }
            }

            $target.Rows = $rows
            $target.Replaced = $replaced
        }

        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        foreach ($target in $targets)
        {
            $status = 'NoRows'
            if ($null -ne $target.Rows)
            {
                $status = 'Skipped'
                if ($PSCmdlet.ShouldProcess($target.OutputPath, "Write pseudonymized CSV (mapping: $resolvedMapping)"))
                {
                    # The mapping is saved before the first output file, so no file with
                    # placeholders exists that the mapping cannot translate back.
                    if ($mapping.Entries.Count -gt $savedCount)
                    {
                        [void][System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($resolvedMapping))
                        $mappingLines = $mapping.Entries | ConvertTo-Csv -NoTypeInformation
                        # Write next to the mapping and swap it in, so an interrupted write never
                        # truncates an existing mapping that earlier exports depend on.
                        $temporaryMapping = "$resolvedMapping.tmp"
                        [System.IO.File]::WriteAllLines($temporaryMapping, $mappingLines, $utf8NoBom)
                        if ([System.IO.File]::Exists($resolvedMapping))
                        {
                            [System.IO.File]::Replace($temporaryMapping, $resolvedMapping, [NullString]::Value)
                        }
                        else
                        {
                            [System.IO.File]::Move($temporaryMapping, $resolvedMapping)
                        }
                        $savedCount = $mapping.Entries.Count
                    }

                    # BOM-less UTF-8, as Xurrent rejects a leading BOM and Windows PowerShell 5.1
                    # has no BOM-less option for Export-Csv -Encoding.
                    [void][System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($target.OutputPath))
                    $csvLines = $target.Rows | ConvertTo-Csv -NoTypeInformation
                    [System.IO.File]::WriteAllLines($target.OutputPath, $csvLines, $utf8NoBom)
                    $status = 'Pseudonymized'
                }
            }

            [PSCustomObject]@{
                Path        = $target.Path
                OutputPath  = $target.OutputPath
                MappingPath = $resolvedMapping
                Rows        = if ($null -ne $target.Rows) { $target.Rows.Count } else { 0 }
                Replaced    = $target.Replaced
                Status      = $status
            }
        }
    }
}
