BeforeAll {
    $script:dscModuleName = 'XurrentHelpers'
    Import-Module -Name $script:dscModuleName

    function New-MappingFile
    {
        param ([string[]] $Line)
        $filePath = Join-Path $TestDrive "$([System.Guid]::NewGuid()).mapping.csv"
        [System.IO.File]::WriteAllText($filePath, (($Line -join "`r`n") + "`r`n"), [System.Text.UTF8Encoding]::new($false))
        $filePath
    }

    function Invoke-ImportPseudonymMapping
    {
        param ([string] $Path)
        & (Get-Module $script:dscModuleName) { Import-PseudonymMapping -Path $args[0] } $Path
    }
}

AfterAll {
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe 'Import-PseudonymMapping' {
    It 'Should return empty lookups for a missing file' {
        $result = Invoke-ImportPseudonymMapping -Path (Join-Path $TestDrive 'missing.mapping.csv')
        $result.Entries.Count | Should -Be 0
        $result.ByValue.Count | Should -Be 0
        $result.ByPlaceholder.Count | Should -Be 0
    }

    It 'Should return empty lookups for a file with only the header' {
        $result = Invoke-ImportPseudonymMapping -Path (New-MappingFile -Line '"Placeholder","Type","Value"')
        $result.Entries.Count | Should -Be 0
    }

    Context 'When the file has entries' {
        BeforeAll {
            $script:result = Invoke-ImportPseudonymMapping -Path (New-MappingFile -Line @(
                    '"Placeholder","Type","Value"'
                    '"Person-001","Name","Ada Example"'
                    '"Person-002","Name","ada example"'
                    '"","Name","Skipped"'
                    '"Text-001","Text","Ada Example"'
                ))
        }

        It 'Should return the entries in file order and skip rows without a placeholder' {
            $script:result.Entries.Placeholder | Should -Be @('Person-001', 'Person-002', 'Text-001')
            $script:result.Entries[0].Type | Should -BeExactly 'Name'
        }

        It 'Should look up values case-sensitively' {
            $script:result.ByValue['Ada Example'] | Should -BeExactly 'Person-001'
            $script:result.ByValue['ada example'] | Should -BeExactly 'Person-002'
            $script:result.ByPlaceholder.ContainsKey('person-001') | Should -BeFalse
        }

        It 'Should keep the first placeholder for a value and restore every placeholder' {
            $script:result.ByPlaceholder['Text-001'] | Should -BeExactly 'Ada Example'
            $script:result.ByValue.Count | Should -Be 2
        }
    }

    It 'Should reject a file without the mapping columns' {
        $path = New-MappingFile -Line @('"Name","City"', '"Ada Example","Graz"')
        { Invoke-ImportPseudonymMapping -Path $path } | Should -Throw '*Not a pseudonymization mapping file*'
    }

    It 'Should reject a placeholder that is listed twice, without naming the real values' {
        $path = New-MappingFile -Line @('"Placeholder","Type","Value"', '"Person-001","Name","Ada Example"', '"Person-001","Name","Ben Sample"')
        { Invoke-ImportPseudonymMapping -Path $path } | Should -Throw "*Placeholder 'Person-001' is listed more than once*"
        try { Invoke-ImportPseudonymMapping -Path $path } catch { $_.Exception.Message | Should -Not -Match 'Ada|Ben' }
    }
}
