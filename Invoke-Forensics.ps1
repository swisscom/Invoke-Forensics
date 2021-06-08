# Module path for all functions
$ModuleRoot = $PSScriptRoot
# Load all functions
Get-ChildItem -Path $ModuleRoot\* -Exclude "Invoke-Forensics.ps1" -Filter *.ps1 | % { . $_.FullName}
