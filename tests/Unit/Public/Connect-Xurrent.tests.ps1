BeforeAll {
    $script:moduleName = 'XurrentHelpers'
    Import-Module -Name $script:moduleName
}

AfterAll {
    Get-Module -Name $script:moduleName -All | Remove-Module -Force
}

AfterEach {
    & (Get-Module $script:moduleName) { $script:XurrentSession = $null }
}

Describe 'Connect-Xurrent' {
    Context 'Bearer token - QA environment' {
        BeforeEach {
            Mock -CommandName 'Invoke-WebRequest' -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{ Content = '{"name":"Test User","primary_email":"test@example.com"}' }
            }
        }

        It 'Should set BaseUrl for QA' {
            $secToken = ConvertTo-SecureString 'mytoken' -AsPlainText -Force
            Connect-Xurrent -Environment QA -Account testaccount -Token $secToken -SkipConnectionTest
            $session = & (Get-Module $script:moduleName) { $script:XurrentSession }
            $session.BaseUrl | Should -Be 'https://api.xurrent.qa/v1'
        }

        It 'Should set Authorization Bearer header' {
            $secToken = ConvertTo-SecureString 'mytoken' -AsPlainText -Force
            Connect-Xurrent -Environment QA -Account testaccount -Token $secToken -SkipConnectionTest
            $session = & (Get-Module $script:moduleName) { $script:XurrentSession }
            $session.Headers['Authorization'] | Should -Be 'Bearer mytoken'
        }
    }

    Context 'Bearer token - Prod environment' {
        It 'Should set BaseUrl for Prod' {
            $secToken = ConvertTo-SecureString 'tok' -AsPlainText -Force
            Connect-Xurrent -Environment Prod -Account testaccount -Token $secToken -SkipConnectionTest
            $session = & (Get-Module $script:moduleName) { $script:XurrentSession }
            $session.BaseUrl | Should -Be 'https://api.xurrent.com/v1'
        }
    }

    Context 'Bearer token - Demo environment' {
        It 'Should set BaseUrl for Demo' {
            $secToken = ConvertTo-SecureString 'tok' -AsPlainText -Force
            Connect-Xurrent -Environment Demo -Account testaccount -Token $secToken -SkipConnectionTest
            $session = & (Get-Module $script:moduleName) { $script:XurrentSession }
            $session.BaseUrl | Should -Be 'https://api.xurrent-demo.com/v1'
        }
    }

    Context 'OAuth2 credentials' {
        BeforeEach {
            Mock -CommandName 'Invoke-WebRequest' -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{ Content = '{"access_token":"oauthtoken","expires_in":3600}' }
            }
        }

        It 'Should perform token exchange and set Authorization header' {
            $cred = [System.Management.Automation.PSCredential]::new(
                'my_client_id',
                (ConvertTo-SecureString 'my_secret' -AsPlainText -Force)
            )
            Connect-Xurrent -Environment QA -Account testaccount -OAuthCredential $cred -SkipConnectionTest
            $session = & (Get-Module $script:moduleName) { $script:XurrentSession }
            $session.Headers['Authorization'] | Should -Be 'Bearer oauthtoken'
            Should -Invoke 'Invoke-WebRequest' -ModuleName $script:moduleName -Times 1
        }

        It 'Should store OAuthCred in session' {
            $cred = [System.Management.Automation.PSCredential]::new(
                'my_client_id',
                (ConvertTo-SecureString 'my_secret' -AsPlainText -Force)
            )
            Connect-Xurrent -Environment QA -Account testaccount -OAuthCredential $cred -SkipConnectionTest
            $session = & (Get-Module $script:moduleName) { $script:XurrentSession }
            $session.OAuthCred | Should -Not -BeNullOrEmpty
        }
    }

    Context 'CliXML bearer credential' {
        BeforeAll {
            $script:tempDir = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid()))
            $script:credFile = Join-Path $script:tempDir.FullName 'creds.xml'
            $bearerCred = [System.Management.Automation.PSCredential]::new(
                'bearer',
                (ConvertTo-SecureString 'mytoken' -AsPlainText -Force)
            )
            $bearerCred | Export-Clixml -Path $script:credFile
        }

        AfterAll {
            Remove-Item $script:tempDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Should load bearer token from CliXML' {
            Connect-Xurrent -Environment QA -Account testaccount -CredentialPath $script:credFile -SkipConnectionTest
            $session = & (Get-Module $script:moduleName) { $script:XurrentSession }
            $session.Headers['Authorization'] | Should -Be 'Bearer mytoken'
        }
    }

    Context 'CliXML OAuth2 credential' {
        BeforeAll {
            $script:tempDir2 = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid()))
            $script:oauthCredFile = Join-Path $script:tempDir2.FullName 'oauth.xml'
            $oauthCred = [System.Management.Automation.PSCredential]::new(
                'my_client',
                (ConvertTo-SecureString 'my_secret' -AsPlainText -Force)
            )
            $oauthCred | Export-Clixml -Path $script:oauthCredFile

            Mock -CommandName 'Invoke-WebRequest' -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{ Content = '{"access_token":"tok","expires_in":3600}' }
            }
        }

        AfterAll {
            Remove-Item $script:tempDir2.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Should detect OAuth2 type and exchange token' {
            Connect-Xurrent -Environment QA -Account testaccount -CredentialPath $script:oauthCredFile -SkipConnectionTest
            $session = & (Get-Module $script:moduleName) { $script:XurrentSession }
            $session.OAuthCred | Should -Not -BeNullOrEmpty
        }
    }

    Context 'SecretStore not available' {
        It 'Should throw a descriptive error' {
            { Connect-Xurrent -Environment QA -Account testaccount -SecretName 'mysecret' -SkipConnectionTest } |
                Should -Throw '*SecretManagement*'
        }
    }

    Context 'Connection test failure' {
        BeforeEach {
            Mock -CommandName 'Invoke-WebRequest' -ModuleName $script:moduleName -MockWith {
                $ex = [System.Net.WebException]::new('Unauthorized')
                $resp = [PSCustomObject]@{ StatusCode = [System.Net.HttpStatusCode]::Unauthorized }
                Add-Member -InputObject $ex -NotePropertyName Response -NotePropertyValue $resp
                throw $ex
            }
        }

        It 'Should clear session and throw on connection test failure' {
            $secToken = ConvertTo-SecureString 'badtoken' -AsPlainText -Force
            { Connect-Xurrent -Environment QA -Account testaccount -Token $secToken } | Should -Throw
            $session = & (Get-Module $script:moduleName) { $script:XurrentSession }
            $session | Should -BeNullOrEmpty
        }
    }

    Context '-SkipConnectionTest' {
        It 'Should not call /me when -SkipConnectionTest is specified' {
            Mock -CommandName 'Invoke-WebRequest' -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{ Content = '{}' }
            }
            $secToken = ConvertTo-SecureString 'tok' -AsPlainText -Force
            Connect-Xurrent -Environment QA -Account testaccount -Token $secToken -SkipConnectionTest
            Should -Invoke 'Invoke-WebRequest' -ModuleName $script:moduleName -Times 0
        }
    }
}
