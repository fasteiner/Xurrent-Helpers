function New-XurrentWebhookConfiguration
{
    <#
        .SYNOPSIS
        Saves a webhook URL and credentials to the Xurrent configuration files.

        .DESCRIPTION
        Exports the webhook PSCredential to an encrypted CliXML file and writes
        the URL and credential path to the .env configuration file. Safe to run
        multiple times — existing entries for the same name are replaced.

        .PARAMETER Name
        A short identifier for the webhook (used as key suffix in the .env file).

        .PARAMETER Url
        The webhook trigger URL.

        .PARAMETER Credential
        A PSCredential containing the Basic authentication username and password.

        .PARAMETER CredentialPath
        Path to save the credential CliXML to. Defaults to a .xurrent folder next to
        the current user's PowerShell profile.

        .PARAMETER ConfigPath
        Path to the .env configuration file to update. Defaults to the same .xurrent folder.

        .EXAMPLE
        New-XurrentWebhookConfiguration -Name techwork -Url https://hooks.example.com/trigger -Credential (Get-Credential)
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $Url,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [string]
        $CredentialPath = (Join-Path (Split-Path $PROFILE) '.xurrent' "webhook_$Name.xml"),

        [Parameter()]
        [string]
        $ConfigPath = (Join-Path (Split-Path $PROFILE) '.xurrent' 'config.env')
    )

    process
    {
        $xurrentDir = Split-Path $CredentialPath
        if (-not (Test-Path $xurrentDir))
        {
            New-Item -ItemType Directory -Path $xurrentDir -Force | Out-Null
            Write-Verbose "Created directory: $xurrentDir"
        }

        $Credential | Export-Clixml -Path $CredentialPath -Force
        Write-Verbose "Credential saved to: $CredentialPath"

        $urlKey  = "XURRENT_WEBHOOK_${Name}_URL"
        $credKey = "XURRENT_WEBHOOK_${Name}_CREDENTIAL_PATH"

        $lines = @()
        if (Test-Path $ConfigPath)
        {
            $lines = @(Get-Content -Path $ConfigPath -Encoding UTF8)
        }

        $newLines = [System.Collections.Generic.List[string]]::new()
        $urlWritten  = $false
        $credWritten = $false

        foreach ($line in $lines)
        {
            if ($line -match "^$([regex]::Escape($urlKey))\s*=")
            {
                $newLines.Add("$urlKey=$Url")
                $urlWritten = $true
            }
            elseif ($line -match "^$([regex]::Escape($credKey))\s*=")
            {
                $newLines.Add("$credKey=$CredentialPath")
                $credWritten = $true
            }
            else
            {
                $newLines.Add($line)
            }
        }

        if (-not $urlWritten)  { $newLines.Add("$urlKey=$Url") }
        if (-not $credWritten) { $newLines.Add("$credKey=$CredentialPath") }

        $configDir = Split-Path $ConfigPath
        if (-not (Test-Path $configDir))
        {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }

        $newLines | Set-Content -Path $ConfigPath -Encoding UTF8

        [PSCustomObject]@{
            Name           = $Name
            Url            = $Url
            CredentialPath = $CredentialPath
            ConfigPath     = $ConfigPath
        }
    }
}
