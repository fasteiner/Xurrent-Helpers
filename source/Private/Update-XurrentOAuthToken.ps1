function Update-XurrentOAuthToken
{
    [CmdletBinding()]
    param()

    process
    {
        $cred = $script:XurrentSession.OAuthCred
        $clientId = $cred.UserName
        $clientSecret = [System.Net.NetworkCredential]::new('', $cred.Password).Password

        $body = "grant_type=client_credentials&client_id=$([uri]::EscapeDataString($clientId))&client_secret=$([uri]::EscapeDataString($clientSecret))"

        $response = Invoke-WebRequest -Uri $script:XurrentSession.OAuthUrl -Method POST `
            -ContentType 'application/x-www-form-urlencoded' -Body $body -UseBasicParsing

        $token = ($response.Content | ConvertFrom-Json)
        $script:XurrentSession.Headers['Authorization'] = "Bearer $($token.access_token)"
        $script:XurrentSession.TokenExpiry = [datetime]::UtcNow.AddSeconds($token.expires_in)

        Write-Verbose 'OAuth2 token refreshed.'
    }
}
