BeforeAll {
    $script:moduleName = 'XurrentHelpers'
    Import-Module -Name $script:moduleName
}

AfterAll {
    Get-Module -Name $script:moduleName -All | Remove-Module -Force
}

Describe 'Disconnect-Xurrent' {
    BeforeEach {
        & (Get-Module $script:moduleName) {
            $script:XurrentSession = @{ BaseUrl = 'https://api.xurrent.qa/v1'; Headers = @{} }
            $script:XurrentConfig  = @{ XURRENT_ENVIRONMENT = 'QA' }
        }
    }

    Context 'When confirmed' {
        It 'Should clear XurrentSession' {
            Disconnect-Xurrent -Confirm:$false
            $session = & (Get-Module $script:moduleName) { $script:XurrentSession }
            $session | Should -BeNullOrEmpty
        }

        It 'Should clear XurrentConfig' {
            Disconnect-Xurrent -Confirm:$false
            $config = & (Get-Module $script:moduleName) { $script:XurrentConfig }
            $config | Should -BeNullOrEmpty
        }
    }

    Context 'When declined with -WhatIf' {
        It 'Should NOT clear XurrentSession' {
            Disconnect-Xurrent -WhatIf
            $session = & (Get-Module $script:moduleName) { $script:XurrentSession }
            $session | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Metadata' {
        It 'Should have ConfirmImpact of High' {
            $cmdlet = Get-Command -Name Disconnect-Xurrent
            $attr = $cmdlet.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attr.ConfirmImpact | Should -Be ([System.Management.Automation.ConfirmImpact]::High)
        }
    }
}
