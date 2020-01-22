# Creates a S2S IPSEC IKEv2 VPN to Azure and a VPN between 2 VNets (1 and 6)

#Supress breaking changes warnings for cmdlet New-AzVirtualNetworkSubnetConfig
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

#https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-connect-multiple-policybased-rm-ps

$loggedin = Get-AzContext
if ($loggedin.Account -eq $null){Write-Warning "You are not currently logged in. Prompting for login." 
        try {Connect-AzAccount -ErrorAction Stop}
        catch{Write-Warning "Login process failed."}
}

Get-AzSubscription

Select-AzSubscription -SubscriptionName "Microsoft Partner Network"

$Sub           = "Microsoft Partner Network"
$RG            = "MRTestVPN"
$Location      = "West Europe"
$VNetName1     = "TestVPNVNet1"
$VNetName6     = "TestVPNVNet6"
$FESubName1    = "FrontEnd"
$BESubName1    = "Backend"
$FESubName6    = "FrontEnd"
$BESubName6    = "Backend"
$GWSubName1    = "GatewaySubnet1"
$GWSubName6    = "GatewaySubnet6"
$VNetPrefix11  = "10.11.0.0/24"
$VNetPrefix12  = "10.12.0.0/24"
$VNetPrefix41  = "10.41.0.0/16"
$VNetPrefix42  = "10.42.0.0/16"
$FESubPrefix6  = "10.41.0.0/24"
$BESubPrefix6  = "10.42.0.0/24"
$GWSubPrefix1  = "10.11.255.0/27"
$GWSubPrefix6  = "10.42.255.0/27"
$DNS1          = "8.8.8.8"
$GWName1       = "VNet1GW"
$GWName6       = "VNet6GW"
$GW1IPName1    = "VNet1GWIP1"
$GW1IPconf1    = "gw1ipconf1"
$GW1IPName6    = "VNet6GWIP1"
$GW1IPconf6    = "gw1ipconf6"
$Connection1  = "VNet1toVNet6"
$Connection6  = "VNet6toVNet1"

$LNGName      = "MainOffice"
$LNGPrefix61   = "10.61.0.0/16"
$LNGPrefix62   = "10.62.0.0/16"
$LNGIP        = "51.132.13.22"

#Max Office public IP
#"80.169.18.244"

New-AzResourceGroup -Name $RG -Location $Location

$fesub1 = New-AzVirtualNetworkSubnetConfig -Name $FESubName1 -AddressPrefix $FESubPrefix1
$besub1 = New-AzVirtualNetworkSubnetConfig -Name $BESubName1 -AddressPrefix $BESubPrefix1
$gwsub1 = New-AzVirtualNetworkSubnetConfig -Name $GWSubName1 -AddressPrefix $GWSubPrefix1

$fesub6 = New-AzVirtualNetworkSubnetConfig -Name $FESubName6 -AddressPrefix $FESubPrefix6
$besub6 = New-AzVirtualNetworkSubnetConfig -Name $BESubName6 -AddressPrefix $BESubPrefix6
$gwsub6 = New-AzVirtualNetworkSubnetConfig -Name $GWSubName6 -AddressPrefix $GWSubPrefix6

New-AzVirtualNetwork -Name $VNetName1 -ResourceGroupName $RG -Location $Location -AddressPrefix $VNetPrefix11,$VNetPrefix12 -Subnet $fesub1,$besub1,$gwsub1
New-AzVirtualNetwork -Name $VNetName6 -ResourceGroupName $RG -Location $Location -AddressPrefix $VNetPrefix41,$VNetPrefix42 -Subnet $fesub6,$besub6,$gwsub6

$gw1pip1    = New-AzPublicIpAddress -Name $GW1IPName1 -ResourceGroupName $RG -Location $Location -AllocationMethod Dynamic
$vnet1      = Get-AzVirtualNetwork -Name $VNetName1 -ResourceGroupName $RG
# It's important that you always name your gateway subnet specifically 'GatewaySubnet'
$subnet1    = Get-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet1" -VirtualNetwork $vnet1
$gw1ipconf1 = New-AzVirtualNetworkGatewayIpConfig -Name $GW1IPconf1 -Subnet $subnet1 -PublicIpAddress $gw1pip1

$gw1pip6    = New-AzPublicIpAddress -Name $GW1IPName6 -ResourceGroupName $RG -Location $Location -AllocationMethod Dynamic
$vnet6      = Get-AzVirtualNetwork -Name $VNetName6 -ResourceGroupName $RG
# It's important that you always name your gateway subnet specifically 'GatewaySubnet'
$subnet6    = Get-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet6" -VirtualNetwork $vnet6
$gw1ipconf6 = New-AzVirtualNetworkGatewayIpConfig -Name $GW1IPconf6 -Subnet $subnet6 -PublicIpAddress $gw1pip6

# Gateway SKUs
# Basic, Standard, HighPerformance, UltraPerformance, VpnGw1, VpnGw2, VpnGw3, VpnGw4, VpnGw5, VpnGw1AZ, VpnGw2AZ, VpnGw3AZ, VpnGw4AZ, VpnGw5AZ, ErGw1AZ, ErGw2AZ, ErGw3AZ
# VpnGw1AZ, VpnGw2AZ and VpnGw3AZ are the zone-resilient versions of VpnGw1, VpnGw2 and VpnGw3.
# NB.The Basic SKU is not supported for OpenVPN.
# https://azure.microsoft.com/en-gb/pricing/details/vpn-gateway/

Write-Host "Creating Gateways, this may take a while..."
New-AzVirtualNetworkGateway -Name $GWName6 -ResourceGroupName $RG -Location $Location -IpConfigurations $gw1ipconf6 -GatewayType Vpn -VpnType RouteBased -GatewaySku Standard
New-AzLocalNetworkGateway -Name $LNGName -ResourceGroupName $RG1 -Location $Location1 -GatewayIpAddress $LNGIP -AddressPrefix $LNGPrefix61,$LNGPrefix62

$ipsecpolicy6 = New-AzIpsecPolicy -IkeEncryption AES256 -IkeIntegrity SHA384 -DhGroup DHGroup24 -IpsecEncryption AES256 -IpsecIntegrity SHA256 -PfsGroup None -SALifeTimeSeconds 14400 -SADataSizeKilobytes 102400000
$vnet1gw = Get-AzVirtualNetworkGateway -Name $GWName6  -ResourceGroupName $RG
$lng6 = Get-AzLocalNetworkGateway -Name $LNGName -ResourceGroupName $RG

# Create an S2S VPN connection and apply the IPsec/IKE policy created in the previous step.
# "-UsePolicyBasedTrafficSelectors $True" which enables policy-based traffic selectors on the connection.
New-AzVirtualNetworkGatewayConnection -Name $Connection16 -ResourceGroupName $RG -VirtualNetworkGateway1 $vnet1gw -LocalNetworkGateway2 $lng6 -Location $Location -ConnectionType IPsec -UsePolicyBasedTrafficSelectors $True -IpsecPolicies $ipsecpolicy6 -SharedKey 'AzureA1b2C3'
$connection6.UsePolicyBasedTrafficSelectors
$RG1          = "TestPolicyRG1"
$Connection16 = "VNet1toSite6"
$connection6  = Get-AzVirtualNetworkGatewayConnection -Name $Connection16 -ResourceGroupName $RG

Set-AzVirtualNetworkGatewayConnection -VirtualNetworkGatewayConnection $connection6 -UsePolicyBasedTrafficSelectors $True

# To Disable UsePolicyBasedTrafficSelectors
# The following example disables the policy-based traffic selectors option, but leaves the IPsec/IKE policy unchanged:
Set-AzVirtualNetworkGatewayConnection -VirtualNetworkGatewayConnection $connection6 -UsePolicyBasedTrafficSelectors $False

Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "false"

# Enable OpenVPN on the gateway
# https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-howto-openvpn
$gw = Get-AzVirtualNetworkGateway -ResourceGroupName $RG -name $name
Set-AzVirtualNetworkGateway -VirtualNetworkGateway $gw -VpnClientProtocol OpenVPN

# https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-download-vpndevicescript
# List the available VPN device models and versions
# Get-AzVirtualNetworkGatewaySupportedVpnDevice -Name $GWName -ResourceGroupName $RG

# Download the configuration script for the connection
#Get-AzVirtualNetworkGatewayConnectionVpnDeviceConfigScript -Name $Connection -ResourceGroupName $RG -DeviceVendor Cisco -DeviceFamily ASA -FirmwareVersion 9.8
# https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-3rdparty-device-config-cisco-asa