$loggedin = Get-AzContext
if ($loggedin.Account -eq $null){Write-Warning "You are not currently logged in. Prompting for login." 
        try {Connect-AzAccount -ErrorAction Stop}
        catch{Write-Warning "Login process failed."}
}
#Provide the subscription Id where the VMs reside
#Silo3
$subscriptionId = "5d4d9f0b-0298-469f-890c-5959bcf3e265"

#Provide the name of the csv file to be exported
$reportName = "GoogleChrome.csv"
$reportFullPath = "$home/documents/$reportName"
Select-AzSubscription $subscriptionId
#$removeapps = @('Google Chrome')

$report = @()

$VMList = Get-AzVM
    foreach($VM in $VMList)
    {
        $VMInst = Get-AzVM -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name -Status
        if($VMInst.OsName -and $VMInst.OsName.Contains("Windows")) {

         $result = Invoke-AzVMRunCommand -ResourceGroupName $VM.ResourceGroupName -VMName $vm.Name -CommandId 'RunPowerShellScript' `
         -ScriptPath '.\DevOps\Azure Auditing Scripts\UninstallGoogleChrome.ps1'
          if ($result.Value[0].Message -eq $true) {
             $outputObject = [pscustomobject]@{ VMName = $VM.Name; "Google Chrome Installed" = "Yes" }
             $trueResults.Add($outputObject)
          }
          
                   
        }
    }
