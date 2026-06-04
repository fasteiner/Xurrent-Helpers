BeforeAll {
    $script:moduleName = 'XurrentHelpers'
    Import-Module -Name $script:moduleName
}

AfterAll {
    Get-Module -Name $script:moduleName -All | Remove-Module -Force
}

Describe 'Assert-XurrentConnection' {
    Context 'When no session is active' {
        BeforeEach {
            & (Get-Module $script:moduleName) { $script:XurrentSession = $null }
        }

        It 'Should throw the expected message' {
            {
                & (Get-Module $script:moduleName) { Assert-XurrentConnection }
            } | Should -Throw '*No active Xurrent session*'
        }
    }

    Context 'When a session is active' {
        BeforeEach {
            & (Get-Module $script:moduleName) {
                $script:XurrentSession = @{
                    BaseUrl    = 'https://api.xurrent.qa/v1'
                    Headers    = @{ Authorization = 'Bearer testtoken' }
                    OAuthCred  = $null
                    TokenExpiry = $null
                }
            }
        }

        AfterEach {
            & (Get-Module $script:moduleName) { $script:XurrentSession = $null }
        }

        It 'Should not throw' {
            { & (Get-Module $script:moduleName) { Assert-XurrentConnection } } | Should -Not -Throw
        }
    }

    Context 'When OAuth2 token is near expiry' {
        BeforeEach {
            & (Get-Module $script:moduleName) {
                $script:XurrentSession = @{
                    BaseUrl     = 'https://api.xurrent.qa/v1'
                    OAuthUrl    = 'https://oauth.xurrent.qa/token'
                    Headers     = @{ Authorization = 'Bearer oldtoken' }
                    OAuthCred   = [System.Management.Automation.PSCredential]::new(
                        'client_id',
                        (ConvertTo-SecureString 'client_secret' -AsPlainText -Force)
                    )
                    TokenExpiry = [datetime]::UtcNow.AddSeconds(30)
                }
            }
            Mock -CommandName 'Invoke-WebRequest' -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{
                    Content = '{"access_token":"newtoken","expires_in":3600}' | Out-String
                }
            }
        }

        AfterEach {
            & (Get-Module $script:moduleName) { $script:XurrentSession = $null }
        }

        It 'Should call Update-XurrentOAuthToken' {
            & (Get-Module $script:moduleName) { Assert-XurrentConnection }
            Should -Invoke 'Invoke-WebRequest' -ModuleName $script:moduleName -Times 1
        }
    }
}
