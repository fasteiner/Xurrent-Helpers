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

        It 'Should export an empty ID column when the Markdown has no **ID:** line' {
            # The fixture TestKnowledgeArticle.md intentionally has no **ID:** line (backwards compatibility).
            Export-XurrentKnowledgeArticle -Folder $script:tempDir.FullName -Service 'svc' -ServiceInstances 'inst' -OutputPath $script:outputCsv
            $rows = Import-Csv -Path $script:outputCsv
            $rows[0].ID | Should -BeNullOrEmpty
        }
    }

        Context 'When an ID metadata line is explicitly empty' {
            BeforeAll {
                $script:emptyIdDir = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString()))
                $content = @'
# Article With Empty ID

**ID:**
**Service:** metadata service
**Service Instances:** metadata instance

## Description
Description body.
'@
                Set-Content -Path (Join-Path $script:emptyIdDir.FullName 'EmptyIdKnowledgeArticle.md') -Value $content -Encoding UTF8
                $script:emptyIdOutput = Join-Path ([System.IO.Path]::GetTempPath()) "$([System.Guid]::NewGuid())-empty-id.csv"
            }

            AfterAll {
                Remove-Item -Path $script:emptyIdDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item -Path $script:emptyIdOutput -Force -ErrorAction SilentlyContinue
            }

            It 'Should export an empty ID without consuming the following metadata' {
                Export-XurrentKnowledgeArticle -Folder $script:emptyIdDir.FullName -Service 'fallback service' -ServiceInstances 'fallback instance' -OutputPath $script:emptyIdOutput
                $rows = Import-Csv -Path $script:emptyIdOutput
                $rows[0].ID | Should -BeNullOrEmpty
                $rows[0].Service | Should -Be 'metadata service'
                $rows[0].'Service Instances' | Should -Be 'metadata instance'
            }
        }

    Context 'When checking the file encoding' {
        # Xurrent rejects a UTF-8 BOM with "Illegal quoting in line 1"; the CSV must be BOM-less
        # on every supported PowerShell version. Read raw bytes (Import-Csv silently strips a BOM,
        # so a string/CSV comparison would not catch a regression here).
        It 'Should write the CSV as UTF-8 without a byte-order mark (BOM)' {
            Export-XurrentKnowledgeArticle -Folder $script:tempDir.FullName -Service 'svc' -ServiceInstances 'inst' -OutputPath $script:outputCsv
            $bytes = [System.IO.File]::ReadAllBytes($script:outputCsv)
            # The UTF-8 BOM is the three-byte sequence 0xEF 0xBB 0xBF.
            $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
            $hasBom | Should -BeFalse
        }

        It 'Should begin the file with CSV content, not a BOM' {
            Export-XurrentKnowledgeArticle -Folder $script:tempDir.FullName -Service 'svc' -ServiceInstances 'inst' -OutputPath $script:outputCsv
            $bytes = [System.IO.File]::ReadAllBytes($script:outputCsv)
            # Decode without BOM detection so a stray BOM would surface as U+FEFF, then assert the
            # text starts with the 'ID' header column rather than the BOM character.
            $text = [System.Text.Encoding]::UTF8.GetString($bytes)
            $text.TrimStart('"') | Should -Match '^ID'
        }
    }

    Context 'When round-tripping articles that contain IDs' {
        BeforeAll {
            # Source CSV with explicit IDs -> Markdown (Import) -> CSV (Export) must preserve the IDs.
            $script:idSourceCsv = Join-Path ([System.IO.Path]::GetTempPath()) "$([System.Guid]::NewGuid())-id-source.csv"
            @(
                [PSCustomObject]@{
                    ID = '100'; Source = '4me'; 'Source ID' = ''; Status = 'published'
                    Service = 'svc alpha'; 'Service Instances' = 'inst alpha'
                    Subject = 'Alpha Article'; Description = 'Alpha description.'
                    Instructions = 'Alpha instructions.'; Keywords = 'alpha'; Template = ''
                },
                [PSCustomObject]@{
                    ID = '200'; Source = '4me'; 'Source ID' = ''; Status = 'published'
                    Service = 'svc beta'; 'Service Instances' = 'inst beta'
                    Subject = 'Beta Article'; Description = 'Beta description.'
                    Instructions = 'Beta instructions.'; Keywords = 'beta'; Template = ''
                }
            ) | Export-Csv -Path $script:idSourceCsv -NoTypeInformation -Encoding UTF8

            $script:idMdDir = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString()))
            Import-XurrentKnowledgeArticle -CsvPath $script:idSourceCsv -OutputFolder $script:idMdDir.FullName

            $script:idRoundtripCsv = Join-Path ([System.IO.Path]::GetTempPath()) "$([System.Guid]::NewGuid())-id-roundtrip.csv"
            Export-XurrentKnowledgeArticle -Folder $script:idMdDir.FullName -Service 'fallback svc' -ServiceInstances 'fallback inst' -OutputPath $script:idRoundtripCsv
            $script:roundtripRows = Import-Csv -Path $script:idRoundtripCsv
        }

        AfterAll {
            Remove-Item -Path $script:idSourceCsv -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $script:idMdDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $script:idRoundtripCsv -Force -ErrorAction SilentlyContinue
        }

        It 'Should preserve the ID for the first article' {
            ($script:roundtripRows | Where-Object { $_.Subject -eq 'Alpha Article' }).ID | Should -Be '100'
        }

        It 'Should preserve the ID for the second article' {
            ($script:roundtripRows | Where-Object { $_.Subject -eq 'Beta Article' }).ID | Should -Be '200'
        }

        It 'Should preserve every original ID through the round-trip' {
            ($script:roundtripRows.ID | Sort-Object) | Should -Be @('100', '200')
        }

        It 'Should preserve Service metadata from Markdown over export parameter defaults' {
            ($script:roundtripRows | Where-Object { $_.Subject -eq 'Alpha Article' }).Service | Should -Be 'svc alpha'
            ($script:roundtripRows | Where-Object { $_.Subject -eq 'Beta Article' }).Service | Should -Be 'svc beta'
        }

        It 'Should preserve Service Instances metadata from Markdown over export parameter defaults' {
            ($script:roundtripRows | Where-Object { $_.Subject -eq 'Alpha Article' }).'Service Instances' | Should -Be 'inst alpha'
            ($script:roundtripRows | Where-Object { $_.Subject -eq 'Beta Article' }).'Service Instances' | Should -Be 'inst beta'
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

        It 'Should not warn when SERVICE_INSTANCES is supplied via the .env file' {
            Export-XurrentKnowledgeArticle -Folder $script:envDir.FullName -OutputPath $script:envOutput -EnvFile $script:envFile -WarningVariable warnings -WarningAction SilentlyContinue
            $warnings.Count | Should -Be 0
        }
    }

    Context 'When InputObject is passed as an array' {
        BeforeAll {
            $script:articleObj = [PSCustomObject]@{
                ID                  = ''
                Source              = '4me'
                'Source ID'         = ''
                Status              = 'work_in_progress'
                Service             = 'obj service'
                'Service Instances' = 'obj instance'
                Subject             = 'Object Article'
                Description         = 'Desc'
                Instructions        = 'Steps'
                Keywords            = 'kw'
                Template            = ''
            }
            $script:objOutput = Join-Path ([System.IO.Path]::GetTempPath()) "$([System.Guid]::NewGuid())-obj.csv"
        }

        AfterAll {
            Remove-Item -Path $script:objOutput -Force -ErrorAction SilentlyContinue
        }

        It 'Should not throw' {
            { Export-XurrentKnowledgeArticle -InputObject $script:articleObj -OutputPath $script:objOutput } | Should -Not -Throw
        }

        It 'Should create the output CSV file' {
            Export-XurrentKnowledgeArticle -InputObject $script:articleObj -OutputPath $script:objOutput
            Test-Path $script:objOutput | Should -Be $true
        }

        It 'Should write one row per object' {
            Export-XurrentKnowledgeArticle -InputObject @($script:articleObj, $script:articleObj) -OutputPath $script:objOutput
            (Import-Csv -Path $script:objOutput).Count | Should -Be 2
        }

        It 'Should preserve the Subject from the object' {
            Export-XurrentKnowledgeArticle -InputObject $script:articleObj -OutputPath $script:objOutput
            (Import-Csv -Path $script:objOutput)[0].Subject | Should -Be 'Object Article'
        }

        It 'Should not warn when an input object has an empty Service Instances value' {
            $emptyInstObj = $script:articleObj.PSObject.Copy()
            $emptyInstObj.'Service Instances' = ''
            Export-XurrentKnowledgeArticle -InputObject $emptyInstObj -OutputPath $script:objOutput -WarningVariable warnings -WarningAction SilentlyContinue
            $warnings.Count | Should -Be 0
        }
    }

    Context 'When InputObject is supplied via pipeline' {
        BeforeAll {
            $script:pipeObj = [PSCustomObject]@{
                ID                  = ''
                Source              = '4me'
                'Source ID'         = ''
                Status              = 'work_in_progress'
                Service             = 'pipe svc'
                'Service Instances' = 'pipe inst'
                Subject             = 'Piped Article'
                Description         = 'Desc'
                Instructions        = 'Steps'
                Keywords            = ''
                Template            = ''
            }
            $script:pipeOutput = Join-Path ([System.IO.Path]::GetTempPath()) "$([System.Guid]::NewGuid())-pipe.csv"
        }

        AfterAll {
            Remove-Item -Path $script:pipeOutput -Force -ErrorAction SilentlyContinue
        }

        It 'Should accept pipeline input and write all rows' {
            @($script:pipeObj, $script:pipeObj) | Export-XurrentKnowledgeArticle -OutputPath $script:pipeOutput
            (Import-Csv -Path $script:pipeOutput).Count | Should -Be 2
        }

        It 'Should preserve Subject from piped objects' {
            $script:pipeObj | Export-XurrentKnowledgeArticle -OutputPath $script:pipeOutput
            (Import-Csv -Path $script:pipeOutput)[0].Subject | Should -Be 'Piped Article'
        }
    }

    Context 'When OutputPath is a directory' {
        BeforeAll {
            $script:dirOutput = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString()))
        }

        AfterAll {
            Remove-Item -Path $script:dirOutput.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Should append the default file name inside the directory' {
            $csvPath = Join-Path $script:dirOutput.FullName 'import-knowledge_articles.csv'
            Remove-Item -Path $csvPath -Force -ErrorAction SilentlyContinue
            Export-XurrentKnowledgeArticle -Folder $script:tempDir.FullName -Service 'svc' -ServiceInstances 'inst' -OutputPath $script:dirOutput.FullName
            Test-Path $csvPath | Should -Be $true
        }

        It 'Should append the default file name when OutputPath ends with a directory separator' {
            $csvPath = Join-Path $script:dirOutput.FullName 'import-knowledge_articles.csv'
            Remove-Item -Path $csvPath -Force -ErrorAction SilentlyContinue
            $pathWithSep = "$($script:dirOutput.FullName)$([System.IO.Path]::DirectorySeparatorChar)"
            Export-XurrentKnowledgeArticle -Folder $script:tempDir.FullName -Service 'svc' -ServiceInstances 'inst' -OutputPath $pathWithSep
            Test-Path $csvPath | Should -Be $true
        }
    }

    Context 'When ServiceInstances is not provided (parameter is optional)' {
        BeforeAll {
            $script:noInstDir = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString()))
            Set-Content -Path (Join-Path $script:noInstDir.FullName 'TestKnowledgeArticle.md') -Value (Get-Content (Join-Path $script:tempDir.FullName 'TestKnowledgeArticle.md') -Raw) -Encoding UTF8
            $script:noInstOutput = Join-Path ([System.IO.Path]::GetTempPath()) "$([System.Guid]::NewGuid())-noinst.csv"
        }

        AfterAll {
            Remove-Item -Path $script:noInstDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $script:noInstOutput -Force -ErrorAction SilentlyContinue
        }

        It 'Should not invoke Read-Host for ServiceInstances when the parameter is omitted' {
            Mock -ModuleName XurrentHelpers -CommandName Read-Host -MockWith { '' }
            Export-XurrentKnowledgeArticle -Folder $script:noInstDir.FullName -Service 'svc' -OutputPath $script:noInstOutput -WarningAction SilentlyContinue
            Should -Invoke -ModuleName XurrentHelpers -CommandName Read-Host -Exactly -Times 0 -Scope It
        }

        It 'Should write an empty Service Instances column when ServiceInstances is not provided' {
            Mock -ModuleName XurrentHelpers -CommandName Read-Host -MockWith { '' }
            Export-XurrentKnowledgeArticle -Folder $script:noInstDir.FullName -Service 'svc' -OutputPath $script:noInstOutput -WarningAction SilentlyContinue
            $rows = Import-Csv -Path $script:noInstOutput
            $rows[0].'Service Instances' | Should -BeNullOrEmpty
        }

        It 'Should not throw when ServiceInstances is omitted' {
            Mock -ModuleName XurrentHelpers -CommandName Read-Host -MockWith { '' }
            { Export-XurrentKnowledgeArticle -Folder $script:noInstDir.FullName -Service 'svc' -OutputPath $script:noInstOutput -WarningAction SilentlyContinue } | Should -Not -Throw
        }

        It 'Should warn that the article(s) will not be scoped to a specific Service Instance' {
            # -EnvFile points at a file that is never created so a stray .env in the current directory cannot suppress the warning.
            Export-XurrentKnowledgeArticle -Folder $script:noInstDir.FullName -Service 'svc' -OutputPath $script:noInstOutput -EnvFile (Join-Path $script:noInstDir.FullName 'missing.env') -WarningVariable warnings -WarningAction SilentlyContinue
            (($warnings | ForEach-Object Message) -join "`n") | Should -Match 'No Service Instances specified'
            (($warnings | ForEach-Object Message) -join "`n") | Should -Match "article 'Test Article'"
        }

        It 'Should emit exactly one warning for the single article without Service Instances' {
            Export-XurrentKnowledgeArticle -Folder $script:noInstDir.FullName -Service 'svc' -OutputPath $script:noInstOutput -EnvFile (Join-Path $script:noInstDir.FullName 'missing.env') -WarningVariable warnings -WarningAction SilentlyContinue
            $warnings.Count | Should -Be 1
        }

        It 'Should not warn when ServiceInstances is provided' {
            Export-XurrentKnowledgeArticle -Folder $script:noInstDir.FullName -Service 'svc' -ServiceInstances 'inst' -OutputPath $script:noInstOutput -WarningVariable warnings -WarningAction SilentlyContinue
            $warnings.Count | Should -Be 0
        }
    }

    Context 'When the Markdown metadata supplies Service Instances and no fallback is provided' {
        BeforeAll {
            $script:metadataInstDir = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString()))
            $metadataContent = @'
# Metadata Article

**Service Instances:** metadata instance

## Description
Description for the metadata article.

## Instructions
Instructions for the metadata article.
'@
            Set-Content -Path (Join-Path $script:metadataInstDir.FullName 'MetadataKnowledgeArticle.md') -Value $metadataContent -Encoding UTF8
            $script:metadataInstOutput = Join-Path ([System.IO.Path]::GetTempPath()) "$([System.Guid]::NewGuid())-metadata-inst.csv"
            # Never created; passed as -EnvFile so a stray .env in the current directory cannot influence the assertions.
            $script:metadataInstNoEnv = Join-Path $script:metadataInstDir.FullName 'missing.env'
        }

        AfterAll {
            Remove-Item -Path $script:metadataInstDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $script:metadataInstOutput -Force -ErrorAction SilentlyContinue
        }

        It 'Should not warn when the article carries its own Service Instances metadata' {
            Export-XurrentKnowledgeArticle -Folder $script:metadataInstDir.FullName -Service 'svc' -OutputPath $script:metadataInstOutput -EnvFile $script:metadataInstNoEnv -WarningVariable warnings -WarningAction SilentlyContinue
            $warnings.Count | Should -Be 0
        }

        It 'Should export the Service Instances value from the Markdown metadata' {
            Export-XurrentKnowledgeArticle -Folder $script:metadataInstDir.FullName -Service 'svc' -OutputPath $script:metadataInstOutput -EnvFile $script:metadataInstNoEnv -WarningAction SilentlyContinue
            $rows = Import-Csv -Path $script:metadataInstOutput
            $rows[0].'Service Instances' | Should -Be 'metadata instance'
        }
    }

    Context 'When a folder mixes articles with and without Service Instances metadata' {
        BeforeAll {
            $script:mixedInstDir = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString()))
            $scopedContent = @'
# Scoped Article

**Service Instances:** scoped instance

## Description
Description for the scoped article.

## Instructions
Instructions for the scoped article.
'@
            Set-Content -Path (Join-Path $script:mixedInstDir.FullName 'ScopedKnowledgeArticle.md') -Value $scopedContent -Encoding UTF8
            $unscopedContent = @'
# Unscoped Article

## Description
Description for the unscoped article.

## Instructions
Instructions for the unscoped article.
'@
            Set-Content -Path (Join-Path $script:mixedInstDir.FullName 'UnscopedKnowledgeArticle.md') -Value $unscopedContent -Encoding UTF8
            $script:mixedInstOutput = Join-Path ([System.IO.Path]::GetTempPath()) "$([System.Guid]::NewGuid())-mixed-inst.csv"
            # Never created; passed as -EnvFile so a stray .env in the current directory cannot influence the assertions.
            $script:mixedInstNoEnv = Join-Path $script:mixedInstDir.FullName 'missing.env'
        }

        AfterAll {
            Remove-Item -Path $script:mixedInstDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $script:mixedInstOutput -Force -ErrorAction SilentlyContinue
        }

        It 'Should warn exactly once, naming only the article without Service Instances' {
            Export-XurrentKnowledgeArticle -Folder $script:mixedInstDir.FullName -Service 'svc' -OutputPath $script:mixedInstOutput -EnvFile $script:mixedInstNoEnv -WarningVariable warnings -WarningAction SilentlyContinue
            $warnings.Count | Should -Be 1
            $joined = ($warnings | ForEach-Object Message) -join "`n"
            $joined | Should -Match "article 'Unscoped Article'"
            $joined | Should -Not -Match "article 'Scoped Article'"
        }

        It 'Should export the metadata value for the scoped article and an empty value for the unscoped article' {
            Export-XurrentKnowledgeArticle -Folder $script:mixedInstDir.FullName -Service 'svc' -OutputPath $script:mixedInstOutput -EnvFile $script:mixedInstNoEnv -WarningAction SilentlyContinue
            $rows = Import-Csv -Path $script:mixedInstOutput
            ($rows | Where-Object { $_.Subject -eq 'Scoped Article' }).'Service Instances' | Should -Be 'scoped instance'
            ($rows | Where-Object { $_.Subject -eq 'Unscoped Article' }).'Service Instances' | Should -BeNullOrEmpty
        }
    }

    Context 'When multiple articles are missing Service Instances' {
        BeforeAll {
            $script:multiMissingDir = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString()))
            $firstMissingContent = @'
# First Missing

## Description
Description for the first article.

## Instructions
Instructions for the first article.
'@
            Set-Content -Path (Join-Path $script:multiMissingDir.FullName 'FirstMissingKnowledgeArticle.md') -Value $firstMissingContent -Encoding UTF8
            $secondMissingContent = @'
# Second Missing

## Description
Description for the second article.

## Instructions
Instructions for the second article.
'@
            Set-Content -Path (Join-Path $script:multiMissingDir.FullName 'SecondMissingKnowledgeArticle.md') -Value $secondMissingContent -Encoding UTF8
            $script:multiMissingOutput = Join-Path ([System.IO.Path]::GetTempPath()) "$([System.Guid]::NewGuid())-multi-missing.csv"
            # Never created; passed as -EnvFile so a stray .env in the current directory cannot influence the assertions.
            $script:multiMissingNoEnv = Join-Path $script:multiMissingDir.FullName 'missing.env'
        }

        AfterAll {
            Remove-Item -Path $script:multiMissingDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $script:multiMissingOutput -Force -ErrorAction SilentlyContinue
        }

        It 'Should warn once per article that is missing Service Instances' {
            Export-XurrentKnowledgeArticle -Folder $script:multiMissingDir.FullName -Service 'svc' -OutputPath $script:multiMissingOutput -EnvFile $script:multiMissingNoEnv -WarningVariable warnings -WarningAction SilentlyContinue
            $warnings.Count | Should -Be 2
            $joined = ($warnings | ForEach-Object Message) -join "`n"
            $joined | Should -Match "article 'First Missing'"
            $joined | Should -Match "article 'Second Missing'"
        }
    }

    Context 'When the Service Instances metadata line is present but empty' {
        BeforeAll {
            $script:emptyInstDir = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString()))
            $emptyInstContent = @'
# Empty Instances Article

**Service Instances:**

## Description
Description for the empty instances article.

## Instructions
Instructions for the empty instances article.
'@
            Set-Content -Path (Join-Path $script:emptyInstDir.FullName 'EmptyInstancesKnowledgeArticle.md') -Value $emptyInstContent -Encoding UTF8
            $script:emptyInstOutput = Join-Path ([System.IO.Path]::GetTempPath()) "$([System.Guid]::NewGuid())-empty-inst.csv"
            # Never created; passed as -EnvFile so a stray .env in the current directory cannot influence the assertions.
            $script:emptyInstNoEnv = Join-Path $script:emptyInstDir.FullName 'missing.env'
        }

        AfterAll {
            Remove-Item -Path $script:emptyInstDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $script:emptyInstOutput -Force -ErrorAction SilentlyContinue
        }

        It 'Should warn for the article when no fallback ServiceInstances is provided' {
            Export-XurrentKnowledgeArticle -Folder $script:emptyInstDir.FullName -Service 'svc' -OutputPath $script:emptyInstOutput -EnvFile $script:emptyInstNoEnv -WarningVariable warnings -WarningAction SilentlyContinue
            $warnings.Count | Should -Be 1
            (($warnings | ForEach-Object Message) -join "`n") | Should -Match "article 'Empty Instances Article'"
        }

        It 'Should not warn and should export the fallback value when ServiceInstances is provided' {
            Export-XurrentKnowledgeArticle -Folder $script:emptyInstDir.FullName -Service 'svc' -ServiceInstances 'fb inst' -OutputPath $script:emptyInstOutput -EnvFile $script:emptyInstNoEnv -WarningVariable warnings -WarningAction SilentlyContinue
            $warnings.Count | Should -Be 0
            $rows = Import-Csv -Path $script:emptyInstOutput
            $rows[0].'Service Instances' | Should -Be 'fb inst'
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
