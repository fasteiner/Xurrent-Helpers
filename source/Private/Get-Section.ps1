function Get-Section
{
    <#
        .SYNOPSIS
        Extracts the body of a named Markdown H2 section.

        .DESCRIPTION
        Returns the trimmed text body of a ## Heading section from a Markdown string.
        Matches content from the heading line to the next same-level ## heading or end of string.
        Returns an empty string when the requested section is not found.

        .PARAMETER Content
        The full Markdown document content as a string.

        .PARAMETER Heading
        The section heading to search for, without the leading ## prefix.

        .EXAMPLE
        Get-Section -Content $markdown -Heading 'Description'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $Content,

        [Parameter(Mandatory = $true)]
        [string]
        $Heading
    )

    process
    {
        $pattern = "(?ms)^##\s+$([regex]::Escape($Heading))\s*$\r?\n(.*?)(?=\r?\n^##\s+|\z)"
        if ($Content -match $pattern)
        {
            return $Matches[1].Trim()
        }
        return ''
    }
}
