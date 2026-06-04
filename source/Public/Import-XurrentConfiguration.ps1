function Import-XurrentConfiguration
{
    <#
        .SYNOPSIS
        Loads a Xurrent .env configuration file into the module session.

        .DESCRIPTION
        Reads key=value pairs from a .env file into the module-scoped $script:XurrentConfig
        hashtable. Optionally auto-connects to the Xurrent API using the loaded configuration.

        .PARAMETER Path
        Path to the .env configuration file. Defaults to the .xurrent directory next to the
        current user's PowerShell profile.

        .PARAMETER AutoConnect
        If specified, or if XURRENT_AUTO_CONNECT=true is set in the config, attempts to call
        Connect-Xurrent using the credential path from the loaded configuration.

        .EXAMPLE
        Import-XurrentConfiguration

        .EXAMPLE
        Import-XurrentConfiguration -Path C:\config\xurrent.env -AutoConnect
    #>
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [string]
        $Path = (Join-Path (Split-Path $PROFILE) '.xurrent' 'config.env'),

        [Parameter()]
        [switch]
        $AutoConnect
    )

    process
    {
        if (-not (Test-Path $Path))
        {
            Write-Verbose "Configuration file not found at '$Path'. Skipping."
            return
        }

        $config = @{}
        foreach ($line in (Get-Content -Path $Path -Encoding UTF8))
        {
            if ($line -match '^\s*#' -or $line -notmatch '=') { continue }
            $key, $value = $line -split '=', 2
            $key = $key.Trim()
            $value = $value.Trim()
            $value = $value -replace "^[`"']|[`"']$", ''
            $config[$key] = $value

            if ($key -match '_PATH$')
            {
                Write-Verbose "Loaded config key: $key = [redacted]"
            }
            else
            {
                Write-Verbose "Loaded config key: $key = $value"
            }
        }

        $script:XurrentConfig = $config

        $shouldAutoConnect = $AutoConnect -or $config['XURRENT_AUTO_CONNECT'] -eq 'true'
        if ($shouldAutoConnect)
        {
            $credPath = $config['XURRENT_CREDENTIAL_PATH']
            $environment = $config['XURRENT_ENVIRONMENT']
            $account = $config['XURRENT_ACCOUNT']

            if (-not $credPath -or -not $environment -or -not $account)
            {
                Write-Warning 'AutoConnect requires XURRENT_CREDENTIAL_PATH, XURRENT_ENVIRONMENT, and XURRENT_ACCOUNT in the config file.'
                return
            }

            Connect-Xurrent -CredentialPath $credPath -Environment $environment -Account $account
        }
    }
}
