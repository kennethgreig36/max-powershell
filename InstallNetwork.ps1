[cmdletBinding()]
Param(

    [Parameter(Mandatory=$true)]$CustomerPrefix, 
    [Parameter(Mandatory=$true)]$Region,
    [Parameter(Mandatory=$true)]$VmName,
    [Parameter(Mandatory=$true)]$CustomerDns, 
    [Parameter(Mandatory=$true)]$SubscriptionName, 
    [Parameter(Mandatory=$true)]$CustomerResourceGroupName, 
    [Parameter(Mandatory=$true)]$CreateVnet,
    [Parameter(Mandatory=$true)]$VnetName,
    [Parameter(Mandatory=$true)]$VNetResourceGroup,
    [Parameter(Mandatory=$true)]$VnetSubnet,
    [Parameter(Mandatory=$true)]$Firewall)

# dotsource the config deployment parameters
. .\LoadConfig.ps1


$tagconfig = @{customer = $cust_name; prefix = $CustomerPrefix; type = "network"}


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

$error.clear()

Write-host "creating public IP"
$pip = New-AzPublicIpAddress -Name ($VmName+ "-ip")  -ResourceGroupName $CustomerResourceGroupName `
    -Location $Region -AllocationMethod Static -DomainNameLabel ($VmName.ToLower()) `
    -Tag $tagconfig

if ($error) {
    write-host -ForegroundColor Yellow "Unable to create a static public IP address. Please check quota limits. Creating a dynamic IP address instead..."
    $pip = New-AzPublicIpAddress -Name ($VmName + "-dynip")  -ResourceGroupName $CustomerResourceGroupName `
        -Location $Region -AllocationMethod Dynamic -Tag $tagconfig
}

# Create an nsg
$nsg = New-AzNetworkSecurityGroup -Name ($VmName + "-nsg") -ResourceGroupName $CustomerResourceGroupName -Location $Region -Tag $tagconfig


$pri = 1100
ForEach ($ip in $Firewall.inbound)
{
    add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg -Name $ip.name -Description "Default rule" -Protocol $ip.protocol `
        -DestinationPortRange $ip.ports.Split(" ") -SourceAddressPrefix $ip.rule.Split(" ") -Access Allow -Priority $pri -Direction Inbound -SourcePortRange * -DestinationAddressPrefix * 
    $pri++
}

$pri = 1100
ForEach ($ip in $Firewall.outbound)
{
    add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg -Name $ip.name -Description "Default rule" -Protocol $ip.protocol `
        -DestinationPortRange $ip.ports.Split(" ") -DestinationAddressPrefix $ip.rule.Split(" ") -Access Allow -Priority $pri -Direction Outbound -SourcePortRange * 
    $pri++
}

$error.Clear()
Set-AzNetworkSecurityGroup -NetworkSecurityGroup $nsg | Out-Null
if ($error) {
    Write-host -ForegroundColor Red "The NSG has not been pre-configured successfully, please add rules manually"
}
#$VnetSubnet
$nic = New-AzNetworkInterface -Name ($VmName + "-Nic") -ResourceGroupName $CustomerResourceGroupName -Location $Region -SubnetId $Vnet.Subnets[0].Id `
    -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.id `
    -InternalDnsNameLabel $VmName -Tag $tagconfig
