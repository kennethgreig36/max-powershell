$loggedin = Get-AzContext
if ($loggedin.Account -eq $null){Write-Warning "You are not currently logged in. Prompting for login." 
        try {Connect-AzAccount -ErrorAction Stop}
        catch{Write-Warning "Login process failed."}
}

New-AzVm `
    -ResourceGroupName "MRTestVPN" `
    -Name "TestVM6" `
    -Location "UKSouth" `
    -VirtualNetworkName "TestVPNVNet6" `
    -SubnetName "FrontEnd" `
    -SecurityGroupName "TestSecurityGroup6" `
    -PublicIpAddressName "TestVMIP6" `
    #-Credential $cred