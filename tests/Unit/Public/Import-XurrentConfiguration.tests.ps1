BeforeAll {
    $script:moduleName = 'XurrentHelpers'
    Import-Module -Name $script:moduleName

    $script:tempDir = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid()))

    $script:credPath = Join-Path $script:tempDir.FullName 'creds.xml'
    $script:cred = [System.Management.Automation.PSCredential]::new(
        'bearer',
        (ConvertTo-SecureString 'mytoken' -AsPlainText -Force)
    )
    $script:cred | Export-Clixml -Path $script:credPath
}

AfterAll {
    Remove-Item $script:tempDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
    Get-Module -Name $script:moduleName -All | Remove-Module -Force
}

AfterEach {
    & (Get-Module $script:moduleName) {
        $script:XurrentConfig  = $null
        $script:XurrentSession = $null
    }
}

Describe 'Import-XurrentConfiguration' {
    Context 'Normal key/value loading' {
        BeforeAll {
            $script:envFile = Join-Path $script:tempDir.FullName 'test.env'
            Set-Content -Path $script:envFile -Encoding UTF8 -Value @"
XURRENT_ENVIRONMENT=QA
XURRENT_ACCOUNT=techwork-support
# this is a comment
XURRENT_QUOTED="quoted value"
"@
        }

        It 'Should load key-value pairs into XurrentConfig' {
            Import-XurrentConfiguration -Path $script:envFile
            $config = & (Get-Module $script:moduleName) { $script:XurrentConfig }
            $config['XURRENT_ENVIRONMENT'] | Should -Be 'QA'
            $config['XURRENT_ACCOUNT']     | Should -Be 'techwork-support'
        }

        It 'Should strip surrounding quotes from values' {
            Import-XurrentConfiguration -Path $script:envFile
            $config = & (Get-Module $script:moduleName) { $script:XurrentConfig }
            $config['XURRENT_QUOTED'] | Should -Be 'quoted value'
        }

        It 'Should ignore comment lines' {
            Import-XurrentConfiguration -Path $script:envFile
            $config = & (Get-Module $script:moduleName) { $script:XurrentConfig }
            $config.Keys | Should -Not -Contain '# this is a comment'
        }
    }

    Context 'When file does not exist' {
        It 'Should not throw' {
            { Import-XurrentConfiguration -Path 'C:\nonexistent\path\config.env' } | Should -Not -Throw
        }

        It 'Should leave XurrentConfig null' {
            Import-XurrentConfiguration -Path 'C:\nonexistent\path\config.env'
            $config = & (Get-Module $script:moduleName) { $script:XurrentConfig }
            $config | Should -BeNullOrEmpty
        }
    }

    Context '-AutoConnect' {
        BeforeAll {
            $script:autoEnvFile = Join-Path $script:tempDir.FullName 'autoconnect.env'
            Set-Content -Path $script:autoEnvFile -Encoding UTF8 -Value @"
XURRENT_ENVIRONMENT=QA
XURRENT_ACCOUNT=techwork-support
XURRENT_CREDENTIAL_PATH=$($script:credPath)
"@
            Mock -CommandName 'Invoke-WebRequest' -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{ Content = '{"name":"Auto User","primary_email":"auto@example.com"}' }
            }
        }

        It 'Should call Connect-Xurrent and set a session' {
            Import-XurrentConfiguration -Path $script:autoEnvFile -AutoConnect
            $session = & (Get-Module $script:moduleName) { $script:XurrentSession }
            $session | Should -Not -BeNullOrEmpty
            $session.BaseUrl | Should -Be 'https://api.xurrent.qa/v1'
        }
    }

    Context 'XURRENT_AUTO_CONNECT=true in config' {
        BeforeAll {
            $script:autoTrueFile = Join-Path $script:tempDir.FullName 'autotrue.env'
            Set-Content -Path $script:autoTrueFile -Encoding UTF8 -Value @"
XURRENT_ENVIRONMENT=QA
XURRENT_ACCOUNT=techwork-support
XURRENT_CREDENTIAL_PATH=$($script:credPath)
XURRENT_AUTO_CONNECT=true
"@
            Mock -CommandName 'Invoke-WebRequest' -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{ Content = '{"name":"Auto User","primary_email":"auto@example.com"}' }
            }
        }

        It 'Should auto-connect when XURRENT_AUTO_CONNECT=true' {
            Import-XurrentConfiguration -Path $script:autoTrueFile
            $session = & (Get-Module $script:moduleName) { $script:XurrentSession }
            $session | Should -Not -BeNullOrEmpty
        }
    }
}
