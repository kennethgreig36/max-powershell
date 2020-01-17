# Verify for each customer all is in order

[cmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]$customerName
)

#Connect-AzAccount

. $PSScriptRoot\MaxOpsApiClient.ps1 
#$customerName = "cc33"


$global:resultSet = @()

$customer = GetCustomerByName $customerName

$sqlToken = Get-ADToken

Get-AzContext
Set-AzContext -SubscriptionName $customer.resources.azureSubscriptionName

function SetPropertyAndLog($propertyName, $propertyValue, $message) {
    $global:resultSet += , @{
        Name = $propertyName
        Value = $propertyValue
        Log = $message
    }
    Write-Host $message
}


function AssertVmSettingCorrect($propertyName, $sourceValue, $expectedValue, $trueValue, $falseValue, $message) {
    if ($sourceValue -eq $expectedValue) {
        SetPropertyAndLog $propertyName $trueValue "[PASS]$message : PASS"
    }
    else {
        SetPropertyAndLog $propertyName $falseValue "[FAIL]$message : FAIL"
    }
}

function AssertVmSettingNotNull($propertyName, $sourceValue, $trueValue, $falseValue, $message) {
    if ($sourceValue -ne $null) {
        AssertVmSettingCorrect $propertyName $true $true $true $false $message
    }
    else {
        AssertVmSettingCorrect $propertyName $false $true $true $false $message
    }
}

#stage
SetPropertyAndLog "customerName" $customerName "[INFO][Customer]$customerName"

# Vm Present
$vm = Get-AzVm | Where { $_.Name -eq $customer.resources.hostVmDnsName }
AssertVmSettingNotNull "mvmPresent" $vm $true $false "[Vm] MVM $($customer.resources.hostVmDnsName)"
SetPropertyAndLog "mvmOsVersion" $vm.StorageProfile.ImageReference.Sku "[Vm][Version] $($vm.StorageProfile.ImageReference.Sku)"

if ($customer.resources.hostVmDnsName -ne $customer.resources.telephonyVmDnsName) {
    $telVm = Get-AzVm | Where { $_.Name -eq $customer.resources.telephonyVmDnsName }
    AssertVmSettingNotNull "tvmPresent" $telVm $true $false "[Vm] TVM $($customer.resources.telephonyVmDnsName)"
    if ($telVm -ne $null) {
        SetPropertyAndLog "tvmOsVersion" $telVm.StorageProfile.ImageReference.Sku "[Vm][Version]TVM $($vm.StorageProfile.ImageReference.Sku)"
        $tvmPresent = $true
    }
}
else {
    SetPropertyAndLog "tvmPresent" "N/A" "Single Box"
    $tvmPresent = $false
}

# Check the vm is in it's own resource group
AssertVmSettingCorrect "mvmResourceGroupValid" $vm.ResourceGroupName $($customerName + "_rg") $true $false "[ResourceGroup] MVM Unique Resource Group"

if ($tvmPresent -eq $true) {
    AssertVmSettingCorrect "tvmResourceGroupValid" $telVm.ResourceGroupName $($customerName + "_rg") $true $false "[ResourceGroup] TVM Unique Resource Group"
}

# Vault present
$vault = Get-AzKeyVault -VaultName $customer.resources.vaultName
AssertVmSettingNotNull "vaultPresent" $vault $true $false "[Vault] Valid Vault"

# storage account working
$storage = Get-AzStorageAccount | Where { $_.StorageAccountName -eq $customer.resources.azureStorageAccountName }

# Container present
AssertVmSettingNotNull "storagePresent" $storage $true $false "[Storage] Valid Storage"
if ($storage -ne $null) {
    $recContainer = Get-AzStorageContainer -Name $customer.resources.azureBlobContainerName -Context $storage.Context

    AssertVmSettingNotNull "storageRecPresent" $recContainer $true $false "[Storage] Valid Recording Container"
    if ($recContainer -ne $null) {
        AssertVmSettingCorrect "storageNotPublic" $recContainer.PublicAccess $false $true "DANGER" "[Storage] Container not Public"
        if ($recContainer.PublicAccess -eq $true) {
            SetPropertyAndLog "storageNotPublicDANGER" "DANGER" "*** ALERT DANGER PUBLIC BLOB FOUND ***"
        }
    }    
}

# DB password working
try {
    $sqltest = RunSqlQueryOnCustDb $customerName "SELECT NOW()" $sqlToken
    AssertVmSettingNotNull "sqlPass" $sqlTest $true $false "[Database] Sql Connection"
}
catch {
    AssertVmSettingNotNull "sqlPass" $null $true $false "[Database] Sql Connection"
}

# Server vm password correct
$vmSecret = Get-AzKeyVaultSecret -VaultName $vault.VaultName -Name $customer.resources.hostVmDnsName
$telSecret = Get-AzKeyVaultSecret -VaultName $vault.VaultName -Name $customer.resources.telephonyVmDnsName

if ($vmSecret -eq $null) {
    Write-Host "[Vault] Missing VM Login Credentials"
    AssertVmSettingCorrect "vaultMvmPass" $false $true $true $false "[Vault] MVM Credentials"
    $vmSecretPlain = "M@x4dm1n@1977"
}
else {
    $vmSecretPlain = $vmSecret.SecretValueText    
}
$vmRet = Invoke-AzVMRunCommand -Name $vm.Name -ResourceGroupName $vm.ResourceGroupName -CommandId 'RunPowerShellScript' -ScriptPath $PSScriptRoot\CheckVmPasswordValid.ps1 -Parameter @{"User" = "max"; "Pass" = $vmSecretPlain}
$state = $vmRet.Value[0].Message | ConvertFrom-Json

AssertVmSettingCorrect "vaultMvmPass" $true $true $true $false "[Vault] MVM Password Found"
AssertVmSettingCorrect "mvmAutoLogin" $state.AutoLoginPresent $true $true $false "[Autologin] MVM Auto Login"
AssertVmSettingCorrect "mvmAutoLoginUser" $state.AutoLoginPresent $true $true $false "[Autologin] MVM Auto Login User is Max"
AssertVmSettingCorrect "mvmAutoLoginPass" $state.AutoLoginPasswordMatch $true $true $false "[Autologin] MVM Auto Login Password"
AssertVmSettingCorrect "mvmPassValid" $state.PasswordCorrect $true $true $false "[Server] MVM Password"
AssertVmSettingCorrect "mvmStartupScript" $state.BootScriptExists $true $true $false "[Startup] MVM Boot Script"


if ($tvmPresent -eq $true) {
    if ($telSecret -eq $null) {
        AssertVmSettingCorrect "vaultTvmPass" $false $true $true $false "[Vault] TVM Credentials"
        $telSecretPlain = "M@x4dm1n@1977"
    }
    else {
       $telSecretPlain = $telSecret.SecretValueText
    }

    $vmRet = Invoke-AzVMRunCommand -Name $vm.Name -ResourceGroupName $vm.ResourceGroupName -CommandId 'RunPowerShellScript' -ScriptPath $PSScriptRoot\CheckVmPasswordValid.ps1 -Parameter @{"User" = "max"; "Pass" = $telSecretPlain} 
    $state = $vmRet.Value[0].Message | ConvertFrom-Json

    AssertVmSettingCorrect "vaultTvmPass" $true $true $true $false "[Vault] TVM Password Found"
    AssertVmSettingCorrect "tvmAutoLogin" $state.AutoLoginPresent $true $true $false "[Autologin] TVM Auto Login"
    AssertVmSettingCorrect "tvmAutoLoginUser" $state.AutoLoginPresent $true $true $false "[Autologin] TVM Auto Login User is Max"
    AssertVmSettingCorrect "tvmAutoLoginPass" $state.AutoLoginPasswordMatch $true $true $false "[Autologin] TVM Auto Login Password"
    AssertVmSettingCorrect "tvmPassValid" $state.PasswordCorrect $true $true $false "[Server] TVM Password"
    AssertVmSettingCorrect "tvmStartupScript" $state.BootScriptExists $true $true $false "[Startup] TVM Boot Script"
}

# Rep password working

# customer db settings are correct
function AssertSettingCorrect($appConfig, $propertyName, $settingName, $expectedValue, $message) {
    $settingSection = ($appConfig.application_config_idResultSet | Where {$_.config_key -eq $settingName }).application_name
    $settingValue = ($appConfig.application_config_idResultSet | Where {$_.config_key -eq $settingName }).config_value

    AssertVmSettingCorrect $propertyName $settingValue $expectedValue $true $false "[Settings][$settingSection]$message"
}

# Get all app config settings
$appConfig = RunSqlQueryOnCustDb $customerName "SELECT * from application_config" $sqlToken
$testSecret = $vmSecretPlain

# Do the checks
if ($tvmPresent -eq $true) {
    $testSecret = $telSecretPlain
}

AssertSettingCorrect $appConfig "settings_recordingsuncusername" "recordingsuncusername" "max" "UNC auth Username"
AssertSettingCorrect $appConfig "settings_recordingsuncdomain" "recordingsuncdomain" $telVm.Name "UNC auth Domain"
AssertSettingCorrect $appConfig "settings_recordingsuncpassword" "recordingsuncpassword" $testSecret "UNC auth Password"

# Check File Manager section
AssertSettingCorrect $appConfig "settings_uncusername" "uncusername" "max" "UNC Tel auth Username"
AssertSettingCorrect $appConfig "settings_mercurydomain" "mercurydomain" $telVm.Name "UNC Tel auth Domain"
AssertSettingCorrect $appConfig "settings_uncpassword" "uncpassword" $testSecret "UNC Tel auth Password"

AssertSettingCorrect $appConfig "settings_compsdomain" "compsdomain" $vm.Name "UNC Comps auth Domain"

#calypso check
$calServerIp = RunSqlQueryOnCustDb $customerName "SELECT server_address FROM calypso_server" $sqlToken
$nic = Get-AzNetworkInterface -ResourceId $vm.NetworkProfile.NetworkInterfaces[0].Id
try {
    # it's an Ip
    Write-Host "[Calypso][Server] Server address is set to an IP Address. This should be a hostname"
    $ipAddr = [IPAddress]$calServerIp.server_addressResultSet[0].server_address
    AssertVmSettingCorrect "calypsoValid" $nic.IpConfigurations[0].PrivateIpAddress $ipAddr.IPAddressToString $true $false "[Calypso][Server][WARNICalypso Server Name Valid"
}
catch {
    # It's a hostname
    AssertVmSettingCorrect "calypsoValid" $vm.Name $calServerIp.server_addressResultSet[0].server_address $true $false "[Calypso][Server]Calypso Server Name Valid"
}
# Need to check calypso "server" field too

# Get the app version
$maxVersion = RunSqlQueryOnCustDb $customerName "SELECT db_version FROM calypso_server" $sqlToken
SetPropertyAndLog "maxVersion" $maxVersion.db_versionResultSet[0].db_version "[INFO][Version]$($maxVersion.db_versionResultSet[0].db_version)"


#print summary
$resultSet.GetEnumerator() | ForEach {[PSCustomObject]$_} | Format-Table -AutoSize
return $resultSet