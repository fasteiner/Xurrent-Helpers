BeforeAll {
    $script:dscModuleName = 'XurrentHelpers'
    Import-Module -Name $script:dscModuleName

    $script:getSection = & (Get-Module $script:dscModuleName) { Get-Command Get-Section }
}

AfterAll {
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe 'Get-Section' {
    Context 'When the section exists' {
        BeforeAll {
            $script:markdown = @'
## Description
This is the description body.

## Instructions
Step 1 here.
Step 2 here.
'@
        }

        It 'Should return the body of the requested section' {
            $result = & (Get-Module $script:dscModuleName) { Get-Section -Content $args[0] -Heading 'Description' } $script:markdown
            $result | Should -Be 'This is the description body.'
        }

        It 'Should return only the body of the matching section, not adjacent sections' {
            $result = & (Get-Module $script:dscModuleName) { Get-Section -Content $args[0] -Heading 'Instructions' } $script:markdown
            $result | Should -Match 'Step 1'
            $result | Should -Not -Match 'Description'
        }
    }

    Context 'When the section does not exist' {
        It 'Should return an empty string' {
            $result = & (Get-Module $script:dscModuleName) { Get-Section -Content $args[0] -Heading 'Nonexistent' } '## Description`nSome text.'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'When the content has only one section' {
        It 'Should return the body up to end of string' {
            $md = "## OnlySection`nOnly content here."
            $result = & (Get-Module $script:dscModuleName) { Get-Section -Content $args[0] -Heading 'OnlySection' } $md
            $result | Should -Be 'Only content here.'
        }
    }
}
