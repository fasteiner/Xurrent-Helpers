BeforeAll {
    $script:moduleName = 'XurrentHelpers'
    Import-Module -Name $script:moduleName

    $script:tempDir = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid()))
    $script:credPath = Join-Path $script:tempDir.FullName 'webhook_hook1.xml'
    $script:cred = [System.Management.Automation.PSCredential]::new(
        'hookuser',
        (ConvertTo-SecureString 'hookpass' -AsPlainText -Force)
    )
    $script:cred | Export-Clixml -Path $script:credPath
}

AfterAll {
    Remove-Item $script:tempDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
    & (Get-Module $script:moduleName) { $script:XurrentConfig = $null }
    Get-Module -Name $script:moduleName -All | Remove-Module -Force
}

Describe 'Invoke-XurrentWebhook' {
    Context 'ByName parameter set' {
        BeforeEach {
            & (Get-Module $script:moduleName) {
                $script:XurrentConfig = @{
                    'XURRENT_WEBHOOK_hook1_URL'             = 'https://hooks.example.com/hook1'
                    'XURRENT_WEBHOOK_hook1_CREDENTIAL_PATH' = $script:credPath
                }
            }
            Mock -CommandName 'Invoke-WebRequest' -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{ Content = '{"ok":true}' }
            }
        }

        AfterEach {
            & (Get-Module $script:moduleName) { $script:XurrentConfig = $null }
        }

        It 'Should call the correct URL from config' {
            Invoke-XurrentWebhook -Name 'hook1'
            Should -Invoke 'Invoke-WebRequest' -ModuleName $script:moduleName -ParameterFilter {
                $Uri -eq 'https://hooks.example.com/hook1'
            }
        }

        It 'Should use Basic Authorization header' {
            Invoke-XurrentWebhook -Name 'hook1'
            Should -Invoke 'Invoke-WebRequest' -ModuleName $script:moduleName -ParameterFilter {
                $Headers['Authorization'] -match '^Basic '
            }
        }

        It 'Should throw when webhook name is not in config' {
            { Invoke-XurrentWebhook -Name 'nonexistent' } | Should -Throw "*nonexistent*"
        }

        It 'Should throw when no config is loaded' {
            & (Get-Module $script:moduleName) { $script:XurrentConfig = $null }
            { Invoke-XurrentWebhook -Name 'hook1' } | Should -Throw '*Import-XurrentConfiguration*'
        }
    }

    Context 'Direct parameter set' {
        BeforeEach {
            Mock -CommandName 'Invoke-WebRequest' -ModuleName $script:moduleName -MockWith {
                [PSCustomObject]@{ Content = '{"result":"ok"}' }
            }
        }

        It 'Should use provided URL and build correct Basic header' {
            Invoke-XurrentWebhook -Url 'https://hooks.example.com/direct' -Credential $script:cred
            $expectedToken = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes('hookuser:hookpass'))
            Should -Invoke 'Invoke-WebRequest' -ModuleName $script:moduleName -ParameterFilter {
                $Uri -eq 'https://hooks.example.com/direct' -and
                $Headers['Authorization'] -eq "Basic $expectedToken"
            }
        }

        It 'Should return parsed response' {
            $result = Invoke-XurrentWebhook -Url 'https://hooks.example.com/direct' -Credential $script:cred
            $result.result | Should -Be 'ok'
        }
    }
}
