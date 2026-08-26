function New-XurrentKnowledgeArticleTemplate
{
    <#
        .SYNOPSIS
        Creates a Markdown template file for a Xurrent knowledge article.

        .DESCRIPTION
        Writes a *KnowledgeArticle.md template to the specified folder with the correct
        structure expected by ConvertTo-XurrentKnowledgeArticle: an H1 heading for the
        Subject, empty **ID:**, **Service:**, and **Service Instances:** metadata lines
        (left blank so the ConvertTo fallbacks still apply), a **Keywords:** line, and
        ## Description and ## Instructions sections.

        .PARAMETER Name
        The name of the knowledge article, used as the H1 heading and filename prefix.
        The file is written as <Name>KnowledgeArticle.md.

        .PARAMETER Path
        The folder in which to create the template file.
        Defaults to the current working directory.

        .EXAMPLE
        New-XurrentKnowledgeArticleTemplate -Name 'HowToResetPassword'
        Creates HowToResetPasswordKnowledgeArticle.md in the current directory.

        .EXAMPLE
        New-XurrentKnowledgeArticleTemplate -Name 'VPN Setup' -Path C:\Articles
        Creates 'VPN SetupKnowledgeArticle.md' in C:\Articles.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([System.IO.FileInfo])]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]
        $Path = (Get-Location).Path
    )

    process
    {
        $fileName = '{0}KnowledgeArticle.md' -f $Name
        $filePath = Join-Path -Path $Path -ChildPath $fileName

        $template = @"
# $Name

**ID:**

**Service:**

**Service Instances:**

**Keywords:** keyword1, keyword2

## Description

Describe the knowledge article here.

## Instructions

Provide step-by-step instructions here.
"@

        if ($PSCmdlet.ShouldProcess($filePath, 'Create knowledge article template'))
        {
            Set-Content -Path $filePath -Value $template -Encoding UTF8
            Get-Item -Path $filePath
        }
    }
}
