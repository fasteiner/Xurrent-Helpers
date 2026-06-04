$_defaultConfig = Join-Path (Split-Path $PROFILE) '.xurrent' 'config.env'
if (Test-Path $_defaultConfig)
{
    try
    {
        Import-XurrentConfiguration -Path $_defaultConfig
    }
    catch
    {
        Write-Warning "XurrentHelpers: auto-load failed: $_"
    }
}
Remove-Variable _defaultConfig
