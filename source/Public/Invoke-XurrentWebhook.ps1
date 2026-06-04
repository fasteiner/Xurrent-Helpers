function Invoke-XurrentWebhook
{
    <#
        .SYNOPSIS
        Triggers a configured Xurrent webhook.

        .DESCRIPTION
        Sends an HTTP request to a webhook URL using Basic authentication. Can look up
        the URL and credential by name from the loaded configuration, or accept them directly.
        Does NOT require an active Xurrent API session.

        .PARAMETER Name
        The webhook name as registered with New-XurrentWebhookConfiguration.

        .PARAMETER Url
        The webhook URL to call directly.

        .PARAMETER Credential
        A PSCredential for Basic authentication when using the Direct parameter set.

        .PARAMETER Body
        An optional body to send with the request (serialized as JSON).

        .PARAMETER Method
        HTTP method to use. Defaults to POST.

        .EXAMPLE
        Invoke-XurrentWebhook -Name techwork -Body @{ key = 'value' }

        .EXAMPLE
        Invoke-XurrentWebhook -Url https://hooks.example.com/trigger -Credential (Get-Credential)
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param
    (
        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Direct')]
        [string]
        $Url,

        [Parameter(Mandatory = $true, ParameterSetName = 'Direct')]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [object]
        $Body,

        [Parameter()]
        [ValidateSet('POST', 'GET')]
        [string]
        $Method = 'POST'
    )

    process
    {
        if ($PSCmdlet.ParameterSetName -eq 'ByName')
        {
            if ($null -eq $script:XurrentConfig)
            {
                throw "No configuration loaded. Call Import-XurrentConfiguration first, or use the Direct parameter set."
            }

            $urlKey  = "XURRENT_WEBHOOK_${Name}_URL"
            $credKey = "XURRENT_WEBHOOK_${Name}_CREDENTIAL_PATH"

            if (-not $script:XurrentConfig.ContainsKey($urlKey))
            {
                throw "Webhook '$Name' not found in loaded configuration. Register it with New-XurrentWebhookConfiguration."
            }

            $Url = $script:XurrentConfig[$urlKey]
            $credPath = $script:XurrentConfig[$credKey]
            if (-not $credPath -or -not (Test-Path $credPath))
            {
                throw "Credential file for webhook '$Name' not found at: $credPath"
            }
            $Credential = Import-Clixml -Path $credPath
        }

        $plainPassword = [System.Net.NetworkCredential]::new('', $Credential.Password).Password
        $basicToken = [Convert]::ToBase64String(
            [System.Text.Encoding]::UTF8.GetBytes("$($Credential.UserName):$plainPassword")
        )

        $headers = @{
            'Authorization' = "Basic $basicToken"
            'Accept'        = 'application/json'
        }

        $iwrParams = @{
            Uri             = $Url
            Method          = $Method
            Headers         = $headers
            UseBasicParsing = $true
        }

        if ($Body)
        {
            $iwrParams['Body']        = $Body | ConvertTo-Json -Depth 10 -Compress
            $iwrParams['ContentType'] = 'application/json'
        }

        $response = Invoke-WebRequest @iwrParams
        if ($response.Content)
        {
            try { return $response.Content | ConvertFrom-Json }
            catch { return $response.Content }
        }
    }
}
