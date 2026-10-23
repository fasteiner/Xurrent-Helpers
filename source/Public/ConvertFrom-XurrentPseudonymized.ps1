function ConvertFrom-XurrentPseudonymized
{
    <#
        .SYNOPSIS
        Replaces placeholders from ConvertTo-XurrentPseudonymized with the real values again.

        .DESCRIPTION
        Translates analysis results back to real names, e-mail addresses and IP addresses. Every
        placeholder listed in the mapping file written by ConvertTo-XurrentPseudonymized (such as
        Person-001 or user001@example.invalid) is replaced with its real value, wherever it
        appears in the text: also inside sentences, lists or other columns. A placeholder only
        matches as a whole, so Person-001 is not replaced inside Person-0010 and 198.18.0.1 not
        inside 198.18.0.10. Text that is not in the mapping stays unchanged.

        Files are written to a new file; the input is not changed. CSV files (.csv) are restored
        field by field, so real values with commas, quotes or line breaks keep the CSV valid and
        a pseudonymized export restores to the original values. Other files (Markdown, text,
        JSON) are restored as plain text with their line endings unchanged. All files are
        written as UTF-8 without a byte-order mark (BOM).

        With -Text, the restored strings are returned instead of writing a file.

        .PARAMETER Path
        One or more files to restore. Accepts the output of Get-ChildItem from the pipeline.
        Relative paths are resolved against the current location; missing files are reported
        as warnings and skipped.

        .PARAMETER Text
        One or more strings to restore, for example an analysis result or the lines read with
        Get-Content. Accepts pipeline input; the restored strings are returned.

        .PARAMETER MappingPath
        Mapping file written by ConvertTo-XurrentPseudonymized (columns Placeholder, Type and
        Value). It must exist; it is only read, never changed.

        .PARAMETER OutputPath
        File or folder for the restored file. Defaults to the input name with .pseudonymized
        replaced by .restored (otherwise .restored is inserted before the extension), next to
        each input file. A folder (an existing one, or a path ending with a directory separator)
        receives that name for each input; a file path is only allowed for a single input file.

        .OUTPUTS
        [PSCustomObject] With -Path, one object per file with Path, OutputPath, Replaced (number
        of replaced placeholders) and Status (Restored or Skipped).
        [string] With -Text, the restored strings.

        .EXAMPLE
        ConvertFrom-XurrentPseudonymized -Path .\requests.pseudonymized.csv -MappingPath .\pseudonymization.mapping.csv

        Writes requests.restored.csv with the real values.

        .EXAMPLE
        Get-Content .\analysis.md | ConvertFrom-XurrentPseudonymized -MappingPath .\pseudonymization.mapping.csv

        Returns the lines of an analysis result with the real names.

        .EXAMPLE
        Get-ChildItem .\Results -Filter '*.csv' |
            ConvertFrom-XurrentPseudonymized -MappingPath ..\Local\exports.mapping.csv -OutputPath .\Restored\ -WhatIf

        Shows which restored files would be written without writing anything.
    #>
    # No DefaultParameterSetName: with one, piped strings are bound to the default set (Path)
    # and fail, instead of choosing the Text set.
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject], ParameterSetName = 'Path')]
    [OutputType([string], ParameterSetName = 'Text')]
    param
    (
        [Parameter(Mandatory = $true, ParameterSetName = 'Path', Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Alias('FullName')]
        [string[]]
        $Path,

        [Parameter(Mandatory = $true, ParameterSetName = 'Text', ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [string[]]
        $Text,

        [Parameter(Mandatory = $true)]
        [string]
        $MappingPath,

        [Parameter(ParameterSetName = 'Path')]
        [string]
        $OutputPath
    )

    begin
    {
        $resolvedMapping = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($MappingPath)
        if (-not (Test-Path -LiteralPath $resolvedMapping -PathType Leaf))
        {
            throw "Mapping file not found: $resolvedMapping"
        }
        $byPlaceholder = (Import-PseudonymMapping -Path $resolvedMapping).ByPlaceholder

        # One pass over the text with all placeholders, longest first, so a restored value is
        # never replaced again. The lookarounds make a placeholder match only as a whole: no
        # letter, digit, '_', '@' or '-' around it, and no '.' before it or '.x' after it, so a
        # placeholder at the end of a sentence still matches.
        $alternatives = @($byPlaceholder.Keys | Sort-Object -Property Length -Descending | ForEach-Object { [regex]::Escape($_) })
        $pattern = if ($alternatives.Count -gt 0) { '(?<![\w.@-])(?:' + ($alternatives -join '|') + ')(?![\w@-]|\.\w)' } else { '(?!)' }
        $regex = [regex]::new($pattern)
        $counter = @{ Replaced = 0 }
        $evaluator = [System.Text.RegularExpressions.MatchEvaluator] {
            param ($match)
            $counter.Replaced++
            $byPlaceholder[$match.Value]
        }

        $files = [System.Collections.Generic.List[string]]::new()
    }

    process
    {
        if ($PSCmdlet.ParameterSetName -eq 'Text')
        {
            foreach ($item in $Text)
            {
                if ([string]::IsNullOrEmpty($item)) { $item } else { $regex.Replace($item, $evaluator) }
            }
            return
        }

        foreach ($name in $Path)
        {
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

        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        foreach ($file in $files)
        {
            $extension = [System.IO.Path]::GetExtension($file)
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file) -replace '\.pseudonymized$', ''
            $fileName = "$baseName.restored$extension"
            $target = if ($outputFolder) { [System.IO.Path]::Combine($outputFolder, $fileName) }
            elseif ($OutputPath) { $resolvedOutput }
            else { [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($file), $fileName) }

            if ($target -eq $file) { throw "OutputPath must not be the input file: $file" }

            $counter.Replaced = 0
            $rows = @()
            if ($extension -eq '.csv') { $rows = @(Import-Csv -LiteralPath $file -Encoding UTF8) }

            if ($rows.Count -gt 0)
            {
                # Field by field: a real value may contain commas, quotes or line breaks, which
                # would break the CSV if it were put into the raw text.
                foreach ($row in $rows)
                {
                    foreach ($property in $row.PSObject.Properties)
                    {
                        if (-not [string]::IsNullOrEmpty($property.Value))
                        {
                            $property.Value = $regex.Replace($property.Value, $evaluator)
                        }
                    }
                }
                $lines = $rows | ConvertTo-Csv -NoTypeInformation
            }
            else
            {
                # ReadAllText drops a BOM and keeps the line endings as they are.
                $content = $regex.Replace([System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8), $evaluator)
            }

            $status = 'Skipped'
            if ($PSCmdlet.ShouldProcess($target, 'Write restored file'))
            {
                [void][System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($target))
                if ($rows.Count -gt 0)
                {
                    [System.IO.File]::WriteAllLines($target, $lines, $utf8NoBom)
                }
                else
                {
                    [System.IO.File]::WriteAllText($target, $content, $utf8NoBom)
                }
                $status = 'Restored'
            }

            [PSCustomObject]@{
                Path       = $file
                OutputPath = $target
                Replaced   = $counter.Replaced
                Status     = $status
            }
        }
    }
}
