[cmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]$Region, 
    [Parameter(Mandatory=$true)]$VmName, 
    [Parameter(Mandatory=$true)]$CustomerResourceGroupName)


#These are the keys for enrolling servers in the correct workspace for update management
$PublicSettingsMMA = @{"workspaceId" = "99031bcf-80c0-4c0d-bc60-0dc7ea78df45"}
$ProtectedSettingsMMA = @{"workspaceKey" = "Jr7yJ2IFje01FEWT9PzhTzpt6Mqmsq1OZ2jXS6O8++VM2Vea1DIx46zPY1fNs1ppxW/XTHC1Ib8FFqOxYNtg7Q=="}


write-host "Deploying extensions..."
    
[System.Collections.Hashtable]$protectedsettings = @{"site24x7LicenseKey" = "5555b0130ac447d0d8616cadce82ac606fe8a555"}
[System.Collections.Hashtable]$settingstring = @{"site24x7AgentType" = "azurevmextnwindowsserver"}

Set-AzVMExtension -Settings $settingstring  `
    -ProtectedSettings $protectedsettings `
    -Publisher Site24x7 -ExtensionType Site24x7WindowsServerExtn -Version 1.5 `
    -Name Site24x7 -ResourceGroupName $CustomerResourceGroupName -Location $Region -VMName $VmName -AsJob | Out-Null

Set-AzVMExtension -ExtensionName "Microsoft.EnterpriseCloud.Monitoring" `
    -ResourceGroupName $CustomerResourceGroupName `
    -VMName $VmName `
    -Publisher "Microsoft.EnterpriseCloud.Monitoring" `
    -ExtensionType "MicrosoftMonitoringAgent" `
    -TypeHandlerVersion 1.0 `
    -Settings $PublicSettingsMMA `
    -ProtectedSettings $ProtectedSettingsMMA `
    -Location $Region `
    -asjob | Out-Null

$settingString = $null

[string]$settingString = '
{ 
"AntimalwareEnabled": true, 
"RealtimeProtectionEnabled": true, 
"ScheduledScanSettings": { 
  "isEnabled": true, 
  "day": 1, 
  "time": 120, 
  "scanType": "Full" },
"Exclusions": { 
  "Paths": "d:\\;d:\\Max;", 
  "Processes": "Qbit.Calypso.CommServer.UI.Console.Display.exe;Mercury.exe" }
}
'

# retrieve the most recent version number of the extension
$allVersions= (Get-AzVMExtensionImage -Location $Region -PublisherName “Microsoft.Azure.Security” -Type “IaaSAntimalware”).Version
$versionString = $allVersions[($allVersions.count)-1].Split(“.”)[0] + “.” + $allVersions[($allVersions.count)-1].Split(“.”)[1]
# set the extension using prepared values
# ****—-Use this script till cmdlets address the -SettingsString format issue we observed ****—-
Set-AzVMExtension -ResourceGroupName $CustomerResourceGroupName -Location $Region -VMName $VmName -Name "IaaSAntimalware" -Publisher “Microsoft.Azure.Security” -ExtensionType “IaaSAntimalware” -TypeHandlerVersion $versionString -SettingString $settingString