$loggedin = Get-AzContext
if ($loggedin.Account -eq $null){Write-Warning "You are not currently logged in. Prompting for login." 
        try {Connect-AzAccount -ErrorAction Stop}
        catch{Write-Warning "Login process failed."}
}
#Provide the subscription Id where the VMs reside
#Silo3
$subscriptionId = "5d4d9f0b-0298-469f-890c-5959bcf3e265"

#Provide the name of the csv file to be exported
$reportName = "Silo3VMs.csv"
$reportFullPath = "$home/documents/$reportName"
Select-AzSubscription $subscriptionId

$report = @()
$vms = Get-AzVM -Status

foreach ($vm in $vms) { 
    $vmStats = [pscustomobject]@{
    VMName = $vm.Name
    OSType = $vm.StorageProfile.OsDisk.OsType
    Location = $vm.Location
    Status = $vm.PowerState
    }

    $report+=$vmStats
}
$report | ft

$fileExists = Test-Path $reportFullPath
if($fileExists -eq $False){
    $report | Export-CSV $reportFullPath
}
else
{
    Write-Warning 'File already present'
}