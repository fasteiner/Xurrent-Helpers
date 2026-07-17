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

    Context 'When the file has an ID line' {
        BeforeAll {
            $script:idFile = New-TemporaryFile
            $content = @'
# Title With ID

**ID:** 42

## Description
Body text.
'@
            Set-Content -Path $script:idFile.FullName -Value $content -Encoding UTF8
        }

        AfterAll {
            Remove-Item -Path $script:idFile.FullName -Force -ErrorAction SilentlyContinue
        }

        It 'Should extract the value from the **ID:** line' {
            $result = ConvertTo-XurrentKnowledgeArticle -File $script:idFile -Service 's' -ServiceInstances 'i'
            $result.ID | Should -Be '42'
        }
    }

    Context 'When the file has no ID line' {
        BeforeAll {
            $script:noIdFile = New-TemporaryFile
            Set-Content -Path $script:noIdFile.FullName -Value "# Title`n`n## Description`nSome description text." -Encoding UTF8
        }

        AfterAll {
            Remove-Item -Path $script:noIdFile.FullName -Force -ErrorAction SilentlyContinue
        }

        It 'Should return an empty ID (backwards compatible)' {
            $result = ConvertTo-XurrentKnowledgeArticle -File $script:noIdFile -Service 's' -ServiceInstances 'i'
            $result.ID | Should -BeNullOrEmpty
        }
    }

    Context 'When the file has Service metadata lines' {
        BeforeAll {
            $script:serviceMetaFile = New-TemporaryFile
            $content = @'
# Title With Service Metadata

**Service:** metadata service
**Service Instances:** metadata instance

## Description
Body text.
'@
            Set-Content -Path $script:serviceMetaFile.FullName -Value $content -Encoding UTF8
        }

        AfterAll {
            Remove-Item -Path $script:serviceMetaFile.FullName -Force -ErrorAction SilentlyContinue
        }

        It 'Should prefer **Service:** metadata over the -Service parameter' {
            $result = ConvertTo-XurrentKnowledgeArticle -File $script:serviceMetaFile -Service 'fallback service' -ServiceInstances 'fallback instance'
            $result.Service | Should -Be 'metadata service'
        }

        It 'Should prefer **Service Instances:** metadata over the -ServiceInstances parameter' {
            $result = ConvertTo-XurrentKnowledgeArticle -File $script:serviceMetaFile -Service 'fallback service' -ServiceInstances 'fallback instance'
            $result.'Service Instances' | Should -Be 'metadata instance'
        }
    }

    Context 'When the file has no Service metadata lines' {
        BeforeAll {
            $script:noServiceMetaFile = New-TemporaryFile
            $content = @'
# Title Without Service Metadata

## Description
Body text.
'@
            Set-Content -Path $script:noServiceMetaFile.FullName -Value $content -Encoding UTF8
        }

        AfterAll {
            Remove-Item -Path $script:noServiceMetaFile.FullName -Force -ErrorAction SilentlyContinue
        }

        It 'Should fall back to the -Service parameter' {
            $result = ConvertTo-XurrentKnowledgeArticle -File $script:noServiceMetaFile -Service 'fallback service' -ServiceInstances 'fallback instance'
            $result.Service | Should -Be 'fallback service'
        }

        It 'Should fall back to the -ServiceInstances parameter' {
            $result = ConvertTo-XurrentKnowledgeArticle -File $script:noServiceMetaFile -Service 'fallback service' -ServiceInstances 'fallback instance'
            $result.'Service Instances' | Should -Be 'fallback instance'
        }
    }

    Context 'When **ID:** appears only inside section content' {
        BeforeAll {
            # The genuine ID line is absent; **ID:** only appears mid-line inside the
            # Description/Instructions bodies. The extraction regex is anchored to the
            # start of a line, so these references must NOT be picked up as the article ID.
            $script:embeddedIdFile = New-TemporaryFile
            $content = @'
# Embedded Reference Article

## Description
This paragraph mentions **ID:** 999 in the middle of a sentence.

## Instructions
Look up the **ID:** 888 value referenced inline here.
'@
            Set-Content -Path $script:embeddedIdFile.FullName -Value $content -Encoding UTF8
        }

        AfterAll {
            Remove-Item -Path $script:embeddedIdFile.FullName -Force -ErrorAction SilentlyContinue
        }

        It 'Should not pick up a mid-line **ID:** reference as the article ID' {
            $result = ConvertTo-XurrentKnowledgeArticle -File $script:embeddedIdFile -Service 's' -ServiceInstances 'i'
            $result.ID | Should -BeNullOrEmpty
        }
    }

    Context 'When the **ID:** line is present but empty' {
        BeforeAll {
            $script:emptyIdFile = New-TemporaryFile
            $content = @'
# Article With Empty ID

**ID:** 

**Service:** real service

**Service Instances:** real instances

**Keywords:** kw1, kw2

## Description

Description body.

## Instructions

Instructions body.
'@
            Set-Content -Path $script:emptyIdFile.FullName -Value $content -Encoding UTF8
        }

        AfterAll {
            Remove-Item -Path $script:emptyIdFile.FullName -Force -ErrorAction SilentlyContinue
        }

        It 'Should return an empty ID when the **ID:** line has no value' {
            $result = ConvertTo-XurrentKnowledgeArticle -File $script:emptyIdFile -Service 's' -ServiceInstances 'i'
            $result.ID | Should -BeNullOrEmpty
        }

        It 'Should not capture subsequent metadata into the ID field' {
            $result = ConvertTo-XurrentKnowledgeArticle -File $script:emptyIdFile -Service 's' -ServiceInstances 'i'
            $result.ID | Should -Not -Match '\*\*Service'
        }

        It 'Should still correctly extract the Service when ID is empty' {
            $result = ConvertTo-XurrentKnowledgeArticle -File $script:emptyIdFile -Service 's' -ServiceInstances 'i'
            $result.Service | Should -Be 'real service'
        }

        It 'Should still correctly extract Service Instances when ID is empty' {
            $result = ConvertTo-XurrentKnowledgeArticle -File $script:emptyIdFile -Service 's' -ServiceInstances 'i'
            $result.'Service Instances' | Should -Be 'real instances'
        }

        It 'Should still correctly extract Keywords when ID is empty' {
            $result = ConvertTo-XurrentKnowledgeArticle -File $script:emptyIdFile -Service 's' -ServiceInstances 'i'
            $result.Keywords | Should -Be 'kw1, kw2'
        }

        It 'Should still correctly extract the Description body when ID is empty' {
            $result = ConvertTo-XurrentKnowledgeArticle -File $script:emptyIdFile -Service 's' -ServiceInstances 'i'
            $result.Description | Should -Be 'Description body.'
        }
    }

    Context 'When the **Service:** line is present but empty' {
        BeforeAll {
            $script:emptyServiceFile = New-TemporaryFile
            $content = @'
# Article With Empty Service

**ID:** 99

**Service:** 

**Service Instances:** real instances

## Description

Description body.
'@
            Set-Content -Path $script:emptyServiceFile.FullName -Value $content -Encoding UTF8
        }

        AfterAll {
            Remove-Item -Path $script:emptyServiceFile.FullName -Force -ErrorAction SilentlyContinue
        }

        It 'Should fall back to the -Service parameter when the **Service:** line has no value' {
            $result = ConvertTo-XurrentKnowledgeArticle -File $script:emptyServiceFile -Service 'fallback' -ServiceInstances 'fi'
            $result.Service | Should -Be 'fallback'
        }

        It 'Should not capture subsequent metadata into the Service field' {
            $result = ConvertTo-XurrentKnowledgeArticle -File $script:emptyServiceFile -Service 'fallback' -ServiceInstances 'fi'
            $result.Service | Should -Not -Match '\*\*Service Instances'
        }

        It 'Should still correctly extract Service Instances when Service is empty' {
            $result = ConvertTo-XurrentKnowledgeArticle -File $script:emptyServiceFile -Service 'fallback' -ServiceInstances 'fi'
            $result.'Service Instances' | Should -Be 'real instances'
        }
    }

    Context 'When the **Keywords:** line is present but empty' {
        BeforeAll {
            $script:emptyKwFile = New-TemporaryFile
            $content = @'
# Article With Empty Keywords

**Keywords:** 

## Description

Description body.
'@
            Set-Content -Path $script:emptyKwFile.FullName -Value $content -Encoding UTF8
        }

        AfterAll {
            Remove-Item -Path $script:emptyKwFile.FullName -Force -ErrorAction SilentlyContinue
        }

        It 'Should return empty Keywords when the **Keywords:** line has no value' {
            $result = ConvertTo-XurrentKnowledgeArticle -File $script:emptyKwFile -Service 's' -ServiceInstances 'i'
            $result.Keywords | Should -BeNullOrEmpty
        }

        It 'Should not capture section headings into the Keywords field' {
            $result = ConvertTo-XurrentKnowledgeArticle -File $script:emptyKwFile -Service 's' -ServiceInstances 'i'
            $result.Keywords | Should -Not -Match '##'
        }
    }

    Context 'When -ServiceInstances is omitted and no metadata provides a value' {
        BeforeAll {
            $script:noInstFile = New-TemporaryFile
            $content = @'
# Article Without Service Instances

## Description
Body text.
'@
            Set-Content -Path $script:noInstFile.FullName -Value $content -Encoding UTF8
        }

        AfterAll {
            Remove-Item -Path $script:noInstFile.FullName -Force -ErrorAction SilentlyContinue
        }

        It 'Should not throw when -ServiceInstances is omitted' {
            { ConvertTo-XurrentKnowledgeArticle -File $script:noInstFile -Service 'svc' } | Should -Not -Throw
        }

        It 'Should return an empty Service Instances when neither metadata nor parameter provides a value' {
            $result = ConvertTo-XurrentKnowledgeArticle -File $script:noInstFile -Service 'svc'
            $result.'Service Instances' | Should -BeNullOrEmpty
        }
    }

    Context 'When the **Service Instances:** line is present but empty' {
        BeforeAll {
            $script:emptyInstFile = New-TemporaryFile
            $content = @'
# Article With Empty Service Instances

**Service:** real service

**Service Instances:** 

**Keywords:** kw1

## Description

Description body.
'@
            Set-Content -Path $script:emptyInstFile.FullName -Value $content -Encoding UTF8
        }

        AfterAll {
            Remove-Item -Path $script:emptyInstFile.FullName -Force -ErrorAction SilentlyContinue
        }

        It 'Should fall back to the -ServiceInstances parameter when the **Service Instances:** line has no value' {
            $result = ConvertTo-XurrentKnowledgeArticle -File $script:emptyInstFile -Service 's' -ServiceInstances 'fallback inst'
            $result.'Service Instances' | Should -Be 'fallback inst'
        }

        It 'Should not capture subsequent metadata into the Service Instances field' {
            $result = ConvertTo-XurrentKnowledgeArticle -File $script:emptyInstFile -Service 's' -ServiceInstances 'fallback inst'
            $result.'Service Instances' | Should -Not -Match '\*\*Keywords'
        }

        It 'Should still correctly extract Keywords when Service Instances is empty' {
            $result = ConvertTo-XurrentKnowledgeArticle -File $script:emptyInstFile -Service 's' -ServiceInstances 'fallback inst'
            $result.Keywords | Should -Be 'kw1'
        }
    }
}
