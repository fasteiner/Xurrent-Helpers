BeforeAll {
    $script:dscModuleName = 'XurrentHelpers'
    Import-Module -Name $script:dscModuleName

    # Synthetic mapping as written by ConvertTo-XurrentPseudonymized.
    $script:mappingLines = @(
        '"Placeholder","Type","Value"'
        '"Person-001","Name","Ada Example"'
        '"Person-002","Name","Ben Sample"'
        '"user001@example.invalid","Email","ada@example.com"'
        '"198.18.0.1","IP","192.0.2.10"'
    )

    # Writes the text into a file below a new TestDrive folder and returns the file.
    function New-TextFixture
    {
        param
        (
            [string] $Text,
            [string] $Name,
            [string] $Folder = (Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())),
            [switch] $Bom
        )

        if (-not (Test-Path -LiteralPath $Folder))
        {
            $null = New-Item -ItemType Directory -Path $Folder
        }

        $filePath = Join-Path $Folder $Name
        [System.IO.File]::WriteAllText($filePath, $Text, [System.Text.UTF8Encoding]::new([bool]$Bom))
        Get-Item -LiteralPath $filePath
    }

    function New-MappingFixture
    {
        param ([string] $Folder = (Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())))
        New-TextFixture -Text (($script:mappingLines -join "`r`n") + "`r`n") -Name 'pseudonymization.mapping.csv' -Folder $Folder
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

Describe 'ConvertFrom-XurrentPseudonymized' {
    Context 'When a pseudonymized CSV export is restored' {
        BeforeAll {
            # Values with commas, quotes, line breaks and a value that looks like a placeholder,
            # in pseudonymized columns, to prove the round trip keeps the CSV valid.
            $lines = @(
                '"Number","Requested by","Organization","Note"'
                '"1","Example, Ada ""AE""","Org Alpha","Asked twice"'
                "`"2`",`"Ben Sample`",`"Org`r`nBeta`",`"Line one`r`nline two`""
                '"3","Example, Ada ""AE""","Text-001",""'
            )
            $script:file = New-TextFixture -Text (($lines -join "`r`n") + "`r`n") -Name 'export.csv'
            $script:original = @(Import-Csv -LiteralPath $script:file.FullName -Encoding UTF8)
            $pseudonymized = ConvertTo-XurrentPseudonymized -Path $script:file.FullName -Column 'Organization' -ColumnType @{ 'Requested by' = 'Name' }
            $script:pseudonymizedBytes = [System.IO.File]::ReadAllBytes($pseudonymized.OutputPath)
            $script:result = ConvertFrom-XurrentPseudonymized -Path $pseudonymized.OutputPath -MappingPath $pseudonymized.MappingPath
            $script:restored = @(Import-Csv -LiteralPath $script:result.OutputPath -Encoding UTF8)
            $script:pseudonymizedPath = $pseudonymized.OutputPath
        }

        It 'Should write <name>.restored.csv next to the input and report the replacements' {
            $script:result.OutputPath | Should -BeExactly (Join-Path $script:file.DirectoryName 'export.restored.csv')
            $script:result.Replaced | Should -Be 6
            $script:result.Status | Should -BeExactly 'Restored'
        }

        It 'Should restore every value of the original export' {
            $script:restored.Count | Should -Be $script:original.Count
            for ($i = 0; $i -lt $script:original.Count; $i++)
            {
                foreach ($property in $script:original[$i].PSObject.Properties)
                {
                    $script:restored[$i].($property.Name) | Should -BeExactly $property.Value
                }
            }
        }

        It 'Should keep the column order' {
            ([System.IO.File]::ReadAllLines($script:result.OutputPath))[0] | Should -BeExactly '"Number","Requested by","Organization","Note"'
        }

        It 'Should leave the pseudonymized file unchanged and write UTF-8 without BOM' {
            [System.IO.File]::ReadAllBytes($script:pseudonymizedPath) | Should -Be $script:pseudonymizedBytes
            Test-Utf8Bom -Path $script:result.OutputPath | Should -BeFalse
        }
    }

    Context 'When text is restored' {
        BeforeAll {
            $script:mappingFile = (New-MappingFixture).FullName
        }

        It 'Should replace placeholders inside sentences, also at the end of a sentence' {
            'Person-001 asked Person-002 about 198.18.0.1.' | ConvertFrom-XurrentPseudonymized -MappingPath $script:mappingFile |
                Should -BeExactly 'Ada Example asked Ben Sample about 192.0.2.10.'
        }

        It 'Should replace e-mail placeholders, also in angle brackets' {
            ConvertFrom-XurrentPseudonymized -Text 'Mail <user001@example.invalid>, cc user001@example.invalid' -MappingPath $script:mappingFile |
                Should -BeExactly 'Mail <ada@example.com>, cc ada@example.com'
        }

        It 'Should only replace whole placeholders' {
            $text = 'Person-0010 XPerson-001 Person-001a 198.18.0.10 198.18.0.1.5 user001@example.invalid.com'
            ConvertFrom-XurrentPseudonymized -Text $text -MappingPath $script:mappingFile | Should -BeExactly $text
        }

        It 'Should leave unknown placeholders and empty lines unchanged' {
            $result = @('Person-999 and Person-001', '') | ConvertFrom-XurrentPseudonymized -MappingPath $script:mappingFile
            $result | Should -Be @('Person-999 and Ada Example', '')
        }

        It 'Should not replace a restored value again' {
            $mapping = New-TextFixture -Name 'chain.mapping.csv' -Text "`"Placeholder`",`"Type`",`"Value`"`r`n`"Text-001`",`"Text`",`"Text-002`"`r`n`"Text-002`",`"Text`",`"Org Beta`"`r`n"
            ConvertFrom-XurrentPseudonymized -Text 'Text-001 / Text-002' -MappingPath $mapping.FullName | Should -BeExactly 'Text-002 / Org Beta'
        }

        It 'Should return the text unchanged for an empty mapping' {
            $mapping = New-TextFixture -Name 'empty.mapping.csv' -Text "`"Placeholder`",`"Type`",`"Value`"`r`n"
            ConvertFrom-XurrentPseudonymized -Text 'Person-001' -MappingPath $mapping.FullName | Should -BeExactly 'Person-001'
        }
    }

    Context 'When a non-CSV file is restored' {
        BeforeAll {
            $script:folder = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
            $mapping = New-MappingFixture -Folder $script:folder
            $script:file = New-TextFixture -Bom -Folder $script:folder -Name 'analysis.pseudonymized.md' -Text "# Result`r`n`r`n- Person-001: 3 requests`r`n- Person-002: 1 request`r`n"
            $script:result = ConvertFrom-XurrentPseudonymized -Path $script:file.FullName -MappingPath $mapping.FullName
            $script:text = [System.IO.File]::ReadAllText($script:result.OutputPath)
        }

        It 'Should replace .pseudonymized with .restored in the file name' {
            $script:result.OutputPath | Should -BeExactly (Join-Path $script:folder 'analysis.restored.md')
        }

        It 'Should restore the text and keep the line endings' {
            $script:text | Should -BeExactly "# Result`r`n`r`n- Ada Example: 3 requests`r`n- Ben Sample: 1 request`r`n"
            $script:result.Replaced | Should -Be 2
        }

        It 'Should drop the BOM of the input' {
            Test-Utf8Bom -Path $script:result.OutputPath | Should -BeFalse
        }

        It 'Should restore a CSV file without rows as text' {
            $file = New-TextFixture -Folder $script:folder -Name 'header.csv' -Text "`"Person-001`"`r`n"
            $result = ConvertFrom-XurrentPseudonymized -Path $file.FullName -MappingPath (Join-Path $script:folder 'pseudonymization.mapping.csv')
            [System.IO.File]::ReadAllText($result.OutputPath) | Should -BeExactly "`"Ada Example`"`r`n"
            $result.OutputPath | Should -BeExactly (Join-Path $script:folder 'header.restored.csv')
        }
    }

    Context 'When files come from the pipeline or -OutputPath is given' {
        BeforeAll {
            $script:folder = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
            $script:mappingFile = (New-MappingFixture -Folder (Join-Path $TestDrive ([System.Guid]::NewGuid().ToString()))).FullName
            $null = New-TextFixture -Folder $script:folder -Name 'a.txt' -Text 'Person-001'
            $null = New-TextFixture -Folder $script:folder -Name 'b.txt' -Text 'Person-002'
        }

        It 'Should bind FileInfo objects from Get-ChildItem to -Path' {
            $result = @(Get-ChildItem -LiteralPath $script:folder -Filter '*.txt' | Sort-Object -Property Name | ConvertFrom-XurrentPseudonymized -MappingPath $script:mappingFile)
            $result.Count | Should -Be 2
            [System.IO.File]::ReadAllText($result[1].OutputPath) | Should -BeExactly 'Ben Sample'
        }

        It 'Should write into an output folder that ends with a separator' {
            $outFolder = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
            $result = ConvertFrom-XurrentPseudonymized -Path (Join-Path $script:folder 'a.txt') -MappingPath $script:mappingFile -OutputPath ($outFolder + [System.IO.Path]::DirectorySeparatorChar)
            $result.OutputPath | Should -BeExactly (Join-Path $outFolder 'a.restored.txt')
            [System.IO.File]::ReadAllText($result.OutputPath) | Should -BeExactly 'Ada Example'
        }

        It 'Should write to a file path for a single input' {
            $target = Join-Path $script:folder 'named.txt'
            $result = ConvertFrom-XurrentPseudonymized -Path (Join-Path $script:folder 'b.txt') -MappingPath $script:mappingFile -OutputPath $target
            $result.OutputPath | Should -BeExactly $target
            [System.IO.File]::ReadAllText($target) | Should -BeExactly 'Ben Sample'
        }

        It 'Should reject a file path for more than one input file' {
            { ConvertFrom-XurrentPseudonymized -Path (Join-Path $script:folder 'a.txt'), (Join-Path $script:folder 'b.txt') -MappingPath $script:mappingFile -OutputPath (Join-Path $script:folder 'one.txt') } |
                Should -Throw '*more than one input file*'
        }

        It 'Should reject the input file as output file' {
            $file = Join-Path $script:folder 'a.txt'
            { ConvertFrom-XurrentPseudonymized -Path $file -MappingPath $script:mappingFile -OutputPath $file } | Should -Throw '*must not be the input file*'
        }

        It 'Should not write anything with -WhatIf' {
            $result = ConvertFrom-XurrentPseudonymized -Path (Join-Path $script:folder 'a.txt') -MappingPath $script:mappingFile -OutputPath (Join-Path $script:folder 'whatif.txt') -WhatIf
            $result.Status | Should -BeExactly 'Skipped'
            Test-Path -LiteralPath (Join-Path $script:folder 'whatif.txt') | Should -BeFalse
        }
    }

    Context 'When the input is invalid' {
        It 'Should throw when the mapping file does not exist' {
            { ConvertFrom-XurrentPseudonymized -Text 'Person-001' -MappingPath (Join-Path $TestDrive 'missing.mapping.csv') } | Should -Throw '*Mapping file not found*'
        }

        It 'Should warn about a missing input file and write nothing' {
            $mapping = New-MappingFixture
            $result = ConvertFrom-XurrentPseudonymized -Path (Join-Path $TestDrive 'missing.csv') -MappingPath $mapping.FullName -WarningVariable warnings -WarningAction SilentlyContinue
            $result | Should -BeNullOrEmpty
            $warnings[0] | Should -Match 'File not found'
        }
    }
}
