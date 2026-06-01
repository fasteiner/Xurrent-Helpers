BeforeAll {
    $script:dscModuleName = 'XurrentHelpers'
    Import-Module -Name $script:dscModuleName

    $script:outputCsv = Join-Path ([System.IO.Path]::GetTempPath()) "$([System.Guid]::NewGuid())-example.csv"
}

AfterAll {
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
    Remove-Item -Path $script:outputCsv -Force -ErrorAction SilentlyContinue
}

Describe 'New-XurrentKnowledgeArticleCsvExample' {
    Context 'When creating the example CSV' {
        BeforeAll {
            $script:result = New-XurrentKnowledgeArticleCsvExample -OutputPath $script:outputCsv
        }

        It 'Should not throw' {
            $path = Join-Path ([System.IO.Path]::GetTempPath()) "$([System.Guid]::NewGuid())-nothrow.csv"
            { New-XurrentKnowledgeArticleCsvExample -OutputPath $path } | Should -Not -Throw
            Remove-Item $path -Force -ErrorAction SilentlyContinue
        }

        It 'Should return a FileInfo object' {
            $script:result | Should -BeOfType [System.IO.FileInfo]
        }

        It 'Should create the file on disk' {
            Test-Path $script:outputCsv | Should -Be $true
        }

        It 'Should write exactly one data row' {
            $rows = Import-Csv -Path $script:outputCsv
            $rows.Count | Should -Be 1
        }

        It 'Should include all required columns' {
            $rows = Import-Csv -Path $script:outputCsv
            $columns = $rows[0].PSObject.Properties.Name
            $columns | Should -Contain 'ID'
            $columns | Should -Contain 'Source'
            $columns | Should -Contain 'Source ID'
            $columns | Should -Contain 'Status'
            $columns | Should -Contain 'Service'
            $columns | Should -Contain 'Service Instances'
            $columns | Should -Contain 'Subject'
            $columns | Should -Contain 'Description'
            $columns | Should -Contain 'Instructions'
            $columns | Should -Contain 'Keywords'
            $columns | Should -Contain 'Template'
        }

        It 'Should set Source to 4me' {
            $rows = Import-Csv -Path $script:outputCsv
            $rows[0].Source | Should -Be '4me'
        }

        It 'Should set Status to work_in_progress' {
            $rows = Import-Csv -Path $script:outputCsv
            $rows[0].Status | Should -Be 'work_in_progress'
        }
    }

    Context 'When using -WhatIf' {
        BeforeAll {
            $script:whatIfCsv = Join-Path ([System.IO.Path]::GetTempPath()) "$([System.Guid]::NewGuid())-whatif.csv"
        }

        AfterAll {
            Remove-Item $script:whatIfCsv -Force -ErrorAction SilentlyContinue
        }

        It 'Should support the WhatIf parameter' {
            (Get-Command -Name 'New-XurrentKnowledgeArticleCsvExample').Parameters.ContainsKey('WhatIf') | Should -Be $true
        }

        It 'Should not create the file with -WhatIf' {
            New-XurrentKnowledgeArticleCsvExample -OutputPath $script:whatIfCsv -WhatIf
            Test-Path $script:whatIfCsv | Should -Be $false
        }
    }
}
