Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

#https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-connect-multiple-policybased-rm-ps

$loggedin = Get-AzContext
if ($loggedin.Account -eq $null){Write-Warning "You are not currently logged in. Prompting for login." 
        try {Connect-AzAccount -ErrorAction Stop}
        catch{Write-Warning "Login process failed."}
}

Get-AzSubscription

Select-AzSubscription -SubscriptionName "Max Silo3"

$Sub          = "Max Silo3"
$RG           = "MRTestVPN"
$Location     = "UK South"
$VNetName     = "TestVPNVNet"
$FESubName    = "FrontEnd"
$BESubName    = "Backend"
$GWSubName    = "GatewaySubnet"
$VNetPrefix41  = "10.41.0.0/16"
$VNetPrefix42  = "10.42.0.0/16"
$FESubPrefix  = "10.41.0.0/24"
$BESubPrefix  = "10.42.0.0/24"
$GWSubPrefix  = "10.42.255.0/27"
$DNS          = "8.8.8.8"
$GW1Name      = "VNet1GW"
$GW1IPName    = "VNet1GWIP1"
$GW1IPconf    = "gw1ipconf"
$connection   = "VNet1toVNet6"
$connection2   = "VNet6toVNet1"
$vnet1gw       = Get-AzVirtualNetworkGateway -Name "VNet1GW" -ResourceGroupName $RG
$vnet6gw       = Get-AzVirtualNetworkGateway -Name "VNet6GW" -ResourceGroupName $RG

$LNGName      = "MainOffice"
$LNGPrefix61   = "10.61.0.0/16"
$LNGPrefix62   = "10.62.0.0/16"
$LNGIP        = "51.132.13.22"

#$ipsecpolicy = New-AzIpsecPolicy -IkeEncryption AES256 -IkeIntegrity SHA384 -DhGroup DHGroup24 -IpsecEncryption AES256 -IpsecIntegrity SHA256 -PfsGroup None -SALifeTimeSeconds 14400 -SADataSizeKilobytes 102400000
$lng = Get-AzLocalNetworkGateway  -Name $LNGName -ResourceGroupName $RG


# Create an S2S VPN connection and apply the IPsec/IKE policy created in the previous step.
# "-UsePolicyBasedTrafficSelectors $True" which enables policy-based traffic selectors on the connection.
New-AzVirtualNetworkGatewayConnection -Name $connection -ResourceGroupName $RG -VirtualNetworkGateway1 $vnet1gw -VirtualNetworkGateway2 $vnet6gw -Location $Location -ConnectionType Vnet2Vnet -SharedKey 'AzureA1b2C3'
$connection  = Get-AzVirtualNetworkGatewayConnection -Name $connection -ResourceGroupName $RG

New-AzVirtualNetworkGatewayConnection -Name $connection2 -ResourceGroupName $RG -VirtualNetworkGateway1 $vnet6gw -VirtualNetworkGateway2 $vnet1gw -Location $Location -ConnectionType Vnet2Vnet -SharedKey 'AzureA1b2C3'
$connection  = Get-AzVirtualNetworkGatewayConnection -Name $connection -ResourceGroupName $RG


#Set-AzVirtualNetworkGatewayConnection -VirtualNetworkGatewayConnection $connection -UsePolicyBasedTrafficSelectors $True

# To Disable UsePolicyBasedTrafficSelectors
# The following example disables the policy-based traffic selectors option, but leaves the IPsec/IKE policy unchanged:
Set-AzVirtualNetworkGatewayConnection -VirtualNetworkGatewayConnection $connection -UsePolicyBasedTrafficSelectors $False

Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "false"