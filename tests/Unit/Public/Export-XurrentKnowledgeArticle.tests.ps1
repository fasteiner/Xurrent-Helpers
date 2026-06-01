BeforeAll {
    $script:dscModuleName = 'XurrentHelpers'
    Import-Module -Name $script:dscModuleName

    $script:tempDir = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString()))
    $content = @'
# Test Article

## Description
This is a test description for the article content.

## Instructions
Follow these instructions carefully when using this feature.
'@
    Set-Content -Path (Join-Path $script:tempDir.FullName 'TestKnowledgeArticle.md') -Value $content -Encoding UTF8
    $script:outputCsv = Join-Path ([System.IO.Path]::GetTempPath()) "$([System.Guid]::NewGuid())-export.csv"
}

AfterAll {
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
    Remove-Item -Path $script:tempDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $script:outputCsv -Force -ErrorAction SilentlyContinue
}

Describe 'Export-XurrentKnowledgeArticle' {
    Context 'When the folder contains KnowledgeArticle files' {
        It 'Should not throw' {
            { Export-XurrentKnowledgeArticle -Folder $script:tempDir.FullName -Service 'svc' -ServiceInstances 'inst' -OutputPath $script:outputCsv } | Should -Not -Throw
        }

        It 'Should create the output CSV file' {
            Export-XurrentKnowledgeArticle -Folder $script:tempDir.FullName -Service 'svc' -ServiceInstances 'inst' -OutputPath $script:outputCsv
            Test-Path $script:outputCsv | Should -Be $true
        }

        It 'Should write one row per article' {
            Export-XurrentKnowledgeArticle -Folder $script:tempDir.FullName -Service 'svc' -ServiceInstances 'inst' -OutputPath $script:outputCsv
            $rows = Import-Csv -Path $script:outputCsv
            $rows.Count | Should -Be 1
        }

        It 'Should write the correct Subject' {
            Export-XurrentKnowledgeArticle -Folder $script:tempDir.FullName -Service 'svc' -ServiceInstances 'inst' -OutputPath $script:outputCsv
            $rows = Import-Csv -Path $script:outputCsv
            $rows[0].Subject | Should -Be 'Test Article'
        }
    }

    Context 'When the folder contains no KnowledgeArticle files' {
        BeforeAll {
            $script:emptyDir = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString()))
            $script:emptyOutput = Join-Path ([System.IO.Path]::GetTempPath()) "$([System.Guid]::NewGuid())-empty.csv"
        }

        AfterAll {
            Remove-Item -Path $script:emptyDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $script:emptyOutput -Force -ErrorAction SilentlyContinue
        }

        It 'Should not throw' {
            { Export-XurrentKnowledgeArticle -Folder $script:emptyDir.FullName -Service 'svc' -ServiceInstances 'inst' -OutputPath $script:emptyOutput -WarningAction SilentlyContinue } | Should -Not -Throw
        }

        It 'Should not create the output file' {
            Export-XurrentKnowledgeArticle -Folder $script:emptyDir.FullName -Service 'svc' -ServiceInstances 'inst' -OutputPath $script:emptyOutput -WarningAction SilentlyContinue
            Test-Path $script:emptyOutput | Should -Be $false
        }
    }

    Context 'When an .env file supplies SERVICE and SERVICE_INSTANCES' {
        BeforeAll {
            $script:envDir = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString()))
            Set-Content -Path (Join-Path $script:envDir.FullName 'TestKnowledgeArticle.md') -Value (Get-Content (Join-Path $script:tempDir.FullName 'TestKnowledgeArticle.md') -Raw) -Encoding UTF8
            $script:envFile = Join-Path $script:envDir.FullName '.env'
            Set-Content -Path $script:envFile -Value "SERVICE='env service'`nSERVICE_INSTANCES='env instance'" -Encoding UTF8
            $script:envOutput = Join-Path ([System.IO.Path]::GetTempPath()) "$([System.Guid]::NewGuid())-env.csv"
        }

        AfterAll {
            Remove-Item -Path $script:envDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $script:envOutput -Force -ErrorAction SilentlyContinue
        }

        It 'Should load Service from the .env file' {
            Export-XurrentKnowledgeArticle -Folder $script:envDir.FullName -OutputPath $script:envOutput -EnvFile $script:envFile
            $rows = Import-Csv -Path $script:envOutput
            $rows[0].Service | Should -Be 'env service'
        }

        It 'Should load Service Instances from the .env file' {
            Export-XurrentKnowledgeArticle -Folder $script:envDir.FullName -OutputPath $script:envOutput -EnvFile $script:envFile
            $rows = Import-Csv -Path $script:envOutput
            $rows[0].'Service Instances' | Should -Be 'env instance'
        }
    }

    Context 'When using -WhatIf' {
        BeforeAll {
            $script:whatIfOutput = Join-Path ([System.IO.Path]::GetTempPath()) "$([System.Guid]::NewGuid())-whatif.csv"
        }

        AfterAll {
            Remove-Item -Path $script:whatIfOutput -Force -ErrorAction SilentlyContinue
        }

        It 'Should support the WhatIf parameter' {
            (Get-Command -Name 'Export-XurrentKnowledgeArticle').Parameters.ContainsKey('WhatIf') | Should -Be $true
        }

        It 'Should not create the output file with -WhatIf' {
            Export-XurrentKnowledgeArticle -Folder $script:tempDir.FullName -Service 'svc' -ServiceInstances 'inst' -OutputPath $script:whatIfOutput -WhatIf
            Test-Path $script:whatIfOutput | Should -Be $false
        }
    }
}
