function Connect-Xurrent
{
    <#
        .SYNOPSIS
        Establishes a connection to the Xurrent API.

        .DESCRIPTION
        Authenticates to the Xurrent REST and GraphQL APIs using a Bearer token,
        OAuth2 client credentials, a CliXML credential file, or a SecretManagement vault.
        Stores the session in the module-scoped $script:XurrentSession.

        .PARAMETER Token
        A SecureString Bearer token for direct token authentication.

        .PARAMETER OAuthCredential
        A PSCredential where Username is the ClientId and Password is the ClientSecret.

        .PARAMETER CredentialPath
        Path to an Export-Clixml credential file. Username 'bearer' indicates a bearer token;
        any other username is treated as an OAuth2 ClientId.

        .PARAMETER SecretName
        Name of a secret in a Microsoft.PowerShell.SecretManagement vault.

        .PARAMETER VaultName
        Name of the vault to retrieve the secret from. Optional when only one vault is registered.

        .PARAMETER Environment
        The Xurrent environment to connect to: Demo, QA, or Prod.

        .PARAMETER Account
        The Xurrent account identifier (e.g. techwork-support).

        .PARAMETER SkipConnectionTest
        If specified, skips the /me endpoint test after establishing the session.

        .EXAMPLE
        Connect-Xurrent -Environment QA -Account techwork-support -CredentialPath ~/.xurrent/creds.xml

        .EXAMPLE
        Connect-Xurrent -Environment Prod -Account techwork-support -Token (Read-Host -AsSecureString)
    #>
    [CmdletBinding(DefaultParameterSetName = 'CliXML')]
    param
    (
        [Parameter(Mandatory = $true, ParameterSetName = 'BearerToken')]
        [System.Security.SecureString]
        $Token,

        [Parameter(Mandatory = $true, ParameterSetName = 'OAuth2')]
        [System.Management.Automation.PSCredential]
        $OAuthCredential,

        [Parameter(Mandatory = $true, ParameterSetName = 'CliXML')]
        [string]
        $CredentialPath,

        [Parameter(Mandatory = $true, ParameterSetName = 'SecretStore')]
        [string]
        $SecretName,

        [Parameter(ParameterSetName = 'SecretStore')]
        [string]
        $VaultName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Demo', 'QA', 'Prod')]
        [string]
        $Environment,

        [Parameter(Mandatory = $true)]
        [string]
        $Account,

        [Parameter()]
        [switch]
        $SkipConnectionTest
    )

    process
    {
        $urls = ConvertTo-XurrentBaseUrl -Environment $Environment

        $resolvedToken = $null
        $resolvedOAuthCred = $null

        switch ($PSCmdlet.ParameterSetName)
        {
            'BearerToken'
            {
                $resolvedToken = $Token
            }

            'OAuth2'
            {
                $resolvedOAuthCred = $OAuthCredential
            }

            'CliXML'
            {
                if (-not (Test-Path $CredentialPath))
                {
                    throw "Credential file not found: $CredentialPath"
                }
                $loadedCred = Import-Clixml -Path $CredentialPath
                if ($loadedCred.UserName -eq 'bearer')
                {
                    $resolvedToken = $loadedCred.Password
                }
                else
                {
                    $resolvedOAuthCred = $loadedCred
                }
            }

            'SecretStore'
            {
                $getSecretCmd = Get-Command Get-Secret -ErrorAction SilentlyContinue
                if (-not $getSecretCmd)
                {
                    throw 'SecretStore parameter set requires the Microsoft.PowerShell.SecretManagement module. Install it with: Install-Module Microsoft.PowerShell.SecretManagement'
                }
                $getSecretParams = @{ Name = $SecretName }
                if ($VaultName) { $getSecretParams['Vault'] = $VaultName }
                $loadedSecret = & $getSecretCmd @getSecretParams
                if ($loadedSecret -is [System.Security.SecureString])
                {
                    $resolvedToken = $loadedSecret
                }
                elseif ($loadedSecret -is [System.Management.Automation.PSCredential])
                {
                    if ($loadedSecret.UserName -eq 'bearer')
                    {
                        $resolvedToken = $loadedSecret.Password
                    }
                    else
                    {
                        $resolvedOAuthCred = $loadedSecret
                    }
                }
                else
                {
                    throw "Secret '$SecretName' must be a SecureString or PSCredential."
                }
            }
        }

        $headers = @{
            'X-4me-Account' = $Account
            'Accept'        = 'application/json'
        }

        $session = @{
            BaseUrl      = $urls.BaseUrl
            GraphQLUrl   = $urls.GraphQLUrl
            OAuthUrl     = $urls.OAuthUrl
            Account      = $Account
            Environment  = $Environment
            Headers      = $headers
            OAuthCred    = $null
            TokenExpiry  = $null
        }

        if ($null -ne $resolvedOAuthCred)
        {
            $session.OAuthCred = $resolvedOAuthCred
            $script:XurrentSession = $session
            Update-XurrentOAuthToken
        }
        elseif ($null -ne $resolvedToken)
        {
            $plainToken = [System.Net.NetworkCredential]::new('', $resolvedToken).Password
            $headers['Authorization'] = "Bearer $plainToken"
            $script:XurrentSession = $session
        }

        if (-not $SkipConnectionTest)
        {
            try
            {
                $me = Invoke-XurrentRestMethod -Path '/me'
                Write-Host "Connected as: $($me.name) ($($me.primary_email))"
            }
            catch
            {
                $script:XurrentSession = $null
                throw "Connection test failed: $_"
            }
        }
    }
}
