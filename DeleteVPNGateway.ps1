$loggedin = Get-AzContext
if ($loggedin.Account -eq $null){Write-Warning "You are not currently logged in. Prompting for login." 
        try {Connect-AzAccount -ErrorAction Stop}
        catch{Write-Warning "Login process failed."}
}

Get-AzSubscription | Out-Null

Select-AzSubscription -SubscriptionName "Max Silo3" 

$RG = "MRTestVPN"
$GW = "VNet6GW"


#Get Virtual Network Gateway
$GW = get-Azvirtualnetworkgateway -Name $GW -ResourceGroupName $RG 

#Check if Virtual Gateway has connections
#$Conns = get-Azvirtualnetworkgatewayconnection -ResourceGroupName $RG | where-object {$_.VirtualNetworkGateway1.Id}

$Conns | ForEach-Object {Get-AzVirtualNetworkGatewayConnection -Name $_.name -ResourceGroupName $RG}
