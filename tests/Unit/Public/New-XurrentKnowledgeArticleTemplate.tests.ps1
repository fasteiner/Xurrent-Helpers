BeforeAll {
    $script:dscModuleName = 'XurrentHelpers'
    Import-Module -Name $script:dscModuleName

    $script:tempDir = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString()))
}

AfterAll {
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
    Remove-Item -Path $script:tempDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'New-XurrentKnowledgeArticleTemplate' {
    Context 'When creating a template with a given name' {
        BeforeAll {
            $script:result = New-XurrentKnowledgeArticleTemplate -Name 'TestArticle' -Path $script:tempDir.FullName
        }

        It 'Should not throw' {
            { New-XurrentKnowledgeArticleTemplate -Name 'NoThrow' -Path $script:tempDir.FullName } | Should -Not -Throw
        }

        It 'Should return a FileInfo object' {
            $script:result | Should -BeOfType [System.IO.FileInfo]
        }

        It 'Should create a file named <Name>KnowledgeArticle.md' {
            $script:result.Name | Should -Be 'TestArticleKnowledgeArticle.md'
        }

        It 'Should create the file on disk' {
            Test-Path $script:result.FullName | Should -Be $true
        }

        It 'Should include the name as an H1 heading' {
            $content = Get-Content -Path $script:result.FullName -Raw
            $content | Should -Match '(?m)^#\s+TestArticle'
        }

        It 'Should include a Keywords line' {
            $content = Get-Content -Path $script:result.FullName -Raw
            $content | Should -Match '\*\*Keywords:\*\*'
        }

        It 'Should include an ID metadata line' {
            $content = Get-Content -Path $script:result.FullName -Raw
            $content | Should -Match '(?m)^\*\*ID:\*\*'
        }

        It 'Should include a Service metadata line' {
            $content = Get-Content -Path $script:result.FullName -Raw
            $content | Should -Match '(?m)^\*\*Service:\*\*'
        }

        It 'Should include a Service Instances metadata line' {
            $content = Get-Content -Path $script:result.FullName -Raw
            $content | Should -Match '(?m)^\*\*Service Instances:\*\*'
        }

        It 'Should place the metadata lines before the Description section' {
            $content = Get-Content -Path $script:result.FullName -Raw
            $descriptionIndex = $content.IndexOf('## Description')
            $descriptionIndex | Should -BeGreaterOrEqual 0
            foreach ($metadataLine in '**ID:**', '**Service:**', '**Service Instances:**') {
                $content.IndexOf($metadataLine) | Should -BeGreaterOrEqual 0
                $content.IndexOf($metadataLine) | Should -BeLessThan $descriptionIndex
            }
        }

        It 'Should round-trip with empty metadata so the Service and ServiceInstances fallbacks still apply' {
            $article = ConvertTo-XurrentKnowledgeArticle -File $script:result.FullName -Service 'fallback svc' -ServiceInstances 'fallback inst'
            $article.ID | Should -BeNullOrEmpty
            $article.Service | Should -Be 'fallback svc'
            $article.'Service Instances' | Should -Be 'fallback inst'
        }

        It 'Should include a Description section' {
            $content = Get-Content -Path $script:result.FullName -Raw
            $content | Should -Match '(?m)^##\s+Description'
        }

        It 'Should include an Instructions section' {
            $content = Get-Content -Path $script:result.FullName -Raw
            $content | Should -Match '(?m)^##\s+Instructions'
        }
    }

    Context 'When using -WhatIf' {
        BeforeAll {
            $script:whatIfPath = Join-Path $script:tempDir.FullName 'WhatIfKnowledgeArticle.md'
        }

        It 'Should support the WhatIf parameter' {
            (Get-Command -Name 'New-XurrentKnowledgeArticleTemplate').Parameters.ContainsKey('WhatIf') | Should -Be $true
        }

        It 'Should not create the file with -WhatIf' {
            New-XurrentKnowledgeArticleTemplate -Name 'WhatIf' -Path $script:tempDir.FullName -WhatIf
            Test-Path $script:whatIfPath | Should -Be $false
        }
    }
}
