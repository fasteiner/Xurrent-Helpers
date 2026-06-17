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

    Context 'When round-tripping articles that contain IDs' {
        BeforeAll {
            # Source CSV with explicit IDs -> Markdown (Import) -> CSV (Export) must preserve the IDs.
            $script:idSourceCsv = Join-Path ([System.IO.Path]::GetTempPath()) "$([System.Guid]::NewGuid())-id-source.csv"
            @(
                [PSCustomObject]@{
                    ID = '100'; Source = '4me'; 'Source ID' = ''; Status = 'published'
                    Service = 'svc'; 'Service Instances' = 'inst'
                    Subject = 'Alpha Article'; Description = 'Alpha description.'
                    Instructions = 'Alpha instructions.'; Keywords = 'alpha'; Template = ''
                },
                [PSCustomObject]@{
                    ID = '200'; Source = '4me'; 'Source ID' = ''; Status = 'published'
                    Service = 'svc'; 'Service Instances' = 'inst'
                    Subject = 'Beta Article'; Description = 'Beta description.'
                    Instructions = 'Beta instructions.'; Keywords = 'beta'; Template = ''
                }
            ) | Export-Csv -Path $script:idSourceCsv -NoTypeInformation -Encoding UTF8

            $script:idMdDir = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString()))
            Import-XurrentKnowledgeArticle -CsvPath $script:idSourceCsv -OutputFolder $script:idMdDir.FullName

            $script:idRoundtripCsv = Join-Path ([System.IO.Path]::GetTempPath()) "$([System.Guid]::NewGuid())-id-roundtrip.csv"
            Export-XurrentKnowledgeArticle -Folder $script:idMdDir.FullName -Service 'svc' -ServiceInstances 'inst' -OutputPath $script:idRoundtripCsv
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
