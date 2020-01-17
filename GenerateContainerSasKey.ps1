##
# Description:
# Generate SAS key at thew ** Container ** level
#
# Default permission:  Read/ Write/ Delete
#
# MaxContact Azure server installation and configuration scripts
# Barry Carter
# Aug-2019
# v1.0

Param(
    [Parameter(Mandatory=$true)]$ResourceGroupName,
    [Parameter(Mandatory=$true)]$StorageAccountName,
    [Parameter(Mandatory=$true)]$Container,
    [Parameter(Mandatory=$true)]$ExpiryHours,
    [Parameter(Mandatory=$true)]$ExpiryYears,
    [Parameter()]$Permission)

Write-Host "Generating Sas Key for Container $Container"
$key = Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
$ctx = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $key.value[0]

$perm = "rwd"

if  ($Permission.length -gt 0) {
    $perm = $Permission
}

$sas = New-AzStorageContainerSASToken -Name 'config' `
   -Permission $perm `
   -StartTime (Get-Date) `
   -ExpiryTime (Get-Date).AddHours($ExpiryHours).AddYears($ExpiryYears) `
   -Context $ctx 

return $sas