BeforeAll {
    $script:dscModuleName = 'XurrentHelpers'
    Import-Module -Name $script:dscModuleName

    # Columns in the order of a Xurrent export; Source ID is deliberately not next to ID so a
    # changed column order would show up.
    $script:header = '"ID","Name","Source","Source ID","Disabled"'
    $script:standardLines = @(
        $script:header
        '"101","Alpha","","","false"'
        '"","Beta","","","true"'
        '"103","Gamma","","","false"'
        '"","Delta","","55","false"'
    )

    # Writes the lines as-is (CRLF-separated) into a file below TestDrive and returns the file.
    # A new folder is used unless -Folder is given, because every conversion rewrites its input.
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

    function New-EmptyFolder
    {
        New-Item -ItemType Directory -Path (Join-Path $TestDrive ([System.Guid]::NewGuid().ToString()))
    }

    function Get-FileHashString
    {
        param ([string] $Path)
        [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Path))
    }
}

AfterAll {
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe 'ConvertTo-XurrentCrossEnvironmentImport' {
    Context 'When a file contains IDs' {
        BeforeAll {
            $script:file = New-CsvFixture
            $script:result = ConvertTo-XurrentCrossEnvironmentImport -Path $script:file.FullName -Folder (New-EmptyFolder).FullName
            $script:rows = @(Import-Csv -LiteralPath $script:file.FullName -Encoding UTF8)
        }

        It 'Should return one object with Status Moved and the number of moved IDs' {
            @($script:result).Count | Should -Be 1
            $script:result.File | Should -Be $script:file.FullName
            $script:result.Moved | Should -Be 2
            $script:result.Status | Should -Be 'Moved'
        }

        It 'Should copy each ID into Source ID' {
            $script:rows[0].'Source ID' | Should -Be '101'
            $script:rows[2].'Source ID' | Should -Be '103'
        }

        It 'Should empty the ID column but keep it in the file' {
            $script:rows[0].PSObject.Properties.Name | Should -Contain 'ID'
            foreach ($row in $script:rows)
            {
                $row.ID | Should -BeNullOrEmpty
            }
        }

        It 'Should leave rows without an ID untouched' {
            $script:rows[1].'Source ID' | Should -BeNullOrEmpty
            $script:rows[3].'Source ID' | Should -Be '55'
        }

        It 'Should keep the column order' {
            [System.IO.File]::ReadAllLines($script:file.FullName)[0] | Should -BeExactly $script:header
        }

        It 'Should keep all other values' {
            $script:rows.Count | Should -Be 4
            ($script:rows | ForEach-Object { $_.Name }) -join ',' | Should -BeExactly 'Alpha,Beta,Gamma,Delta'
            ($script:rows | ForEach-Object { $_.Disabled }) -join ',' | Should -BeExactly 'false,true,false,false'
            ($script:rows | ForEach-Object { $_.Source }) -join ',' | Should -BeExactly ',,,'
        }
    }

    Context 'When a quoted field spans several lines' {
        It 'Should keep the multi-line value unchanged' {
            # UI extension exports carry HTML/CSS/JS with embedded CRLF and LF line breaks and quotes.
            $html = "<style>`r`n  .a { color: red; }`r`n</style>`n<div class=`"a`">x</div>"
            $file = New-CsvFixture -Line @(
                '"ID","Name","HTML","Source ID"'
                ('"7","Widget","' + $html.Replace('"', '""') + '",""')
            )

            $result = ConvertTo-XurrentCrossEnvironmentImport -Path $file.FullName -Folder (New-EmptyFolder).FullName

            $result.Moved | Should -Be 1
            $rows = @(Import-Csv -LiteralPath $file.FullName -Encoding UTF8)
            $rows.Count | Should -Be 1
            $rows[0].HTML | Should -BeExactly $html
            $rows[0].Name | Should -BeExactly 'Widget'
            $rows[0].'Source ID' | Should -Be '7'
        }
    }

    Context 'When a file is converted a second time' {
        BeforeAll {
            $script:file = New-CsvFixture
            $emptyFolder = (New-EmptyFolder).FullName
            $null = ConvertTo-XurrentCrossEnvironmentImport -Path $script:file.FullName -Folder $emptyFolder
            $script:hashAfterFirstRun = Get-FileHashString -Path $script:file.FullName
            $script:secondResult = ConvertTo-XurrentCrossEnvironmentImport -Path $script:file.FullName -Folder $emptyFolder
        }

        It 'Should report NothingToMove' {
            $script:secondResult.Status | Should -Be 'NothingToMove'
            $script:secondResult.Moved | Should -Be 0
        }

        It 'Should keep the Source ID written by the first run' {
            $rows = @(Import-Csv -LiteralPath $script:file.FullName -Encoding UTF8)
            $rows[0].'Source ID' | Should -Be '101'
            $rows[2].'Source ID' | Should -Be '103'
        }

        It 'Should not rewrite the file' {
            Get-FileHashString -Path $script:file.FullName | Should -Be $script:hashAfterFirstRun
        }
    }

    Context 'When Source ID already holds a value' {
        It 'Should overwrite a different Source ID and warn' {
            $file = New-CsvFixture -Line @('"ID","Source ID"', '"101","999"')

            $result = ConvertTo-XurrentCrossEnvironmentImport -Path $file.FullName -Folder (New-EmptyFolder).FullName -WarningVariable warnings -WarningAction SilentlyContinue

            $result.Status | Should -Be 'Moved'
            (Import-Csv -LiteralPath $file.FullName -Encoding UTF8).'Source ID' | Should -Be '101'
            $warnings.Count | Should -Be 1
            $warnings[0].Message | Should -Match "'999' overwritten with '101'"
        }

        It 'Should not warn when Source ID already equals the ID' {
            $file = New-CsvFixture -Line @('"ID","Source ID"', '"101","101"')

            $result = ConvertTo-XurrentCrossEnvironmentImport -Path $file.FullName -Folder (New-EmptyFolder).FullName -WarningVariable warnings -WarningAction SilentlyContinue

            $result.Moved | Should -Be 1
            $warnings.Count | Should -Be 0
            $row = Import-Csv -LiteralPath $file.FullName -Encoding UTF8
            $row.ID | Should -BeNullOrEmpty
            $row.'Source ID' | Should -Be '101'
        }
    }

    Context 'When a required column is missing' {
        It 'Should skip a file without the Source ID column and leave it unchanged' {
            $file = New-CsvFixture -Line @('"ID","Name"', '"101","Alpha"')
            $hashBefore = Get-FileHashString -Path $file.FullName

            $result = ConvertTo-XurrentCrossEnvironmentImport -Path $file.FullName -Folder (New-EmptyFolder).FullName -WarningVariable warnings -WarningAction SilentlyContinue

            $result.Status | Should -Be 'Skipped'
            $result.Moved | Should -Be 0
            $warnings[0].Message | Should -Match "'Source ID' missing, skipped"
            Get-FileHashString -Path $file.FullName | Should -Be $hashBefore
        }

        It 'Should skip a file without the ID column' {
            $file = New-CsvFixture -Line @('"Name","Source ID"', '"Alpha",""')

            $result = ConvertTo-XurrentCrossEnvironmentImport -Path $file.FullName -Folder (New-EmptyFolder).FullName -WarningAction SilentlyContinue

            $result.Status | Should -Be 'Skipped'
        }
    }

    Context 'When custom column names are given' {
        It 'Should move the value between the columns named by -IdColumn and -SourceIdColumn' {
            $file = New-CsvFixture -Line @('"Record","Name","Origin"', '"5","Alpha",""')

            $result = ConvertTo-XurrentCrossEnvironmentImport -Path $file.FullName -Folder (New-EmptyFolder).FullName -IdColumn 'Record' -SourceIdColumn 'Origin'

            $result.Moved | Should -Be 1
            $row = Import-Csv -LiteralPath $file.FullName -Encoding UTF8
            $row.Record | Should -BeNullOrEmpty
            $row.Origin | Should -Be '5'
        }
    }

    Context 'When the file has no rows' {
        It 'Should skip an empty file' {
            $file = New-CsvFixture -Line @()

            $result = ConvertTo-XurrentCrossEnvironmentImport -Path $file.FullName -Folder (New-EmptyFolder).FullName -WarningVariable warnings -WarningAction SilentlyContinue

            $result.Status | Should -Be 'Skipped'
            $warnings[0].Message | Should -Match 'no rows, skipped'
            (Get-Item -LiteralPath $file.FullName).Length | Should -Be 0
        }

        It 'Should skip a file with only a header line' {
            $file = New-CsvFixture -Line @($script:header)

            $result = ConvertTo-XurrentCrossEnvironmentImport -Path $file.FullName -Folder (New-EmptyFolder).FullName -WarningAction SilentlyContinue

            $result.Status | Should -Be 'Skipped'
        }
    }

    Context 'When selecting files by name' {
        It 'Should convert a single file given by absolute path, ignoring -Folder' {
            $file = New-CsvFixture

            $result = ConvertTo-XurrentCrossEnvironmentImport -Path $file.FullName -Folder (New-EmptyFolder).FullName

            $result.File | Should -Be $file.FullName
            $result.Status | Should -Be 'Moved'
        }

        It 'Should convert every file of an array' {
            $first = New-CsvFixture -Name 'teams-1.csv'
            $second = New-CsvFixture -Name 'slas-1.csv'

            $result = @(ConvertTo-XurrentCrossEnvironmentImport -Path $first.FullName, $second.FullName -Folder (New-EmptyFolder).FullName)

            $result.Count | Should -Be 2
            $result[0].File | Should -Be $first.FullName
            $result[1].File | Should -Be $second.FullName
            $result.Status | Should -Not -Contain 'Skipped'
        }

        It 'Should resolve a relative name against -Folder' {
            $file = New-CsvFixture -Name 'slas-1.csv'

            $result = ConvertTo-XurrentCrossEnvironmentImport 'slas-1.csv' -Folder $file.DirectoryName

            $result.File | Should -Be $file.FullName
            $result.Status | Should -Be 'Moved'
        }

        It 'Should warn about a name that is not found and continue with the others' {
            $file = New-CsvFixture -Name 'slas-1.csv'

            $result = @(ConvertTo-XurrentCrossEnvironmentImport -Path 'missing.csv', 'slas-1.csv' -Folder $file.DirectoryName -WarningVariable warnings -WarningAction SilentlyContinue)

            $result.Count | Should -Be 1
            $result[0].File | Should -Be $file.FullName
            $warnings.Count | Should -Be 1
            $warnings[0].Message | Should -Match '^Not found: .*missing\.csv$'
        }

        It 'Should warn and return nothing when no name is found' {
            $folder = (New-EmptyFolder).FullName

            $result = ConvertTo-XurrentCrossEnvironmentImport -Path 'missing.csv' -Folder $folder -WarningVariable warnings -WarningAction SilentlyContinue

            $result | Should -BeNullOrEmpty
            $warnings.Message | Should -Contain 'No CSV files selected.'
        }

        It 'Should accept files piped from Get-ChildItem' {
            $folder = (New-EmptyFolder).FullName
            $null = New-CsvFixture -Name 'a.csv' -Folder $folder
            $null = New-CsvFixture -Name 'b.csv' -Folder $folder

            $result = @(Get-ChildItem -LiteralPath $folder -Filter '*.csv' | ConvertTo-XurrentCrossEnvironmentImport -Folder (New-EmptyFolder).FullName)

            $result.Count | Should -Be 2
            ($result.File | ForEach-Object { Split-Path -Path $_ -Leaf }) -join ',' | Should -Be 'a.csv,b.csv'
            $result.Status | Should -Not -Contain 'Skipped'
        }

        It 'Should accept names piped as strings' {
            $folder = (New-EmptyFolder).FullName
            $null = New-CsvFixture -Name 'a.csv' -Folder $folder
            $null = New-CsvFixture -Name 'b.csv' -Folder $folder

            $result = @('a.csv', 'b.csv' | ConvertTo-XurrentCrossEnvironmentImport -Folder $folder)

            $result.Count | Should -Be 2
            $result.Status | Should -Not -Contain 'Skipped'
        }

        It 'Should warn instead of scanning -Folder when the pipeline delivers nothing' {
            $folder = (New-EmptyFolder).FullName
            $file = New-CsvFixture -Folder $folder
            $hashBefore = Get-FileHashString -Path $file.FullName

            $result = @() | ConvertTo-XurrentCrossEnvironmentImport -Folder $folder -WarningVariable warnings -WarningAction SilentlyContinue

            $result | Should -BeNullOrEmpty
            $warnings.Message | Should -Contain 'No CSV files selected.'
            Get-FileHashString -Path $file.FullName | Should -Be $hashBefore
        }
    }

    Context 'When selecting files by time' {
        It 'Should convert a CSV file written just now and ignore other file types' {
            $folder = (New-EmptyFolder).FullName
            $file = New-CsvFixture -Folder $folder
            Set-Content -LiteralPath (Join-Path $folder 'notes.txt') -Value 'not a csv'

            $result = @(ConvertTo-XurrentCrossEnvironmentImport -Folder $folder -LastHours 1)

            $result.Count | Should -Be 1
            $result[0].File | Should -Be $file.FullName
            $result[0].Status | Should -Be 'Moved'
        }

        It 'Should warn when the folder holds no CSV file' {
            $result = ConvertTo-XurrentCrossEnvironmentImport -Folder (New-EmptyFolder).FullName -WarningVariable warnings -WarningAction SilentlyContinue

            $result | Should -BeNullOrEmpty
            $warnings.Message | Should -Contain 'No CSV files selected.'
        }

        Context 'When CreationTime and LastWriteTime differ' {
            BeforeAll {
                $script:timeFolder = (New-EmptyFolder).FullName
                $script:recentCreation = New-CsvFixture -Name 'a-recent-creation.csv' -Folder $script:timeFolder
                $script:recentWrite = New-CsvFixture -Name 'b-recent-write.csv' -Folder $script:timeFolder
                $script:bothOld = New-CsvFixture -Name 'c-both-old.csv' -Folder $script:timeFolder
                $script:bothOldHash = Get-FileHashString -Path $script:bothOld.FullName

                # CreationTime cannot be set on Linux, so the listing with the timestamps under test
                # comes from a mock. The files behind FullName are real and get converted.
                $now = Get-Date
                $fiveHoursAgo = $now.AddHours(-5)
                $script:listing = @(
                    [PSCustomObject]@{ Name = $script:bothOld.Name; FullName = $script:bothOld.FullName; CreationTime = $fiveHoursAgo; LastWriteTime = $fiveHoursAgo }
                    [PSCustomObject]@{ Name = $script:recentWrite.Name; FullName = $script:recentWrite.FullName; CreationTime = $fiveHoursAgo; LastWriteTime = $now }
                    [PSCustomObject]@{ Name = $script:recentCreation.Name; FullName = $script:recentCreation.FullName; CreationTime = $now; LastWriteTime = $fiveHoursAgo }
                )
                Mock -ModuleName XurrentHelpers -CommandName Get-ChildItem -MockWith { $script:listing }

                $script:timeResult = @(ConvertTo-XurrentCrossEnvironmentImport -Folder $script:timeFolder -LastHours 2)
            }

            It 'Should list the CSV files of -Folder' {
                Should -Invoke -ModuleName XurrentHelpers -CommandName Get-ChildItem -Exactly -Times 1 -Scope Context -ParameterFilter {
                    $LiteralPath -contains $script:timeFolder -and $Filter -eq '*.csv' -and $File
                }
            }

            It 'Should convert a file whose CreationTime is recent although its LastWriteTime is old' {
                $script:timeResult.File | Should -Contain $script:recentCreation.FullName
            }

            It 'Should convert a file whose LastWriteTime is recent although its CreationTime is old' {
                $script:timeResult.File | Should -Contain $script:recentWrite.FullName
            }

            It 'Should leave a file untouched when both timestamps are outside the window' {
                $script:timeResult.File | Should -Not -Contain $script:bothOld.FullName
                Get-FileHashString -Path $script:bothOld.FullName | Should -Be $script:bothOldHash
            }

            It 'Should process the selected files in name order' {
                ($script:timeResult.File | ForEach-Object { Split-Path -Path $_ -Leaf }) -join ',' | Should -Be 'a-recent-creation.csv,b-recent-write.csv'
                $script:timeResult.Status | Should -Not -Contain 'Skipped'
            }
        }
    }

    Context 'When -WhatIf is used' {
        It 'Should leave the file unchanged and report WhatIf with the number of IDs it would move' {
            $file = New-CsvFixture
            $hashBefore = Get-FileHashString -Path $file.FullName

            $result = ConvertTo-XurrentCrossEnvironmentImport -Path $file.FullName -Folder (New-EmptyFolder).FullName -WhatIf

            $result.Status | Should -Be 'WhatIf'
            $result.Moved | Should -Be 2
            Get-FileHashString -Path $file.FullName | Should -Be $hashBefore
        }
    }

    Context 'When checking the file encoding' {
        BeforeAll {
            # Input with a BOM and a non-ASCII character covers both the read and the write side.
            $script:name = [string][char]0x00C4 + 'rger'
            $script:encodedFile = New-CsvFixture -Line @('"ID","Name","Source ID"', ('"8","' + $script:name + '",""')) -Bom
            $null = ConvertTo-XurrentCrossEnvironmentImport -Path $script:encodedFile.FullName -Folder (New-EmptyFolder).FullName
            $script:bytes = [System.IO.File]::ReadAllBytes($script:encodedFile.FullName)
        }

        # Xurrent rejects a UTF-8 BOM with "Illegal quoting in line 1". Import-Csv silently strips a
        # BOM, so only the raw bytes show a regression.
        It 'Should write UTF-8 without a byte-order mark (BOM)' {
            $hasBom = $script:bytes.Length -ge 3 -and $script:bytes[0] -eq 0xEF -and $script:bytes[1] -eq 0xBB -and $script:bytes[2] -eq 0xBF
            $hasBom | Should -BeFalse
            [System.Text.Encoding]::UTF8.GetString($script:bytes) | Should -Match '^"ID"'
        }

        It 'Should keep non-ASCII characters' {
            (Import-Csv -LiteralPath $script:encodedFile.FullName -Encoding UTF8).Name | Should -BeExactly $script:name
        }
    }
}
