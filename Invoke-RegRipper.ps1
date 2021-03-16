function Invoke-RegRipper()
{
    [CmdletBinding(SupportsShouldProcess=$True)]
    param(
        [string]
        $Hive,

        [string]
        $ComputerName,

        [string]
        $UserName,

        [switch]
        $Automatic,

        [switch]
        $Print,

        [switch]
        $List

    )

    DynamicParam
    {
        Get-DynamicFlowParamRR -Params $PSBoundParameters
    }
    Process
    {
        if ($Print)
        {
            write-verbose "Printing profile or plugins"
            foreach ($p in $PSBoundParameters.Plugins)
            {
                write $p
                get-content .\plugins\$p.pl
                write ""
            }
            foreach ($p in ($PSBoundParameters.Profile))
            {
                get-content .\plugins\$p
                write ""
            }
            return
        }
        elseif ($PSBoundParameters.Profile -or $PSBoundParameters.Plugins)
        {
            write-verbose "Run RR..."
            foreach ($p in $PSBoundParameters.Plugins)
            {
                write "Processing hive $Hive using plugin $p"
                & ".\rip.exe" -r $Hive -p $p
                write ""
            }

            if ($PSBoundParameters.Profile)
            {
                write "Processing hive $Hive using profile $($PSBoundParameters.Profile)"
                & ".\rip.exe" -r $Hive -f $PSBoundParameters.Profile
                write ""
            }
        }
    }
}

# Below is the code for the dynamic parameters for plugins

function Get-DynamicFlowParamRR()
{
    $Dictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
    New-DynamicParam -Name Plugins -type string[] -ValidateSet $(((gci .\plugins\*.pl).name) -replace "\.pl","") -DPDictionary $Dictionary

    New-DynamicParam -Name Profile -type string -ValidateSet $(((gci .\plugins\* | ? {!($_.Extension)}).name)) -DPDictionary $Dictionary

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
