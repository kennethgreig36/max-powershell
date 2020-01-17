$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
Set-Location $scriptPath
. .\Util\MaxOpsApiClient.ps1

$settings = Get-Content "silosettings.json" | ConvertFrom-Json

$regions = $settings.silos | Group-Object -Property location -NoElement 


function bye() {
    Param($ErrorString)
    Write-Host $ErrorString
    Write-Host "Quitting. Bye!"
    exit 1
}

function GetOption() {
    Param($optionsText, $PromptText, [bool]$BailOnBadInput = $false)

    while($true) {
        Write-Host $OptionsText
        Write-Host ""
        $Ret = Read-Host -Prompt $PromptText

        try {
            $retNum = [int] $Ret
            return $retNum
        }
        catch {
            Write-Host "Error: '$Ret' is not valid input"
            if ($BailOnBadInput -eq $true) { throw "Bad" }
            Write-Host " Try Again `n"
        }
    }
}


$optionsText = 
@" 
`nAvailable Regions
=================
"@

$i = 0
ForEach ($region in $regions) {
    $optionsText += "`n $i) $($region.Name) "
    $i++
}

try {
    $region_num = GetOption $optionsText "Select Region Number"
    $region_name = ""
    $region_name = $regions[[int]$region_num].Name
    if ($region_name -eq "") { throw }
}
catch {
    bye "Invalid input '$region_num'. Please enter a number!" 
}


$optionsText = "`nSubscriptions For Region $region_name `n"
$optionsText += "================="


$i = 0
$subs = @()
ForEach ($set in $settings.silos) {
    if ($set.location -eq $region_name) {
        $optionsText += "`n $i) $($set.Name)"
        $subs += ,$set
        $i++
    }
}

try {
    $sub_num = GetOption $optionsText "Select Subscription Number"
    $sub_name = ""
    $sub_name = $subs[$sub_num].Name
    if ($region_name -eq "") { throw }
}
catch {
    bye "Invalid input '$sub_num'. Please enter a number!" 
}

foreach ($set in $subs) {
    if ($set.Name -eq $sub_name) {
        $SelectedSet = $set
        break
    }
}

Write-Host  "(12 characters max) no special chars or spaces"
$CustomerFullName = Read-Host -Prompt 'Enter Customer Full Name'

$CustomerPrefix = Read-Host -Prompt 'Enter Customer Prefix'
#Check for length and any non alphanumeric character while allowing hyphens otherwise the resources won't be created in Azure
if ($CustomerPrefix.Length -gt 12){
    Write-Warning 'The name is too long-please choose one 12 characters or less'

     while($CustomerPrefix.Length -gt 12){
        $CustomerPrefix = Read-Host -Prompt 'Enter Customer Prefix'
    }
}
if($CustomerPrefix -notmatch '^[a-zA-Z0-9-]*$'){
    while($CustomerPrefix -notmatch '^[a-zA-Z0-9-]*$'){
        Write-Warning 'The name cannot contain spaces or special characters, please try again'
        $CustomerPrefix = Read-Host -Prompt 'Enter Customer Prefix'
    }
}


$DeploymentTypes = @(
    @{ id=0; name = "1 Box. 1: Comps + Mercury + Brekeke"; templateFile = "DeploymentTemplates/maxbuildsettings-1box.json" },
    @{ id=1; name = "1 Box. 1: Comps + Mercury + Shared Brekeke"; templateFile = "DeploymentTemplates/maxbuildsettings-1box-shared-bre.json" },
    @{ id=2; name = "1 Box. 1: Comps + Shared Mercury"; templateFile = "DeploymentTemplates/maxbuildsettings-1box-shared-tel.json" },
	@{ id=3; name = "1 Box. 1: Totally Empty"; templateFile = "DeploymentTemplates/maxbuildsettings-1box-empty.json" },
    @{ id=4; name = "1 Box. 1: No Comps + IIS + PGAdmin"; templateFile = "DeploymentTemplates/maxbuildsettings-1box-no-comps.json" },
    @{ id=5; name = "1 Box. 1: Brekeke"; templateFile = "DeploymentTemplates/maxbuildsettings-1box-brekeke.json" },
    @{ id=6; name = "2 Box. 1: Comps  2: Mercury"; templateFile = "DeploymentTemplates/maxbuildsettings-2box-nobre.json" },
    @{ id=7; name = "2 Box. 1: Comps  2: Mercury + Brekeke"; templateFile = "DeploymentTemplates/maxbuildsettings-2box.json" },
    @{ id=8; name = "3 Box. 1: Comps  2: Mercury + Brekeke  3: Web";templateFile = "DeploymentTemplates/maxbuildsettings-3box.json" }
)


$optionsText = "`nDeployment Types `n"
$optionsText += "================= `n"
$i = 0
ForEach ($dep in $DeploymentTypes) {
    $optionsText += "$i) $($dep.name) `n"
    $i++
}

$DeploymentType = GetOption $optionsText "Deployment Type Number"
$Deployment = $DeploymentTypes[$DeploymentType]
$NoDataDrive = @(2, 3, 4, 5)

if (-not $NoDataDrive.Contains($DeploymentType)) {
    Write-Host 
    $HDSize = GetOption "How big should the Recordings drive be? (Default 200GB)" "Disk Size"
    if ($HDSize -eq "") {
        $HDSize = "200"
    }
}

$ServerTypes = ("Standard_B2ms", "Standard_B4ms", "Standard_DS11_v2")
$optionsText = "Server Types `n"
$optionsText += "================= `n"

$i = 0
ForEach ($svr in $ServerTypes) {
    $optionsText += "$i) $svr `n"
    $i++
}

$ServerNum = GetOption $optionsText "Server Type Number"

$ServerType = $ServerTypes[$ServerNum]

$optionsText = "Database Server `n"
$optionsText += "================= `n"
$optionsText += "0) Use Existing Server `n"

#FIXME TODO
$DbServersFull = GetDatabases
$DbServers = $DbServersFull | Select -Property name # ("UKSouth-HA01", "UKSouth-HA02", "NorthEurope-HA01", "UKWest-HA01")

$i = 1
ForEach ($dbs in $DbServers) {
    $optionsText += "$i) $($dbs.name) `n"
    $i++
}

$ServerNum = GetOption $optionsText "Database Number"
$DbServerName = $DbServers[$ServerNum - 1].name

$CreateDb = "true"
if ($ServerNum -eq 0) {
    Write-Host "Choosing Existing DB server means you have to input the details into maxbuildsettings.json manually until we enhance this part of the script"
    $CreateDb = "false"
    $DbServerName = ""
}

$UpdateBlock = GetOption "Choose a windows update block number" "Update Block (0-7)"

if ($Deployment.id -eq 2) { # single box, shared tel
    $sharedTel = Read-Host -Prompt "Enter Tel VM box *Name*"
}

$sharedReg = Read-Host -Prompt "Where is your Brekeke? (Enter for local)"

$vnetyn = Read-Host -Prompt "Default VNET from selected Subscription is $($SelectedSet.vnet), do you want to override? (Y/N)" # Requires creating a new VNET in Azure manually
if ($vnetyn.ToLower() -eq "y") {
    Write-Host "Overriding vnet settings, please make sure you have created a new VNET in Azure and enter the followings:"
    $SelectedSet.vnet = Read-Host -Prompt "Vnet Name"
    $SelectedSet.resgroup = Read-Host -Prompt "Vnet Resource Group"
    $SelectedSet.subnet = Read-Host -Prompt "Vnet Subnet"
}

cp maxbuildsettings.json maxbuildsettings-$(get-date -f yyyy-MM-dd_hh-mm-ss).json

$Deployment.TemplateFile
cp $Deployment.TemplateFile maxbuildsettings.json


# TODO Load this as JSON and use property accessors
((Get-Content -path maxbuildsettings.json -Raw) -replace '{CUSTOMERNAME}', $CustomerFullName) | Set-Content -Path maxbuildsettings.json
((Get-Content -path maxbuildsettings.json -Raw) -replace '{CUSTOMERPREFIX}', $CustomerPrefix) | Set-Content -Path maxbuildsettings.json
((Get-Content -path maxbuildsettings.json -Raw) -replace '{CREATEDB}', $CreateDb) | Set-Content -Path maxbuildsettings.json
((Get-Content -path maxbuildsettings.json -Raw) -replace '{DBSERVERNAME}', $DbServerName) | Set-Content -Path maxbuildsettings.json
((Get-Content -path maxbuildsettings.json -Raw) -replace '{SUBSCRIPTION}', $SelectedSet.siloname) | Set-Content -Path maxbuildsettings.json
((Get-Content -path maxbuildsettings.json -Raw) -replace '{REGION}', $SelectedSet.location) | Set-Content -Path maxbuildsettings.json
((Get-Content -path maxbuildsettings.json -Raw) -replace '{UPDATEBLOCK}', $UpdateBlock) | Set-Content -Path maxbuildsettings.json
((Get-Content -path maxbuildsettings.json -Raw) -replace '{SERVERTYPE}', $ServerType) | Set-Content -Path maxbuildsettings.json
((Get-Content -path maxbuildsettings.json -Raw) -replace '{VNETNAME}', $SelectedSet.vnet) | Set-Content -Path maxbuildsettings.json
((Get-Content -path maxbuildsettings.json -Raw) -replace '{VNETRG}', $SelectedSet.resgroup) | Set-Content -Path maxbuildsettings.json
((Get-Content -path maxbuildsettings.json -Raw) -replace '{VNETSUBNET}', $SelectedSet.subnet) | Set-Content -Path maxbuildsettings.json
((Get-Content -path maxbuildsettings.json -Raw) -replace '{RECORDINGSIZE}', $HDSize) | Set-Content -Path maxbuildsettings.json
((Get-Content -path maxbuildsettings.json -Raw) -replace '{TELSERVERSIP}', $sharedTel) | Set-Content -Path maxbuildsettings.json
((Get-Content -path maxbuildsettings.json -Raw) -replace '{TELSERVERREG}', $sharedReg) | Set-Content -Path maxbuildsettings.json

Write-Host "Configuration written to maxbuildsettings.json"

$yn = Read-Host -Prompt "Do you want to run it? (Y/N)"
if ($yn.ToLower() -eq "y") {
    .\Install.ps1
}

