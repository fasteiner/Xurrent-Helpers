BeforeAll {
    $script:moduleName = 'XurrentHelpers'
    Import-Module -Name $script:moduleName

    $script:tempDir = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString()))
}

AfterAll {
    Get-Module -Name $script:moduleName -All | Remove-Module -Force
    Remove-Item -Path $script:tempDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'ConvertFrom-XurrentKnowledgeArticle' {
    BeforeAll {
        $script:row = [PSCustomObject]@{
            Subject      = 'VPN Setup Guide'
            Description  = 'How to configure VPN access on your device.'
            Instructions = 'Step 1: Install the client. Step 2: Connect.'
            Keywords     = 'vpn, network, remote'
        }
        $script:result = ConvertFrom-XurrentKnowledgeArticle -InputObject $script:row -Path $script:tempDir.FullName
    }

    Context 'When given a valid row' {
        It 'Should not throw' {
            { ConvertFrom-XurrentKnowledgeArticle -InputObject $script:row -Path $script:tempDir.FullName } | Should -Not -Throw
        }

        It 'Should return a FileInfo object' {
            $script:result | Should -BeOfType [System.IO.FileInfo]
        }

        It 'Should create the output file' {
            $script:result.Exists | Should -Be $true
        }

        It 'Should name the file using the Subject' {
            $script:result.Name | Should -Be 'VPN Setup GuideKnowledgeArticle.md'
        }

        It 'Should write the Subject as an H1 heading' {
            $content = Get-Content $script:result.FullName -Raw
            $content | Should -Match '(?m)^# VPN Setup Guide'
        }

        It 'Should write the Keywords line' {
            $content = Get-Content $script:result.FullName -Raw
            $content | Should -Match '\*\*Keywords:\*\*\s*vpn, network, remote'
        }

        It 'Should write the Description into its section' {
            $content = Get-Content $script:result.FullName -Raw
            $content | Should -Match 'How to configure VPN access'
        }

        It 'Should write the Instructions into its section' {
            $content = Get-Content $script:result.FullName -Raw
            $content | Should -Match 'Step 1: Install'
        }
    }

    Context 'When Subject contains invalid filename characters' {
        BeforeAll {
            $script:badRow = [PSCustomObject]@{
                Subject      = 'How to: Fix/Reset <Password>'
                Description  = 'Reset your password.'
                Instructions = 'Follow the steps.'
                Keywords     = 'password'
            }
            $script:badResult = ConvertFrom-XurrentKnowledgeArticle -InputObject $script:badRow -Path $script:tempDir.FullName
        }

        It 'Should not throw' {
            { ConvertFrom-XurrentKnowledgeArticle -InputObject $script:badRow -Path $script:tempDir.FullName } | Should -Not -Throw
        }

        It 'Should create a file with a sanitized name' {
            $script:badResult.Exists | Should -Be $true
        }

        It 'Should not contain invalid filename characters in the output name' {
            $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($script:badResult.Name)
            $baseName.IndexOfAny($invalidChars) | Should -Be -1
        }
    }

    Context 'When Subject is empty' {
        It 'Should use Unknown as the filename prefix' {
            $emptyRow = [PSCustomObject]@{ Subject = ''; Description = 'desc'; Instructions = 'inst'; Keywords = '' }
            $result = ConvertFrom-XurrentKnowledgeArticle -InputObject $emptyRow -Path $script:tempDir.FullName
            $result.Name | Should -Be 'UnknownKnowledgeArticle.md'
        }
    }

    Context 'When the row has a numeric ID' {
        BeforeAll {
            $script:idRow = [PSCustomObject]@{
                ID           = 12345
                Subject      = 'Article With ID'
                Description  = 'Some description.'
                Instructions = 'Some instructions.'
                Keywords     = 'kw'
            }
            $script:idResult = ConvertFrom-XurrentKnowledgeArticle -InputObject $script:idRow -Path $script:tempDir.FullName
        }

        It 'Should write the numeric ID as an **ID:** line' {
            $content = Get-Content $script:idResult.FullName -Raw
            $content | Should -Match '(?m)^\*\*ID:\*\* 12345\s*$'
        }
    }

    Context 'When the row has no ID' {
        BeforeAll {
            $script:noIdRow = [PSCustomObject]@{
                Subject      = 'Article Without ID'
                Description  = 'Some description.'
                Instructions = 'Some instructions.'
                Keywords     = 'kw'
            }
            $script:noIdResult = ConvertFrom-XurrentKnowledgeArticle -InputObject $script:noIdRow -Path $script:tempDir.FullName
        }

        It 'Should not throw when the row has no ID (backwards compatible)' {
            { ConvertFrom-XurrentKnowledgeArticle -InputObject $script:noIdRow -Path $script:tempDir.FullName } | Should -Not -Throw
        }

        It 'Should write an empty **ID:** line' {
            $content = Get-Content $script:noIdResult.FullName -Raw
            # The ID line is present for schema consistency but carries no value.
            $content | Should -Match '(?m)^\*\*ID:\*\*\s*$'
        }
    }

    Context 'When round-tripping a numeric ID back through ConvertTo' {
        It 'Should recover the same numeric ID from the generated Markdown' {
            $row = [PSCustomObject]@{
                ID           = 777
                Subject      = 'Round Trip Article'
                Description  = 'desc'
                Instructions = 'inst'
                Keywords     = 'kw'
            }
            $file = ConvertFrom-XurrentKnowledgeArticle -InputObject $row -Path $script:tempDir.FullName
            $obj = ConvertTo-XurrentKnowledgeArticle -File $file.FullName -Service 's' -ServiceInstances 'i'
            $obj.ID | Should -Be '777'
        }
    }

    Context 'When piping multiple rows' {
        BeforeAll {
            $script:pipeDir = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString()))
            $script:rows = @(
                [PSCustomObject]@{ Subject = 'Article One'; Description = 'desc1'; Instructions = 'inst1'; Keywords = 'kw1' },
                [PSCustomObject]@{ Subject = 'Article Two'; Description = 'desc2'; Instructions = 'inst2'; Keywords = 'kw2' }
            )
        }

        AfterAll {
            Remove-Item -Path $script:pipeDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Should return one FileInfo per row' {
            $results = $script:rows | ConvertFrom-XurrentKnowledgeArticle -Path $script:pipeDir.FullName
            $results.Count | Should -Be 2
        }
    }

    Context 'When using -WhatIf' {
        BeforeAll {
            $script:whatIfDir = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString()))
        }

        AfterAll {
            Remove-Item -Path $script:whatIfDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Should support the WhatIf parameter' {
            (Get-Command -Name 'ConvertFrom-XurrentKnowledgeArticle').Parameters.ContainsKey('WhatIf') | Should -Be $true
        }

        It 'Should not create the file with -WhatIf' {
            ConvertFrom-XurrentKnowledgeArticle -InputObject $script:row -Path $script:whatIfDir.FullName -WhatIf
            (Get-ChildItem $script:whatIfDir.FullName).Count | Should -Be 0
        }
    }
}
