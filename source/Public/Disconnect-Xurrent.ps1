function Disconnect-Xurrent
{
    <#
        .SYNOPSIS
        Clears the active Xurrent session.

        .DESCRIPTION
        Removes the module-scoped session and configuration, effectively disconnecting
        from the Xurrent API. Requires confirmation due to high impact on running scripts.

        .EXAMPLE
        Disconnect-Xurrent
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param()

    process
    {
        if ($PSCmdlet.ShouldProcess('Xurrent session', 'Disconnect and clear session'))
        {
            $script:XurrentSession = $null
            $script:XurrentConfig = $null
            Write-Verbose 'Xurrent session cleared.'
        }
    }
}
