Function Invoke-KapeUnpack()
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [Parameter(Mandatory=$true)]
        [string]
        $TOutPattern,

        [switch]
        $SkipUnzipEvidenceZip,

        [switch]
        $WhatIf,

        [switch]
        $Recurse = $false
    )

    $WhatIfPassed = ($PSBoundParameters.ContainsKey('whatif') -and $PSBoundParameters['whatif'].ispresent)
    $PathZIP = ""
    $PathVHDXZIP = ""
    $VHDXZipFiles = ""
    $PathTOut = ""

    # Unzip whole evidence package before unzipping the tout vhdx zip
    if (!($SkipUnzipEvidenceZip))
    {
        if ($Path -match "\.zip$")
        {
            write-verbose "Processing single ZIP $Path"
            $PathZIP = $Path
        }
        else
        {
            write-verbose "Processing folder $Path"
            $PathZIP = join-path $Path "\*.zip"
        }

        gci $PathZIP | % { Expand-Archive -Path $_.FullName -DestinationPath $_.Directory -whatif:$WhatIfPassed}
    }

    if ($WhatIfPassed -and (!($SkipUnzipEvidenceZip)))
    {
        write-verbose "Skip rest of unzipping due to WhatIf"
        return
    }

    $PathTOut = join-path $($Path -replace ".zip", "") $TOutPattern

    write-verbose "Processing tout folder $PathTOut"
    if (!(test-path $PathTOut))
    {
        write-error "Path to $PathTOut not found."
        return
    }

    $VHDXZipFiles = gci $(join-path $PathTOut "\*.zip")
    foreach ($z in $VHDXZipFiles)
    {
        if (!(test-path $($z.FullName -replace ".zip", ".vhdx")))
        {
            write "[*] VHDX not found for $($z.FullName), unzipping..."
            unzip $z.FullName -d $z.Directory
        } else {
            write "[*] VHDX already extracted from $($z.FullName)"
        }
    }
}

Function Remove-VHDX()
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [switch]
        $WhatIf
    )

    $WhatIfPassed = ($PSBoundParameters.ContainsKey('whatif') -and $PSBoundParameters['whatif'].ispresent)

    get-childitem -Path "$Path" -Recurse *.vhdx | rm -Verbose -WhatIf:$WhatIfPassed
}

Function Invoke-KapeOnMultipleImages()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $KapeEvidenceFolder, # KAPE evidence folder where collection files are stored

        [Parameter(Mandatory=$true)]
        [string]
        $TOutPattern, # KAPE evidence folder where tout (vhdx) files are stored

        [Parameter(Mandatory=$true)]
        [string]
        $Destination, # KAPE output folder, new folders per server are created

        [Parameter(Mandatory=$true)]
        [string]
        $HostnamePattern, # Regex pattern to extract hostname out of the path to the vhdx file

        [string]
        $Mvars, # Module variables forwarded to KAPE

        [string]
        $DriveLetterCollection = "C",

        [switch]
        $SkipUnzip,

        [switch]
        $SkipUnzipEvidenceZip
    )

    DynamicParam
    {
        Get-DynamicFlowParamModules -Params $PSBoundParameters
    }
    Process
    {
        $TOutPath = ""

        if (!($SkipUnzip))
        {
            Invoke-KapeUnpack -Path $KapeEvidenceFolder -TOut $TOutPattern -SkipUnzipEvidenceZip:$SkipUnzipEvidenceZip
        }

        $TOutPath = join-path $($KapeEvidenceFolder -replace ".zip", "") $TOutPattern

        $VHDXFiles = gci $(join-path $TOutPath "\*.vhdx")
        foreach ($f in $VHDXFiles) {
            write "[*] Processing $f"

            $Drive = Mount-VHDX -VHDXFile $f.FullName
            if (!($Drive))
            {
                write-error "Error in mounting, missing drive name, already mounted?"
                continue
            }
            write "[*] Drive $Drive is used"

            $server = $f.directory -match $HostnamePattern
            $server = $Matches[1]

            $output = $(join-path $Destination "Analysis-$server")

            write "[*] Run KAPE for $server, Dest: $output"

            if ($mvars)
            {
                $mvars_combined = "computerName:$server^$mvars"
            }
            else
            {
                $mvars_combined = "computerName:$server"
            }

            Invoke-Kape -msource "$Drive`:\$DriveLetterCollection" -mdest $output -module $PSBoundParameters.Module -mvars $mvars_combined

            sleep 5

            $res = Dismount-DiskImage $f.FullName
            write "[*] Image attached: $($res.Attached)"

            write "Finished.`n"
        }
    }
}

function Mount-VHDX ()
{
    [cmdletbinding()]
    param(
        [string]
        $VHDXFile
    )

    $VolumesBefore = Get-Volume

    write-verbose "Processing $VHDXFile"

    try {
        $res = Mount-DiskImage $VHDXFile -ea stop
        write-verbose "[*] Image attached: $($res.Attached)"
    }
    catch  {
        $res = Dismount-DiskImage $VHDXFile
        write-verbose "[*] Image attached: $($res.Attached)"

        $VolumesBefore = Get-Volume
        $res = Mount-DiskImage $VHDXFile
        write-verbose "[*] Image attached: $($res.Attached)"
    }

    $VolumesAfter = Get-Volume
    $Drive = (diff $VolumesBefore $VolumesAfter -property driveletter).driveletter
    $Drive
}

Function Invoke-KapeFileCollection()
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $KapeEvidenceFolder, # KAPE evidence folder where collection files are stored

        [Parameter(Mandatory=$true)]
        [string]
        $TOutPattern, # KAPE evidence folder where tout (vhdx) files are stored

        [Parameter(Mandatory=$true)]
        [string]
        $Destination, # File collection output folder, new folders per server are created

        [Parameter(Mandatory=$true)]
        [string]
        $HostnamePattern, # Regex pattern to extract hostname out of the path to the vhdx file,

        [string]
        [Parameter(Mandatory=$true)]
        $FileNamePattern,

        [switch]
        $SkipUnzip,

        [switch]
        $SkipUnzipEvidenceZip
    )
    $TOutPath = ""
    $output = ""

    if (!($SkipUnzip))
    {
        Invoke-KapeUnpack -Path $KapeEvidenceFolder -TOut $TOutPattern -SkipUnzipEvidenceZip:$SkipUnzipEvidenceZip
    }

    $TOutPath = join-path $($KapeEvidenceFolder -replace ".zip", "") $TOutPattern

    $VHDXFiles = gci $(join-path $TOutPath "\*.vhdx")
    foreach ($f in $VHDXFiles) {
        write "[*] Processing $f"

        $res = ""
        $targets = ""

        $Drive = Mount-VHDX -VHDXFile $f.FullName
        if (!($Drive))
        {
            write-error "Error in mounting, missing drive name, already mounted?"
            continue
        }
        write "[*] Drive $Drive is used"

        $server = $f.directory -match $HostnamePattern
        $server = $Matches[1]

        write "[*] Run file collection for $server on mounted $Drive, Dest: $Destination\$server"

        $targets = gci "$Drive`:\" -Recurse -Filter $FileNamePattern

        if (!$targets){ write "[!] No files found for $Drive`:\ using pattern $FileNamePattern...?" }

        foreach ($t in $targets)
        {
            $output = $(Join-Path "$Destination\$server" ( $($t.directory) -replace ":","") )

            $res = mkdir $output -force
            if ($res) {
                copy-item -force -path ($t.fullname) -dest $output
                write "[*] File $($t.FullName) copied."
            }
        }

        sleep 2

        $res = Dismount-DiskImage $f.FullName
        write "[*] Image attached: $($res.Attached)"

        write "[*] Finished.`n"
    }
}

function Invoke-Kape()
{
    [CmdletBinding(SupportsShouldProcess=$True)]
    param(
        [string[]]
        $tsource,

        [string[]]
        $msource,

        [string[]]
        $tdest,

        [string[]]
        $mdest,

        [string]
        $mvars,

        [switch]
        $print
    )

    DynamicParam
    {
        Get-DynamicFlowParamKAPE -Params $PSBoundParameters
    }
    Process
    {
        if ($PSBoundParameters.Print)
        {
            foreach ($t in ($PSBoundParameters.Target))
            {
                gc .\Targets\*\$t.tkape
                write ""
            }
            foreach ($m in ($PSBoundParameters.Module))
            {
                gc .\Modules\*\$m.mkape
                write ""
            }
            return
        }
        if ($PSBoundParameters.Target)
        {
            .\kape.exe --tsource $tsource --tdest $tdest --target $($PSBoundParameters.Target -join ",")
        }
        if ($PSBoundParameters.Module)
        {
            .\kape.exe --msource $msource --mdest $mdest --module $($PSBoundParameters.Module -join ",") --mvars $mvars
        }
    }
}

function Search-KapeFile()
{
    [CmdletBinding(DefaultParameterSetName="All")]
    param(
        [Parameter(ParameterSetName="All")]
        [string]
        $Filter,

        [Parameter(ParameterSetName="Specific")]
        [string]
        $FilterDescription,

        [Parameter(ParameterSetName="Specific")]
        [string]
        $FilterID,

        [Parameter(ParameterSetName="Specific")]
        [string]
        $FilterTargetName,

        [Parameter(ParameterSetName="Specific")]
        [string]
        $FilterCategory,

        [Parameter(ParameterSetName="Specific")]
        [string]
        $FilterPath,

        [Parameter(ParameterSetName="Specific")]
        [string]
        $FilterFileMask,

        [switch]
        $Print,

        [switch]
        $ShortList,

        [switch]
        $MatchAllOfThem,

        [Parameter(ParameterSetName="All")]
        [Parameter(ParameterSetName="Specific")]
        [Parameter(ParameterSetName="Modules")]
        [switch]
        $OnlyModules,

        [Parameter(ParameterSetName="All")]
        [Parameter(ParameterSetName="Specific")]
        [Parameter(ParameterSetName="Targets")]
        [switch]
        $OnlyTargets
    )
    $Pattern = @()
    $Scope = @(".\Modules\",".\Targets\")
    $ScopeFilter = @("*.mkape","*.tkape")
    if ($OnlyModules)
    {
        $Scope = ".\Modules\"
        $ScopeFilter = "*.mkape"
    }
    if ($OnlyTargets)
    {
        $Scope = ".\Targets\"
        $ScopeFilter = "*.tkape"
    }

    if ($Filter)
    {
        $Pattern += ".*$Filter.*"
    }
    else
    {
        if ($FilterDescription)
        {
            $Pattern += "^Description:.*$FilterDescription.*"
        }
        if ($FilterID)
        {
            $Pattern += "^ID:.*$FilterID.*"
        }
        if ($FilterTargetName)
        {
            $Pattern += "^\s*Name:.*$FilterTargetName.*"
        }
        if ($FilterCategory)
        {
            $Pattern += "^\s*Category.*$FilterCategory.*"
        }
        if ($FilterPath)
        {
            $Pattern += "^\s*Path:.*$FilterPath.*"
        }
        if ($FilterFileMask)
        {
            $Pattern += "^\s*FileMask:.*$FilterFileMask.*"
        }
    }

    if ($Pattern)
    {
        write-verbose "MatchAllOfThem: $MatchAllOfThem, Pattern $($Pattern -join ","), Scope: $Scope, ScopeFilter: $ScopeFilter"

        if ($MatchAllOfThem)
        {
            $files = gci -Recurse -file $Scope -Include $ScopeFilter | MultiSelect-String $Pattern | select name, fullname

        }
        else
        {
            $files = gci -Recurse -file $Scope -Include $ScopeFilter | where { $_ | sls $Pattern } | select name, fullname
        }

        if ($Print)
        {
            $files = $files | sort name
            foreach ($f in $files)
            {
                if ($f.name -match ".tkape$")
                {
                    write "$($f.name) $($f.FullName -replace ".*\\targets\\",".\Targets\")"
                    write ""
                    Invoke-Kape -target $($f.name -replace ".tkape","") -print
                }
                else
                {
                    write "$($f.name) $($f.FullName -replace ".*\\modules\\",".\Modules\")"
                    write ""
                    Invoke-Kape -module $($f.name -replace ".mkape","") -print
                }
            }
        }
        elseif ($ShortList)
        {
            $files = $files | sort name
            foreach ($f in $files)
            {
                if ($f.name -match ".tkape$")
                {
                    write "$($f.name) $($f.FullName -replace ".*\\targets\\",".\Targets\")"
                }
                else
                {
                    write "$($f.name) $($f.FullName -replace ".*\\modules\\",".\Modules\")"
                }
            }
        }
        else
        {
            $files
        }
    }
}

filter MultiSelect-String( [string[]]$Patterns )
{
  foreach( $Pattern in $Patterns ) {
    $matched = @($_ | Select-String -Pattern $Pattern -AllMatches)
    if( -not $matched ) {
      return
    }
  }
  $_
}

# Below is the code for the dynamic parameters for modules and targets

function Get-DynamicFlowParamKAPE()
{
    $Dictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

    New-DynamicParam -Name Module -type string[] -ValidateSet $(((gci -Recurse  .\modules\* -Filter *.mkape).name) -replace "\.mkape","") -DPDictionary $Dictionary

    New-DynamicParam -Name Target -type string[] -ValidateSet $(((gci .\targets\*\*.tkape).name) -replace "\.tkape","") -DPDictionary $Dictionary

    $Dictionary
}

function Get-DynamicFlowParamModules()
{
    $Dictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

    New-DynamicParam -Name Module -type string[] -ValidateSet $(((gci -Recurse  .\modules\* -Filter *.mkape).name) -replace "\.mkape","") -DPDictionary $Dictionary -Mandatory

    $Dictionary
}

# Generic dynamic param function

Function New-DynamicParam ()
{
    param(
        [string]
        $Name,

        [System.Type]
        $Type = [string],

        [string[]]
        $Alias = @(),

        [string[]]
        $ValidateSet,

        [switch]
        $Mandatory,

        [string]
        $ParameterSetName="__AllParameterSets",

        [int]
        $Position,

        [switch]
        $ValueFromPipelineByPropertyName,

        [string]
        $HelpMessage,

        [validatescript({
            if(-not ( $_ -is [System.Management.Automation.RuntimeDefinedParameterDictionary] -or -not $_) )
            {
                Throw "DPDictionary must be a System.Management.Automation.RuntimeDefinedParameterDictionary object, or not exist"
            }
            $True
        })]
        $DPDictionary = $false

    )
    $ParamAttr = New-Object System.Management.Automation.ParameterAttribute
    $ParamAttr.ParameterSetName = $ParameterSetName
    if($Mandatory)
    {
        $ParamAttr.Mandatory = $True
    }
    if($Position -ne $null)
    {
        $ParamAttr.Position=$Position
    }
    if($ValueFromPipelineByPropertyName)
    {
        $ParamAttr.ValueFromPipelineByPropertyName = $True
    }
    if($HelpMessage)
    {
        $ParamAttr.HelpMessage = $HelpMessage
    }

    $AttributeCollection = New-Object -type System.Collections.ObjectModel.Collection[System.Attribute]
    $AttributeCollection.Add($ParamAttr)

    if($ValidateSet)
    {
        $ParamOptions = New-Object System.Management.Automation.ValidateSetAttribute -ArgumentList $ValidateSet
        $AttributeCollection.Add($ParamOptions)
    }

    if($Alias.count -gt 0) {
        $ParamAlias = New-Object System.Management.Automation.AliasAttribute -ArgumentList $Alias
        $AttributeCollection.Add($ParamAlias)
    }

    $Parameter = New-Object -TypeName System.Management.Automation.RuntimeDefinedParameter -ArgumentList @($Name, $Type, $AttributeCollection)

    if($DPDictionary)
    {
        $DPDictionary.Add($Name, $Parameter)
    }
    else
    {
        $Dictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $Dictionary.Add($Name, $Parameter)
        $Dictionary
    }
}
