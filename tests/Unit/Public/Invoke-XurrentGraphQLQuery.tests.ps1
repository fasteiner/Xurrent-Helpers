BeforeAll {
    $script:moduleName = 'XurrentHelpers'
    Import-Module -Name $script:moduleName
}

AfterAll {
    Get-Module -Name $script:moduleName -All | Remove-Module -Force
}

Describe 'Invoke-XurrentGraphQLQuery' {
    Context 'When no session is active' {
        BeforeEach {
            & (Get-Module $script:moduleName) { $script:XurrentSession = $null }
        }

        It 'Should throw' {
            { Invoke-XurrentGraphQLQuery -Query 'query { me { id } }' } | Should -Throw '*No active Xurrent session*'
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

        It 'Should POST to the GraphQL URL' {
            Mock -CommandName 'Invoke-WebRequest' -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{ Content = '{"data":{"me":{"id":"1","name":"Test"}}}' }
            }
            Invoke-XurrentGraphQLQuery -Query 'query { me { id name } }'
            Should -Invoke 'Invoke-WebRequest' -ModuleName $script:moduleName -ParameterFilter {
                $Uri -eq 'https://graphql.xurrent.qa'
            }
        }

        It 'Should return the data property' {
            Mock -CommandName 'Invoke-WebRequest' -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{ Content = '{"data":{"me":{"id":"1","name":"Test"}}}' }
            }
            $result = Invoke-XurrentGraphQLQuery -Query 'query { me { id name } }'
            $result.me.name | Should -Be 'Test'
        }

        It 'Should throw on non-rate-limit errors' {
            Mock -CommandName 'Invoke-WebRequest' -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{ Content = '{"errors":[{"message":"Some error","extensions":{"code":"INTERNAL_SERVER_ERROR"}}]}' }
            }
            { Invoke-XurrentGraphQLQuery -Query 'query { me { id } }' } | Should -Throw '*GraphQL errors*'
        }

        It 'Should retry on rate limit and return data' {
            Mock -CommandName 'Start-Sleep' -ModuleName $script:moduleName -MockWith { }
            $script:gqlCallCount = 0
            Mock -CommandName 'Invoke-WebRequest' -ModuleName $script:moduleName -MockWith {
                $script:gqlCallCount++
                if ($script:gqlCallCount -eq 1)
                {
                    return [PSCustomObject]@{
                        Content = '{"errors":[{"message":"rate limit","extensions":{"code":"RATE_LIMITED","retryAfter":1}}]}'
                    }
                }
                [PSCustomObject]@{ Content = '{"data":{"me":{"id":"1"}}}' }
            }
            $result = Invoke-XurrentGraphQLQuery -Query 'query { me { id } }'
            $result.me.id | Should -Be '1'
            Should -Invoke 'Start-Sleep' -ModuleName $script:moduleName -Times 1
        }
    }
}
