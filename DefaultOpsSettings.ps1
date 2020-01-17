# Default config settings for the powershell scripts

$key = (Get-AzKeyVaultSecret -VaultName 'max-internal-vault' -Name 'MaxEncryptionKey').SecretValueText
$iv = (Get-AzKeyVaultSecret -VaultName 'max-internal-vault' -Name 'MaxEncryptionIV').SecretValueText

$opsVault = @{
    Name = "max-internal-vault"
    ResourceGroup = "internal_rg"
    Subscription = "DevOps"
    Sas = "?st=2019-09-15T12%3A28%3A13Z&se=2050-09-16T12%3A28%3A00Z&sp=rl&sv=2018-03-28&sr=c&sig=EvHAPGMi04FoxBs4TcHrtPY4AYBXbw2UnTpbpwaVL60%3D"
    BootScriptsUri = "https://maxopsstorage.blob.core.windows.net/vmbootscripts"
}

$maxcontactCertificate = @{
    Name = "maxcontact-wildcard"
    SecretName = "maxcontact-wildcard-password"
}