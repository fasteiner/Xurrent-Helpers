function Assert-XurrentConnection
{
    [CmdletBinding()]
    param()

    process
    {
        if ($null -eq $script:XurrentSession)
        {
            throw 'No active Xurrent session. Call Connect-Xurrent first.'
        }

        if ($null -ne $script:XurrentSession.OAuthCred -and
            $null -ne $script:XurrentSession.TokenExpiry -and
            ($script:XurrentSession.TokenExpiry - [datetime]::UtcNow).TotalSeconds -lt 60)
        {
            Update-XurrentOAuthToken
        }
    }
}
