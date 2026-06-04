BeforeAll {
    $script:moduleName = 'XurrentHelpers'
    Import-Module -Name $script:moduleName

    & (Get-Module $script:moduleName) {
        $script:XurrentSession = @{
            BaseUrl    = 'https://api.xurrent.qa/v1'
            GraphQLUrl = 'https://graphql.xurrent.qa'
            OAuthUrl   = 'https://oauth.xurrent.qa/token'
            Headers    = @{ Authorization = 'Bearer testtoken'; 'X-4me-Account' = 'test' }
            OAuthCred  = $null
            TokenExpiry = $null
        }
    }
}

AfterAll {
    & (Get-Module $script:moduleName) { $script:XurrentSession = $null }
    Get-Module -Name $script:moduleName -All | Remove-Module -Force
}

Describe 'Invoke-XurrentAPIRequest' {
    Context 'On HTTP 200' {
        BeforeEach {
            Mock -CommandName 'Invoke-WebRequest' -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{ Content = '{"id":1,"name":"Test"}'; StatusCode = 200 }
            }
        }

        It 'Should return parsed JSON' {
            $result = & (Get-Module $script:moduleName) {
                Invoke-XurrentAPIRequest -Uri 'https://api.xurrent.qa/v1/me' -Method GET
            }
            $result.name | Should -Be 'Test'
        }
    }

    Context 'On HTTP 200 with -Raw' {
        BeforeEach {
            Mock -CommandName 'Invoke-WebRequest' -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{ Content = '{"id":1}'; StatusCode = 200 }
            }
        }

        It 'Should return the raw WebResponseObject' {
            $result = & (Get-Module $script:moduleName) {
                Invoke-XurrentAPIRequest -Uri 'https://api.xurrent.qa/v1/me' -Method GET -Raw
            }
            $result.Content | Should -Be '{"id":1}'
        }
    }

    Context 'On HTTP 404' {
        BeforeEach {
            Mock -CommandName 'Invoke-WebRequest' -ModuleName $script:moduleName -MockWith {
                $ex = [System.Net.WebException]::new('Not Found')
                $responseMock = [PSCustomObject]@{ StatusCode = [System.Net.HttpStatusCode]::NotFound }
                Add-Member -InputObject $ex -NotePropertyName Response -NotePropertyValue $responseMock
                throw $ex
            }
        }

        It 'Should return $null' {
            $result = & (Get-Module $script:moduleName) {
                Invoke-XurrentAPIRequest -Uri 'https://api.xurrent.qa/v1/notfound' -Method GET
            }
            $result | Should -BeNullOrEmpty
        }

        It 'Should call Write-Error' {
            & (Get-Module $script:moduleName) {
                Invoke-XurrentAPIRequest -Uri 'https://api.xurrent.qa/v1/notfound' -Method GET -ErrorAction SilentlyContinue
            }
            Should -Invoke 'Invoke-WebRequest' -ModuleName $script:moduleName -Times 1
        }
    }

    Context 'On HTTP 429 with Retry-After' {
        BeforeAll {
            $script:callCount = 0
        }

        BeforeEach {
            Mock -CommandName 'Start-Sleep' -ModuleName $script:moduleName -MockWith { }
            Mock -CommandName 'Invoke-WebRequest' -ModuleName $script:moduleName -MockWith {
                $script:callCount++
                if ($script:callCount -eq 1)
                {
                    $ex = [System.Net.WebException]::new('Too Many Requests')
                    $headers = [System.Net.WebHeaderCollection]::new()
                    $headers.Add('Retry-After', '1')
                    $responseMock = [PSCustomObject]@{
                        StatusCode = [System.Net.HttpStatusCode]::TooManyRequests
                        Headers    = $headers
                    }
                    Add-Member -InputObject $ex -NotePropertyName Response -NotePropertyValue $responseMock
                    throw $ex
                }
                [PSCustomObject]@{ Content = '{"ok":true}'; StatusCode = 200 }
            }
            $script:callCount = 0
        }

        It 'Should retry and return parsed JSON on second attempt' {
            $result = & (Get-Module $script:moduleName) {
                Invoke-XurrentAPIRequest -Uri 'https://api.xurrent.qa/v1/me' -Method GET
            }
            $result.ok | Should -Be $true
            Should -Invoke 'Start-Sleep' -ModuleName $script:moduleName -Times 1
        }
    }

    Context 'On HTTP 401 with OAuth2 session' {
        BeforeAll {
            & (Get-Module $script:moduleName) {
                $script:XurrentSession.OAuthCred = [System.Management.Automation.PSCredential]::new(
                    'client_id',
                    (ConvertTo-SecureString 'secret' -AsPlainText -Force)
                )
            }
            $script:callCount = 0
        }

        AfterAll {
            & (Get-Module $script:moduleName) { $script:XurrentSession.OAuthCred = $null }
        }

        BeforeEach {
            Mock -CommandName 'Invoke-WebRequest' -ModuleName $script:moduleName -MockWith {
                $script:callCount++
                if ($script:callCount -eq 1)
                {
                    $ex = [System.Net.WebException]::new('Unauthorized')
                    $responseMock = [PSCustomObject]@{ StatusCode = [System.Net.HttpStatusCode]::Unauthorized }
                    Add-Member -InputObject $ex -NotePropertyName Response -NotePropertyValue $responseMock
                    throw $ex
                }
                if ($script:callCount -eq 2)
                {
                    # Simulates token refresh call
                    return [PSCustomObject]@{ Content = '{"access_token":"new","expires_in":3600}' }
                }
                [PSCustomObject]@{ Content = '{"id":1}'; StatusCode = 200 }
            }
            $script:callCount = 0
        }

        It 'Should refresh token and retry once' {
            $result = & (Get-Module $script:moduleName) {
                Invoke-XurrentAPIRequest -Uri 'https://api.xurrent.qa/v1/me' -Method GET
            }
            $result.id | Should -Be 1
            Should -Invoke 'Invoke-WebRequest' -ModuleName $script:moduleName -Times 3
        }
    }
}
