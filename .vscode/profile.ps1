./build.ps1 -tasks minibuild
$version = dotnet-gitversion /showvariable MajorMinorPatch /nocache
$ModuleFile = ".\output\module\XurrentHelpers\$version\XurrentHelpers.psd1"
Import-Module $ModuleFile
