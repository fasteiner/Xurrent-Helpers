BeforeAll {
    $script:moduleName = 'XurrentHelpers'
    Import-Module -Name $script:moduleName

    $script:tempDir = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid()))
    $script:credPath = Join-Path $script:tempDir.FullName 'webhook_test.xml'
    $script:configPath = Join-Path $script:tempDir.FullName 'config.env'
    $script:cred = [System.Management.Automation.PSCredential]::new(
        'webhookuser',
        (ConvertTo-SecureString 'webhookpass' -AsPlainText -Force)
    )
}

AfterAll {
    Remove-Item $script:tempDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
    Get-Module -Name $script:moduleName -All | Remove-Module -Force
}

Describe 'New-XurrentWebhookConfiguration' {
    Context 'First run' {
        BeforeEach {
            Remove-Item $script:credPath -Force -ErrorAction SilentlyContinue
            Remove-Item $script:configPath -Force -ErrorAction SilentlyContinue
        }

        It 'Should create the credential file' {
            New-XurrentWebhookConfiguration -Name 'test' -Url 'https://hooks.example.com/t' `
                -Credential $script:cred -CredentialPath $script:credPath -ConfigPath $script:configPath
            Test-Path $script:credPath | Should -Be $true
        }

        It 'Should write URL to config file' {
            New-XurrentWebhookConfiguration -Name 'test' -Url 'https://hooks.example.com/t' `
                -Credential $script:cred -CredentialPath $script:credPath -ConfigPath $script:configPath
            $content = Get-Content $script:configPath -Raw
            $content | Should -Match 'XURRENT_WEBHOOK_test_URL=https://hooks.example.com/t'
        }

        It 'Should write credential path to config file' {
            New-XurrentWebhookConfiguration -Name 'test' -Url 'https://hooks.example.com/t' `
                -Credential $script:cred -CredentialPath $script:credPath -ConfigPath $script:configPath
            $content = Get-Content $script:configPath -Raw
            $content | Should -Match 'XURRENT_WEBHOOK_test_CREDENTIAL_PATH='
        }

        It 'Should return a summary object' {
            $result = New-XurrentWebhookConfiguration -Name 'test' -Url 'https://hooks.example.com/t' `
                -Credential $script:cred -CredentialPath $script:credPath -ConfigPath $script:configPath
            $result.Name | Should -Be 'test'
            $result.Url  | Should -Be 'https://hooks.example.com/t'
        }
    }

    Context 'Second run (upsert)' {
        BeforeEach {
            New-XurrentWebhookConfiguration -Name 'test' -Url 'https://old.example.com' `
                -Credential $script:cred -CredentialPath $script:credPath -ConfigPath $script:configPath
        }

        It 'Should update URL without duplicating lines' {
            New-XurrentWebhookConfiguration -Name 'test' -Url 'https://new.example.com' `
                -Credential $script:cred -CredentialPath $script:credPath -ConfigPath $script:configPath
            $lines = Get-Content $script:configPath
            ($lines | Where-Object { $_ -match '^XURRENT_WEBHOOK_test_URL=' }).Count | Should -Be 1
            $lines | Where-Object { $_ -match '^XURRENT_WEBHOOK_test_URL=' } |
                Should -Match 'https://new.example.com'
        }
    }

    Context 'Directory creation' {
        BeforeAll {
            $script:newDir = Join-Path $script:tempDir.FullName 'newsubdir'
            $script:newCredPath = Join-Path $script:newDir 'creds.xml'
            $script:newConfigPath = Join-Path $script:newDir 'config.env'
        }

        It 'Should create missing parent directory' {
            Test-Path $script:newDir | Should -Be $false
            New-XurrentWebhookConfiguration -Name 'test' -Url 'https://hooks.example.com/t' `
                -Credential $script:cred -CredentialPath $script:newCredPath -ConfigPath $script:newConfigPath
            Test-Path $script:newDir | Should -Be $true
        }
    }
}
