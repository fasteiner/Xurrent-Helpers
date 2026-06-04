BeforeAll {
    $script:moduleName = 'XurrentHelpers'
    Import-Module -Name $script:moduleName
}

AfterAll {
    Get-Module -Name $script:moduleName -All | Remove-Module -Force
}

Describe 'Invoke-XurrentRestMethod' {
    Context 'When no session is active' {
        BeforeEach {
            & (Get-Module $script:moduleName) { $script:XurrentSession = $null }
        }

        It 'Should throw' {
            { Invoke-XurrentRestMethod -Path '/me' } | Should -Throw '*No active Xurrent session*'
        }
    }

    Context 'With an active session' {
        BeforeEach {
            & (Get-Module $script:moduleName) {
                $script:XurrentSession = @{
                    BaseUrl    = 'https://api.xurrent.qa/v1'
                    GraphQLUrl = 'https://graphql.xurrent.qa'
                    Headers    = @{ Authorization = 'Bearer testtoken'; 'X-4me-Account' = 'test' }
                    OAuthCred  = $null
                    TokenExpiry = $null
                }
            }
            Mock -CommandName 'Invoke-WebRequest' -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{ Content = '{"id":42,"name":"Test"}'; StatusCode = 200 }
            }
        }

        AfterEach {
            & (Get-Module $script:moduleName) { $script:XurrentSession = $null }
        }

        It 'Should build the correct full URI' {
            Invoke-XurrentRestMethod -Path '/people/42'
            Should -Invoke 'Invoke-WebRequest' -ModuleName $script:moduleName -ParameterFilter {
                $Uri -eq 'https://api.xurrent.qa/v1/people/42'
            }
        }

        It 'Should append query parameters' {
            Invoke-XurrentRestMethod -Path '/people' -QueryParameters @{ per_page = 50 }
            Should -Invoke 'Invoke-WebRequest' -ModuleName $script:moduleName -ParameterFilter {
                $Uri -like '*per_page=50*'
            }
        }

        It 'Should return parsed JSON by default' {
            $result = Invoke-XurrentRestMethod -Path '/me'
            $result.name | Should -Be 'Test'
        }

        It 'Should return raw response with -Raw' {
            $result = Invoke-XurrentRestMethod -Path '/me' -Raw
            $result.Content | Should -Be '{"id":42,"name":"Test"}'
        }
    }
}
