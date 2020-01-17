#Supress break in changes warnings for cmdlet New-AzVirtualNetworkSubnetConfig
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

#https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-connect-multiple-policybased-rm-ps

$loggedin = Get-AzContext
if ($loggedin.Account -eq $null){Write-Warning "You are not currently logged in. Prompting for login." 
        try {Connect-AzAccount -ErrorAction Stop}
        catch{Write-Warning "Login process failed."}
}

Get-AzSubscription

Select-AzSubscription -SubscriptionName "Max Silo3"

$Sub6          = "Max Silo3"
$RG6           = "MRTestVPN"
$Location6     = "UK South"
$VNetName6     = "TestVPNVNet6"
$FESubName6    = "FrontEnd"
$BESubName6    = "Backend"
$GWSubName6    = "GatewaySubnet"
$VNetPrefix41  = "10.41.0.0/16"
$VNetPrefix42  = "10.42.0.0/16"
$FESubPrefix6  = "10.41.0.0/24"
$BESubPrefix6  = "10.42.0.0/24"
$GWSubPrefix6  = "10.42.255.0/27"
#$DNS1          = "8.8.8.8"
$GWName6       = "VNet6GW"
$GW1IPName6    = "VNet6GWIP1"
$GW1IPconf6    = "gw1ipconf6"
$Connection6  = "VNet6toVNet1"

#$LNGName      = "MainOffice"
#$LNGPrefix61   = "10.61.0.0/16"
#$LNGPrefix62   = "10.62.0.0/16"
#$LNGIP        = "51.132.13.22"

#Max Office public IP
#"80.169.18.244"

New-AzResourceGroup -Name $RG6 -Location $Location6

$fesub6 = New-AzVirtualNetworkSubnetConfig -Name $FESubName6 -AddressPrefix $FESubPrefix6
$besub6 = New-AzVirtualNetworkSubnetConfig -Name $BESubName6 -AddressPrefix $BESubPrefix6
$gwsub6 = New-AzVirtualNetworkSubnetConfig -Name $GWSubName6 -AddressPrefix $GWSubPrefix6

New-AzVirtualNetwork -Name $VNetName6 -ResourceGroupName $RG6 -Location $Location6 -AddressPrefix $VNetPrefix41,$VNetPrefix42 -Subnet $fesub6,$besub6,$gwsub6

$gw1pip6    = New-AzPublicIpAddress -Name $GW1IPName6 -ResourceGroupName $RG6 -Location $Location6 -AllocationMethod Dynamic
$vnet6      = Get-AzVirtualNetwork -Name $VNetName6 -ResourceGroupName $RG6
# it's important that you always name your gateway subnet specifically 'GatewaySubnet'
$subnet6    = Get-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $vnet6
$gw1ipconf6 = New-AzVirtualNetworkGatewayIpConfig -Name $GW1IPconf6 -Subnet $subnet6 -PublicIpAddress $gw1pip6

#Gateway SKUs
#Basic, Standard, HighPerformance, UltraPerformance, VpnGw1, VpnGw2, VpnGw3, VpnGw4, VpnGw5, VpnGw1AZ, VpnGw2AZ, VpnGw3AZ, VpnGw4AZ, VpnGw5AZ, ErGw1AZ, ErGw2AZ, ErGw3AZ
#VpnGw1AZ, VpnGw2AZ and VpnGw3AZ are the zone-resilient versions of VpnGw1, VpnGw2 and VpnGw3.
#https://azure.microsoft.com/en-gb/pricing/details/vpn-gateway/
New-AzVirtualNetworkGateway -Name $GWName6 -ResourceGroupName $RG6 -Location $Location6 -IpConfigurations $gw1ipconf6 -GatewayType Vpn -VpnType RouteBased -GatewaySku Standard

#New-AzLocalNetworkGateway -Name $LNGName -ResourceGroupName $RG1 -Location $Location1 -GatewayIpAddress $LNGIP -AddressPrefix $LNGPrefix61,$LNGPrefix62

#$ipsecpolicy6 = New-AzIpsecPolicy -IkeEncryption AES256 -IkeIntegrity SHA384 -DhGroup DHGroup24 -IpsecEncryption AES256 -IpsecIntegrity SHA256 -PfsGroup None -SALifeTimeSeconds 14400 -SADataSizeKilobytes 102400000
#$vnet1gw = Get-AzVirtualNetworkGateway -Name $GWName1  -ResourceGroupName $RG1
#$lng6 = Get-AzLocalNetworkGateway  -Name $LNGName -ResourceGroupName $RG1

# Create an S2S VPN connection and apply the IPsec/IKE policy created in the previous step.
# "-UsePolicyBasedTrafficSelectors $True" which enables policy-based traffic selectors on the connection.
#New-AzVirtualNetworkGatewayConnection -Name $Connection16 -ResourceGroupName $RG1 -VirtualNetworkGateway1 $vnet1gw -LocalNetworkGateway2 $lng6 -Location $Location1 -ConnectionType IPsec -UsePolicyBasedTrafficSelectors $True -IpsecPolicies $ipsecpolicy6 -SharedKey 'AzureA1b2C3'
#$connection6.UsePolicyBasedTrafficSelectors
#$RG1          = "TestPolicyRG1"
#$Connection16 = "VNet1toSite6"
#$connection6  = Get-AzVirtualNetworkGatewayConnection -Name $Connection16 -ResourceGroupName $RG1

#Set-AzVirtualNetworkGatewayConnection -VirtualNetworkGatewayConnection $connection6 -UsePolicyBasedTrafficSelectors $True

# To Disable UsePolicyBasedTrafficSelectors
# The following example disables the policy-based traffic selectors option, but leaves the IPsec/IKE policy unchanged:
# Set-AzVirtualNetworkGatewayConnection -VirtualNetworkGatewayConnection $connection6 -UsePolicyBasedTrafficSelectors $False

Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "false"