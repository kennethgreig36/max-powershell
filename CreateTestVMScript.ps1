$loggedin = Get-AzContext
if ($loggedin.Account -eq $null){Write-Warning "You are not currently logged in. Prompting for login." 
        try {Connect-AzAccount -ErrorAction Stop}
        catch{Write-Warning "Login process failed."}
}

$LocationName = "UKWest"
$SubscriptionName = "Max Silo3"
$ResourceGroupName = "VPNTest_RG"
$ComputerName = "TestVM"
$VMName = "TestVM"
$VMSize = "Standard_B2ms"
$NetworkName = "TestVNet"
$NICName = "TestNIC"
$SubnetName = "TestSubnet"
$SubnetAddressPrefix = "10.0.0.0/24"
$VnetAddressPrefix = "10.0.0.0/16"


# set subscription
Select-AzSubscription $SubscriptionName

# creating Resource group
Get-AzResourceGroup -Name $ResourceGroupName -ErrorVariable notPresent -ErrorAction SilentlyContinue
if ($notPresent){
    New-AzResourceGroup -Name $ResourceGroupName -Location $Region
}

# creating network
Write-Host "============================="
Write-Host " Installing Network"
Write-Host "============================="

if ($CreateVnet -eq $true)
{
    Write-host "Unimplemented. You will likely end up with no network, or at best a wonky one"
    # TODO make this create a vnet and then set the appropriate values as below
}
else
{
    $vnet = Get-AzVirtualNetwork -Name $VnetName -ResourceGroupName $VNetResourceGroup
}

if ($vnet -eq $null)
{
    Write-host "Bad Vnet!"
    exit 1
}

#create public ip
$pip = New-AzPublicIpAddress -Name ($VmName + "-ip")  -ResourceGroupName $ResourceGroupName `
    -Location $LocationName -AllocationMethod Static -DomainNameLabel ($VmName.ToLower()) `

# create nsg
$NSG = New-AzNetworkSecurityGroup -Name ($VmName + "-nsg") -ResourceGroupName $ResourceGroupName -Location $LocationName

# set vm credentials
$Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword);

Write-Host "============================="
Write-Host " Creating Virtual Machine"
Write-Host "============================="
Write-host "Creating VM" $VMName
Write-host ""

try {
    $VirtualMachine = New-AzVMConfig -VmName $VMName `
        -VMSize $VMSize
}
catch {
    write-host -ForegroundColor red "failed to create VM."
    exit

}

# vm settings
$vmpass = "8LvoX224!"
$SecurePass = $vmPass | ConvertTo-SecureString -AsPlainText -Force
$creds = New-Object System.Management.Automation.PSCredential -ArgumentList "max", $SecurePass
Set-AzVMOperatingSystem -VM $VMName -Windows -ComputerName $VMName -Credential $creds 
AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
Set-AzVMSourceImage -VM $vm -PublisherName "MicrosoftWindowsServer" -Offer "WindowsServer" -Skus $ServerSKU -Version "latest" 
Set-AzVMOSDisk -VM $vm -CreateOption fromimage -Windows -StorageAccountType Standard_LRS

# create vm
Write-Host "Creating Vm in the background"
New-AzVM -ResourceGroupName $ResourceGroupName -Location $LocationName -VM $VirtualMachine -Verbose

Write-Host "Windows Server Build completed"