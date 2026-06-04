function Invoke-XurrentAPIRequest
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $Uri,

        [Parameter()]
        [ValidateSet('GET', 'POST', 'PUT', 'DELETE', 'PATCH')]
        [string]
        $Method = 'GET',

        [Parameter()]
        [object]
        $Body,

        [Parameter()]
        [hashtable]
        $Form,

        [Parameter()]
        [string]
        $OutFile,

        [Parameter()]
        [hashtable]
        $AdditionalHeaders,

        [Parameter()]
        [switch]
        $Raw
    )

    process
    {
        $headers = @{}
        foreach ($key in $script:XurrentSession.Headers.Keys)
        {
            $headers[$key] = $script:XurrentSession.Headers[$key]
        }
        if ($AdditionalHeaders)
        {
            foreach ($key in $AdditionalHeaders.Keys)
            {
                $headers[$key] = $AdditionalHeaders[$key]
            }
        }

        $verboseAuth = if ($headers['Authorization'] -and $headers['Authorization'].Length -gt 8)
        {
            $headers['Authorization'].Substring(0, 8) + '...'
        }
        else
        {
            $headers['Authorization']
        }
        Write-Verbose "Invoke-XurrentAPIRequest: $Method $Uri [Authorization: $verboseAuth]"

        $iwrParams = @{
            Uri             = $Uri
            Method          = $Method
            Headers         = $headers
            UseBasicParsing = $true
            ErrorAction     = 'Stop'
        }

        if ($Body)
        {
            $iwrParams['Body'] = $Body | ConvertTo-Json -Depth 10 -Compress
            if (-not $headers.ContainsKey('Content-Type'))
            {
                $iwrParams['ContentType'] = 'application/json'
            }
        }

        if ($Form)
        {
            $iwrParams['Form'] = $Form
        }

        if ($OutFile)
        {
            $iwrParams['OutFile'] = $OutFile
        }

        $tokenRefreshed = $false
        :loop while ($true)
        {
            try
            {
                $response = Invoke-WebRequest @iwrParams

                if ($Raw)
                {
                    return $response
                }
                return $response.Content | ConvertFrom-Json
            }
            catch
            {
                $statusCode = $null
                if ($_.Exception.Response)
                {
                    $statusCode = [int]$_.Exception.Response.StatusCode
                }

                if ($statusCode -eq 429)
                {
                    $retryAfter = 30
                    if ($_.Exception.Response.Headers['Retry-After'])
                    {
                        $retryAfter = [int]$_.Exception.Response.Headers['Retry-After']
                    }
                    elseif ($_.Exception.Response.Headers['X-RateLimit-Reset'])
                    {
                        $resetEpoch = [long]$_.Exception.Response.Headers['X-RateLimit-Reset']
                        $retryAfter = [int]([datetime]::UtcNow - [datetime]::new(1970, 1, 1, 0, 0, 0, [System.DateTimeKind]::Utc)).TotalSeconds
                        $retryAfter = [int]($resetEpoch - $retryAfter)
                        if ($retryAfter -lt 1) { $retryAfter = 1 }
                    }
                    Write-Verbose "Rate limited. Retrying after $retryAfter seconds."
                    Start-Sleep -Seconds $retryAfter
                    continue loop
                }

                if ($statusCode -eq 401 -and $null -ne $script:XurrentSession.OAuthCred -and -not $tokenRefreshed)
                {
                    Write-Verbose 'Received 401, refreshing OAuth2 token and retrying.'
                    Update-XurrentOAuthToken
                    $headers['Authorization'] = $script:XurrentSession.Headers['Authorization']
                    $iwrParams['Headers'] = $headers
                    $tokenRefreshed = $true
                    continue loop
                }

                $errorMessage = $_.Exception.Message
                if ($_.Exception.Response)
                {
                    try
                    {
                        $stream = $_.Exception.Response.GetResponseStream()
                        $reader = [System.IO.StreamReader]::new($stream)
                        $errorBody = $reader.ReadToEnd()
                        $reader.Dispose()
                        if ($errorBody) { $errorMessage = "$errorMessage - $errorBody" }
                    }
                    catch { }
                }

                Write-Error "Xurrent API error ($statusCode): $errorMessage"
                return $null
            }
        }
    }
}
