BeforeAll {
    $script:dscModuleName = 'XurrentHelpers'
    Import-Module -Name $script:dscModuleName
}

AfterAll {
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe 'ConvertTo-XurrentKnowledgeArticle' {
    BeforeAll {
        $script:tempFile = New-TemporaryFile
        $content = @'
# My Article Title

**Keywords:** powershell, automation, xurrent

## Description
This is the description body text.

## Instructions
Step 1: do this.
Step 2: do that.
'@
        Set-Content -Path $script:tempFile.FullName -Value $content -Encoding UTF8
    }

    AfterAll {
        Remove-Item -Path $script:tempFile.FullName -Force -ErrorAction SilentlyContinue
    }

    Context 'When given a valid KnowledgeArticle file' {
        BeforeAll {
            $script:result = ConvertTo-XurrentKnowledgeArticle -File $script:tempFile -Service 'my service' -ServiceInstances 'my instance'
        }

        It 'Should not throw' {
            { ConvertTo-XurrentKnowledgeArticle -File $script:tempFile -Service 'svc' -ServiceInstances 'inst' } | Should -Not -Throw
        }

        It 'Should return a single object' {
            ($script:result | Measure-Object).Count | Should -Be 1
        }

        It 'Should extract the Subject from the first H1 heading' {
            $script:result.Subject | Should -Be 'My Article Title'
        }

        It 'Should extract Keywords from the Keywords line' {
            $script:result.Keywords | Should -Be 'powershell, automation, xurrent'
        }

        It 'Should extract the Description section body' {
            $script:result.Description | Should -Be 'This is the description body text.'
        }

        It 'Should extract the Instructions section body' {
            $script:result.Instructions | Should -Match 'Step 1'
        }

        It 'Should stamp the Service column' {
            $script:result.Service | Should -Be 'my service'
        }

        It 'Should stamp the Service Instances column' {
            $script:result.'Service Instances' | Should -Be 'my instance'
        }

        It 'Should set Status to work_in_progress' {
            $script:result.Status | Should -Be 'work_in_progress'
        }
    }

    Context 'When the file has no H1 heading' {
        BeforeAll {
            $script:noH1File = New-TemporaryFile
            Set-Content -Path $script:noH1File.FullName -Value "## Description`nSome description text here." -Encoding UTF8
        }

        AfterAll {
            Remove-Item -Path $script:noH1File.FullName -Force -ErrorAction SilentlyContinue
        }

        It 'Should return an empty Subject' {
            $result = ConvertTo-XurrentKnowledgeArticle -File $script:noH1File -Service 's' -ServiceInstances 'i'
            $result.Subject | Should -BeNullOrEmpty
        }
    }

    Context 'When the file has no Keywords line' {
        BeforeAll {
            $script:noKwFile = New-TemporaryFile
            Set-Content -Path $script:noKwFile.FullName -Value "# Title`n`n## Description`nSome description text." -Encoding UTF8
        }

        AfterAll {
            Remove-Item -Path $script:noKwFile.FullName -Force -ErrorAction SilentlyContinue
        }

        It 'Should return empty Keywords' {
            $result = ConvertTo-XurrentKnowledgeArticle -File $script:noKwFile -Service 's' -ServiceInstances 'i'
            $result.Keywords | Should -BeNullOrEmpty
        }
    }

    Context 'When piping multiple files' {
        It 'Should return one object per file' {
            $result = $script:tempFile, $script:tempFile | ConvertTo-XurrentKnowledgeArticle -Service 's' -ServiceInstances 'i'
            $result.Count | Should -Be 2
        }
    }

    Context 'When given a string path' {
        It 'Should accept a plain string file path' {
            { ConvertTo-XurrentKnowledgeArticle -File $script:tempFile.FullName -Service 's' -ServiceInstances 'i' } | Should -Not -Throw
        }

        It 'Should return the correct Subject when given a string path' {
            $result = ConvertTo-XurrentKnowledgeArticle -File $script:tempFile.FullName -Service 's' -ServiceInstances 'i'
            $result.Subject | Should -Be 'My Article Title'
        }
    }

    Context 'When given an object with a FullName property' {
        It 'Should accept an object with a FullName property' {
            $obj = [PSCustomObject]@{ FullName = $script:tempFile.FullName }
            { ConvertTo-XurrentKnowledgeArticle -File $obj -Service 's' -ServiceInstances 'i' } | Should -Not -Throw
        }
    }

    Context 'When given an object with a Path property' {
        It 'Should accept an object with a Path property' {
            $obj = [PSCustomObject]@{ Path = $script:tempFile.FullName }
            { ConvertTo-XurrentKnowledgeArticle -File $obj -Service 's' -ServiceInstances 'i' } | Should -Not -Throw
        }
    }

    Context 'When given an unsupported object type' {
        It 'Should throw when the object has no usable path property' {
            $obj = [PSCustomObject]@{ SomeOtherProperty = 'value' }
            { ConvertTo-XurrentKnowledgeArticle -File $obj -Service 's' -ServiceInstances 'i' } | Should -Throw
        }
    }

    Context 'When given a path that is not a file' {
        It 'Should throw when the path points to a directory' {
            $dir = [System.IO.Path]::GetTempPath()
            { ConvertTo-XurrentKnowledgeArticle -File $dir -Service 's' -ServiceInstances 'i' } | Should -Throw
        }
    }
}
