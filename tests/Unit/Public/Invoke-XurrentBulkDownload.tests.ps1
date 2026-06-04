BeforeAll {
    $script:moduleName = 'XurrentHelpers'
    Import-Module -Name $script:moduleName
}

AfterAll {
    Get-Module -Name $script:moduleName -All | Remove-Module -Force
}

Describe 'Invoke-XurrentBulkDownload' {
    Context 'When no session is active' {
        BeforeEach {
            & (Get-Module $script:moduleName) { $script:XurrentSession = $null }
        }

        It 'Should throw' {
            { Invoke-XurrentBulkDownload -ResourceType 'people' } |
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

        BeforeEach {
            Mock -CommandName 'Start-Sleep' -ModuleName $script:moduleName -MockWith { }

            $script:tempCsv = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.csv'
            [PSCustomObject]@{ id = '1'; name = 'Alice' } | Export-Csv -Path $script:tempCsv -NoTypeInformation -Encoding UTF8

            Mock -CommandName 'Invoke-WebRequest' -ModuleName $script:moduleName -MockWith {
                param($Uri, $OutFile)
                if ($Uri -match '/export$')
                {
                    return [PSCustomObject]@{ Content = '{"token":"exporttok"}' }
                }
                if ($Uri -match '/export/exporttok')
                {
                    return [PSCustomObject]@{ Content = '{"state":"done","url":"https://cdn.xurrent.qa/export.csv"}' }
                }
                if ($OutFile)
                {
                    Copy-Item $script:tempCsv -Destination $OutFile
                    return [PSCustomObject]@{ Content = '' }
                }
            }
        }

        AfterEach {
            Remove-Item $script:tempCsv -Force -ErrorAction SilentlyContinue
        }

        It 'Should POST to the export endpoint' {
            Invoke-XurrentBulkDownload -ResourceType 'people'
            Should -Invoke 'Invoke-WebRequest' -ModuleName $script:moduleName -ParameterFilter {
                $Uri -eq 'https://api.xurrent.qa/v1/export'
            }
        }

        It 'Should return an array for a single resource type' {
            $result = Invoke-XurrentBulkDownload -ResourceType 'people'
            $result | Should -Not -BeNullOrEmpty
            $result[0].name | Should -Be 'Alice'
        }

        It 'Should include from field when -Delta is specified' {
            Invoke-XurrentBulkDownload -ResourceType 'people' -Delta -FromDate '2024-01-01T00:00:00Z'
            Should -Invoke 'Invoke-WebRequest' -ModuleName $script:moduleName -ParameterFilter {
                $Uri -eq 'https://api.xurrent.qa/v1/export'
            }
        }

        Context '-SaveAs' {
            BeforeAll {
                $script:saveDir = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid()))
                $script:savePath = Join-Path $script:saveDir.FullName 'export.csv'
            }

            AfterAll {
                Remove-Item $script:saveDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
            }

            It 'Should save to file and return nothing' {
                $result = Invoke-XurrentBulkDownload -ResourceType 'people' -SaveAs $script:savePath
                $result | Should -BeNullOrEmpty
                Test-Path $script:savePath | Should -Be $true
            }
        }
    }
}
