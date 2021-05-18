# Module path for all functions
$ModuleRoot = $PSScriptRoot
# Load all functions
Get-ChildItem -Path $ModuleRoot\* -Exclude "Invoke-Forensic.ps1" -Filter *.ps1 | % { . $_.FullName}
