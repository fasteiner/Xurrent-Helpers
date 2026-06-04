BeforeAll {
    $script:moduleName = 'XurrentHelpers'
    Import-Module -Name $script:moduleName
}

AfterAll {
    Get-Module -Name $script:moduleName -All | Remove-Module -Force
}

Describe 'Invoke-XurrentBulkUpload' {
    Context 'When no session is active' {
        BeforeEach {
            & (Get-Module $script:moduleName) { $script:XurrentSession = $null }
        }

        It 'Should throw' {
            { Invoke-XurrentBulkUpload -Object @([PSCustomObject]@{ id = 1 }) -ResourceType 'people' } |
                Should -Throw '*No active Xurrent session*'
        }
    }

    Context 'With an active session' {
        BeforeEach {
            & (Get-Module $script:moduleName) {
                $script:XurrentSession = @{
                    BaseUrl    = 'https://api.xurrent.qa/v1'
                    GraphQLUrl = 'https://graphql.xurrent.qa'
                    Headers    = @{ Authorization = 'Bearer tok'; 'X-4me-Account' = 'test' }
                    OAuthCred  = $null
                    TokenExpiry = $null
                }
            }
        }

        AfterEach {
            & (Get-Module $script:moduleName) { $script:XurrentSession = $null }
        }

        Context '-Simulate switch' {
            It 'Should return done without calling Invoke-WebRequest' {
                Mock -CommandName 'Invoke-WebRequest' -ModuleName $script:moduleName -MockWith {
                    [PSCustomObject]@{ Content = '{}' }
                }
                $result = Invoke-XurrentBulkUpload -Object @([PSCustomObject]@{ id = 1 }) -ResourceType 'people' -Simulate
                $result | Should -Be 'done'
                Should -Invoke 'Invoke-WebRequest' -ModuleName $script:moduleName -Times 0
            }
        }

        Context 'Normal upload' {
            BeforeEach {
                Mock -CommandName 'Start-Sleep' -ModuleName $script:moduleName -MockWith { }
                Mock -CommandName 'Invoke-WebRequest' -ModuleName $script:moduleName -MockWith {
                    param($Uri)
                    if ($Uri -match '/import$')
                    {
                        return [PSCustomObject]@{ Content = '{"token":"abc123"}' }
                    }
                    [PSCustomObject]@{ Content = '{"state":"done","results":{"errors":[]}}' }
                }
            }

            It 'Should POST to the import endpoint' {
                Invoke-XurrentBulkUpload -Object @([PSCustomObject]@{ name = 'Alice' }) -ResourceType 'people'
                Should -Invoke 'Invoke-WebRequest' -ModuleName $script:moduleName -ParameterFilter {
                    $Uri -eq 'https://api.xurrent.qa/v1/import'
                }
            }

            It 'Should return done on success' {
                $result = Invoke-XurrentBulkUpload -Object @([PSCustomObject]@{ name = 'Alice' }) -ResourceType 'people'
                $result | Should -Be 'done'
            }

            It 'Should clean up the temp CSV by default' {
                $tempsBefore = (Get-ChildItem ([System.IO.Path]::GetTempPath()) -Filter '*.csv').Count
                Invoke-XurrentBulkUpload -Object @([PSCustomObject]@{ name = 'Alice' }) -ResourceType 'people'
                $tempsAfter = (Get-ChildItem ([System.IO.Path]::GetTempPath()) -Filter '*.csv').Count
                $tempsAfter | Should -Be $tempsBefore
            }
        }

        Context 'Auto-chunking' {
            BeforeEach {
                Mock -CommandName 'Start-Sleep' -ModuleName $script:moduleName -MockWith { }
                Mock -CommandName 'Invoke-WebRequest' -ModuleName $script:moduleName -MockWith {
                    param($Uri)
                    if ($Uri -match '/import$')
                    {
                        return [PSCustomObject]@{ Content = '{"token":"tok"}' }
                    }
                    [PSCustomObject]@{ Content = '{"state":"done","results":{"errors":[]}}' }
                }
            }

            It 'Should split into multiple jobs when count exceeds JobLimit' {
                $items = 1..600 | ForEach-Object { [PSCustomObject]@{ id = $_ } }
                Invoke-XurrentBulkUpload -Object $items -ResourceType 'people' -JobLimit 500
                Should -Invoke 'Invoke-WebRequest' -ModuleName $script:moduleName -ParameterFilter {
                    $Uri -match '/import$'
                } -Times 2
            }
        }
    }
}
