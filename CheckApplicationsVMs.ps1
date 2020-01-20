#Script to check if Google Chrome is installed
$remoteCommand = 'Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | `
Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | Where-Object {$_.DisplayName -like "Google Chrome"}'

#Check if logged into Azure
$loggedin = Get-AzContext
if ($loggedin.Account -eq $null){Write-Warning "You are not currently logged in. Prompting for login." 
        try {Connect-AzAccount -ErrorAction Stop}
        catch{Write-Warning "Login process failed."}
}
#Provide the subscription Id where the VMs reside
#Silo3
$subscriptionId = "5d4d9f0b-0298-469f-890c-5959bcf3e265"

#Script Path
$script = "$home\documents\DevOps\Azure Auditing Scripts\CheckApplications.ps1"

#Create a local file based on the script defined as $remoteCommand
Set-Content -Path $script -Value $remoteCommand

#Provide the name of the csv file to be exported
$reportName = "GoogleChrome.csv"
$reportFullPath = "$home\documents\$reportName"
Select-AzSubscription $subscriptionId
#$removeapps = @('Google Chrome')

#TODO report array
$report = @()

#Loop through each VM in the subscription
$VMList = Get-AzVM
    foreach($VM in $VMList)
    {
        $VMInst = Get-AzVM -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name -Status
        if($VMInst.OsName -and $VMInst.OsName.Contains("Windows")) {
    
         $result = Invoke-AzVMRunCommand -ResourceGroupName $VM.ResourceGroupName -VMName $vm.Name -CommandId 'RunPowerShellScript' `
         -ScriptPath $script
         
              if($result.Value[0].Message) {
                $outputObject = [pscustomobject]@{ VMName = $VM.Name; "Google Chrome Installed" = "Yes" }
                Write-Host $outputObject
              } else {
                $outputObject = [pscustomobject]@{ VMName = $VM.Name; "Google Chrome Installed" = "No" }
                Write-Host $outputObject
              }
                   
        }
    }


#Remove the local file after we have finished using it
Remove-Item .\CheckApplications.ps1