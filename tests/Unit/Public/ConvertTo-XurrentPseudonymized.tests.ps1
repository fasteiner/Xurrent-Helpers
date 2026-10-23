BeforeAll {
    $script:dscModuleName = 'XurrentHelpers'
    Import-Module -Name $script:dscModuleName

    # Synthetic export: names, addresses and IPs are invented (192.0.2.0/24 is a documentation
    # range). Note is not pseudonymized and holds a multi-line value and quotes.
    $script:header = '"Number","Subject","Requested by","Requested for","Requested by email","Organization","IP address","Note"'
    $script:standardLines = @(
        $script:header
        "`"1001`",`"Printer broken`",`"Ada Example`",`"Ben Sample`",`"ada@example.com`",`"Org Alpha`",`"192.0.2.10`",`"Line one`r`nline two`""
        '"1002","VPN down","Ben Sample","Ada Example","ben@example.com","Org Beta","192.0.2.11","Short"'
        '"1003","Mail issue","Ada Example","","ada@example.com","Org Alpha","","Says ""hello"", twice"'
    )
    $script:types = @{ 'Requested by' = 'Name'; 'Requested for' = 'Name'; 'Requested by email' = 'Email'; 'IP address' = 'IP' }

    # Writes the lines (CRLF-separated) into a file below TestDrive and returns the file.
    # A new folder is used unless -Folder is given, so default output names never collide.
    function New-CsvFixture
    {
        param
        (
            [string[]] $Line = $script:standardLines,
            [string] $Name = 'export.csv',
            [string] $Folder = (Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())),
            [switch] $Bom
        )

        if (-not (Test-Path -LiteralPath $Folder))
        {
            $null = New-Item -ItemType Directory -Path $Folder
        }

        $filePath = Join-Path $Folder $Name
        $text = if ($Line) { ($Line -join "`r`n") + "`r`n" } else { '' }
        [System.IO.File]::WriteAllText($filePath, $text, [System.Text.UTF8Encoding]::new([bool]$Bom))
        Get-Item -LiteralPath $filePath
    }

    function Get-FileHashString
    {
        param ([string] $Path)
        [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Path))
    }

    function Test-Utf8Bom
    {
        param ([string] $Path)
        $bytes = [System.IO.File]::ReadAllBytes($Path)
        $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    }
}

AfterAll {
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe 'ConvertTo-XurrentPseudonymized' {
    Context 'When a file is pseudonymized with the default paths' {
        BeforeAll {
            $script:file = New-CsvFixture
            $script:originalBytes = Get-FileHashString -Path $script:file.FullName
            $script:result = ConvertTo-XurrentPseudonymized -Path $script:file.FullName -Column 'Organization' -ColumnType $script:types
            $script:outputFile = Join-Path $script:file.DirectoryName 'export.pseudonymized.csv'
            $script:mappingFile = Join-Path $script:file.DirectoryName 'pseudonymization.mapping.csv'
            $script:rows = @(Import-Csv -LiteralPath $script:outputFile -Encoding UTF8)
            $script:mapping = @(Import-Csv -LiteralPath $script:mappingFile -Encoding UTF8)
        }

        It 'Should return one result per file with the paths, counts and status' {
            $script:result.Path | Should -BeExactly $script:file.FullName
            $script:result.OutputPath | Should -BeExactly $script:outputFile
            $script:result.MappingPath | Should -BeExactly $script:mappingFile
            $script:result.Rows | Should -Be 3
            $script:result.Replaced | Should -Be 13
            $script:result.Status | Should -BeExactly 'Pseudonymized'
        }

        It 'Should leave the original file unchanged' {
            Get-FileHashString -Path $script:file.FullName | Should -BeExactly $script:originalBytes
        }

        It 'Should use the placeholder format of each column type' {
            $script:rows[0].'Requested by' | Should -BeExactly 'Person-001'
            $script:rows[0].'Requested for' | Should -BeExactly 'Person-002'
            $script:rows[0].'Requested by email' | Should -BeExactly 'user001@example.invalid'
            $script:rows[0].Organization | Should -BeExactly 'Text-001'
            $script:rows[0].'IP address' | Should -BeExactly '198.18.0.1'
            $script:rows[1].'IP address' | Should -BeExactly '198.18.0.2'
        }

        It 'Should give the same value the same placeholder in every row and column' {
            $script:rows[1].'Requested by' | Should -BeExactly 'Person-002'
            $script:rows[1].'Requested for' | Should -BeExactly 'Person-001'
            $script:rows[2].'Requested by' | Should -BeExactly 'Person-001'
            $script:rows[2].'Requested by email' | Should -BeExactly 'user001@example.invalid'
            $script:rows[2].Organization | Should -BeExactly 'Text-001'
            $script:rows[1].Organization | Should -BeExactly 'Text-002'
        }

        It 'Should keep empty values empty' {
            $script:rows[2].'Requested for' | Should -BeExactly ''
            $script:rows[2].'IP address' | Should -BeExactly ''
        }

        It 'Should keep the column order and the values of all other columns, including multi-line fields' {
            ([System.IO.File]::ReadAllLines($script:outputFile))[0] | Should -BeExactly $script:header
            $script:rows.Number | Should -Be @('1001', '1002', '1003')
            $script:rows.Subject | Should -Be @('Printer broken', 'VPN down', 'Mail issue')
            $script:rows[0].Note | Should -BeExactly "Line one`r`nline two"
            $script:rows[2].Note | Should -BeExactly 'Says "hello", twice'
        }

        It 'Should write the mapping with placeholder, type and real value in the order of creation' {
            $script:mapping.Placeholder | Should -Be @('Person-001', 'Person-002', 'user001@example.invalid', 'Text-001', '198.18.0.1', 'user002@example.invalid', 'Text-002', '198.18.0.2')
            $script:mapping.Type | Should -Be @('Name', 'Name', 'Email', 'Text', 'IP', 'Email', 'Text', 'IP')
            $script:mapping.Value | Should -Be @('Ada Example', 'Ben Sample', 'ada@example.com', 'Org Alpha', '192.0.2.10', 'ben@example.com', 'Org Beta', '192.0.2.11')
        }

        It 'Should write the output and the mapping as UTF-8 without BOM' {
            Test-Utf8Bom -Path $script:outputFile | Should -BeFalse
            Test-Utf8Bom -Path $script:mappingFile | Should -BeFalse
        }

        It 'Should not leave a temporary mapping file behind' {
            Test-Path -LiteralPath "$script:mappingFile.tmp" | Should -BeFalse
        }
    }

    Context 'When the input has a BOM and non-ASCII values' {
        BeforeAll {
            $script:name = "J$([char]0x00FC)rgen Beispiel"
            $script:file = New-CsvFixture -Bom -Line @('"Name","City"', "`"$script:name`",`"Graz`"")
            $script:result = ConvertTo-XurrentPseudonymized -Path $script:file.FullName -ColumnType @{ Name = 'Name' }
            $script:mapping = @(Import-Csv -LiteralPath $script:result.MappingPath -Encoding UTF8)
        }

        It 'Should read the first column name without the BOM' {
            ([System.IO.File]::ReadAllLines($script:result.OutputPath))[0] | Should -BeExactly '"Name","City"'
            Test-Utf8Bom -Path $script:result.OutputPath | Should -BeFalse
        }

        It 'Should keep non-ASCII values intact in the mapping' {
            $script:mapping[0].Value | Should -BeExactly $script:name
        }
    }

    Context 'When several files are pseudonymized in one call' {
        BeforeAll {
            $script:folder = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
            $null = New-CsvFixture -Folder $script:folder -Name 'a.csv'
            $null = New-CsvFixture -Folder $script:folder -Name 'b.csv' -Line @('"Requested by","Requested by email"', '"Cleo Test","cleo@example.com"', '"Ada Example","ada@example.com"')
            $script:result = @(Get-ChildItem -LiteralPath $script:folder -Filter '*.csv' | Sort-Object -Property Name | ConvertTo-XurrentPseudonymized -ColumnType $script:types -WarningAction SilentlyContinue)
            $script:second = @(Import-Csv -LiteralPath (Join-Path $script:folder 'b.pseudonymized.csv') -Encoding UTF8)
            $script:mapping = @(Import-Csv -LiteralPath (Join-Path $script:folder 'pseudonymization.mapping.csv') -Encoding UTF8)
        }

        It 'Should accept FileInfo objects from the pipeline and return one result per file' {
            $script:result.Count | Should -Be 2
            $script:result.Status | Should -Be @('Pseudonymized', 'Pseudonymized')
        }

        It 'Should give the same value the same placeholder across files' {
            $script:second[1].'Requested by' | Should -BeExactly 'Person-001'
            $script:second[1].'Requested by email' | Should -BeExactly 'user001@example.invalid'
            $script:second[0].'Requested by' | Should -BeExactly 'Person-003'
        }

        It 'Should write one shared mapping and warn about columns a file does not have' {
            @($script:result.MappingPath | Select-Object -Unique).Count | Should -Be 1
            $script:mapping.Value | Should -Contain 'Cleo Test'
            $null = New-CsvFixture -Folder $script:folder -Name 'c.csv' -Line @('"Requested by"', '"Ada Example"')
            $null = ConvertTo-XurrentPseudonymized -Path (Join-Path $script:folder 'c.csv') -ColumnType $script:types -WarningVariable warnings -WarningAction SilentlyContinue
            $warnings.Count | Should -Be 3
            $warnings[0] | Should -Match "^Column '.+' not found in "
        }
    }

    Context 'When an existing mapping file is passed' {
        BeforeAll {
            $script:folder = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
            $script:mappingFile = Join-Path $script:folder 'shared.mapping.csv'
            $first = New-CsvFixture -Folder $script:folder -Name 'first.csv'
            $null = ConvertTo-XurrentPseudonymized -Path $first.FullName -ColumnType $script:types -MappingPath $script:mappingFile
            $script:linesAfterFirstRun = [System.IO.File]::ReadAllLines($script:mappingFile)

            $second = New-CsvFixture -Folder $script:folder -Name 'second.csv' -Line @('"Requested by","IP address"', '"Cleo Test","192.0.2.99"', '"Ben Sample","192.0.2.10"')
            $script:result = ConvertTo-XurrentPseudonymized -Path $second.FullName -ColumnType $script:types -MappingPath $script:mappingFile -WarningAction SilentlyContinue
            $script:rows = @(Import-Csv -LiteralPath $script:result.OutputPath -Encoding UTF8)
            $script:linesAfterSecondRun = [System.IO.File]::ReadAllLines($script:mappingFile)
        }

        It 'Should keep all existing entries and append the new ones' {
            $script:linesAfterSecondRun.Count | Should -Be ($script:linesAfterFirstRun.Count + 2)
            $script:linesAfterSecondRun[0..($script:linesAfterFirstRun.Count - 1)] | Should -Be $script:linesAfterFirstRun
        }

        It 'Should reuse the existing placeholders and continue the numbering' {
            $script:rows[1].'Requested by' | Should -BeExactly 'Person-002'
            $script:rows[1].'IP address' | Should -BeExactly '198.18.0.1'
            $script:rows[0].'Requested by' | Should -BeExactly 'Person-003'
            $script:rows[0].'IP address' | Should -BeExactly '198.18.0.3'
        }

        It 'Should skip numbers that are already taken in the mapping' {
            $mappingFile = Join-Path $script:folder 'gap.mapping.csv'
            [System.IO.File]::WriteAllLines($mappingFile, @('"Placeholder","Type","Value"', '"Person-002","Name","Dora Demo"'))
            $file = New-CsvFixture -Folder $script:folder -Name 'gap.csv' -Line @('"Requested by"', '"Eve Example"', '"Finn Fake"', '"Dora Demo"')
            $result = ConvertTo-XurrentPseudonymized -Path $file.FullName -ColumnType @{ 'Requested by' = 'Name' } -MappingPath $mappingFile
            (Import-Csv -LiteralPath $result.OutputPath -Encoding UTF8).'Requested by' | Should -Be @('Person-001', 'Person-003', 'Person-002')
        }

        It 'Should give a value that looks like a placeholder its own placeholder' {
            $file = New-CsvFixture -Line @('"Organization"', '"Org Alpha"', '"Text-001"')
            $result = ConvertTo-XurrentPseudonymized -Path $file.FullName -Column 'Organization'
            (Import-Csv -LiteralPath $result.OutputPath -Encoding UTF8).Organization | Should -Be @('Text-001', 'Text-002')
            (Import-Csv -LiteralPath $result.MappingPath -Encoding UTF8)[1].Value | Should -BeExactly 'Text-001'
        }

        It 'Should reject a file that is not a mapping' {
            $file = New-CsvFixture
            { ConvertTo-XurrentPseudonymized -Path $file.FullName -Column 'Subject' -MappingPath $file.FullName -OutputPath (Join-Path $file.DirectoryName 'out.csv') } |
                Should -Throw '*must not be an input or output file*'
            $other = New-CsvFixture -Folder $file.DirectoryName -Name 'other.csv'
            { ConvertTo-XurrentPseudonymized -Path $file.FullName -Column 'Subject' -MappingPath $other.FullName } |
                Should -Throw '*Not a pseudonymization mapping file*'
        }
    }

    Context 'When a column is named twice or in a different case' {
        It 'Should replace its values once' {
            $file = New-CsvFixture
            $result = ConvertTo-XurrentPseudonymized -Path $file.FullName -Column 'requested by' -ColumnType @{ 'REQUESTED BY' = 'Name' }
            (Import-Csv -LiteralPath $result.OutputPath -Encoding UTF8)[0].'Requested by' | Should -BeExactly 'Person-001'
            (Import-Csv -LiteralPath $result.MappingPath -Encoding UTF8).Value | Should -Be @('Ada Example', 'Ben Sample')
        }

        It 'Should accept the type name in any case' {
            $file = New-CsvFixture
            $result = ConvertTo-XurrentPseudonymized -Path $file.FullName -ColumnType @{ 'Requested by email' = 'email' }
            (Import-Csv -LiteralPath $result.MappingPath -Encoding UTF8)[0].Type | Should -BeExactly 'Email'
        }
    }

    Context 'When -WhatIf is used' {
        BeforeAll {
            $script:file = New-CsvFixture
            $script:result = ConvertTo-XurrentPseudonymized -Path $script:file.FullName -ColumnType $script:types -WhatIf
        }

        It 'Should not write the output or the mapping' {
            Test-Path -LiteralPath (Join-Path $script:file.DirectoryName 'export.pseudonymized.csv') | Should -BeFalse
            Test-Path -LiteralPath (Join-Path $script:file.DirectoryName 'pseudonymization.mapping.csv') | Should -BeFalse
        }

        It 'Should report the file as skipped' {
            $script:result.Status | Should -BeExactly 'Skipped'
            $script:result.Replaced | Should -Be 10
        }
    }

    Context 'When -OutputPath is given' {
        It 'Should create a missing output folder that ends with a separator' {
            $file = New-CsvFixture
            $folder = Join-Path $file.DirectoryName 'out'
            $result = ConvertTo-XurrentPseudonymized -Path $file.FullName -Column 'Subject' -OutputPath ($folder + [System.IO.Path]::DirectorySeparatorChar)
            $result.OutputPath | Should -BeExactly (Join-Path $folder 'export.pseudonymized.csv')
            Test-Path -LiteralPath $result.OutputPath | Should -BeTrue
            $result.MappingPath | Should -BeExactly (Join-Path $folder 'pseudonymization.mapping.csv')
        }

        It 'Should write to a file path for a single input, resolved against the current location' {
            $file = New-CsvFixture
            Push-Location -LiteralPath $file.DirectoryName
            try
            {
                $result = ConvertTo-XurrentPseudonymized -Path 'export.csv' -Column 'Subject' -OutputPath 'renamed.csv'
            }
            finally
            {
                Pop-Location
            }
            $result.OutputPath | Should -BeExactly (Join-Path $file.DirectoryName 'renamed.csv')
            (Import-Csv -LiteralPath $result.OutputPath -Encoding UTF8)[0].Subject | Should -BeExactly 'Text-001'
        }

        It 'Should reject a file path for more than one input file' {
            $first = New-CsvFixture
            $second = New-CsvFixture -Folder $first.DirectoryName -Name 'second.csv'
            { ConvertTo-XurrentPseudonymized -Path $first.FullName, $second.FullName -Column 'Subject' -OutputPath (Join-Path $first.DirectoryName 'out.csv') } |
                Should -Throw '*more than one input file*'
        }

        It 'Should reject the input file as output file' {
            $file = New-CsvFixture
            { ConvertTo-XurrentPseudonymized -Path $file.FullName -Column 'Subject' -OutputPath $file.FullName } | Should -Throw '*must not be the input file*'
        }
    }

    Context 'When the input is incomplete or invalid' {
        It 'Should throw when no column is named' {
            $file = New-CsvFixture
            { ConvertTo-XurrentPseudonymized -Path $file.FullName } | Should -Throw '*-Column or -ColumnType*'
        }

        It 'Should throw for an unknown column type' {
            $file = New-CsvFixture
            { ConvertTo-XurrentPseudonymized -Path $file.FullName -ColumnType @{ Subject = 'Phone' } } | Should -Throw "*Unknown ColumnType 'Phone'*"
        }

        It 'Should warn about a missing file and write nothing' {
            $missing = Join-Path $TestDrive 'missing.csv'
            $result = ConvertTo-XurrentPseudonymized -Path $missing -Column 'Subject' -WarningVariable warnings -WarningAction SilentlyContinue
            $result | Should -BeNullOrEmpty
            $warnings[0] | Should -Match 'File not found'
        }

        It 'Should warn about a file without rows and not write it' {
            $file = New-CsvFixture -Line @($script:header)
            $result = ConvertTo-XurrentPseudonymized -Path $file.FullName -Column 'Subject' -WarningVariable warnings -WarningAction SilentlyContinue
            $result.Status | Should -BeExactly 'NoRows'
            $result.Rows | Should -Be 0
            $warnings[0] | Should -Match 'No rows'
            Test-Path -LiteralPath $result.OutputPath | Should -BeFalse
            Test-Path -LiteralPath $result.MappingPath | Should -BeFalse
        }
    }
}
