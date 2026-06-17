BeforeAll {
    $script:moduleName = 'XurrentHelpers'
    Import-Module -Name $script:moduleName

    $script:tempDir = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString()))

    $script:csvPath = Join-Path $script:tempDir.FullName 'import-test.csv'
    @(
        [PSCustomObject]@{
            ID = '1'; Source = '4me'; 'Source ID' = ''; Status = 'published'
            Service = 'my service'; 'Service Instances' = 'my instance'
            Subject = 'First Article'; Description = 'First description here.'
            Instructions = 'First step instructions.'; Keywords = 'first, article'; Template = ''
        },
        [PSCustomObject]@{
            ID = '2'; Source = '4me'; 'Source ID' = ''; Status = 'published'
            Service = 'my service'; 'Service Instances' = 'my instance'
            Subject = 'Second Article'; Description = 'Second description here.'
            Instructions = 'Second step instructions.'; Keywords = 'second, article'; Template = ''
        }
    ) | Export-Csv -Path $script:csvPath -NoTypeInformation -Encoding UTF8
}

AfterAll {
    Get-Module -Name $script:moduleName -All | Remove-Module -Force
    Remove-Item -Path $script:tempDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Import-XurrentKnowledgeArticle' {
    Context 'When the CSV contains rows' {
        BeforeAll {
            $script:outputDir = New-Item -ItemType Directory -Path (Join-Path $script:tempDir.FullName 'output')
            Import-XurrentKnowledgeArticle -CsvPath $script:csvPath -OutputFolder $script:outputDir.FullName
        }

        It 'Should not throw' {
            { Import-XurrentKnowledgeArticle -CsvPath $script:csvPath -OutputFolder $script:outputDir.FullName } | Should -Not -Throw
        }

        It 'Should create one Markdown file per row' {
            (Get-ChildItem $script:outputDir.FullName -Filter '*.md').Count | Should -BeGreaterOrEqual 2
        }

        It 'Should return FileInfo objects' {
            $results = Import-XurrentKnowledgeArticle -CsvPath $script:csvPath -OutputFolder $script:outputDir.FullName
            $results | ForEach-Object { $_ | Should -BeOfType [System.IO.FileInfo] }
        }

        It 'Should write the correct Subject as H1 in the first article' {
            $file = Get-ChildItem $script:outputDir.FullName -Filter 'First Article*'
            $content = Get-Content $file.FullName -Raw
            $content | Should -Match '(?m)^# First Article'
        }

        It 'Should write the correct Subject as H1 in the second article' {
            $file = Get-ChildItem $script:outputDir.FullName -Filter 'Second Article*'
            $content = Get-Content $file.FullName -Raw
            $content | Should -Match '(?m)^# Second Article'
        }

        It 'Should write the ID from the CSV as an **ID:** line in the first article' {
            $file = Get-ChildItem $script:outputDir.FullName -Filter 'First Article*'
            $content = Get-Content $file.FullName -Raw
            $content | Should -Match '(?m)^\*\*ID:\*\* 1\s*$'
        }

        It 'Should write the ID from the CSV as an **ID:** line in the second article' {
            $file = Get-ChildItem $script:outputDir.FullName -Filter 'Second Article*'
            $content = Get-Content $file.FullName -Raw
            $content | Should -Match '(?m)^\*\*ID:\*\* 2\s*$'
        }
    }

    Context 'When the CSV has no data rows' {
        BeforeAll {
            $script:emptyCsv = Join-Path $script:tempDir.FullName 'empty.csv'
            Set-Content -Path $script:emptyCsv -Value '"Subject","Description","Instructions","Keywords"' -Encoding UTF8
            $script:emptyDir = New-Item -ItemType Directory -Path (Join-Path $script:tempDir.FullName 'empty')
        }

        It 'Should not throw' {
            { Import-XurrentKnowledgeArticle -CsvPath $script:emptyCsv -OutputFolder $script:emptyDir.FullName -WarningAction SilentlyContinue } | Should -Not -Throw
        }

        It 'Should not create any files' {
            Import-XurrentKnowledgeArticle -CsvPath $script:emptyCsv -OutputFolder $script:emptyDir.FullName -WarningAction SilentlyContinue
            (Get-ChildItem $script:emptyDir.FullName).Count | Should -Be 0
        }

        It 'Should emit a warning' {
            { Import-XurrentKnowledgeArticle -CsvPath $script:emptyCsv -OutputFolder $script:emptyDir.FullName -WarningAction Stop } | Should -Throw
        }
    }

    Context 'When -WhatIf is passed' {
        BeforeAll {
            $script:whatIfDir = New-Item -ItemType Directory -Path (Join-Path $script:tempDir.FullName 'whatif')
        }

        It 'Should not create any files' {
            Import-XurrentKnowledgeArticle -CsvPath $script:csvPath -OutputFolder $script:whatIfDir.FullName -WhatIf
            (Get-ChildItem $script:whatIfDir.FullName).Count | Should -Be 0
        }
    }
}
