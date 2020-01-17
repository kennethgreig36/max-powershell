[cmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]$Subscription, 
    [Parameter(Mandatory=$true)]$ResourceGroup, 
    [Parameter(Mandatory=$true)]$Region, 
    [Parameter(Mandatory=$true)]$StorageName, 
    [Parameter(Mandatory=$true)]$VaultName)


Select-AzSubscription -SubscriptionName $Subscription

# creating Resource group
Get-AzResourceGroup -Name $ResourceGroup -ErrorVariable notPresent -ErrorAction SilentlyContinue
if ($notPresent){
    New-AzResourceGroup -Name $ResourceGroup -Location $Region -Tag @{customer=$cust_name; prefix=$cust; type="resource_group"}
}

# creating storage account
Get-AzStorageAccount -Name $StorageName -ResourceGroupName $ResourceGroup  -ErrorVariable notPresent -ErrorAction SilentlyContinue
if ($notPresent) {
    New-AzStorageAccount -ResourceGroupName $ResourceGroup -AccountName $StorageName -Location $Region -SkuName Standard_LRS -Kind StorageV2 -AccessTier Cool -Tag @{customer=$cust_name; prefix=$cust; type="storage_account"}
}
Start-Sleep -s 5
$s = Get-AzStorageAccount -ResourceGroupName $ResourceGroup -Name $StorageName
$storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $ResourceGroup -Name $StorageName).Value[0]
$storageContext = New-AzStorageContext -StorageAccountName $StorageName -StorageAccountKey $storageAccountKey
$storagePolicyName = $StorageName + "-policy”

Get-AzStorageContainer -Name "recordings" -Context $storageContext   -ErrorVariable notPresent -ErrorAction SilentlyContinue
if ($notPresent) {
    $storageContainer = New-AzStorageContainer -Name "recordings" -Context $storageContext
}

Get-AzStorageContainer -Name "config" -Context $storageContext   -ErrorVariable notPresent -ErrorAction SilentlyContinue
if ($notPresent) {
    $storageContainer = New-AzStorageContainer -Name "config" -Context $storageContext
}

Get-AzStorageContainerStoredAccessPolicy -Policy $storagePolicyName -Container "recordings" -Context $storageContext   -ErrorVariable notPresent -ErrorAction SilentlyContinue
if ($notPresent) {
    $expiryTime = (Get-Date).AddYears(20)
    New-AzStorageContainerStoredAccessPolicy -Container "recordings" -Policy $storagePolicyName -Permission racwdl -ExpiryTime $expiryTime -Context $storageContext
}

$sasToken = (New-AzStorageContainerSASToken -Name "recordings" -Policy $storagePolicyName -Context $storageContext).substring(1)

# creating vault
#Get-AzKeyVault -VaultName $VaultName -ErrorVariable notPresent -ErrorAction SilentlyContinue
#if ($notPresent) {
    New-AzKeyVault -VaultName $VaultName -ResourceGroupName $ResourceGroup -Location $Region -EnabledForDeployment -EnabledForTemplateDeployment -EnabledForDiskEncryption -Tag @{customer=$cust_name; prefix=$cust; type="key_vault"}  -ErrorVariable notPresent -ErrorAction SilentlyContinue
#}
Start-Sleep -s 5

#Get a SAS key for the container, and store the value in the vault
$secretvalue = ConvertTo-SecureString "?$($sasToken)" -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName $VaultName -Name 'AzureBlobContainerSasKey' -SecretValue $secretvalue
#$secretvalue = ConvertTo-SecureString $database_password -AsPlainText -Force
#Set-AzKeyVaultSecret -VaultName $VaultName -Name 'DatabasePassword' -SecretValue $secretvalue

# add vault permissions
$servicePrincipal = Get-AzADServicePrincipal -DisplayName "maxapi"
Set-AzKeyVaultAccessPolicy -VaultName $VaultName `
  -ObjectId $servicePrincipal.Id `
  -PermissionsToSecrets get