function Import-PseudonymMapping
{
    <#
        .SYNOPSIS
        Reads a pseudonymization mapping file into lookup tables.

        .DESCRIPTION
        Reads the mapping CSV written by ConvertTo-XurrentPseudonymized (columns Placeholder,
        Type and Value) and returns its entries in file order together with two case-sensitive
        lookups: real value to placeholder (ByValue) and placeholder to real value
        (ByPlaceholder). A missing file returns empty lookups, so a new mapping can be started.
        A file without the Placeholder and Value columns, or with a placeholder listed twice,
        is rejected because restoring from it would be ambiguous. Error messages never contain
        real values.

        .PARAMETER Path
        Full file system path of the mapping CSV file to read. The file does not need to exist.

        .EXAMPLE
        $mapping = Import-PseudonymMapping -Path 'C:\Temp\pseudonymization.mapping.csv'
        $mapping.ByPlaceholder['Person-001']
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    $entries = [System.Collections.Generic.List[object]]::new()
    # Ordinal: values that differ only in case are different people or hosts, and restoring
    # must give back the exact original text.
    $byValue = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::Ordinal)
    $byPlaceholder = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::Ordinal)

    if (Test-Path -LiteralPath $Path -PathType Leaf)
    {
        $rows = @(Import-Csv -LiteralPath $Path -Encoding UTF8)
        if ($rows.Count -gt 0)
        {
            $columns = $rows[0].PSObject.Properties.Name
            if ($columns -notcontains 'Placeholder' -or $columns -notcontains 'Value')
            {
                throw "Not a pseudonymization mapping file (columns Placeholder, Type and Value expected): $Path"
            }
        }

        foreach ($row in $rows)
        {
            if ([string]::IsNullOrEmpty($row.Placeholder)) { continue }
            if ($byPlaceholder.ContainsKey($row.Placeholder))
            {
                throw "Placeholder '$($row.Placeholder)' is listed more than once in $Path"
            }

            $byPlaceholder[$row.Placeholder] = $row.Value
            if (-not $byValue.ContainsKey($row.Value)) { $byValue[$row.Value] = $row.Placeholder }
            $entries.Add([PSCustomObject]@{ Placeholder = $row.Placeholder; Type = $row.Type; Value = $row.Value })
        }
    }

    [PSCustomObject]@{
        Entries       = $entries
        ByValue       = $byValue
        ByPlaceholder = $byPlaceholder
    }
}
