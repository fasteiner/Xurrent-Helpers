function Invoke-XurrentRestMethod
{
    <#
        .SYNOPSIS
        Sends an HTTP request to the Xurrent REST API.

        .DESCRIPTION
        Wraps Invoke-XurrentAPIRequest to build the full URI from a relative path and the
        current session's base URL. Requires an active session (Connect-Xurrent).

        .PARAMETER Path
        The relative API path, e.g. '/me' or '/people/123'.

        .PARAMETER Method
        The HTTP method. Defaults to GET.

        .PARAMETER Body
        An object to serialize as the JSON request body.

        .PARAMETER QueryParameters
        A hashtable of query string parameters to append to the URI.

        .PARAMETER Raw
        If specified, returns the full WebResponseObject instead of parsed JSON.

        .EXAMPLE
        Invoke-XurrentRestMethod -Path '/me'

        .EXAMPLE
        Invoke-XurrentRestMethod -Path '/people' -QueryParameters @{ per_page = 100 }
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter()]
        [ValidateSet('GET', 'POST', 'PUT', 'DELETE', 'PATCH')]
        [string]
        $Method = 'GET',

        [Parameter()]
        [object]
        $Body,

        [Parameter()]
        [hashtable]
        $QueryParameters,

        [Parameter()]
        [switch]
        $Raw
    )

    process
    {
        Assert-XurrentConnection

        $uri = $script:XurrentSession.BaseUrl + $Path

        if ($QueryParameters -and $QueryParameters.Count -gt 0)
        {
            $qs = ($QueryParameters.GetEnumerator() | ForEach-Object {
                "$([uri]::EscapeDataString($_.Key))=$([uri]::EscapeDataString([string]$_.Value))"
            }) -join '&'
            $uri = "$uri`?$qs"
        }

        $apiParams = @{
            Uri    = $uri
            Method = $Method
        }
        if ($Body)          { $apiParams['Body'] = $Body }
        if ($Raw)           { $apiParams['Raw'] = $true }

        Invoke-XurrentAPIRequest @apiParams
    }
}
