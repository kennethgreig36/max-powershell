[cmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]$CustomerPrefix, 
    [Parameter(Mandatory=$true)]$VmName,
    [Parameter(Mandatory=$true)]$RegName,
    [Parameter(Mandatory=$true)]$Region,
    [Parameter(Mandatory=$true)]$DeploymentName,
    [Parameter(Mandatory=$true)]$UpdateBlockNumber,
    [Parameter(Mandatory=$true)]$MachineType,
    [Parameter(Mandatory=$false)]$ServerSKU,
    [Parameter(Mandatory=$true)]$VaultName,
    [Parameter(Mandatory=$true)]$CustomerResourceGroupName,
    [Parameter(Mandatory=$true)]$Drives,
    [Parameter(Mandatory=$true)]$Dns)


$tagconfig = @{customer = $cust_name; prefix = $CustomerPrefix; type = "vm"; "system_type" = $DeploymentName; update_block = $UpdateBlockNumber }

if ($RegName -eq "") {
    $RegName = $VmName
}

Write-Host "============================="
Write-Host " Creating Virtual Machine"
Write-Host "============================="
Write-host "Creating VM" $VmName
Write-host ""

try {
    $vm = New-AzVMConfig -VmName $VmName `
        -VMSize $MachineType -Tags $tagconfig
}
catch {
    write-host -ForegroundColor red "failed to create VM."
    exit

}

$defaultSku = "2016-Datacenter"
if ($ServerSKU -eq "")
{
    $ServerSKU = $defaultSku
}

$vmPass = [System.Web.Security.Membership]::GeneratePassword(15,5)

# Converted to SecureString
$SecurePass = $vmPass | ConvertTo-SecureString -AsPlainText -Force
$creds = New-Object System.Management.Automation.PSCredential -ArgumentList "max", $SecurePass

Set-AzVMOperatingSystem -VM $vm -Windows -ComputerName $VmName -Credential $creds 

#add creds to customer vault
Set-AzKeyVaultSecret -VaultName $VaultName -Name $VmName -SecretValue $securePass

$nic = Get-AzNetworkInterface -Name ($VmName + "-Nic") -ResourceGroupName $CustomerResourceGroupName
Add-AzVMNetworkInterface -VM $vm -Id $nic.Id

Set-AzVMSourceImage -VM $vm -PublisherName "MicrosoftWindowsServer" -Offer "WindowsServer" -Skus $ServerSKU -Version "latest" 
Set-AzVMOSDisk -VM $vm -CreateOption fromimage -Windows -StorageAccountType Standard_LRS


Write-Host "Creating Vm in the background"
$job = New-Azvm -VM $vm -ResourceGroupName $CustomerResourceGroupName `
    -Location $Region -Tag $tagconfig -AsJob

Start-Sleep -Seconds 3

#$currentjob = Get-job -Id $job.Id


#Start-Sleep -Milliseconds 1500
write-host "Creating disks"



$lun = 1
# Check if data drives are required from json
if ($Drives.Count -gt 0)
{
    ForEach($disk in $Drives)
    {
        # Get the vm object instance again to avoid a bug where attaching multiple disks in sequence throws.
        $vm = Get-AzVm -Name $VmName -ResourceGroupName $CustomerResourceGroupName
    
        $diskConfig = New-AzDiskConfig -SkuName Standard_LRS -Location $Region.ToString() -CreateOption Empty -DiskSizeGB $disk.sizeGB 
        $dataDisk1 = New-AzDisk -DiskName ($VmName + "-datadisk" + $lun) -Disk $diskConfig -ResourceGroupName $CustomerResourceGroupName
        
        Write-host "Attaching Disk " $disk.name
    
        #Tagging disk
        Set-AzResource -ResourceId $dataDisk1.Id -Tag ($tagconfig + @{usage = $disk.usage; } ) -force
    
        $ndisk = Add-AzVMDataDisk -VM $vm -Name ($VmName + "-datadisk" + $lun) -ManagedDiskId $dataDisk1.Id -CreateOption Attach -Lun $lun 
    
        write-host "Disk has been added!"
        $lun++
    }
    # Send the update command to attach the new disks to the VM
    Write-Host "Attaching all created disks. Takes about 60 seconds"
    Update-AzVM -vm $vm -ResourceGroupName $CustomerResourceGroupName -Tag $tagconfig
}
else
{
    Write-Host "No data disk to create, continue..."
}

write-host "Adding DNS record for server"
if ($Dns.Count -gt 0)
{
    $current_sub = (Get-AzContext).Subscription
    Get-AzSubscription -SubscriptionName "MaxCore" | Select-AzSubscription
    ForEach ($dns in $Dns) 
    {
        $suffix = ""
        if ($dns.suffix.length -gt 0) {
            $suffix += $dns.suffix
        }
        if ($suffix -eq "sip")
        {
            New-AzDnsRecordSet -Name ($CustomerPrefix + $suffix) -ZoneName $dns.domain -ResourceGroupName "dns" -Ttl 600 -RecordType CNAME -DnsRecords (New-AzDnsRecordConfig -Cname ($RegName + "." + $Region.Replace(" ", "") + ".cloudapp.azure.com"))
        }
        else
        {
            New-AzDnsRecordSet -Name ($CustomerPrefix + $suffix) -ZoneName $dns.domain -ResourceGroupName "dns" -Ttl 600 -RecordType CNAME -DnsRecords (New-AzDnsRecordConfig -Cname ($VmName + "." + $Region.Replace(" ", "") + ".cloudapp.azure.com"))
        }
    }
    Get-AzSubscription -SubscriptionName $current_sub.Name | Select-AzSubscription
}
else
{
    Write-Host "No DNS records to add, continue..."
}

# Wait for jobs
Wait-Job $job
Receive-Job $job
Remove-Job $job
Write-Host "Windows Server Build completed"